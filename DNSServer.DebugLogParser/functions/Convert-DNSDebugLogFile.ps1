function Convert-DNSDebugLogFile {
    <#
    .SYNOPSIS
        Transforms Windows DNS Server debug logs into structured CSV format for analysis and reporting.

    .DESCRIPTION
        Converts Windows DNS Server debug log files into structured CSV data that can be analyzed
        in Excel, Power BI, SQL databases, or SIEM tools. Designed for security analysis, performance
        monitoring, troubleshooting, and compliance reporting.

        The cmdlet parses all 17 fields from DNS debug logs including date/time, protocol, client IP,
        query type, domain names, response codes, flags, event information, and computer name. It generates
        structured CSV output with an optional statistics summary aggregating activity by client, protocol,
        and query type.

        KEY FEATURES:
        - High-performance parsing optimized for large files (100MB+)
        - Customizable CSV delimiter (default: semicolon)
        - Optional statistical summaries with aggregated metrics
        - Context filtering (PACKET, EVENT, Note) to focus on specific log entry types
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
        Optimized using StreamReader/StreamWriter with 64KB buffers, string operations instead of
        regex, manual CSV generation, and efficient hashtable-based statistics collection.

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

        Note: This is NOT a remoting parameter. The cmdlet processes local files only.

    .PARAMETER OutputType
        Specifies the type of output to generate.

        Valid values:
        - 'CSV': Generate only the data file with all parsed log entries (default)
        - 'Statistic': Generate only the statistics file with aggregated metrics
        - 'Both': Generate both data and statistics files

        Default: Both

        Statistics provide aggregated counts by client IP, protocol, direction, and query type, along with
        date range for each unique combination.

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
        Filters which log entry types to include in the output.

        DNS debug logs contain different context types:
        - PACKET: DNS query and response packet information (primary data)
        - EVENT: DNS server events (e.g., "The DNS server has started.")
        - Note: Diagnostic notes and warnings (e.g., socket errors, internal states)

        Valid values:
        - 'All': Include all context types (default)
        - 'Packet': Include only PACKET entries (DNS queries/responses)
        - 'Event': Include only EVENT entries (server events)
        - 'Note': Include only Note entries (diagnostic information)

        Default: All

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
        Output: C:\Logs\dns.csv and C:\Logs\dns_statistic.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType CSV

        Generates only the data file without statistics.
        Output: C:\Logs\dns.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Statistic

        Generates only the statistics file with aggregated metrics.
        Output: C:\Logs\dns_statistic.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputFile "C:\Output\parsed.csv"

        Converts the log to a custom output location.
        Output: C:\Output\parsed.csv

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter "," -ComputerName "DNS01" -OutputType Both

        Converts with comma delimiter and adds ComputerName column with value "DNS01".
        Output: C:\Logs\dns.csv and C:\Logs\dns_statistic.csv with ComputerName column

    .EXAMPLE
        PS C:\> Get-ChildItem "C:\Logs\*.log" | Convert-DNSDebugLogFile -OutputType Both

        Batch processes multiple DNS debug log files via pipeline.
        Output: For each .log file, generates .csv and _statistic.csv files

    .EXAMPLE
        PS C:\> Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -CompressOutput

        Converts and compresses output to ZIP archive.
        Output: C:\Logs\dns.zip (containing dns.csv and dns_statistic.csv)

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
        PS C:\> Get-ChildItem "C:\Logs\*.log" | Convert-DNSDebugLogFile -RemoveSourceFile -CompressOutput

        Automated log archival: processes all logs, compresses output, and removes source files.
        Ideal for scheduled log processing pipelines.

    .NOTES
        Version  : 1.3.0.1
        Author   : Andi Bellstedt, Copilot
        Date     : 2026-01-23
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
        [ValidateSet('All', 'Packet', 'Event', 'Note')]
        [string]
        $ContextFilter = 'All',

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
        $OutputCulture = [System.Globalization.CultureInfo]::CurrentCulture
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
        $headerTemplate = 'DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName{0}Information{0}ComputerName'
        #endregion Initialization

        # Start a stopwatch to measure total script runtime and a file counter
        $dnsParserStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        [int]$fileCount = 0

        # Validate parameter combination safety
        if ($RemoveSourceFile -and $SkipHeaderValidation) {
            throw "RemoveSourceFile cannot be used with SkipHeaderValidation due to safety concerns. Header validation ensures the file is a valid DNS log before permanent deletion."
        }
    }

    process {
        #region File Processing
        foreach ($currentFile in $InputFile) {
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

            # Initialize statistics dictionary if requested (using Dictionary for performance)
            $statistics = $null
            if ($OutputType -eq 'Statistic' -or $OutputType -eq 'Both') {
                $statistics = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new()
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

                # Process data lines
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    $lineCount++

                    $parsed = ConvertFrom-DnsLogLine -Line $line -Culture $InputCulture -ContextFilter $ContextFilter
                    if ($null -ne $parsed) {
                        # Build CSV line manually for performance (avoiding Export-Csv overhead) - only if needed
                        if ($writeCsvData) {
                            # Format DateTime using OutputCulture for culture-aware output
                            $formattedDateTime = $parsed.DateTime.ToString($outputDateTimeFormat, $OutputCulture)

                            # Escape double quotes in QuestionName and Information fields for proper CSV formatting
                            # Standard CSV escaping: replace " with ""
                            $escapedQuestionName = $parsed.QuestionName -replace '"', '""'
                            $escapedInformation = $parsed.Information -replace '"', '""'

                            # ComputerName is always included at the end
                            $csvLine = ('{0}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"' + $Delimiter + '"{15}"' + $Delimiter + '{16}') -f @(
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
                                    elseif ($parsed.Context -eq 'PACKET') { 'Query' }
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
                                $computerNameValue
                            )

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

                Write-Verbose "Completed parsing: $lineCount total lines, $parsedCount valid entries"
                if ($writeCsvData) {
                    Write-Verbose "Successfully exported $parsedCount DNS log entries to: '$currentOutputPath'"
                }

                # Write statistics file if requested
                if ($null -ne $statistics -and $statistics.Count -gt 0) {
                    Write-Verbose "Generating statistics file with $($statistics.Count) unique groups"
                    $statPath = [System.IO.Path]::Combine(
                        [System.IO.Path]::GetDirectoryName($currentOutputPath),
                        [System.IO.Path]::GetFileNameWithoutExtension($currentOutputPath) + '_statistic' + [System.IO.Path]::GetExtension($currentOutputPath)
                    )

                    # Check if we should process (WhatIf support)
                    if ($PSCmdlet.ShouldProcess($statPath, "Create statistics output file")) {
                        $statWriter = $null
                        try {
                            $statWriter = [System.IO.StreamWriter]::new($statPath, $false, [System.Text.Encoding]::UTF8, 65536)

                            # Write statistics header (ComputerName is always included at the end)
                            $statWriter.WriteLine('ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'DateMin' + $Delimiter + 'DateMax' + $Delimiter + 'ComputerName')

                            # Write statistics data
                            foreach ($kvp in $statistics.GetEnumerator()) {
                                $keyParts = $kvp.Key.Split('|')
                                $dateMinFormatted = $kvp.Value[1].ToString($outputDateTimeFormat, $OutputCulture)
                                $dateMaxFormatted = $kvp.Value[2].ToString($outputDateTimeFormat, $OutputCulture)
                                $statLine = $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $kvp.Value[0].ToString() + $Delimiter + $dateMinFormatted + $Delimiter + $dateMaxFormatted + $Delimiter + $computerNameValue
                                $statWriter.WriteLine($statLine)
                            }

                            Write-Verbose "Successfully exported statistics to: '$statPath' ($($statistics.Count) unique groups)"
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