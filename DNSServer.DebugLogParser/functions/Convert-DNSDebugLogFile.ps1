function Convert-DNSDebugLogFile {
    <#
.SYNOPSIS
    Converts Windows DNS Server debug log files to CSV format.

.DESCRIPTION
    High-performance parser for Windows DNS Server debug log files designed to make DNS server
    activity transparent, analyzable, and evaluable in reporting and analytics tools.

    DNS Server debug logs contain detailed query/response information but are difficult to analyze
    in their raw text format. This script transforms these logs into structured CSV files that can
    be imported into Excel, Power BI, SQL databases, or other data analysis platforms.

    KEY CAPABILITIES:
    - Parses all 16 fields from DNS debug logs (date, time, protocol, client IP, query type, etc.)
    - Generates structured CSV output with customizable delimiters
    - Creates optional statistical summaries aggregating activity by client, protocol, and query type
    - Processes single files or batches via pipeline
    - Supports both standard and detailed DNS debug log formats
    - Optional automatic compression of output files to save disk space
    - Optional removal of source files after successful processing
    - Validates log file headers to ensure data integrity

    USE CASES:
    - Security analysis: Identify suspicious DNS query patterns
    - Performance monitoring: Track query volumes and response times
    - Capacity planning: Analyze DNS server load and client distribution
    - Compliance reporting: Document DNS activity for audit requirements
    - Troubleshooting: Investigate DNS resolution issues

    PERFORMANCE:
    Optimized for large files (100MB+) using:
    - String operations instead of regex for parsing
    - StreamReader/StreamWriter with 64KB buffers
    - Manual CSV generation to avoid Export-Csv overhead
    - Efficient dictionary-based statistics collection

    COMPATIBILITY:
    - PowerShell 5.1+ on Windows
    - PowerShell 7+ on Windows
    - Windows Server 2016 and later
    - Supports DNS Server 2012 R2 through 2025 debug log formats

.PARAMETER InputFile
    Path to the DNS debug log file to parse. Supports arrays for processing multiple files.

.PARAMETER OutputFile
    Optional. Path for the output CSV file.
    If not specified, uses the input filename with .csv extension.

    Must be a file path, not a directory. If you want to specify only the output directory,
    omit this parameter and the script will use the same directory as the input file.

.PARAMETER Delimiter
    The delimiter character for the CSV output.

    Default is semicolon ';'

.PARAMETER ComputerName
    Optional. If specified, adds a ComputerName column to the CSV output with the specified value.
    Useful when consolidating logs from multiple DNS servers.

    Important: This is NOT a remoting feature. The script processes local files only.

.PARAMETER OutputType
    Specifies the type of output to generate.

    Valid values:
    - 'CSV': Generate only the CSV file with parsed log data (default)
    - 'Statistic': Generate only the statistics file with aggregated data
    - 'Both': Generate both CSV and statistics files

    Default is 'Both'.

.PARAMETER SkipHeaderValidation
    Bypasses the DNS debug log header validation check.

    By default, the script validates that input files have a valid DNS Server debug log header structure.
    Use this switch to process files without header validation, which can be useful for:
    - Processing modified or custom log formats
    - Troubleshooting validation issues
    - Processing logs with non-standard headers

    Warning: Using this parameter may result in processing errors if the file is not a valid DNS log.

.PARAMETER RemoveSourceFile
    Removes the source DNS debug log file after successful processing.

    Use this switch to automatically delete input files after they have been successfully parsed
    and output files created. This is useful for:
    - Automated log processing pipelines
    - Disk space management in log collection scenarios
    - Preventing reprocessing of already-converted files

    Safety features:
    - Only removes files after successful processing and output creation
    - Skips removal if processing fails or is interrupted
    - Cannot be used with SkipHeaderValidation for safety

    Warning: Source files are permanently deleted. Ensure output files are valid before using this option.

.PARAMETER CompressOutput
    Compresses output CSV files into a ZIP archive after creation.

    Creates a .zip file containing the generated CSV file(s), then removes the uncompressed CSV(s).
    The ZIP file is created in the same directory as the output CSV with the same base name.
    Compression occurs immediately after each file is processed to manage disk space efficiently.

    Benefits:
    - Significantly reduces disk space usage (CSV files compress very well)
    - Simplifies file management and archival
    - Suitable for long-term storage of processed logs

    Example: Input 'dns.log' generates 'dns.csv' which is compressed to 'dns.zip', then 'dns.csv' is removed.

    Compatible with PowerShell 5.1+ and Windows Server 2016+.

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log"

    Converts the DNS debug log to CSV format using default settings.
    Outputs: C:\Logs\dns.csv (data file only, semicolon delimiter).

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -OutputType Both

    Converts the DNS debug log and generates both output files.
    Outputs: C:\Logs\dns.csv (data) and C:\Logs\dns_statistic.csv (aggregated statistics).

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -OutputType Statistic

    Generates only the statistics file without creating the full CSV data file.
    Outputs: C:\Logs\dns_statistic.csv (statistics only).

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -OutputFile "C:\Output\parsed.csv"

    Converts the DNS debug log to a custom output location.
    Outputs: C:\Output\parsed.csv.

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -Delimiter "," -ComputerName "DNS01" -OutputType Both

    Converts the log using comma delimiter with a ComputerName column.
    Outputs: C:\Logs\dns.csv and C:\Logs\dns_statistic.csv, both with "DNS01" in ComputerName column.

.EXAMPLE
    PS C:\> Get-ChildItem "C:\Logs\*.log" | .\Convert-DnsDebugLogFile.ps1 -OutputType Both

    Processes multiple DNS debug log files via pipeline.
    Outputs: For each .log file, generates both .csv (data) and _statistic.csv (statistics) files.

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -CompressOutput

    Converts the DNS debug log and compresses the output to a ZIP archive.
    Outputs: C:\Logs\dns.zip containing dns.csv. The uncompressed csv file is removed after compression.

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -OutputType Both -CompressOutput

    Converts the log with statistics and compresses both output files.
    Outputs: C:\Logs\dns.zip containing both dns.csv and dns_statistic.csv.

.EXAMPLE
    PS C:\> Get-ChildItem "C:\Logs\*.log" | .\Convert-DnsDebugLogFile.ps1 -RemoveSourceFile -CompressOutput

    Processes multiple log files, compresses output, and removes source files.
    Each .log file is converted to compressed .zip, then the source .log file is deleted.
    Ideal for automated log archival pipelines.

.EXAMPLE
    PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\old_dns.log" -RemoveSourceFile -Verbose

    Converts the log file and removes the source after successful processing.
    Verbose output confirms file removal. Use with caution as source files are permanently deleted.

.NOTES
    Version:    1.2.0.0
    Author:     Andreas Bellstedt, Copilot
    Date:       2026-01-23
    Keywords:   Microsoft, Windows Server, DNSServer, DNS, DebugLog, LogParser

.LINK
    https://github.com/AndiBellstedt

#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('FullName', 'FilePath', 'InputPath', 'File', 'Path')]
        [string[]]
        $InputFile,

        [Parameter()]
        [Alias('Output', 'Destination', 'OutFile', 'OutputPath')]
        [string]
        $OutputFile,

        [Parameter()]
        [ValidateLength(1, 1)]
        [string]
        $Delimiter = ';',

        [Parameter()]
        [Alias('Server', 'DNSServer', 'HostName')]
        [string]
        $ComputerName,

        [Parameter()]
        [ValidateSet('CSV', 'Statistic', 'Both')]
        [string]
        $OutputType = 'Both',

        [Parameter()]
        [switch]
        $SkipHeaderValidation,

        [Parameter()]
        [switch]
        $RemoveSourceFile,

        [Parameter()]
        [switch]
        $CompressOutput
    )

    begin {
        #region -- Initialization
        # Track if user explicitly provided an OutputFile (for pipeline support)
        $explicitOutputFile = -not [string]::IsNullOrEmpty($OutputFile)

        # Validate OutputFile if provided - must not be a directory
        if ($explicitOutputFile) {
            # Resolve to absolute path for validation
            if (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
                $resolvedOutputFile = Join-Path -Path (Get-Location).Path -ChildPath $OutputFile
            } else {
                $resolvedOutputFile = $OutputFile
            }

            # Check if path exists and is a directory
            if (Test-Path -Path $resolvedOutputFile -PathType Container) {
                throw "OutputFile parameter must be a file path, not a directory: '$OutputFile'. Please specify a file name (e.g., 'C:\Output\result.csv')."
            }

            # Check if parent directory exists (if path contains directory)
            $parentDir = [System.IO.Path]::GetDirectoryName($resolvedOutputFile)
            if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -Path $parentDir -PathType Container)) {
                throw "Output directory does not exist: '$parentDir'. Please create the directory first or omit OutputFile to use the input file's directory."
            }
        }

        <#
    DNS Debug Log Field Definitions (from log header lines 5-29):
        Field 1:  Date
        Field 2:  Time
        Field 3:  Thread ID
        Field 4:  Context
        Field 5:  Internal packet identifier
        Field 6:  UDP/TCP indicator
        Field 7:  Send/Receive indicator
        Field 8:  Client IP
        Field 9:  Xid (hex)
        Field 10: Query/Response (R = Response, blank = Query)
        Field 11: Opcode (Q = Standard Query, N = Notify, U = Update, ? = Unknown)
        Field 12: Flags (hex) - starts with [
        Field 13: Flags (char codes) - A=Authoritative, T=Truncated, D=Recursion Desired, R=Recursion Available
        Field 14: ResponseCode - ends with ]
        Field 15: Question Type
        Field 16: Question Name
    #>
        $headerTemplateBase = 'DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName'
        $headerTemplateWithComputer = 'ComputerName{0}DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName'
        #endregion Initialization

        # Start a stopwatch to measure total script runtime and a file counter
        $dnsParserStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        [int]$fileCount = 0

        #region -- Helper Functions
        function Test-DnsDebugLogHeader {
            <#
        .SYNOPSIS
            Validates that a file is a valid DNS Server debug log by checking the header structure.

        .DESCRIPTION
            Checks the first few lines of the file to ensure they match the standard DNS debug log format:
            - Line 1: "DNS Server log file creation at <timestamp>"
            - Line 2: "Log file wrap at <timestamp>" or empty line
            - Line 3: Empty line (or line 4 if line 2 had wrap message)
            - Next: "Message logging key (for packets - other items use a subset of these fields):"
            - Next: Tab + "Field #  Information         Values"

            The function validates the essential header components and returns the number of header
            lines to skip (typically 30 for standard logs). Returns 0 if validation fails.

            Supports both standard DNS debug logs and detailed logs with additional UDP/TCP information.
        #>
            param(
                [Parameter(Mandatory = $true)]
                [string]
                $FilePath
            )

            try {
                $reader = [System.IO.StreamReader]::new($FilePath, [System.Text.Encoding]::UTF8, $true)

                # Read first several lines to validate header structure
                $lines = @()
                for ($i = 0; $i -lt 10; $i++) {
                    $line = $reader.ReadLine()
                    if ($null -eq $line) {
                        break
                    }
                    $lines += $line
                }

                $reader.Close()
                $reader.Dispose()

                # Need at least 5 lines to validate
                if ($lines.Count -lt 5) {
                    return 0
                }

                # Line 1: Must start with "DNS Server log file creation at" with timestamp
                # Use StartsWith for better performance than regex
                if (-not $lines[0].StartsWith('DNS Server log file creation at ')) {
                    return 0
                }
                # Quick validation: line should be at least 47 chars ("DNS Server log file creation at DD.MM.YYYY HH:MM:SS")
                if ($lines[0].Length -lt 47) {
                    return 0
                }

                # Line 2: Can be "Log file wrap at" or empty line
                $lineOffset = 0
                if ($lines[1].StartsWith('Log file wrap at')) {
                    $lineOffset = 1
                    # If line 2 is wrap message, line 3 should be empty
                    if (-not [string]::IsNullOrWhiteSpace($lines[2])) {
                        return 0
                    }
                } elseif (-not [string]::IsNullOrWhiteSpace($lines[1])) {
                    return 0
                }

                # Find the "Message logging key" line (should be at index 2+offset or 3+offset)
                $messageKeyIndex = -1
                for ($i = (2 + $lineOffset); $i -lt $lines.Count; $i++) {
                    if ($lines[$i].StartsWith('Message logging key (for packets')) {
                        $messageKeyIndex = $i
                        break
                    }
                }

                if ($messageKeyIndex -eq -1) {
                    return 0
                }

                # Next line after "Message logging key" should contain "Field #"
                $fieldHeaderIndex = $messageKeyIndex + 1
                if ($fieldHeaderIndex -ge $lines.Count) {
                    return 0
                }

                # Use Contains for better performance than regex with \s+ pattern
                $fieldHeaderLine = $lines[$fieldHeaderIndex].TrimStart()
                if (-not $fieldHeaderLine.StartsWith('Field #') -or -not $fieldHeaderLine.Contains('Information')) {
                    return 0
                }

                # Valid DNS debug log - return standard header line count
                # Standard DNS debug log has 29 lines of header + 1 empty line = 30 total
                return 30

            } catch {
                return 0
            }
        }

        function ConvertTo-Fqdn {
            <#
        .SYNOPSIS
            Converts DNS name format (3)odc(10)officeapps(4)live(3)com(0) to FQDN odc.officeapps.live.com
        #>
            param([string]$EncodedName)

            if ([string]::IsNullOrWhiteSpace($EncodedName)) {
                return [string]::Empty
            }

            # Fast string parsing without regex
            $result = [System.Text.StringBuilder]::new(256)
            $i = 0
            $len = $EncodedName.Length

            while ($i -lt $len) {
                # Find opening parenthesis
                $openParen = $EncodedName.IndexOf('(', $i)
                if ($openParen -eq -1) { break }

                # Find closing parenthesis
                $closeParen = $EncodedName.IndexOf(')', $openParen)
                if ($closeParen -eq -1) { break }

                # Extract the number (length indicator)
                $lengthStr = $EncodedName.Substring($openParen + 1, $closeParen - $openParen - 1)

                # Check if it's the terminating (0)
                if ($lengthStr -eq '0') { break }

                # Extract the label that follows
                $labelStart = $closeParen + 1
                $nextParen = $EncodedName.IndexOf('(', $labelStart)

                if ($nextParen -eq -1) {
                    $label = $EncodedName.Substring($labelStart)
                } else {
                    $label = $EncodedName.Substring($labelStart, $nextParen - $labelStart)
                }

                # Append with dot separator
                if ($result.Length -gt 0) {
                    $null = $result.Append('.')
                }
                $null = $result.Append($label)

                $i = if ($nextParen -eq -1) { $len } else { $nextParen }
            }

            return $result.ToString()
        }

        function ConvertFrom-DnsLogLine {
            <#
        .SYNOPSIS
            Parses a single DNS debug log line into a structured object.
        #>
            param([string]$Line)

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($Line)) {
                return $null
            }

            # Minimum line length check (date + time + minimal data)
            if ($Line.Length -lt 25) {
                return $null
            }

            # Parse fixed-position fields for maximum performance
            # Format: "13.01.2026 23:00:16 0FE0 PACKET  000002C53117D990 UDP Rcv 10.10.31.11     c049   Q [0001   D   NOERROR] A      (3)odc..."

            # Field 1 & 2: Date and Time (positions 0-18, format: DD.MM.YYYY HH:MM:SS)
            $dateStr = $Line.Substring(0, 10)    # DD.MM.YYYY
            $timeStr = $Line.Substring(11, 8)    # HH:MM:SS

            # Parse DateTime - German format DD.MM.YYYY
            $dateTime = $null
            $dateParts = $dateStr.Split('.')
            if ($dateParts.Count -eq 3) {
                try {
                    $dateTime = [datetime]::new(
                        [int]$dateParts[2],  # Year
                        [int]$dateParts[1],  # Month
                        [int]$dateParts[0],  # Day
                        [int]$timeStr.Substring(0, 2),   # Hour
                        [int]$timeStr.Substring(3, 2),   # Minute
                        [int]$timeStr.Substring(6, 2)    # Second
                    )
                } catch {
                    return $null
                }
            } else {
                return $null
            }

            # Remaining part after datetime (position 20+)
            $remaining = $Line.Substring(20).TrimStart()

            # Split on whitespace for remaining fields
            $parts = $remaining.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)

            if ($parts.Count -lt 7) {
                return $null
            }

            # Field 3: Thread ID
            $threadId = $parts[0]

            # Field 4: Context (e.g., PACKET)
            $context = $parts[1]

            # Field 5: Internal packet identifier
            $packetId = $parts[2]

            # Field 6: UDP/TCP indicator
            $protocol = $parts[3]

            # Field 7: Send/Receive indicator
            $direction = $parts[4]

            # Field 8: Remote IP
            $remoteIp = $parts[5]

            # Field 9: Xid (hex)
            $xid = $parts[6]

            # Fields 10-16: Variable position based on Query/Response
            $partIndex = 7
            $queryResponse = [string]::Empty
            $opcode = [string]::Empty
            $flagsHex = [string]::Empty
            $flagsChar = [string]::Empty
            $responseCode = [string]::Empty
            $questionType = [string]::Empty
            $questionName = [string]::Empty

            # Check for Response indicator "R"
            if ($partIndex -lt $parts.Count -and $parts[$partIndex] -eq 'R') {
                $queryResponse = 'R'
                $partIndex++
            }

            # Field 11: Opcode (Q, N, U, ?)
            if ($partIndex -lt $parts.Count) {
                $opcode = $parts[$partIndex]
                $partIndex++
            }

            # Fields 12-14: Flags section in brackets [FlagsHex FlagsChar ResponseCode]
            # Format: [8081 DR NOERROR] or [8085 A DR NOERROR]
            # Find the bracket section
            $bracketStart = $remaining.IndexOf('[')
            $bracketEnd = $remaining.IndexOf(']')

            if ($bracketStart -gt -1 -and $bracketEnd -gt $bracketStart) {
                $bracketContent = $remaining.Substring($bracketStart + 1, $bracketEnd - $bracketStart - 1).Trim()
                $flagParts = $bracketContent.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)

                if ($flagParts.Count -ge 1) {
                    $flagsHex = $flagParts[0]
                }
                # ResponseCode is always last (NOERROR, NXDOMAIN, etc.)
                # FlagsChar is everything between FlagsHex and ResponseCode
                if ($flagParts.Count -ge 2) {
                    $responseCode = $flagParts[$flagParts.Count - 1]
                    if ($flagParts.Count -gt 2) {
                        $flagsChar = [string]::Join('', $flagParts[1..($flagParts.Count - 2)])
                    }
                }
            }

            # Field 15 & 16: Question Type and Name (after the bracket)
            if ($bracketEnd -gt -1 -and $bracketEnd + 1 -lt $remaining.Length) {
                $afterBracket = $remaining.Substring($bracketEnd + 1).TrimStart()
                $afterParts = $afterBracket.Split([char[]]@(' ', "`t"), 2, [StringSplitOptions]::RemoveEmptyEntries)

                if ($afterParts.Count -ge 1) {
                    $questionType = $afterParts[0]
                }
                if ($afterParts.Count -ge 2) {
                    $questionName = $afterParts[1].Trim()
                }
            }

            # Convert question name to FQDN
            $fqdn = ConvertTo-Fqdn -EncodedName $questionName

            # Return parsed object using ordered hashtable for performance
            return [PSCustomObject]@{
                DateTime      = $dateTime
                ThreadId      = $threadId
                Context       = $context
                PacketId      = $packetId
                Protocol      = $protocol
                Direction     = $direction
                RemoteIP      = $remoteIp
                Xid           = $xid
                QueryResponse = $queryResponse
                Opcode        = $opcode
                FlagsHex      = $flagsHex
                FlagsChar     = $flagsChar
                ResponseCode  = $responseCode
                QuestionType  = $questionType
                QuestionName  = $fqdn
            }
        }
        #endregion Helper Functions
    }

    process {
        foreach ($currentFile in $InputFile) {
            # Validate input file exists and is a file (not a directory)
            if (-not (Test-Path -Path $currentFile)) {
                Write-Error ("Input file does not exist: '{0}'" -f $currentFile)
                continue
            }

            if ((Get-Item -Path $currentFile).PSIsContainer) {
                Write-Error ("Input path is a directory, not a file: '{0}'. Please specify a file path." -f $currentFile)
                continue
            }

            # Resolve full path
            $resolvedPath = Resolve-Path -Path $currentFile | Select-Object -ExpandProperty Path

            # Validate DNS debug log header (unless validation is skipped)
            if ($SkipHeaderValidation) {
                # Skip validation - assume standard 30-line header
                $skipLines = 30
                Write-Verbose "Header validation skipped for: '$resolvedPath'"
            } else {
                $skipLines = Test-DnsDebugLogHeader -FilePath $resolvedPath
                if ($skipLines -eq 0) {
                    Write-Error ("File is not a valid DNS Server debug log: '{0}'. The file header does not match the expected DNS debug log format. Use -SkipHeaderValidation to bypass this check." -f $resolvedPath)
                    continue
                }
            }

            # Calculate output path for this input file
            # If user didn't explicitly provide OutputFile, derive from input file
            if (-not $explicitOutputFile) {
                $currentOutputPath = [System.IO.Path]::ChangeExtension($resolvedPath, '.csv')
            } else {
                # Use the explicitly provided OutputFile (resolved to absolute)
                if (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
                    $currentOutputPath = Join-Path -Path (Get-Location).Path -ChildPath $OutputFile
                } else {
                    $currentOutputPath = $OutputFile
                }
            }

            Write-Verbose "Processing: '$resolvedPath' --> Output: '$currentOutputPath' (Delimiter: '$Delimiter')"

            # Build header with specified delimiter (conditionally include ComputerName)
            $includeComputerName = -not [string]::IsNullOrEmpty($ComputerName)
            if ($includeComputerName) {
                $header = $headerTemplateWithComputer -f $Delimiter
            } else {
                $header = $headerTemplateBase -f $Delimiter
            }

            # Use StreamReader for maximum performance with large files
            $reader = $null
            $writer = $null
            $lineCount = 0
            $parsedCount = 0

            # Initialize statistics dictionary if requested (using Dictionary for performance)
            $statistics = $null
            if ($OutputType -eq 'Statistic' -or $OutputType -eq 'Both') {
                $statistics = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new()
            }

            # Determine if we need to write CSV data
            $writeCsvData = ($OutputType -eq 'CSV' -or $OutputType -eq 'Both')

            try {
                $reader = [System.IO.StreamReader]::new($resolvedPath, [System.Text.Encoding]::UTF8, $true, 65536)

                # Only create CSV writer if we're outputting CSV data
                if ($writeCsvData) {
                    $writer = [System.IO.StreamWriter]::new($currentOutputPath, $false, [System.Text.Encoding]::UTF8, 65536)
                    # Write CSV header
                    $writer.WriteLine($header)
                }

                # Skip header lines (validated count from Test-DnsDebugLogHeader)
                for ($i = 0; $i -lt $skipLines -and -not $reader.EndOfStream; $i++) {
                    $null = $reader.ReadLine()
                    $lineCount++
                }

                # Process data lines
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    $lineCount++

                    $parsed = ConvertFrom-DnsLogLine -Line $line
                    if ($null -ne $parsed) {
                        # Build CSV line manually for performance (avoiding Export-Csv overhead) - only if needed
                        if ($writeCsvData) {
                            if ($includeComputerName) {
                                $csvLine = ($ComputerName + $Delimiter + '{0:yyyy-MM-dd HH:mm:ss}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"') -f @(
                                    $parsed.DateTime,
                                    $parsed.ThreadId,
                                    $parsed.Context,
                                    $parsed.PacketId,
                                    $parsed.Protocol,
                                    $parsed.Direction,
                                    $parsed.RemoteIP,
                                    $parsed.Xid,
                                    $(
                                        if ($parsed.QueryResponse -eq 'R') { 'Response' } else { 'Query' }
                                    ),
                                    $(
                                        switch ($parsed.Opcode) {
                                            'Q' { 'Standard' }
                                            'N' { 'Notify' }
                                            'U' { 'Update' }
                                            '?' { 'Unknown' }
                                            default { $parsed.Opcode }
                                        }
                                    ),
                                    $parsed.FlagsHex,
                                    $(
                                        switch ($parsed.FlagsChar) {
                                            'A' { 'Authoritative' }
                                            'T' { 'Truncated' }
                                            'D' { 'RecursionDesired' }
                                            'R' { 'RecursionAvailable' }
                                            default { $parsed.FlagsChar }
                                        }
                                    ),
                                    $parsed.ResponseCode,
                                    $parsed.QuestionType,
                                    $parsed.QuestionName
                                )
                            } else {
                                $csvLine = ('{0:yyyy-MM-dd HH:mm:ss}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"') -f @(
                                    $parsed.DateTime,
                                    $parsed.ThreadId,
                                    $parsed.Context,
                                    $parsed.PacketId,
                                    $parsed.Protocol,
                                    $parsed.Direction,
                                    $parsed.RemoteIP,
                                    $parsed.Xid,
                                    $(
                                        if ($parsed.QueryResponse -eq 'R') { 'Response' } else { 'Query' }
                                    ),
                                    $(
                                        switch ($parsed.Opcode) {
                                            'Q' { 'Standard' }
                                            'N' { 'Notify' }
                                            'U' { 'Update' }
                                            '?' { 'Unknown' }
                                            default { $parsed.Opcode }
                                        }
                                    ),
                                    $parsed.FlagsHex,
                                    $(
                                        switch ($parsed.FlagsChar) {
                                            'A' { 'Authoritative' }
                                            'T' { 'Truncated' }
                                            'D' { 'RecursionDesired' }
                                            'R' { 'RecursionAvailable' }
                                            default { $parsed.FlagsChar }
                                        }
                                    ),
                                    $parsed.ResponseCode,
                                    $parsed.QuestionType,
                                    $parsed.QuestionName
                                )
                            }

                            # Write CSV line
                            $writer.WriteLine($csvLine)
                        }
                        $parsedCount++

                        # Collect statistics if requested
                        if ($null -ne $statistics) {
                            # Create composite key: ClientIP|Protocol|Direction|QuestionType
                            $statKey = $parsed.RemoteIP + '|' + $parsed.Protocol + '|' + $parsed.Direction + '|' + $parsed.QuestionType

                            if ($statistics.ContainsKey($statKey)) {
                                $entry = $statistics[$statKey]
                                $entry[0]++  # Count
                                if ($parsed.DateTime -lt $entry[1]) { $entry[1] = $parsed.DateTime }  # DateMin
                                if ($parsed.DateTime -gt $entry[2]) { $entry[2] = $parsed.DateTime }  # DateMax
                            } else {
                                # [Count, DateMin, DateMax]
                                $statistics[$statKey] = [System.Collections.Generic.List[object]]@(1, $parsed.DateTime, $parsed.DateTime)
                            }
                        }
                    }
                }

                Write-Verbose "Processed $lineCount lines, parsed $parsedCount entries"
                if ($writeCsvData) {
                    Write-Verbose "Successfully exported $parsedCount DNS log entries to: $currentOutputPath"
                }

                # Write statistics file if requested
                if ($null -ne $statistics -and $statistics.Count -gt 0) {
                    $statPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_statistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )

                    $statWriter = $null
                    try {
                        $statWriter = [System.IO.StreamWriter]::new($statPath, $false, [System.Text.Encoding]::UTF8, 65536)

                        # Write statistics header (conditionally include ComputerName)
                        if ($includeComputerName) {
                            $statWriter.WriteLine('ComputerName' + $Delimiter + 'ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'DateMin' + $Delimiter + 'DateMax')
                        } else {
                            $statWriter.WriteLine('ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'DateMin' + $Delimiter + 'DateMax')
                        }

                        # Write statistics data
                        foreach ($kvp in $statistics.GetEnumerator()) {
                            $keyParts = $kvp.Key.Split('|')
                            if ($includeComputerName) {
                                $statLine = $ComputerName + $Delimiter + $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $kvp.Value[0].ToString() + $Delimiter + $kvp.Value[1].ToString('yyyy-MM-dd HH:mm:ss') + $Delimiter + $kvp.Value[2].ToString('yyyy-MM-dd HH:mm:ss')
                            } else {
                                $statLine = $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $kvp.Value[0].ToString() + $Delimiter + $kvp.Value[1].ToString('yyyy-MM-dd HH:mm:ss') + $Delimiter + $kvp.Value[2].ToString('yyyy-MM-dd HH:mm:ss')
                            }
                            $statWriter.WriteLine($statLine)
                        }

                        Write-Verbose "Statistics: $($statistics.Count) unique groups"
                        Write-Verbose "Successfully exported statistics to: $statPath"
                    } finally {
                        if ($null -ne $statWriter) { $statWriter.Dispose() }
                    }
                }
            } finally {
                if ($null -ne $reader) { $reader.Dispose() }
                if ($null -ne $writer) { $writer.Dispose() }
            }

            # Compress output files if requested (process after each file for disk space management)
            if ($CompressOutput) {
                $filesToCompress = @()
                $zipPath = [System.IO.Path]::ChangeExtension($currentOutputPath, '.zip')

                # Collect files to compress
                if ($writeCsvData -and (Test-Path -Path $currentOutputPath)) {
                    $filesToCompress += $currentOutputPath
                }
                if ($null -ne $statistics -and $statistics.Count -gt 0) {
                    $statPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_statistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )
                    if (Test-Path -Path $statPath) {
                        $filesToCompress += $statPath
                    }
                }

                if ($filesToCompress.Count -gt 0) {
                    try {
                        # Remove existing ZIP if present
                        if (Test-Path -Path $zipPath) {
                            Remove-Item -Path $zipPath -Force -ErrorAction Stop
                        }

                        # Compress output files
                        Compress-Archive -Path $filesToCompress -DestinationPath $zipPath -CompressionLevel Optimal -ErrorAction Stop
                        Write-Verbose "Compressed output to: $zipPath"

                        # Remove uncompressed CSV files after successful compression
                        foreach ($file in $filesToCompress) {
                            Remove-Item -Path $file -Force -ErrorAction Stop
                            Write-Verbose "Removed uncompressed file: $file"
                        }
                    } catch {
                        Write-Error "Failed to compress output files: $_"
                    }
                }
            }

            # Remove source file if requested (only after successful processing)
            if ($RemoveSourceFile) {
                try {
                    Remove-Item -Path $resolvedPath -Force -ErrorAction Stop
                    Write-Verbose "Removed source file: $resolvedPath"
                } catch {
                    Write-Error "Failed to remove source file '$resolvedPath': $_"
                }
            }

            # Increment file counter for each processed input
            $fileCount++
        }
    }

    end {
        if ($null -ne $dnsParserStopwatch) {
            $dnsParserStopwatch.Stop()
            Write-Verbose ("Processed {0} file(s) in {1} elapsed time" -f $fileCount, $dnsParserStopwatch.Elapsed.ToString())
        }
    }
}