BeforeAll {
    $moduleRoot = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
    $functionName = 'Test-DnsDebugLogHeader'
    $functionFilePath = Join-Path $moduleRoot "internal\functions\$functionName.ps1"
}

Describe "Test-DnsDebugLogHeader - Parameter Contract" {
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

            $outputTypeAttribute | Should -Not -BeNullOrEmpty -Because "Function returns an integer"
        }
    }

    Context "Specific Parameter Validation" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($functionFilePath, [ref]$null, [ref]$null)
            $paramBlock = $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
                }, $true) | Select-Object -First 1
        }

        It "Should have Path as mandatory parameter" {
            $pathParam = $paramBlock.Parameters | Where-Object {
                $_.Name.VariablePath.UserPath -eq 'Path'
            }

            $pathParam | Should -Not -BeNullOrEmpty
            $pathParam.StaticType.Name | Should -Be 'String'

            # Check for Mandatory attribute
            $paramAttr = $pathParam.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }
            $mandatory = $paramAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
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

Describe "Test-DnsDebugLogHeader - Functionality" {
    BeforeAll {
        # Dot-source internal function
        $modulePath = (Resolve-Path "$global:testroot\..\DNSServer.DebugLogParser").Path
        . (Join-Path $modulePath "internal\functions\Test-DnsDebugLogHeader.ps1")

        # Create temp directory for test files
        $script:tempDir = Join-Path $TestDrive "DnsLogHeaderTests"
        New-Item -Path $script:tempDir -ItemType Directory -Force | Out-Null

        # Valid DNS debug log header (en-us format)
        $script:validHeaderContent = @"
DNS Server log file creation at 1/20/2026 11:00:00 PM

Message logging key (for packets - other items use a subset of these fields):
	Field #  Information         Values
	-------  -----------         ------
	1        Date
	2        Time
	3        Thread ID
	4        Context
	5        Internal packet identifier
	6        UDP/TCP indicator
	7        Send/Receive indicator
	8        Remote IP
	9        Xid (hex)
	10       Query/Response      R = Response
	                             blank = Query
	11       Opcode              Q = Standard Query
	                             N = Notify
	                             U = Update
	                             ? = Unknown
	12       Flags (hex)
	13       Flags (char codes)  A = Authoritative Answer
	                             T = Truncated Response
	                             D = Recursion Desired
	                             R = Recursion Available
	14       ResponseCode
	15       Question Type
	16       Question Name

1/20/2026 11:00:16 PM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)
"@

        # Valid header with log wrap message (German format)
        $script:validHeaderWithWrap = @"
DNS Server log file creation at 20.01.2026 23:00:00
Log file wrap at 20.01.2026 23:30:00

Message logging key (for packets - other items use a subset of these fields):
	Field #  Information         Values
	-------  -----------         ------
	1        Date
	2        Time
	3        Thread ID
	4        Context
	5        Internal packet identifier
	6        UDP/TCP indicator
	7        Send/Receive indicator
	8        Remote IP
	9        Xid (hex)
	10       Query/Response      R = Response
	                             blank = Query
	11       Opcode              Q = Standard Query
	                             N = Notify
	                             U = Update
	                             ? = Unknown
	12       Flags (hex)
	13       Flags (char codes)  A = Authoritative Answer
	                             T = Truncated Response
	                             D = Recursion Desired
	                             R = Recursion Available
	14       ResponseCode
	15       Question Type
	16       Question Name

20.01.2026 23:00:16 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)
"@

        # Create valid test file
        $script:validLogFile = Join-Path $script:tempDir "valid.log"
        Set-Content -Path $script:validLogFile -Value $script:validHeaderContent -Encoding UTF8

        # Create valid test file with wrap
        $script:validLogFileWithWrap = Join-Path $script:tempDir "validWithWrap.log"
        Set-Content -Path $script:validLogFileWithWrap -Value $script:validHeaderWithWrap -Encoding UTF8

        # Invalid file - missing header
        $script:invalidLogFile = Join-Path $script:tempDir "invalid.log"
        $invalidContent = @"
1/20/2026 11:00:16 PM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)
"@
        Set-Content -Path $script:invalidLogFile -Value $invalidContent -Encoding UTF8

        # Invalid file - wrong first line
        $script:invalidHeaderFile = Join-Path $script:tempDir "invalidHeader.log"
        $invalidHeaderContent = @"
This is not a DNS log file

Message logging key (for packets - other items use a subset of these fields):
	Field #  Information         Values

1/20/2026 11:00:16 PM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)
"@
        Set-Content -Path $script:invalidHeaderFile -Value $invalidHeaderContent -Encoding UTF8

        # Empty file
        $script:emptyLogFile = Join-Path $script:tempDir "empty.log"
        Set-Content -Path $script:emptyLogFile -Value "" -Encoding UTF8

        # Too few lines
        $script:shortLogFile = Join-Path $script:tempDir "short.log"
        Set-Content -Path $script:shortLogFile -Value "DNS Server log file creation at 1/20/2026 11:00:00 PM`n" -Encoding UTF8
    }

    Context "Valid DNS Log Header Detection" {
        It "Should return 30 for valid DNS log file with standard header" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }

        It "Should return 30 for valid DNS log file with wrap message" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFileWithWrap

            $result | Should -Be 30
        }

        It "Should validate 'DNS Server log file creation at' prefix" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -BeGreaterThan 0
            $result | Should -Be 30
        }

        It "Should validate 'Message logging key' section exists" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }

        It "Should validate 'Field #' line exists" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }
    }

    Context "Invalid DNS Log Header Detection" {
        It "Should return 0 for file without proper header" {
            $result = Test-DnsDebugLogHeader -Path $script:invalidLogFile

            $result | Should -Be 0
        }

        It "Should return 0 for file with incorrect first line" {
            $result = Test-DnsDebugLogHeader -Path $script:invalidHeaderFile

            $result | Should -Be 0
        }

        It "Should return 0 for empty file" {
            $result = Test-DnsDebugLogHeader -Path $script:emptyLogFile

            $result | Should -Be 0
        }

        It "Should return 0 for file with too few lines" {
            $result = Test-DnsDebugLogHeader -Path $script:shortLogFile

            $result | Should -Be 0
        }

        It "Should return 0 for non-existent file" {
            $nonExistentFile = Join-Path $script:tempDir "doesnotexist.log"
            $result = Test-DnsDebugLogHeader -Path $nonExistentFile

            $result | Should -Be 0
        }
    }

    Context "Header Format Variations" {
        It "Should handle en-us date format (MM/DD/YYYY)" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }

        It "Should handle German date format (DD.MM.YYYY)" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFileWithWrap

            $result | Should -Be 30
        }

        It "Should handle header with log wrap message" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFileWithWrap

            $result | Should -Be 30
        }

        It "Should handle header without log wrap message" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }
    }

    Context "Date Format Validation" {
        BeforeAll {
            # Create test file with AM designation
            $script:amFormatFile = Join-Path $script:tempDir "amFormat.log"
            $amContent = $script:validHeaderContent -replace '11:00:00 PM', '11:00:00 AM'
            Set-Content -Path $script:amFormatFile -Value $amContent -Encoding UTF8

            # Create test file with ISO date format (YYYY-MM-DD)
            $script:isoFormatFile = Join-Path $script:tempDir "isoFormat.log"
            $isoContent = $script:validHeaderContent -replace '1/20/2026 11:00:00 PM', '2026-01-20 23:00:00'
            Set-Content -Path $script:isoFormatFile -Value $isoContent -Encoding UTF8
        }

        It "Should handle AM/PM designation" {
            $result = Test-DnsDebugLogHeader -Path $script:amFormatFile

            $result | Should -Be 30
        }

        It "Should handle ISO date format (YYYY-MM-DD)" {
            $result = Test-DnsDebugLogHeader -Path $script:isoFormatFile

            $result | Should -Be 30
        }

        It "Should validate minimum line length for date/time" {
            # Test that first line meets minimum 43 character requirement
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
        }
    }

    Context "Error Handling" {
        It "Should handle file access errors gracefully" {
            $lockedFile = Join-Path $script:tempDir "locked.log"
            Set-Content -Path $lockedFile -Value $script:validHeaderContent -Encoding UTF8

            # Try to test even if file is in use
            $result = Test-DnsDebugLogHeader -Path $lockedFile

            $result | Should -BeOfType [int]
        }

        It "Should return integer type" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -BeOfType [int]
        }

        It "Should not throw exceptions for invalid files" {
            { Test-DnsDebugLogHeader -Path $script:invalidLogFile } | Should -Not -Throw
        }

        It "Should not throw exceptions for non-existent files" {
            $nonExistent = Join-Path $script:tempDir "nothere.log"
            { Test-DnsDebugLogHeader -Path $nonExistent } | Should -Not -Throw
        }
    }

    Context "Return Values" {
        It "Should return exactly 30 for valid header" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -Be 30
            $result | Should -Not -Be 29
            $result | Should -Not -Be 31
        }

        It "Should return exactly 0 for invalid header" {
            $result = Test-DnsDebugLogHeader -Path $script:invalidLogFile

            $result | Should -Be 0
            $result | Should -Not -BeGreaterThan 0
        }

        It "Should always return non-negative integer" {
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile

            $result | Should -BeGreaterOrEqual 0
        }
    }

    Context "Edge Cases" {
        BeforeAll {
            # File with extra whitespace in header
            $script:whitespaceFile = Join-Path $script:tempDir "whitespace.log"
            $whitespaceContent = $script:validHeaderContent -replace 'DNS Server log file creation at', '  DNS Server log file creation at  '
            Set-Content -Path $script:whitespaceFile -Value $whitespaceContent -Encoding UTF8

            # File with missing empty line after creation line
            $script:noEmptyLineFile = Join-Path $script:tempDir "noEmptyLine.log"
            $noEmptyLineContent = $script:validHeaderContent -replace "(`r?`n){2}Message", "`nMessage"
            Set-Content -Path $script:noEmptyLineFile -Value $noEmptyLineContent -Encoding UTF8
        }

        It "Should handle file with extra whitespace in first line" {
            $result = Test-DnsDebugLogHeader -Path $script:whitespaceFile

            # Should fail because first line doesn't start correctly
            $result | Should -Be 0
        }

        It "Should validate empty line after creation timestamp" {
            $result = Test-DnsDebugLogHeader -Path $script:noEmptyLineFile

            # Should fail because structure is wrong
            $result | Should -Be 0
        }

        It "Should handle very long file efficiently" {
            # Function only reads first 10 lines, so should be fast
            $longFile = Join-Path $script:tempDir "long.log"
            $longContent = $script:validHeaderContent
            # Add many log lines (but function only reads first 10)
            for ($i = 1; $i -le 100; $i++) {
                $longContent += "`n1/20/2026 11:00:16 PM 0FE0 PACKET  000002C53117D990 UDP Rcv 10.0.0.2        c049   Q [0001   D   NOERROR] A      (3)odc(10)officeapps(4)live(3)com(0)"
            }
            Set-Content -Path $longFile -Value $longContent -Encoding UTF8

            $result = Test-DnsDebugLogHeader -Path $longFile

            $result | Should -Be 30
        }
    }

    Context "Performance" {
        It "Should complete validation quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Test-DnsDebugLogHeader -Path $script:validLogFile
            $stopwatch.Stop()

            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
            $result | Should -Be 30
        }

        It "Should handle multiple consecutive calls" {
            for ($i = 1; $i -le 10; $i++) {
                $result = Test-DnsDebugLogHeader -Path $script:validLogFile
                $result | Should -Be 30
            }
        }
    }
}
