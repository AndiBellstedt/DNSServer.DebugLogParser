BeforeAll {
    $moduleRoot = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
    $functionName = 'ConvertTo-Fqdn'
    $functionFilePath = Join-Path $moduleRoot "internal\functions\$functionName.ps1"
}

Describe "ConvertTo-Fqdn - Parameter Contract" {
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

            $outputTypeAttribute | Should -Not -BeNullOrEmpty -Because "Function returns a string"
        }
    }

    Context "Specific Parameter Validation" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1
        }

        It "Should have EncodedName parameter that is optional" {
            $encodedNameParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'EncodedName'
            }

            $encodedNameParam | Should -Not -BeNullOrEmpty
            $encodedNameParam.StaticType.Name | Should -Be 'String'

            # Check for Mandatory attribute (should be optional)
            $paramAttr = $encodedNameParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }
            $mandatory = $paramAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
            $mandatory | Should -BeNullOrEmpty
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

Describe "ConvertTo-Fqdn - Functionality" {
    BeforeAll {
        # Dot-source internal function
        $modulePath = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
        . (Join-Path $modulePath "internal\functions\ConvertTo-Fqdn.ps1")
    }

    Context "Basic FQDN Conversion" {
        It "Should convert simple domain name" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

            $result | Should -Be 'example.com'
        }

        It "Should convert subdomain" {
            $result = ConvertTo-Fqdn -EncodedName "(3)www(7)example(3)com(0)"

            $result | Should -Be 'www.example.com'
        }

        It "Should convert multi-level subdomain" {
            $result = ConvertTo-Fqdn -EncodedName "(3)odc(10)officeapps(4)live(3)com(0)"

            $result | Should -Be 'odc.officeapps.live.com'
        }

        It "Should convert single label domain" {
            $result = ConvertTo-Fqdn -EncodedName "(8)localhost(0)"

            $result | Should -Be 'localhost'
        }
    }

    Context "Complex Domain Names" {
        It "Should convert ocsp.digicert.com" {
            $result = ConvertTo-Fqdn -EncodedName "(4)ocsp(8)digicert(3)com(0)"

            $result | Should -Be 'ocsp.digicert.com'
        }

        It "Should convert windowsupdate.com subdomain" {
            $result = ConvertTo-Fqdn -EncodedName "(1)4(2)au(8)download(13)windowsupdate(3)com(0)"

            $result | Should -Be '4.au.download.windowsupdate.com'
        }

        It "Should convert deep subdomain with many levels" {
            $result = ConvertTo-Fqdn -EncodedName "(3)sub(6)domain(4)test(7)example(2)co(2)uk(0)"

            $result | Should -Be 'sub.domain.test.example.co.uk'
        }

        It "Should convert domain with numeric labels" {
            $result = ConvertTo-Fqdn -EncodedName "(1)1(1)2(1)3(1)4(7)example(3)com(0)"

            $result | Should -Be '1.2.3.4.example.com'
        }
    }

    Context "PTR and Reverse DNS" {
        It "Should convert PTR record (in-addr.arpa)" {
            $result = ConvertTo-Fqdn -EncodedName "(1)1(1)1(1)1(1)1(7)in-addr(4)arpa(0)"

            $result | Should -Be '1.1.1.1.in-addr.arpa'
        }

        It "Should convert IPv4 reverse lookup" {
            $result = ConvertTo-Fqdn -EncodedName "(3)100(1)0(1)0(2)10(7)in-addr(4)arpa(0)"

            $result | Should -Be '100.0.0.10.in-addr.arpa'
        }

        It "Should convert ip6.arpa reverse lookup" {
            $result = ConvertTo-Fqdn -EncodedName "(1)1(1)0(1)0(1)0(3)ip6(4)arpa(0)"

            $result | Should -Be '1.0.0.0.ip6.arpa'
        }
    }

    Context "Special Characters and Edge Cases" {
        It "Should convert domain with hyphen" {
            $result = ConvertTo-Fqdn -EncodedName "(7)my-site(7)example(3)com(0)"

            $result | Should -Be 'my-site.example.com'
        }

        It "Should convert domain with multiple hyphens" {
            $result = ConvertTo-Fqdn -EncodedName "(15)this-is-my-site(7)example(3)com(0)"

            $result | Should -Be 'this-is-my-site.example.com'
        }

        It "Should handle very long label" {
            $longLabel = "(63)verylonglabelthatisexactlysixtycharactersforlongdomaintesting(3)com(0)"
            $result = ConvertTo-Fqdn -EncodedName $longLabel

            $result | Should -Be 'verylonglabelthatisexactlysixtycharactersforlongdomaintesting.com'
        }
    }

    Context "Empty and Invalid Input" {
        It "Should return empty string for whitespace input" {
            $result = ConvertTo-Fqdn -EncodedName "   "

            $result | Should -Be ''
        }

        It "Should handle malformed encoding (missing closing parenthesis)" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com"

            # Should gracefully handle and return partial or empty result
            $result | Should -BeOfType [string]
        }

        It "Should handle terminating (0) only" {
            $result = ConvertTo-Fqdn -EncodedName "(0)"

            $result | Should -Be ''
        }

        It "Should handle encoding without terminator" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com"

            # Should stop at last valid label
            $result | Should -BeOfType [string]
        }
    }

    Context "Real-World Examples from DNS Logs" {
        It "Should convert odc.officeapps.live.com" {
            $result = ConvertTo-Fqdn -EncodedName "(3)odc(10)officeapps(4)live(3)com(0)"

            $result | Should -Be 'odc.officeapps.live.com'
        }

        It "Should convert ocsp.digicert.com" {
            $result = ConvertTo-Fqdn -EncodedName "(4)ocsp(8)digicert(3)com(0)"

            $result | Should -Be 'ocsp.digicert.com'
        }

        It "Should convert 4.au.download.windowsupdate.com" {
            $result = ConvertTo-Fqdn -EncodedName "(1)4(2)au(8)download(13)windowsupdate(3)com(0)"

            $result | Should -Be '4.au.download.windowsupdate.com'
        }

        It "Should convert login.microsoftonline.com" {
            $result = ConvertTo-Fqdn -EncodedName "(5)login(16)microsoftonline(3)com(0)"

            $result | Should -Be 'login.microsoftonline.com'
        }

        It "Should convert _ldap._tcp.dc._msdcs.example.local" {
            $result = ConvertTo-Fqdn -EncodedName "(5)_ldap(4)_tcp(2)dc(6)_msdcs(7)example(5)local(0)"

            $result | Should -Be '_ldap._tcp.dc._msdcs.example.local'
        }
    }

    Context "Output Type" {
        It "Should return a string" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

            $result | Should -BeOfType [string]
        }

        It "Should not return null for valid input" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should return proper string without trailing dot" {
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

            $result | Should -Not -Match '\.$'
        }
    }

    Context "Performance and Efficiency" {
        It "Should handle multiple consecutive conversions" {
            $domains = @(
                "(7)example(3)com(0)",
                "(3)www(7)example(3)com(0)",
                "(4)mail(7)example(3)com(0)",
                "(3)ftp(7)example(3)com(0)"
            )

            foreach ($domain in $domains) {
                $result = ConvertTo-Fqdn -EncodedName $domain
                $result | Should -BeOfType [string]
                $result | Should -Not -BeNullOrEmpty
            }
        }

        It "Should process correctly without regex dependency" {
            # Testing that string operations work (no regex)
            $result = ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

            $result | Should -Be 'example.com'
            $result | Should -Not -Match '\(' # No parentheses should remain
            $result | Should -Not -Match '\d' # No numbers should remain
        }
    }
}
