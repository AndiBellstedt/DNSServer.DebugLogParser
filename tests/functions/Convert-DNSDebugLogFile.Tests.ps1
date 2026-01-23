BeforeAll {
    $moduleRoot = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
    $functionName = 'Convert-DNSDebugLogFile'
    $functionFilePath = Join-Path $moduleRoot "functions\$functionName.ps1"
}

Describe "Convert-DNSDebugLogFile - Parameter Contract" {
    Context "Basic Parameter Validation" {
        It "Should have a param block with CmdletBinding" {
            $content = Get-Content -Path $functionFilePath -Raw
            $content | Should -Match '\[CmdletBinding\(' -Because "Function should have CmdletBinding attribute"
            $content | Should -Match 'param\s*\('
        }

        It "Should support ShouldProcess for destructive operations" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $functionDef = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $args[0].Name -eq $functionName
                }, $true) | Select-Object -First 1

            $cmdletBinding = $functionDef.Body.ParamBlock.Attributes |
            Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }

            $cmdletBinding | Should -Not -BeNullOrEmpty

            # Check for SupportsShouldProcess parameter
            $shouldProcessArg = $cmdletBinding.NamedArguments |
            Where-Object { $_.ArgumentName -eq 'SupportsShouldProcess' }

            # If function has RemoveSourceFile or CompressOutput, it should support ShouldProcess
            # This is a recommended best practice for functions that perform destructive operations
            if ($null -eq $shouldProcessArg) {
                Set-ItResult -Inconclusive -Because "Function has RemoveSourceFile parameter but does not implement SupportsShouldProcess"
            } else {
                $shouldProcessArg.Argument.Extent.Text | Should -Be '$true'
            }
        }

        It "Should have pipeline support for primary input parameters" {
            $content = Get-Content -Path $functionFilePath -Raw
            $content | Should -Match 'ValueFromPipeline\s*=\s*\$true'
            $content | Should -Match 'ValueFromPipelineByPropertyName\s*=\s*\$true'
        }

        It "Should have process block for pipeline input" {
            $content = Get-Content -Path $functionFilePath -Raw
            $content | Should -Match '\s+process\s+\{' -Because "Function accepts pipeline input"
        }

        It "Should use CmdletBinding attribute" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $functionDef = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $args[0].Name -eq $functionName
                }, $true) | Select-Object -First 1

            $functionDef | Should -Not -BeNullOrEmpty
            $functionDef.Body.ParamBlock.Attributes.TypeName.Name | Should -Contain 'CmdletBinding'
        }

        It "Should have properly typed parameters" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            $paramBlock | Should -Not -BeNullOrEmpty

            foreach ($param in $paramBlock.Parameters) {
                $param.StaticType | Should -Not -BeNullOrEmpty
                $param.StaticType.Name | Should -Not -Be 'Object'
            }
        }
    }

    Context "Specific Parameter Validation" {
        BeforeAll {
            $functionAst = [System.Management.Automation.Language.Parser]::ParseFile(
                $functionFilePath,
                [ref]$null,
                [ref]$null
            )
            $paramBlock = $functionAst.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1
        }

        It "Should have InputFile parameter with correct attributes" {
            $inputFileParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'InputFile'
            }

            $inputFileParam | Should -Not -BeNullOrEmpty
            $inputFileParam.StaticType.Name | Should -Be 'String[]'

            # Check for Mandatory attribute
            $paramAttr = $inputFileParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }
            $mandatory = $paramAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
            $mandatory.Argument.Extent.Text | Should -Be '$true'

            # Check for aliases
            $aliasAttr = $inputFileParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' }
            $aliasAttr | Should -Not -BeNullOrEmpty -Because "InputFile should have aliases for pipeline flexibility"
        }

        It "Should have OutputFile parameter with aliases" {
            $outputFileParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'OutputFile'
            }

            $outputFileParam | Should -Not -BeNullOrEmpty

            # Check for aliases
            $aliasAttr = $outputFileParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' }
            $aliasAttr | Should -Not -BeNullOrEmpty -Because "OutputFile should have aliases for user convenience"
        }

        It "Should have Delimiter parameter with ValidateLength attribute" {
            $delimiterParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'Delimiter'
            }

            $delimiterParam | Should -Not -BeNullOrEmpty
            $delimiterParam.StaticType.Name | Should -Be 'String'

            # Check for ValidateLength
            $validateLength = $delimiterParam.Attributes |
            Where-Object { $_.TypeName.Name -eq 'ValidateLength' }

            $validateLength | Should -Not -BeNullOrEmpty
            $validateLength.PositionalArguments[0].Value | Should -Be 1
            $validateLength.PositionalArguments[1].Value | Should -Be 1
        }

        It "Should have OutputType parameter with ValidateSet attribute" {
            $outputTypeParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'OutputType'
            }

            $outputTypeParam | Should -Not -BeNullOrEmpty

            # Check for ValidateSet
            $validateSet = $outputTypeParam.Attributes |
            Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

            $validateSet | Should -Not -BeNullOrEmpty

            # Check expected values
            $validValues = $validateSet.PositionalArguments | ForEach-Object { $_.Value }
            $validValues | Should -Contain 'CSV'
            $validValues | Should -Contain 'Statistic'
            $validValues | Should -Contain 'Both'
        }

        It "Should have RemoveSourceFile as a switch parameter" {
            $removeParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'RemoveSourceFile'
            }

            $removeParam | Should -Not -BeNullOrEmpty
            $removeParam.StaticType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have CompressOutput as a switch parameter" {
            $compressParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'CompressOutput'
            }

            $compressParam | Should -Not -BeNullOrEmpty
            $compressParam.StaticType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have SkipHeaderValidation as a switch parameter" {
            $skipParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'SkipHeaderValidation'
            }

            $skipParam | Should -Not -BeNullOrEmpty
            $skipParam.StaticType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have InputCulture and OutputCulture with CultureInfo type and ArgumentCompleter" {
            $inputCultureParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'InputCulture'
            }
            $outputCultureParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'OutputCulture'
            }

            $inputCultureParam | Should -Not -BeNullOrEmpty
            $outputCultureParam | Should -Not -BeNullOrEmpty

            $inputCultureParam.StaticType.Name | Should -Be 'CultureInfo'
            $outputCultureParam.StaticType.Name | Should -Be 'CultureInfo'

            # Both should have ArgumentCompleter
            $inputCultureParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ArgumentCompleter' } |
            Should -Not -BeNullOrEmpty
            $outputCultureParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ArgumentCompleter' } |
            Should -Not -BeNullOrEmpty
        }

        It "Should have ComputerName parameter with aliases" {
            $computerNameParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'ComputerName'
            }

            $computerNameParam | Should -Not -BeNullOrEmpty
            $computerNameParam.StaticType.Name | Should -Be 'String'

            # Check for aliases
            $aliasAttr = $computerNameParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' }
            $aliasAttr | Should -Not -BeNullOrEmpty
        }

        It "Should have ContextFilter parameter with ValidateSet attribute" {
            $contextFilterParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'ContextFilter'
            }

            $contextFilterParam | Should -Not -BeNullOrEmpty
            $contextFilterParam.StaticType.Name | Should -Be 'String'

            # Check for ValidateSet
            $validateSet = $contextFilterParam.Attributes |
            Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

            $validateSet | Should -Not -BeNullOrEmpty

            # Check expected values
            $validValues = $validateSet.PositionalArguments | ForEach-Object { $_.Value }
            $validValues | Should -Contain 'All'
            $validValues | Should -Contain 'Packet'
            $validValues | Should -Contain 'Event'
            $validValues | Should -Contain 'Note'
            $validValues.Count | Should -Be 4
        }

        It "Should have ContextFilter parameter with default value of 'All'" {
            $contextFilterParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'ContextFilter'
            }

            $contextFilterParam | Should -Not -BeNullOrEmpty
            $contextFilterParam.DefaultValue | Should -Not -BeNullOrEmpty
            $contextFilterParam.DefaultValue.Extent.Text | Should -Match "'All'"
        }
    }

    Context "Parameter Naming and Consistency" {
        It "Should follow PascalCase naming for all parameters" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            foreach ($param in $paramBlock.Parameters) {
                $paramName = $param.Name.VariablePath.UserPath
                $paramName.Substring(0, 1) | Should -MatchExactly '^[A-Z]$' -Because "Parameters should use PascalCase naming"
            }
        }

        It "Should not have validation attributes on switch parameters" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            foreach ($param in $paramBlock.Parameters) {
                if ($param.StaticType.Name -eq 'SwitchParameter') {
                    $validationAttrs = $param.Attributes | Where-Object {
                        $_.TypeName.Name -in @('ValidateSet', 'ValidateLength', 'ValidateRange', 'ValidatePattern', 'ValidateScript')
                    }

                    $validationAttrs | Should -BeNullOrEmpty -Because "Switch parameters should not have validation attributes"
                }
            }
        }

        It "Aliases should not conflict with standard PowerShell parameters" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            $reservedNames = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
                'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
                'PipelineVariable', 'WhatIf', 'Confirm')

            foreach ($param in $paramBlock.Parameters) {
                $aliasAttr = $param.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' }

                if ($aliasAttr) {
                    foreach ($arg in $aliasAttr.PositionalArguments) {
                        $aliasValue = $arg.Value
                        $aliasValue | Should -Not -BeIn $reservedNames -Because "Aliases should not conflict with common parameters"
                    }
                }
            }
        }

        It "Mandatory parameters should have meaningful names" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            foreach ($param in $paramBlock.Parameters) {
                $mandatoryAttr = $param.Attributes |
                Where-Object { $_.TypeName.Name -eq 'Parameter' } |
                ForEach-Object {
                    $_.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
                }

                if ($mandatoryAttr -and $mandatoryAttr.Argument.Extent.Text -eq '$true') {
                    $param.Name.VariablePath.UserPath.Length | Should -BeGreaterThan 1
                }
            }
        }
    }

    Context "ValidateSet and ArgumentCompleter" {
        It "ValidateSet values should be documented in help" {
            $content = Get-Content -Path $functionFilePath -Raw
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            foreach ($param in $paramBlock.Parameters) {
                $paramName = $param.Name.VariablePath.UserPath
                $validateSetAttr = $param.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

                if ($validateSetAttr) {
                    $validValues = $validateSetAttr.PositionalArguments | ForEach-Object { $_.Value }

                    $helpPattern = "\.PARAMETER\s+$paramName"
                    if ($content -match $helpPattern) {
                        foreach ($value in $validValues) {
                            $content | Should -Match $value -Because "ValidateSet value '$value' should be documented"
                        }
                    }
                }
            }
        }

        It "ArgumentCompleter should have valid scriptblock" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1

            foreach ($param in $paramBlock.Parameters) {
                $argCompleterAttr = $param.Attributes | Where-Object { $_.TypeName.Name -eq 'ArgumentCompleter' }

                if ($argCompleterAttr) {
                    $scriptBlock = $argCompleterAttr.PositionalArguments[0]
                    $scriptBlock | Should -Not -BeNullOrEmpty -Because "ArgumentCompleter should have a valid scriptblock"
                }
            }
        }
    }
}
