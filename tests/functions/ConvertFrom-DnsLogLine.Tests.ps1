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

Describe "ConvertFrom-DnsLogLine - Functionality" {
    BeforeAll {
        # Dot-source internal functions
        $modulePath = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
        . (Join-Path $modulePath "internal\functions\ConvertFrom-DnsLogLine.ps1")
        . (Join-Path $modulePath "internal\functions\ConvertTo-Fqdn.ps1")

        # Sample log lines based on en-us format (MM/DD/YYYY HH:MM:SS format)
        $sampleLogLineQuery = "1/20/2026 11:00:16 PM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)"
        $sampleLogLineResponse = "1/20/2026 11:00:17 PM 0FE0 PACKET  000002C530473140 UDP Rcv 10.0.0.1        420b R Q [8081   DR  NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)"
        $sampleLogLineGerman = "20.01.2026 23:00:18 0FE0 PACKET  000002C5307CFCD0 UDP Rcv 10.0.0.2        ede1   Q [0001   D   NOERROR] A      (4)ocsp(8)digicert(3)com(0)"
        $sampleLogLineAAAA = "1/20/2026 11:00:22 PM 0FE0 PACKET  000002C52FBF1130 UDP Rcv 10.0.0.2        1cde   Q [0001   D   NOERROR] AAAA   (1)4(2)au(8)download(13)windowsupdate(3)com(0)"
        $sampleLogLineTCP = "1/21/2026 8:15:30 AM 1A2B PACKET  000002C52FBF2240 TCP Snd 10.0.0.3        5f3a R Q [8085 A DR NOERROR] PTR    (1)1(1)1(1)1(1)1(1)1(7)in-addr(4)arpa(0)"
    }

    Context "Basic Parsing" {
        It "Should parse a standard Query log line (en-us format)" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result | Should -Not -BeNullOrEmpty
            $result.DateTime | Should -BeOfType [DateTime]
            $result.ThreadId | Should -Be '0FE0'
            $result.Context | Should -Be 'PACKET'
            $result.PacketId | Should -Be '000002C53117D990'
            $result.Protocol | Should -Be 'UDP'
            $result.Direction | Should -Be 'Rcv'
            $result.RemoteIP | Should -Be '10.0.0.2'
            $result.Xid | Should -Be 'c049'
            $result.QueryResponse | Should -Be ''
            $result.Opcode | Should -Be 'Q'
            $result.FlagsHex | Should -Be '0001'
            $result.FlagsChar | Should -Be 'D'
            $result.ResponseCode | Should -Be 'NOERROR'
            $result.QuestionType | Should -Be 'A'
            $result.QuestionName | Should -Be 'odc.officeapps.live.com'
        }

        It "Should parse a Response log line" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineResponse

            $result | Should -Not -BeNullOrEmpty
            $result.QueryResponse | Should -Be 'R'
            $result.FlagsHex | Should -Be '8081'
            $result.FlagsChar | Should -Be 'DR'
            $result.ResponseCode | Should -Be 'NOERROR'
            $result.QuestionName | Should -Be 'odc.officeapps.live.com'
        }

        It "Should parse German date format (DD.MM.YYYY)" {
            $germanCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineGerman -Culture $germanCulture

            $result | Should -Not -BeNullOrEmpty
            $result.DateTime | Should -BeOfType [DateTime]
            $result.DateTime.Year | Should -Be 2026
            $result.DateTime.Month | Should -Be 1
            $result.DateTime.Day | Should -Be 20
            $result.QuestionName | Should -Be 'ocsp.digicert.com'
        }

        It "Should parse AAAA query type" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineAAAA

            $result | Should -Not -BeNullOrEmpty
            $result.QuestionType | Should -Be 'AAAA'
            $result.QuestionName | Should -Be '4.au.download.windowsupdate.com'
        }

        It "Should parse TCP protocol with PTR query" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineTCP

            $result | Should -Not -BeNullOrEmpty
            $result.Protocol | Should -Be 'TCP'
            $result.Direction | Should -Be 'Snd'
            $result.QuestionType | Should -Be 'PTR'
            $result.FlagsChar | Should -Be 'ADR'
            $result.QuestionName | Should -Be '1.1.1.1.1.in-addr.arpa'
        }
    }

    Context "DateTime Parsing" {
        It "Should correctly parse en-us date format (MM/DD/YYYY)" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result | Should -Not -BeNullOrEmpty
            $result.DateTime.Year | Should -Be 2026
            $result.DateTime.Month | Should -Be 1
            $result.DateTime.Day | Should -Be 20
            $result.DateTime.Hour | Should -Be 23
            $result.DateTime.Minute | Should -Be 0
            $result.DateTime.Second | Should -Be 16
        }

        It "Should handle AM/PM designation" {
            $amLine = "1/20/2026 8:30:15 AM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (7)example(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $amLine

            $result | Should -Not -BeNullOrEmpty
            $result.DateTime.Hour | Should -Be 8
        }

        It "Should handle culture-specific date formats" {
            $deCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
            $germanLine = "20.01.2026 08:30:15 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (7)example(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $germanLine -Culture $deCulture

            $result | Should -Not -BeNullOrEmpty
            $result.DateTime.Day | Should -Be 20
            $result.DateTime.Month | Should -Be 1
        }
    }

    Context "Protocol and Direction" {
        It "Should identify UDP Receive direction" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.Protocol | Should -Be 'UDP'
            $result.Direction | Should -Be 'Rcv'
        }

        It "Should identify TCP Send direction" {
            $tcpLine = "1/21/2026 10:00:00 AM 1A2B PACKET  000002C52FBF2240 TCP Snd 10.0.0.3        5f3a   Q [0001   D   NOERROR] A      (7)example(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $tcpLine

            $result.Protocol | Should -Be 'TCP'
            $result.Direction | Should -Be 'Snd'
        }
    }

    Context "Question Name Conversion" {
        It "Should convert encoded DNS name to FQDN" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.QuestionName | Should -Be 'odc.officeapps.live.com'
        }

        It "Should handle PTR records with in-addr.arpa" {
            $ptrLine = "1/21/2026 8:15:30 AM 1A2B PACKET  000002C52FBF2240 TCP Snd 10.0.0.3        5f3a   Q [0001   D   NOERROR] PTR    (1)1(1)0(1)0(1)1(7)in-addr(4)arpa(0)"
            $result = ConvertFrom-DnsLogLine -Line $ptrLine

            $result.QuestionName | Should -Be '1.0.0.1.in-addr.arpa'
        }

        It "Should handle subdomain with multiple labels" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineAAAA

            $result.QuestionName | Should -Be '4.au.download.windowsupdate.com'
        }
    }

    Context "Flag Parsing" {
        It "Should parse Query flags correctly" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.FlagsHex | Should -Be '0001'
            $result.FlagsChar | Should -Be 'D'
        }

        It "Should parse Response flags with multiple characters" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineResponse

            $result.FlagsHex | Should -Be '8081'
            $result.FlagsChar | Should -Be 'DR'
        }

        It "Should parse Response flags with three characters" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineTCP

            $result.FlagsChar | Should -Be 'ADR'
        }
    }

    Context "Response Code Handling" {
        It "Should identify NOERROR response" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.ResponseCode | Should -Be 'NOERROR'
        }

        It "Should parse NXDOMAIN response" {
            $nxLine = "1/21/2026 10:00:00 AM 0FE0 PACKET  000002C53117D990 UDP Snd 10.0.0.2        c049 R Q [8083   DR  NXDOMAIN] A      (12)nonexistent(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $nxLine

            $result.ResponseCode | Should -Be 'NXDOMAIN'
        }
    }

    Context "Edge Cases and Error Handling" {
        It "Should return null for empty line" {
            $result = ConvertFrom-DnsLogLine -Line ""

            $result | Should -BeNullOrEmpty
        }

        It "Should return null for whitespace-only line" {
            $result = ConvertFrom-DnsLogLine -Line "    "

            $result | Should -BeNullOrEmpty
        }

        It "Should return null for too-short line" {
            $result = ConvertFrom-DnsLogLine -Line "short"

            $result | Should -BeNullOrEmpty
        }

        It "Should return null for malformed line without proper date" {
            $result = ConvertFrom-DnsLogLine -Line "not a valid log line at all"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle line with insufficient fields" {
            $result = ConvertFrom-DnsLogLine -Line "1/20/2026 11:00:16 PM 0FE0 PACKET"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query Types" {
        It "Should identify A record query" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.QuestionType | Should -Be 'A'
        }

        It "Should identify AAAA record query" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineAAAA

            $result.QuestionType | Should -Be 'AAAA'
        }

        It "Should identify PTR record query" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineTCP

            $result.QuestionType | Should -Be 'PTR'
        }

        It "Should identify CNAME record query" {
            $cnameLine = "1/21/2026 10:00:00 AM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] CNAME  (3)www(7)example(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $cnameLine

            $result.QuestionType | Should -Be 'CNAME'
        }

        It "Should identify MX record query" {
            $mxLine = "1/21/2026 10:00:00 AM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] MX     (7)example(3)com(0)"
            $result = ConvertFrom-DnsLogLine -Line $mxLine

            $result.QuestionType | Should -Be 'MX'
        }
    }

    Context "Output Structure" {
        It "Should return a PSCustomObject" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result | Should -BeOfType [PSCustomObject]
        }

        It "Should have all required properties" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            $result.PSObject.Properties.Name | Should -Contain 'DateTime'
            $result.PSObject.Properties.Name | Should -Contain 'ThreadId'
            $result.PSObject.Properties.Name | Should -Contain 'Context'
            $result.PSObject.Properties.Name | Should -Contain 'PacketId'
            $result.PSObject.Properties.Name | Should -Contain 'Protocol'
            $result.PSObject.Properties.Name | Should -Contain 'Direction'
            $result.PSObject.Properties.Name | Should -Contain 'RemoteIP'
            $result.PSObject.Properties.Name | Should -Contain 'Xid'
            $result.PSObject.Properties.Name | Should -Contain 'QueryResponse'
            $result.PSObject.Properties.Name | Should -Contain 'Opcode'
            $result.PSObject.Properties.Name | Should -Contain 'FlagsHex'
            $result.PSObject.Properties.Name | Should -Contain 'FlagsChar'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseCode'
            $result.PSObject.Properties.Name | Should -Contain 'QuestionType'
            $result.PSObject.Properties.Name | Should -Contain 'QuestionName'
            $result.PSObject.Properties.Name | Should -Contain 'Information'
        }

        It "Should have 16 properties" {
            $result = ConvertFrom-DnsLogLine -Line $sampleLogLineQuery

            ($result.PSObject.Properties | Measure-Object).Count | Should -Be 16
        }
    }
}
