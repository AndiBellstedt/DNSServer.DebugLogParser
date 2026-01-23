BeforeAll {
    $moduleRoot = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
    $functionName = 'ConvertFrom-DnsLogLine'
    $functionFilePath = Join-Path $moduleRoot "internal\functions\$functionName.ps1"
}

Describe "ConvertFrom-DnsLogLine - Parameter Contract" {
    Context "Basic Parameter Validation" {
        It "Should have a param block with CmdletBinding" {
            $content = Get-Content -Path $functionFilePath -Raw
            $content | Should -Match '\[CmdletBinding\(\)\]'
            $content | Should -Match 'param\s*\('
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

        It "Should have OutputType attribute" {
            $content = Get-Content -Path $functionFilePath -Raw
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $functionDef = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $args[0].Name -eq $functionName
                }, $true) | Select-Object -First 1

            $outputTypeAttribute = $functionDef.Body.ParamBlock.Attributes |
                Where-Object { $_.TypeName.Name -eq 'OutputType' }

            $outputTypeAttribute | Should -Not -BeNullOrEmpty -Because "Function returns a hashtable"
        }
    }

    Context "Specific Parameter Validation" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1
        }

        It "Should have Line parameter with correct type" {
            $lineParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'Line'
            }

            $lineParam | Should -Not -BeNullOrEmpty
            $lineParam.StaticType.Name | Should -Be 'String'
        }

        It "Should have Culture parameter with correct type and default value" {
            $cultureParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'Culture'
            }

            $cultureParam | Should -Not -BeNullOrEmpty
            $cultureParam.StaticType.Name | Should -Be 'CultureInfo'

            # Should have default value
            $cultureParam.DefaultValue | Should -Not -BeNullOrEmpty
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
}
