function Convert-DNSDebugLogFile {
    <#
    .SYNOPSIS
        Transforms Windows DNS Server debug logs into structured CSV format for analysis and reporting.

    .DESCRIPTION
        Converts Windows DNS Server debug log files into structured CSV data that can be analyzed
        in Excel, Power BI, SQL databases, or SIEM tools. Designed for security analysis, performance
        monitoring, troubleshooting, and compliance reporting.

        The cmdlet parses DNS debug logs and writes a consistent CSV output for analysis.
        The CSV output contains 18 columns, including an `Information` column for event/diagnostic text,
        an optional `Details` JSON column for Packet detail blocks, and an always-present `ComputerName`
        column (empty unless specified).

        KEY FEATURES:
        - Streaming processing avoids loading the full file into memory (suitable for very large logs)
        - High-performance parsing optimized for large files (100MB+)
        - Customizable CSV delimiter (default: semicolon)
        - Optional statistical summaries with aggregated metrics
        - Context filtering (Packet, Event, Note, and additional contexts) to focus on specific log entry types
        - Culture-aware date parsing and formatting for international servers
        - Pipeline support for batch processing multiple files
        - Optional compression of output files (ZIP format)
        - Optional automatic removal of source files after processing
        - Header validation to ensure data integrity

        OUTPUT FORMAT:
        The ComputerName column is always included at the end of each record. If the -ComputerName
        parameter is not specified, the column will be empty. This ensures consistent output structure
        for multi-server consolidation scenarios.

        PERFORMANCE:
        Optimized using StreamReader/StreamWriter with 64KB buffers, streaming processing for
        memory-efficient handling of large files, string operations instead of regex, manual CSV
        generation, and efficient hashtable-based statistics collection.

        COMPATIBILITY:
        - PowerShell 5.1+ (Desktop and Core editions)
        - Windows Server 2016+
        - DNS Server 2012 R2 through 2025 log formats

    .PARAMETER InputFile
        Specifies the path to the DNS debug log file to parse. Supports arrays for processing multiple files.

        Accepts pipeline input from Get-ChildItem or other file-producing cmdlets.

    .PARAMETER OutputFile
        Specifies the path for the output CSV file. If not specified, uses the input filename with .csv extension
        in the same directory as the input file.

        Important: Must be a file path, not a directory. If you want to use the input file's directory with
        a custom name, specify the full path including filename.

    .PARAMETER Delimiter
        Specifies the delimiter character for the CSV output.

        Default: Semicolon (;)

        Common alternatives: Comma (,), Tab (`t), Pipe (|)

        Use semicolon in regions where comma is the decimal separator (Europe). Use comma for standard
        CSV tools and databases that expect comma-separated values.

    .PARAMETER ComputerName
        Specifies the value for the ComputerName column in the CSV output. The ComputerName column is
        always present in the output - if this parameter is not specified, the column will be empty.

        Use this when consolidating logs from multiple DNS servers to identify the source server in
        combined datasets.

        Note: This is NOT a remoting parameter. It only labels the output. If you point -InputFile to
        a UNC path, the file is read from that path (no WinRM/remote execution is performed).

    .PARAMETER OutputType
        Specifies the type of output to generate.

        Valid values:
        - 'CSV': Generate only the data file with all parsed log entries
        - 'Statistic': Generate only the statistics files with aggregated metrics
        - 'Both': Generate both data and statistics files (default)

        Default: Both

        When statistics are generated, two separate files are created:
        - '_Statistic.csv': Summary counts per context type per day (Date, Context, Count, ComputerName)
        - '_PacketStatistic.csv': Detailed PACKET counts per day by client IP, protocol, direction,
          and query type (Date, ClientIP, Protocol, Direction, QuestionType, Count, ComputerName)

    .PARAMETER SkipHeaderValidation
        Bypasses the DNS debug log header validation check.

        By default, the cmdlet validates that input files have a valid DNS Server debug log header.
        Use this switch to process files without validation, which can be useful for:
        - Modified or custom log formats
        - Troubleshooting validation issues
        - Non-standard or pre-processed logs

        Warning: May result in processing errors if the file is not a valid DNS log.

    .PARAMETER RemoveSourceFile
        Removes the source DNS debug log file after successful processing.

        Use this for automated log processing pipelines or disk space management. The source file is
        only removed if processing completes successfully and all output files are created.

        Safety: Cannot be used with -SkipHeaderValidation to prevent accidental deletion of invalid files.

        Warning: Source files are permanently deleted. Ensure output files are valid before using this option.

    .PARAMETER CompressOutput
        Compresses output CSV files into a ZIP archive after creation.

        Creates a .zip file containing the generated CSV file(s), then removes the uncompressed CSV(s).
        The ZIP file is created in the same directory as the output CSV with the same base name.

        Benefits:
        - Significantly reduces disk space (CSV files typically compress 90%+)
        - Simplifies file management and archival
        - Suitable for long-term storage

        Example: Input 'dns.log' generates 'dns.csv' compressed to 'dns.zip', then 'dns.csv' is removed.

    .PARAMETER ContextFilter
        Filters which log entry types to include in the output. Accepts single or multiple values.

        DNS debug logs contain different context types:
        - PACKET: DNS query and response packet information (primary data)
        - EVENT: DNS server events (e.g., "The DNS server has started.")
        - Note: Diagnostic notes and warnings (e.g., socket errors, internal states)
        - DSPoll, Init, Lookup, Recurse, Remote, Tombstone: Additional context types

        Valid values:
        - 'All': Include all context types (default)
        - 'Packet': Include only PACKET entries (DNS queries/responses)
        - 'Event': Include only EVENT entries (server events)
        - 'Note': Include only Note entries (diagnostic information)
        - Any combination: Specify multiple values to include specific context types

        Default: All

        Examples:
        - 'Packet' filters to only DNS traffic
        - 'Packet','Event' includes both DNS traffic and server events
        - 'Note','Event' includes diagnostic notes and server events

        Note: When filtering to 'Event' or 'Note', only DateTime, ThreadId, Context, and Information
        columns will contain data. Other columns (Protocol, ClientIP, etc.) will be empty.

    .PARAMETER InputCulture
        Specifies the culture/locale to use for parsing date/time values in the DNS debug log.

        DNS Server debug logs use the date format of the Windows locale on the server where the log
        was generated. Use this parameter when processing logs from servers with different regional
        settings.

        Default: Current culture

        Common examples:
        - 'de-DE' or 'de-AT': German format (DD.MM.YYYY or DD/MM/YYYY)
        - 'en-US': US format (MM/DD/YYYY with AM/PM)
        - 'en-GB': UK format (DD/MM/YYYY with 24-hour time)
        - 'sv-SE': Swedish/ISO format (YYYY-MM-DD)

    .PARAMETER OutputCulture
        Specifies the culture/locale to use for formatting date/time values in the output CSV files.

        Controls how DateTime values are written to the CSV. Use this when CSV files will be consumed
        by applications or systems with specific regional settings.

        Default: Current culture

        Common examples:
        - 'en-US': US format (MM/DD/YYYY)
        - 'de-DE': German format (DD.MM.YYYY)
        - 'sv-SE' or InvariantCulture: ISO format (YYYY-MM-DD) for maximum compatibility

    .PARAMETER NoDetailsParsing
        Skips parsing PACKET detail blocks into structured JSON format.

        When specified, PACKET records with detail blocks will have the TCP/UDP info line in the
        Information column, but the Details column will remain empty. This significantly improves
        processing performance for large log files when detailed packet structure analysis is not needed.

        Use this switch when:
        - Processing very large log files (100MB+) and only need basic query information
        - Detail structure (Message flags, DNS sections) is not required for analysis
        - Maximizing parsing speed is more important than data completeness

        Performance impact: Can improve processing speed by 30-50% for logs with many PACKET detail blocks.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

        When specified, displays detailed information about the operations that would be performed
        without actually executing them. Useful for:
        - Previewing which files would be processed
        - Verifying output file paths before processing
        - Testing scripts before running in production

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

        When specified, prompts for confirmation before:
        - Processing each DNS debug log file
        - Removing source files (when -RemoveSourceFile is specified)
        - Overwriting existing output files

        Useful for interactive processing when you want to control which files are processed.

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log"

        Converts the DNS debug log using default settings (both data and statistics files with semicolon delimiter).
        Output:
        - C:\Logs\dns.csv
        - C:\Logs\dns_Statistic.csv
        - C:\Logs\dns_PacketStatistic.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType CSV

        Generates only the data file without statistics.
        Output: C:\Logs\dns.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Statistic

        Generates only the statistics file with aggregated metrics.
        Output:
        - C:\Logs\dns_Statistic.csv
        - C:\Logs\dns_PacketStatistic.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputFile "C:\Output\parsed.csv"

        Converts the log to a custom output location.
        Output: C:\Output\parsed.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter "," -ComputerName "DNS01" -OutputType Both

        Converts with comma delimiter and adds ComputerName column with value "DNS01".
        Output:
        - C:\Logs\dns.csv
        - C:\Logs\dns_Statistic.csv
        - C:\Logs\dns_PacketStatistic.csv

    .EXAMPLE
        PS C:\> Get-ChildItem "C:\Logs\*.log" | Convert-DNSDebugLogFile -OutputType Both

        Batch processes multiple DNS debug log files via pipeline.
        Output: For each .log file, generates .csv and _statistic.csv files

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -CompressOutput

        Converts and compresses output to ZIP archive.
        Output: C:\Logs\dns.zip (containing dns.csv + statistics files)

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -RemoveSourceFile -Verbose

        Converts the log and removes the source file after successful processing.
        Verbose output confirms file removal.

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -InputCulture 'de-DE' -OutputCulture 'en-US'

        Parses German date format (DD.MM.YYYY) and outputs in US format (MM/DD/YYYY).
        Use when processing logs from servers with different regional settings.

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -ContextFilter 'Packet'

        Converts only DNS query/response packet entries, excluding EVENT and Note entries.
        Use to focus analysis on actual DNS traffic.

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -ContextFilter 'Packet','Event'

        Converts both DNS query/response packets and server events, excluding Note and other entries.
        Use to analyze DNS traffic along with server event context.

    .EXAMPLE
        PS C:\> Get-ChildItem "C:\Logs\*.log" | Convert-DNSDebugLogFile -RemoveSourceFile -CompressOutput

        Automated log archival: processes all logs, compresses output, and removes source files.
        Ideal for scheduled log processing pipelines.

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\large-dns.log" -NoDetailsParsing

        Processes a large log file with detail parsing disabled for maximum performance.
        PACKET detail blocks are skipped, keeping the Details column empty.
        Use when processing very large files and detailed packet structure is not needed.

    .NOTES
        Version  : 1.7.1.0
        Author   : Andi Bellstedt, Copilot
        Date     : 2026-01-26
        Keywords : Microsoft Windows Server, DNSServer, DNS, DebugLog, LogParser

    .LINK
        https://github.com/AndiBellstedt/DNSServer.DebugLogParser

    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
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
        $CompressOutput,

        [Parameter()]
        [ValidateSet('All', 'Packet', 'Event', 'Note', 'DSPoll', 'Init', 'Lookup', 'Recurse', 'Remote', 'Tombstone')]
        [string[]]
        $ContextFilter = @('All'),

        [Parameter()]
        [ArgumentCompleter({
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
                param($_commandName, $_parameterName, $wordToComplete, $_commandAst, $_fakeBoundParameters)
                [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) |
                Where-Object { $_.Name -like "$wordToComplete*" -and -not [string]::IsNullOrEmpty($_.Name) } |
                Sort-Object Name |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new(
                        $_.Name,
                        $_.Name,
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        "$($_.Name) - $($_.DisplayName)"
                    )
                }
            })]
        [System.Globalization.CultureInfo]
        $InputCulture = [System.Globalization.CultureInfo]::CurrentCulture,

        [Parameter()]
        [ArgumentCompleter({
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
                param($_commandName, $_parameterName, $wordToComplete, $_commandAst, $_fakeBoundParameters)
                [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) |
                Where-Object { $_.Name -like "$wordToComplete*" -and -not [string]::IsNullOrEmpty($_.Name) } |
                Sort-Object Name |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new(
                        $_.Name,
                        $_.Name,
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        "$($_.Name) - $($_.DisplayName)"
                    )
                }
            })]
        [System.Globalization.CultureInfo]
        $OutputCulture = [System.Globalization.CultureInfo]::CurrentCulture,

        [Parameter()]
        [switch]
        $NoDetailsParsing
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
        $headerTemplate = 'DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName{0}Information{0}Details{0}ComputerName'
        #endregion Initialization

        # Start a stopwatch to measure total script runtime and a file counter
        $dnsParserStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        [int]$fileCount = 0
        [int]$progressCounter = 0
        [int]$progressUpdateInterval = 1000

        # Validate parameter combination safety
        if ($RemoveSourceFile -and $SkipHeaderValidation) {
            throw "RemoveSourceFile cannot be used with SkipHeaderValidation due to safety concerns. Header validation ensures the file is a valid DNS log before permanent deletion."
        }
    }

    process {
        #region File Processing
        foreach ($currentFile in $InputFile) {
            # Reset progress counter for each file to ensure consistent progress update intervals
            $progressCounter = 0

            # Validate input file exists and is a file (not a directory)
            if (-not (Test-Path -Path $currentFile)) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.IO.FileNotFoundException]::new("Input file does not exist: '$currentFile'"),
                    'InputFileNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $currentFile
                )
                $PSCmdlet.WriteError($errorRecord)
                continue
            }

            # Check if input path is a directory
            if ((Get-Item -Path $currentFile).PSIsContainer) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.ArgumentException]::new("Input path is a directory, not a file: '$currentFile'. Please specify a file path."),
                    'InputPathIsDirectory',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $currentFile
                )
                $PSCmdlet.WriteError($errorRecord)
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
                Write-Verbose "Validating DNS debug log header for: '$resolvedPath'"
                $skipLines = Test-DnsDebugLogHeader -Path $resolvedPath
                if ($skipLines -eq 0) {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.FormatException]::new("File is not a valid DNS Server debug log: '$resolvedPath'. The file header does not match the expected DNS debug log format. Use -SkipHeaderValidation to bypass this check."),
                        'InvalidDnsLogHeader',
                        [System.Management.Automation.ErrorCategory]::InvalidData,
                        $resolvedPath
                    )
                    $PSCmdlet.WriteError($errorRecord)
                    continue
                }
                Write-Verbose "Header validation successful ($skipLines header lines)"
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

            Write-Verbose "Starting processing: '$resolvedPath' (Input culture for date parsing: $($InputCulture.Name) [$($InputCulture.DisplayName)])"
            Write-Verbose "Output type: $($OutputType) | CSV delimiter: '$Delimiter'"
            Write-Verbose "Output path: '$currentOutputPath' (Output culture for date formatting: $($OutputCulture.Name) [$($OutputCulture.DisplayName)])"

            # Build header with specified delimiter (ComputerName is always included at the end)
            $header = $headerTemplate -f $Delimiter
            $computerNameValue = if ([string]::IsNullOrEmpty($ComputerName)) { '' } else { $ComputerName }

            # Use StreamReader for maximum performance with large files
            $reader = $null
            $writer = $null
            $lineCount = 0
            $parsedCount = 0

            # Initialize statistics dictionaries if requested (using Dictionary for performance)
            # contextStatistics: summarizes all records by Date|Context
            # packetStatistics: detailed PACKET records by Date|ClientIP|Protocol|Direction|QuestionType
            $contextStatistics = $null
            $packetStatistics = $null
            if ($OutputType -eq 'Statistic' -or $OutputType -eq 'Both') {
                $contextStatistics = [System.Collections.Generic.Dictionary[string, int]]::new()
                $packetStatistics = [System.Collections.Generic.Dictionary[string, int]]::new()
            }

            # Determine if we need to write CSV data
            $writeCsvData = ($OutputType -eq 'CSV' -or $OutputType -eq 'Both')

            # Pre-build date/time format string for OutputCulture (performance optimization)
            # Use the culture's short date and long time patterns for consistent output
            $outputDateTimeFormat = $OutputCulture.DateTimeFormat.ShortDatePattern + ' ' + $OutputCulture.DateTimeFormat.LongTimePattern

            try {
                $reader = [System.IO.StreamReader]::new($resolvedPath, [System.Text.Encoding]::UTF8, $true, 65536)

                # Only create CSV writer if we're outputting CSV data
                if ($writeCsvData) {
                    # Check if we should process (WhatIf support)
                    if ($PSCmdlet.ShouldProcess($currentOutputPath, "Create CSV output file")) {
                        Write-Verbose "Initializing CSV writer for: '$currentOutputPath'"
                        $writer = [System.IO.StreamWriter]::new($currentOutputPath, $false, [System.Text.Encoding]::UTF8, 65536)
                        # Write CSV header
                        $writer.WriteLine($header)
                    } else {
                        # In WhatIf mode, don't create writer
                        $writeCsvData = $false
                    }
                }

                # Skip header lines (validated count from Test-DnsDebugLogHeader)
                for ($i = 0; $i -lt $skipLines -and -not $reader.EndOfStream; $i++) {
                    $null = $reader.ReadLine()
                    $lineCount++
                }

                #region -- Process data lines
                # Multi-line record processing:
                # - PACKET context can have detail blocks (TCP/UDP info + indented detail lines until empty line)
                # - Other contexts can have continuation lines (indented lines following the main line)
                # Records are delimited by: empty lines OR lines starting with a date (new record)

                # Streaming lookahead buffer implementation:
                # - Maintains a small queue of upcoming lines for multi-line record detection
                # - Avoids loading entire file into memory (OOM prevention for 100MB+ files)
                # - Buffer size of 100 lines provides sufficient lookahead for detail blocks
                $bufferSize = 100
                $lookaheadBuffer = [System.Collections.Generic.Queue[string]]::new($bufferSize)

                # Pre-fill the lookahead buffer
                while (-not $reader.EndOfStream -and $lookaheadBuffer.Count -lt $bufferSize) {
                    $lookaheadBuffer.Enqueue($reader.ReadLine())
                    $lineCount++
                }

                # Process lines using streaming approach with lookahead capability
                while ($lookaheadBuffer.Count -gt 0) {
                    # Dequeue next line for processing
                    $line = $lookaheadBuffer.Dequeue()

                    # Refill buffer to maintain lookahead capability
                    if (-not $reader.EndOfStream) {
                        $lookaheadBuffer.Enqueue($reader.ReadLine())
                        $lineCount++
                    }

                    # Skip empty lines (record separators)
                    if ([string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }

                    # Parse the main record line
                    $parsed = ConvertFrom-DnsLogLine -Line $line -Culture $InputCulture -ContextFilter $ContextFilter
                    if ($null -eq $parsed) { continue }

                    # Initialize multi-line record fields
                    $information = $parsed.Information
                    $details = [string]::Empty

                    #region -- -- Collect continuation/detail lines
                    if ($parsed.Context -eq 'Packet') {
                        # PACKET context: Check for detail block
                        # Detail blocks start with "TCP " or "UDP " on the next line (no date prefix)
                        # followed by indented lines, terminated by empty line

                        if ($lookaheadBuffer.Count -gt 0) {
                            # Peek at next line (convert Queue to array for indexed access)
                            $bufferArray = $lookaheadBuffer.ToArray()
                            $nextLine = $bufferArray[0]

                            # Check if next line starts with "TCP " or "UDP " (detail block indicator)
                            if ($nextLine.StartsWith('TCP ') -or $nextLine.StartsWith('UDP ')) {
                                # This is a detail block - extract the TCP/UDP info line
                                $information = $nextLine.TrimEnd()

                                # Consume the TCP/UDP line from buffer
                                $null = $lookaheadBuffer.Dequeue()
                                if (-not $reader.EndOfStream) {
                                    $lookaheadBuffer.Enqueue($reader.ReadLine())
                                    $lineCount++
                                }

                                # Collect all indented detail lines until empty line or new record
                                $detailLineList = [System.Collections.Generic.List[string]]::new()

                                while ($lookaheadBuffer.Count -gt 0) {
                                    # Peek at next line
                                    $bufferArray = $lookaheadBuffer.ToArray()
                                    $detailLine = $bufferArray[0]

                                    # Empty line terminates the detail block
                                    if ([string]::IsNullOrWhiteSpace($detailLine)) {
                                        # Consume empty line
                                        $null = $lookaheadBuffer.Dequeue()
                                        if (-not $reader.EndOfStream) {
                                            $lookaheadBuffer.Enqueue($reader.ReadLine())
                                            $lineCount++
                                        }
                                        break
                                    }

                                    # Check if line starts with whitespace (continuation) or is a new record (starts with date)
                                    if ($detailLine.Length -gt 0 -and $detailLine[0] -eq ' ') {
                                        # Continuation line - trim leading whitespace (2 spaces indent) but preserve structure
                                        $detailLineList.Add($detailLine.TrimStart())

                                        # Consume the detail line from buffer
                                        $null = $lookaheadBuffer.Dequeue()
                                        if (-not $reader.EndOfStream) {
                                            $lookaheadBuffer.Enqueue($reader.ReadLine())
                                            $lineCount++
                                        }
                                    } else {
                                        # New record detected - don't consume this line
                                        break
                                    }
                                }

                                # Parse detail lines into JSON structure if we have any (unless NoDetailsParsing is enabled)
                                if ($detailLineList.Count -gt 0 -and -not $NoDetailsParsing) {
                                    $details = ConvertTo-PacketDetailJson -DetailLines $detailLineList
                                }
                            } elseif ([string]::IsNullOrWhiteSpace($nextLine)) {
                                # Empty line after PACKET without details - skip it
                                $null = $lookaheadBuffer.Dequeue()
                                if (-not $reader.EndOfStream) {
                                    $lookaheadBuffer.Enqueue($reader.ReadLine())
                                    $lineCount++
                                }
                            }
                            # Otherwise, nextLine is a new record - don't consume it
                        }
                    } else {
                        # Non-PACKET context: Collect continuation lines (indented lines) into Information
                        # Continuation lines start with whitespace and are appended to the main line's information
                        $continuationTextList = [System.Collections.Generic.List[string]]::new()

                        while ($lookaheadBuffer.Count -gt 0) {
                            # Peek at next line
                            $bufferArray = $lookaheadBuffer.ToArray()
                            $contLine = $bufferArray[0]

                            # Empty line terminates continuation
                            if ([string]::IsNullOrWhiteSpace($contLine)) {
                                # Consume empty line
                                $null = $lookaheadBuffer.Dequeue()
                                if (-not $reader.EndOfStream) {
                                    $lookaheadBuffer.Enqueue($reader.ReadLine())
                                    $lineCount++
                                }
                                break
                            }

                            # Check if line starts with whitespace (continuation)
                            if ($contLine.Length -gt 0 -and $contLine[0] -eq ' ') {
                                # Continuation line - trim whitespace and add to list
                                $continuationTextList.Add($contLine.Trim())

                                # Consume the continuation line from buffer
                                $null = $lookaheadBuffer.Dequeue()
                                if (-not $reader.EndOfStream) {
                                    $lookaheadBuffer.Enqueue($reader.ReadLine())
                                    $lineCount++
                                }
                            } else {
                                # New record detected - don't consume this line
                                break
                            }
                        }

                        # Combine continuation lines with original information
                        if ($continuationTextList.Count -gt 0) {
                            if ([string]::IsNullOrEmpty($information)) {
                                $information = [string]::Join(' ', $continuationTextList)
                            } else {
                                $information = $information + ' ' + [string]::Join(' ', $continuationTextList)
                            }
                        }
                    }
                    #endregion -- -- Collect continuation/detail lines

                    #region -- -- Build CSV line
                    if ($writeCsvData) {
                        # Format DateTime using OutputCulture for culture-aware output
                        $formattedDateTime = $parsed.DateTime.ToString($outputDateTimeFormat, $OutputCulture)

                        # Escape double quotes in text fields for proper CSV formatting
                        # Standard CSV escaping: replace " with ""
                        $escapedQuestionName = $parsed.QuestionName -replace '"', '""'
                        $escapedInformation = $information -replace '"', '""'
                        $escapedDetails = $details -replace '"', '""'

                        # Build CSV line with all 18 columns including Details
                        $csvLine = ('{0}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"' + $Delimiter + '"{15}"' + $Delimiter + '"{16}"' + $Delimiter + '{17}') -f @(
                            $formattedDateTime,
                            $parsed.ThreadId,
                            $parsed.Context,
                            $parsed.PacketId,
                            $parsed.Protocol,
                            $parsed.Direction,
                            $parsed.RemoteIP,
                            $parsed.Xid,
                            $(
                                if ($parsed.QueryResponse -eq 'R') { 'Response' }
                                elseif ($parsed.Context -eq 'Packet') { 'Query' }
                                else { '' }
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
                            $escapedQuestionName,
                            $escapedInformation,
                            $escapedDetails,
                            $computerNameValue
                        )

                        # Write CSV line
                        $writer.WriteLine($csvLine)
                    }
                    #endregion -- -- Build CSV line

                    $parsedCount++
                    $progressCounter++

                    # Update progress every 1000 records for performance efficiency
                    if ($progressCounter -ge $progressUpdateInterval) {
                        Write-Progress -Activity "Processing DNS log file: $([System.IO.Path]::GetFileName($resolvedPath))" -Status "Parsed $parsedCount records ($lineCount lines read)" -PercentComplete -1
                        $progressCounter = 0
                    }

                    #region -- -- Collect statistics
                    if ($null -ne $contextStatistics) {
                        # Extract date portion only (no time) for daily grouping
                        $dateOnly = $parsed.DateTime.Date.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)

                        # Context statistics: count all records by Date|Context
                        $contextKey = $dateOnly + '|' + $parsed.Context
                        if ($contextStatistics.ContainsKey($contextKey)) {
                            $contextStatistics[$contextKey]++
                        } else {
                            $contextStatistics[$contextKey] = 1
                        }

                        # Packet statistics: count only standard PACKET records (with RemoteIP) by Date|ClientIP|Protocol|Direction|QuestionType
                        # Info-only PACKET records (e.g., "Response packet does not match") have empty RemoteIP and are excluded
                        if ($parsed.Context -eq 'Packet' -and -not [string]::IsNullOrEmpty($parsed.RemoteIP)) {
                            $packetKey = $dateOnly + '|' + $parsed.RemoteIP + '|' + $parsed.Protocol + '|' + $parsed.Direction + '|' + $parsed.QuestionType
                            if ($packetStatistics.ContainsKey($packetKey)) {
                                $packetStatistics[$packetKey]++
                            } else {
                                $packetStatistics[$packetKey] = 1
                            }
                        }
                    }
                    #endregion -- -- Collect statistics
                }
                #endregion Process data lines

                # Complete progress bar
                Write-Progress -Activity "Processing DNS log file: $([System.IO.Path]::GetFileName($resolvedPath))" -Completed

                Write-Verbose "Completed parsing: $lineCount total lines, $parsedCount valid entries"
                if ($writeCsvData) {
                    Write-Verbose "Successfully exported $parsedCount DNS log entries to: '$currentOutputPath'"
                }

                # Write context statistics file if requested (_Statistic)
                if ($null -ne $contextStatistics -and $contextStatistics.Count -gt 0) {
                    Write-Verbose "Generating context statistics file with $($contextStatistics.Count) unique groups"
                    $contextStatPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_Statistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )

                    # Check if we should process (WhatIf support)
                    if ($PSCmdlet.ShouldProcess($contextStatPath, "Create context statistics output file")) {
                        $statWriter = $null
                        try {
                            $statWriter = [System.IO.StreamWriter]::new($contextStatPath, $false, [System.Text.Encoding]::UTF8, 65536)

                            # Write context statistics header
                            $statWriter.WriteLine('Date' + $Delimiter + 'Context' + $Delimiter + 'Count' + $Delimiter + 'ComputerName')

                            # Write context statistics data (sort by Date, then Context for better readability)
                            foreach ($kvp in ($contextStatistics.GetEnumerator() | Sort-Object -Property Key)) {
                                $keyParts = $kvp.Key.Split('|')
                                # Key format: Date|Context
                                $statLine = $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $kvp.Value.ToString() + $Delimiter + $computerNameValue
                                $statWriter.WriteLine($statLine)
                            }

                            Write-Verbose "Successfully exported context statistics to: '$contextStatPath' ($($contextStatistics.Count) unique groups)"
                        } finally {
                            if ($null -ne $statWriter) { $statWriter.Dispose() }
                        }
                    }
                }

                # Write packet statistics file if requested (_PacketStatistic)
                if ($null -ne $packetStatistics -and $packetStatistics.Count -gt 0) {
                    Write-Verbose "Generating packet statistics file with $($packetStatistics.Count) unique groups"
                    $packetStatPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_PacketStatistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )

                    # Check if we should process (WhatIf support)
                    if ($PSCmdlet.ShouldProcess($packetStatPath, "Create packet statistics output file")) {
                        $statWriter = $null
                        try {
                            $statWriter = [System.IO.StreamWriter]::new($packetStatPath, $false, [System.Text.Encoding]::UTF8, 65536)

                            # Write packet statistics header (ComputerName is always included at the end)
                            $statWriter.WriteLine('Date' + $Delimiter + 'ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'ComputerName')

                            # Write packet statistics data (sort by Date, then ClientIP for better readability)
                            foreach ($kvp in ($packetStatistics.GetEnumerator() | Sort-Object -Property Key)) {
                                $keyParts = $kvp.Key.Split('|')
                                # Key format: Date|ClientIP|Protocol|Direction|QuestionType
                                $statLine = $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $keyParts[4] + $Delimiter + $kvp.Value.ToString() + $Delimiter + $computerNameValue
                                $statWriter.WriteLine($statLine)
                            }

                            Write-Verbose "Successfully exported packet statistics to: '$packetStatPath' ($($packetStatistics.Count) unique groups)"
                        } finally {
                            if ($null -ne $statWriter) { $statWriter.Dispose() }
                        }
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
                if ($null -ne $contextStatistics -and $contextStatistics.Count -gt 0) {
                    $contextStatPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_Statistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )
                    if (Test-Path -Path $contextStatPath) {
                        $filesToCompress += $contextStatPath
                    }
                }
                if ($null -ne $packetStatistics -and $packetStatistics.Count -gt 0) {
                    $packetStatPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_PacketStatistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )
                    if (Test-Path -Path $packetStatPath) {
                        $filesToCompress += $packetStatPath
                    }
                }

                if ($filesToCompress.Count -gt 0) {
                    # Check if we should process (WhatIf support)
                    if ($PSCmdlet.ShouldProcess($zipPath, "Compress output files and remove originals")) {
                        try {
                            Write-Verbose "Starting compression: $($filesToCompress.Count) file(s) to '$zipPath'"
                            # Remove existing ZIP if present
                            if (Test-Path -Path $zipPath) {
                                Write-Verbose "Removing existing ZIP file: '$zipPath'"
                                Remove-Item -Path $zipPath -Force -ErrorAction Stop
                            }

                            # Compress output files
                            Compress-Archive -Path $filesToCompress -DestinationPath $zipPath -CompressionLevel Optimal -ErrorAction Stop
                            Write-Verbose "Successfully compressed output to: '$zipPath'"

                            # Remove uncompressed CSV files after successful compression
                            foreach ($file in $filesToCompress) {
                                Remove-Item -Path $file -Force -ErrorAction Stop
                                Write-Verbose "Removed uncompressed file: '$file'"
                            }
                        } catch {
                            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                                [System.IO.IOException]::new("Failed to compress output files: $_"),
                                'CompressionFailed',
                                [System.Management.Automation.ErrorCategory]::WriteError,
                                $zipPath
                            )
                            $PSCmdlet.WriteError($errorRecord)
                        }
                    }
                }
            }

            # Remove source file if requested (only after successful processing)
            if ($RemoveSourceFile) {
                # Check if we should process (WhatIf support)
                if ($PSCmdlet.ShouldProcess($resolvedPath, "Remove source file")) {
                    try {
                        Write-Verbose "Removing source file: '$resolvedPath'"
                        Remove-Item -Path $resolvedPath -Force -ErrorAction Stop
                        Write-Verbose "Successfully removed source file: '$resolvedPath'"
                    } catch {
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            [System.IO.IOException]::new("Failed to remove source file '$resolvedPath': $_"),
                            'SourceFileRemovalFailed',
                            [System.Management.Automation.ErrorCategory]::WriteError,
                            $resolvedPath
                        )
                        $PSCmdlet.WriteError($errorRecord)
                    }
                }
            }

            # Increment file counter for each processed input
            $fileCount++
        }
        #endregion File Processing
    }

    end {
        #region Completion
        if ($null -ne $dnsParserStopwatch) {
            $dnsParserStopwatch.Stop()
            Write-Verbose "Processing complete: $fileCount file(s) processed in $($dnsParserStopwatch.Elapsed.ToString())"
        }
        #endregion Completion
    }
}
