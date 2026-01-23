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

    .PARAMETER InputCulture
        Specifies the culture to use for parsing date/time values in the DNS debug log.

        DNS Server debug logs use the date format of the Windows locale on the server where the log
        was generated. This parameter allows parsing logs from servers with different regional settings.

        Default is the current culture ([System.Globalization.CultureInfo]::CurrentCulture).

        Common culture values:
        - 'de-DE' or 'de-AT': German format (DD.MM.YYYY or DD/MM/YYYY)
        - 'en-US': US format (MM/DD/YYYY)
        - 'en-GB': UK format (DD/MM/YYYY)
        - 'sv-SE': Swedish/ISO format (YYYY-MM-DD)

        Example: -InputCulture 'de-DE' for logs from a German Windows server.
        Example: -InputCulture ([System.Globalization.CultureInfo]::GetCultureInfo('sv-SE')) for Swedish logs.

    .PARAMETER OutputCulture
        Specifies the culture to use for formatting date/time values in the output CSV files.

        This parameter controls how DateTime values are written to the CSV output. This is useful
        when the CSV files will be consumed by applications or systems with specific regional settings.

        Default is the current culture ([System.Globalization.CultureInfo]::CurrentCulture).

        Common culture values:
        - 'en-US': US format (MM/DD/YYYY)
        - 'de-DE': German format (DD.MM.YYYY)
        - 'en-GB': UK format (DD/MM/YYYY)
        - 'sv-SE': Swedish/ISO format (YYYY-MM-DD)

        Example: -OutputCulture 'en-US' to format dates for US systems.
        Example: -OutputCulture ([System.Globalization.CultureInfo]::InvariantCulture) for ISO format.

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

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -InputCulture 'de-DE'

        Converts a DNS debug log from a German Windows server.
        Use this when the log file originates from a server with different regional settings.

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -InputCulture ([System.Globalization.CultureInfo]::GetCultureInfo('sv-SE'))

        Converts a DNS debug log from a Swedish Windows server using ISO date format (YYYY-MM-DD).
        Useful for processing logs from servers with different locale settings.

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -InputCulture 'de-DE' -OutputCulture 'en-US'

        Converts a DNS debug log from a German Windows server and formats output dates for US systems.
        Useful for processing logs from international servers for consumption by US-based systems.

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -OutputCulture ([System.Globalization.CultureInfo]::InvariantCulture)

        Converts a DNS debug log and formats output dates using ISO 8601 format (YYYY-MM-DD).
        Ideal for cross-platform compatibility or data interchange scenarios.

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -WhatIf

        Shows what would happen if the command runs without actually creating any files.
        Useful for testing command parameters before processing actual data.

    .EXAMPLE
        PS C:\> .\Convert-DnsDebugLogFile.ps1 -InputFile "C:\Logs\dns.log" -RemoveSourceFile -CompressOutput -WhatIf

        Previews the complete workflow including compression and source file removal.
        No files are created, compressed, or deleted - only shows what would happen.

    .NOTES
        Version:    1.2.0.0
        Author:     Andreas Bellstedt, Copilot
        Date:       2026-01-23
        Keywords:   Microsoft, Windows Server, DNSServer, DNS, DebugLog, LogParser

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
        $headerTemplateBase = 'DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName'
        $headerTemplateWithComputer = 'ComputerName{0}DateTime{0}ThreadId{0}Context{0}PacketId{0}Protocol{0}Direction{0}ClientIP{0}Xid{0}Type{0}Opcode{0}FlagsHex{0}FlagsChar{0}ResponseCode{0}QuestionType{0}QuestionName'
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
                Write-Verbose "Header validation successful - will skip $skipLines header lines"
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

            Write-Verbose "Starting processing: '$resolvedPath'"
            Write-Verbose "Output path: '$currentOutputPath'"
            Write-Verbose "CSV delimiter: '$Delimiter'"
            Write-Verbose "Output type: $($OutputType)"
            Write-Verbose "Input culture for date parsing: $($InputCulture.Name) ($($InputCulture.DisplayName))"
            Write-Verbose "Output culture for date formatting: $($OutputCulture.Name) ($($OutputCulture.DisplayName))"

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

                    $parsed = ConvertFrom-DnsLogLine -Line $line -Culture $InputCulture
                    if ($null -ne $parsed) {
                        # Build CSV line manually for performance (avoiding Export-Csv overhead) - only if needed
                        if ($writeCsvData) {
                            # Format DateTime using OutputCulture for culture-aware output
                            $formattedDateTime = $parsed.DateTime.ToString($outputDateTimeFormat, $OutputCulture)

                            if ($includeComputerName) {
                                $csvLine = ($ComputerName + $Delimiter + '{0}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"') -f @(
                                    $formattedDateTime,
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
                                $csvLine = ('{0}' + $Delimiter + '{1}' + $Delimiter + '{2}' + $Delimiter + '{3}' + $Delimiter + '{4}' + $Delimiter + '{5}' + $Delimiter + '{6}' + $Delimiter + '{7}' + $Delimiter + '{8}' + $Delimiter + '{9}' + $Delimiter + '{10}' + $Delimiter + '{11}' + $Delimiter + '{12}' + $Delimiter + '{13}' + $Delimiter + '"{14}"') -f @(
                                    $formattedDateTime,
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

                            # Write statistics header (conditionally include ComputerName)
                            if ($includeComputerName) {
                                $statWriter.WriteLine('ComputerName' + $Delimiter + 'ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'DateMin' + $Delimiter + 'DateMax')
                            } else {
                                $statWriter.WriteLine('ClientIP' + $Delimiter + 'Protocol' + $Delimiter + 'Direction' + $Delimiter + 'QuestionType' + $Delimiter + 'Count' + $Delimiter + 'DateMin' + $Delimiter + 'DateMax')
                            }

                            # Write statistics data
                            foreach ($kvp in $statistics.GetEnumerator()) {
                                $keyParts = $kvp.Key.Split('|')
                                $dateMinFormatted = $kvp.Value[1].ToString($outputDateTimeFormat, $OutputCulture)
                                $dateMaxFormatted = $kvp.Value[2].ToString($outputDateTimeFormat, $OutputCulture)
                                if ($includeComputerName) {
                                    $statLine = $ComputerName + $Delimiter + $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $kvp.Value[0].ToString() + $Delimiter + $dateMinFormatted + $Delimiter + $dateMaxFormatted
                                } else {
                                    $statLine = $keyParts[0] + $Delimiter + $keyParts[1] + $Delimiter + $keyParts[2] + $Delimiter + $keyParts[3] + $Delimiter + $kvp.Value[0].ToString() + $Delimiter + $dateMinFormatted + $Delimiter + $dateMaxFormatted
                                }
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