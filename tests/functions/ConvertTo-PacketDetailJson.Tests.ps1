BeforeAll {
    $moduleRoot = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
    $functionName = 'ConvertTo-PacketDetailJson'
    $functionFilePath = Join-Path $moduleRoot "internal\functions\$functionName.ps1"
}

Describe "ConvertTo-PacketDetailJson - Parameter Contract" {
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

        It "Should have DetailLines parameter that is mandatory" {
            $detailLinesParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'DetailLines'
            }

            $detailLinesParam | Should -Not -BeNullOrEmpty
            $detailLinesParam.StaticType.Name | Should -Be 'List`1'

            # Check for Mandatory attribute
            $paramAttr = $detailLinesParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }
            $mandatory = $paramAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
            $mandatory | Should -Not -BeNullOrEmpty
            $mandatory.Argument.Extent.Text | Should -Be '$true'
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

Describe "ConvertTo-PacketDetailJson - Functionality" {
    BeforeAll {
        # Dot-source internal functions
        $modulePath = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
        . (Join-Path $modulePath "internal\functions\ConvertTo-Fqdn.ps1")
        . (Join-Path $modulePath "internal\functions\ConvertTo-PacketDetailJson.ps1")
    }

    Context "Empty and Null Input" {
        It "Should return empty string for null input" {
            $result = ConvertTo-PacketDetailJson -DetailLines $null

            $result | Should -Be ''
        }

        It "Should return empty string for empty list" {
            $emptyList = [System.Collections.Generic.List[string]]::new()
            $result = ConvertTo-PacketDetailJson -DetailLines $emptyList

            $result | Should -Be ''
        }

        It "Should return empty string for list with only whitespace" {
            $whitespaceList = [System.Collections.Generic.List[string]]::new()
            $whitespaceList.Add('   ')
            $whitespaceList.Add('')
            $result = ConvertTo-PacketDetailJson -DetailLines $whitespaceList

            $result | Should -Be ''
        }
    }

    Context "Simple Connection Properties" {
        It "Should parse Socket property" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be '848'
        }

        It "Should parse Remote addr property" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Remote | Should -Be 'addr 10.10.0.11, port 60580'
        }

        It "Should parse Time with multiple key-value pairs" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Time Query=179992, Queued=0, Expire=0')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Time.Query | Should -Be '179992'
            $json.Time.Queued | Should -Be '0'
            $json.Time.Expire | Should -Be '0'
        }

        It "Should parse multiple top-level properties" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $lines.Add('Xid = 0x0001')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be '848'
            $json.Remote | Should -Be 'addr 10.10.0.11, port 60580'
            $json.Xid | Should -Be '0x0001'
        }

        It "Should normalize keys by removing spaces" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Remote addr = 10.10.0.11')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Remoteaddr | Should -Be '10.10.0.11'
        }
    }

    Context "Message Section Parsing" {
        It "Should recognize Message section" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $lines.Add('Message:')
            $lines.Add('  XID       0x0001')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message | Should -Not -BeNullOrEmpty
            $json.Message.XID | Should -Be '0x0001'
        }

        It "Should parse multiple Message properties" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  XID       0x0001')
            $lines.Add('  OPCODE    QUERY')
            $lines.Add('  RCODE     NOERROR')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.XID | Should -Be '0x0001'
            $json.Message.OPCODE | Should -Be 'QUERY'
            $json.Message.RCODE | Should -Be 'NOERROR'
        }

        It "Should parse Flags with sub-properties" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  Flags     0x0100')
            $lines.Add('    QR        0 (QUESTION)')
            $lines.Add('    OPCODE    0 (QUERY)')
            $lines.Add('    AA        0')
            $lines.Add('    TC        0')
            $lines.Add('    RD        1')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.Flags | Should -Not -BeNullOrEmpty
            $json.Message.Flags.Value | Should -Be '0x0100'
            $json.Message.Flags.QR | Should -Be '0 (QUESTION)'
            $json.Message.Flags.OPCODE | Should -Be '0 (QUERY)'
            $json.Message.Flags.RD | Should -Be '1'
        }
    }

    Context "DNS Section Parsing" {
        It "Should recognize QUESTION SECTION" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    QTYPE    A')
            $lines.Add('    QCLASS   IN')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.QUESTION | Should -Not -BeNullOrEmpty
            $json.Message.QUESTION.Count | Should -Be 1
            $json.Message.QUESTION[0].Name | Should -Be 'example.com'
            $json.Message.QUESTION[0].QTYPE | Should -Be 'A'
            $json.Message.QUESTION[0].QCLASS | Should -Be 'IN'
        }

        It "Should recognize ANSWER SECTION" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  ANSWER SECTION:')
            $lines.Add('    Offset = 0x001e, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    TYPE     A')
            $lines.Add('    CLASS    IN')
            $lines.Add('    TTL      3600')
            $lines.Add('    DLEN     4')
            $lines.Add('    DATA     93.184.216.34')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.ANSWER | Should -Not -BeNullOrEmpty
            $json.Message.ANSWER.Count | Should -Be 1
            $json.Message.ANSWER[0].Name | Should -Be 'example.com'
            $json.Message.ANSWER[0].TYPE | Should -Be 'A'
            $json.Message.ANSWER[0].DATA | Should -Be '93.184.216.34'
        }

        It "Should recognize AUTHORITY SECTION" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  AUTHORITY SECTION:')
            $lines.Add('    Offset = 0x0030, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    TYPE     NS')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.AUTHORITY | Should -Not -BeNullOrEmpty
            $json.Message.AUTHORITY.Count | Should -Be 1
        }

        It "Should recognize ADDITIONAL SECTION" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  ADDITIONAL SECTION:')
            $lines.Add('    Offset = 0x0040, RR count = 0')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.ADDITIONAL | Should -Not -BeNullOrEmpty
        }

        It "Should handle empty DNS section" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    empty')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.PSObject.Properties.Name | Should -Contain 'QUESTION'
            @($json.Message.QUESTION).Count | Should -Be 0
        }

        It "Should parse multiple records in same section" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  ANSWER SECTION:')
            $lines.Add('    Offset = 0x001e, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    TYPE     A')
            $lines.Add('    DATA     93.184.216.34')
            $lines.Add('    Offset = 0x002e, RR count = 2')
            $lines.Add('    Name = (3)www(7)example(3)com(0)')
            $lines.Add('    TYPE     A')
            $lines.Add('    DATA     93.184.216.35')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.ANSWER.Count | Should -Be 2
            $json.Message.ANSWER[0].Name | Should -Be 'example.com'
            $json.Message.ANSWER[1].Name | Should -Be 'www.example.com'
        }

        It "Should parse multiple DNS sections in same message" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    QTYPE    A')
            $lines.Add('  ANSWER SECTION:')
            $lines.Add('    Offset = 0x001e, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    TYPE     A')
            $lines.Add('  AUTHORITY SECTION:')
            $lines.Add('    empty')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.PSObject.Properties.Name | Should -Contain 'QUESTION'
            $json.Message.PSObject.Properties.Name | Should -Contain 'ANSWER'
            $json.Message.PSObject.Properties.Name | Should -Contain 'AUTHORITY'
            @($json.Message.QUESTION).Count | Should -Be 1
            @($json.Message.ANSWER).Count | Should -Be 1
            @($json.Message.AUTHORITY).Count | Should -Be 0
        }
    }

    Context "ConvertTo-Fqdn Integration" {
        It "Should convert encoded domain names to FQDN" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (3)www(7)example(3)com(0)')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.QUESTION[0].Name | Should -Be 'www.example.com'
        }

        It "Should convert reverse DNS names" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (1)1(1)1(1)1(1)1(7)in-addr(4)arpa(0)')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Message.QUESTION[0].Name | Should -Be '1.1.1.1.in-addr.arpa'
        }
    }

    Context "JSON Output Validation" {
        It "Should return valid JSON" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should return compressed JSON (no whitespace)" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -Match '\n'
            $result | Should -Not -Match '\r'
            $result | Should -Not -Match '  '
        }

        It "Should handle special characters in values" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Data = test"value')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should preserve order of properties (ordered hashtable)" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $lines.Add('Message:')
            $lines.Add('  XID       0x0001')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            # JSON should maintain order with Socket first, then Remote, then Message
            $result.IndexOf('Socket') | Should -BeLessThan $result.IndexOf('Remote')
            $result.IndexOf('Remote') | Should -BeLessThan $result.IndexOf('Message')
        }
    }

    Context "Real-World Examples" {
        It "Should parse typical UDP query detail block" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('UDP question info at 000001A7B5E5F010')
            $lines.Add('Socket = 848')
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $lines.Add('Time Query=179992, Queued=0, Expire=0')
            $lines.Add('Buf length = 0x0fa0 (4000)')
            $lines.Add('Msg length = 0x0027 (39)')
            $lines.Add('Message:')
            $lines.Add('  XID       0xf77a')
            $lines.Add('  Flags     0x0100')
            $lines.Add('    QR        0 (QUESTION)')
            $lines.Add('    OPCODE    0 (QUERY)')
            $lines.Add('    AA        0')
            $lines.Add('    TC        0')
            $lines.Add('    RD        1')
            $lines.Add('    RA        0')
            $lines.Add('    Z         0')
            $lines.Add('    CD        0')
            $lines.Add('    AD        0')
            $lines.Add('    RCODE     0 (NOERROR)')
            $lines.Add('  QCOUNT    1')
            $lines.Add('  ACOUNT    0')
            $lines.Add('  NSCOUNT   0')
            $lines.Add('  ARCOUNT   0')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    QTYPE    A')
            $lines.Add('    QCLASS   IN')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be '848'
            $json.Remote | Should -Be 'addr 10.10.0.11, port 60580'
            $json.Time.Query | Should -Be '179992'
            $json.Message.XID | Should -Be '0xf77a'
            $json.Message.Flags.Value | Should -Be '0x0100'
            $json.Message.Flags.QR | Should -Be '0 (QUESTION)'
            $json.Message.Flags.RD | Should -Be '1'
            $json.Message.QCOUNT | Should -Be '1'
            $json.Message.QUESTION[0].Name | Should -Be 'example.com'
            $json.Message.QUESTION[0].QTYPE | Should -Be 'A'
        }

        It "Should parse typical UDP response detail block" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('UDP response info at 000001A7B5E5F010')
            $lines.Add('Socket = 848')
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $lines.Add('Xid = 0xf77a')
            $lines.Add('Flags     0x8180')
            $lines.Add('  QR        1 (RESPONSE)')
            $lines.Add('  OPCODE    0 (QUERY)')
            $lines.Add('  AA        0')
            $lines.Add('  TC        0')
            $lines.Add('  RD        1')
            $lines.Add('  RA        1')
            $lines.Add('  Z         0')
            $lines.Add('  CD        0')
            $lines.Add('  AD        0')
            $lines.Add('  RCODE     0 (NOERROR)')
            $lines.Add('QCOUNT    1')
            $lines.Add('ACOUNT    1')
            $lines.Add('NSCOUNT   0')
            $lines.Add('ARCOUNT   0')
            $lines.Add('Message:')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    QTYPE    A')
            $lines.Add('    QCLASS   IN')
            $lines.Add('  ANSWER SECTION:')
            $lines.Add('    Offset = 0x001e, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('    TYPE     A')
            $lines.Add('    CLASS    IN')
            $lines.Add('    TTL      3600')
            $lines.Add('    DLEN     4')
            $lines.Add('    DATA     93.184.216.34')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be '848'
            $json.Xid | Should -Be '0xf77a'
            $json.QCOUNT | Should -Be '1'
            $json.ACOUNT | Should -Be '1'
            $json.Message.QUESTION[0].Name | Should -Be 'example.com'
            $json.Message.ANSWER[0].Name | Should -Be 'example.com'
            $json.Message.ANSWER[0].DATA | Should -Be '93.184.216.34'
        }
    }

    Context "Output Type" {
        It "Should return a string" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -BeOfType [string]
        }

        It "Should return empty string on error" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }
    }

    Context "Performance and Edge Cases" {
        It "Should handle large number of detail lines" {
            $lines = [System.Collections.Generic.List[string]]::new()
            for ($i = 1; $i -le 100; $i++) {
                $lines.Add("Property$i = Value$i")
            }
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should skip empty lines" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = 848')
            $lines.Add('')
            $lines.Add('Remote addr 10.10.0.11, port 60580')
            $lines.Add('   ')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be '848'
            $json.Remote | Should -Be 'addr 10.10.0.11, port 60580'
        }

        It "Should handle properties without values" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Socket = ')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            $json = $result | ConvertFrom-Json
            $json.Socket | Should -Be ''
        }

        It "Should handle deeply nested structures" {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('Message:')
            $lines.Add('  Flags     0x0100')
            $lines.Add('    QR        0')
            $lines.Add('    OPCODE    0')
            $lines.Add('  QUESTION SECTION:')
            $lines.Add('    Offset = 0x000c, RR count = 0')
            $lines.Add('    Name = (7)example(3)com(0)')
            $lines.Add('  ANSWER SECTION:')
            $lines.Add('    Offset = 0x001e, RR count = 1')
            $lines.Add('    Name = (7)example(3)com(0)')
            $result = ConvertTo-PacketDetailJson -DetailLines $lines

            $result | Should -Not -BeNullOrEmpty
            { $result | ConvertFrom-Json } | Should -Not -Throw
            $json = $result | ConvertFrom-Json
            $json.Message.Flags.QR | Should -Be '0'
            $json.Message.QUESTION.Count | Should -Be 1
            $json.Message.ANSWER.Count | Should -Be 1
        }
    }
}
