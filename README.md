<!-- markdownlint-disable MD041 -->
# ![logo](assets/DNSServer.DebugLogParser_128x128.png) DNSServer.DebugLogParser - PowerShell Module for Parsing Windows DNS Server Debug Logs

| Platform           | Information                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| PowerShell Gallery | [![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/DNSServer.DebugLogParser)](https://www.powershellgallery.com/packages/DNSServer.DebugLogParser) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/DNSServer.DebugLogParser)](https://www.powershellgallery.com/packages/DNSServer.DebugLogParser) [![PowerShell Gallery Platform](https://img.shields.io/powershellgallery/p/DNSServer.DebugLogParser)](https://www.powershellgallery.com/packages/DNSServer.DebugLogParser)                                                                                                                                                                                      |
| GitHub             | [![GitHub release](https://img.shields.io/github/v/release/AndiBellstedt/DNSServer.DebugLogParser)](https://github.com/AndiBellstedt/DNSServer.DebugLogParser/releases) [![GitHub](https://img.shields.io/github/license/AndiBellstedt/DNSServer.DebugLogParser)](https://github.com/AndiBellstedt/DNSServer.DebugLogParser/blob/main/LICENSE) ![GitHub issues](https://img.shields.io/github/issues-raw/AndiBellstedt/DNSServer.DebugLogParser) ![GitHub last commit (main branch)](https://img.shields.io/github/last-commit/AndiBellstedt/DNSServer.DebugLogParser/main) ![GitHub last commit (dev branch)](https://img.shields.io/github/last-commit/AndiBellstedt/DNSServer.DebugLogParser/Development) |

DNSServer.DebugLogParser transforms Windows DNS Server debug logs into structured, analyzable data. The module parses complex debug log files and converts them into CSV format for easy analysis in Excel, Power BI, SQL databases, or SIEM tools. It's designed for security analysis, performance monitoring, troubleshooting, and compliance reporting.

## Key Features
- Parse all 16 fields from DNS debug logs (date, time, protocol, client IP, query type, response codes, etc.)
- Generate structured CSV output with customizable delimiters
- Create optional statistical summaries aggregating activity by client, protocol, and query type
- Process single files or batches via pipeline
- High-performance parsing optimized for large files (100MB+)
- Optional automatic compression of output files to save disk space
- Optional removal of source files after successful processing
- Validates log file headers to ensure data integrity

## How to Use DNSServer.DebugLogParser

### Installation from PowerShell Gallery

The easiest way to install DNSServer.DebugLogParser is directly from the PowerShell Gallery:

```powershell
# Install the module (run as administrator for system-wide installation)
Install-Module -Name DNSServer.DebugLogParser -Scope AllUsers

# Or install for current user only (no admin rights required)
Install-Module -Name DNSServer.DebugLogParser -Scope CurrentUser

# Import the module
Import-Module DNSServer.DebugLogParser
```

### Using DNSServer.DebugLogParser via Command Line

DNSServer.DebugLogParser provides the `Convert-DNSDebugLogFile` cmdlet for transforming DNS Server debug logs. Here are the main workflows:

#### Basic Log Conversion

Convert a DNS debug log file to CSV format using default settings:

```powershell
# Convert a single DNS debug log file
Convert-DNSDebugLogFile -InputFile "C:\Windows\System32\dns\dns.log"

# Output: C:\Windows\System32\dns\dns.csv (data file with semicolon delimiter)
```

#### Generate Statistics

Create aggregated statistics showing DNS activity patterns:

```powershell
# Generate both CSV data and statistics
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Both

# Output:
# - C:\Logs\dns.csv (full parsed data)
# - C:\Logs\dns_statistic.csv (aggregated statistics by client, protocol, query type)

# Generate only statistics (no full CSV)
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Statistic

# Output: C:\Logs\dns_statistic.csv (statistics only)
```

#### Custom Output Location and Delimiter

Specify a custom output location and use comma delimiter for compatibility with standard CSV tools:

```powershell
# Custom output file with comma delimiter
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -OutputFile "C:\Analysis\dns-queries.csv" `
    -Delimiter ","

# Output: C:\Analysis\dns-queries.csv (comma-delimited CSV file)
```

#### Multi-Server Consolidation

Add a ComputerName column when consolidating logs from multiple DNS servers:

```powershell
# Add ComputerName column for multi-server analysis
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns01.log" `
    -ComputerName "DNS01" `
    -Delimiter "," `
    -OutputType Both

# Output: Files include ComputerName column with "DNS01" value
# Useful for combining data from multiple servers in a single database or dashboard
```

#### Batch Processing via Pipeline

Process multiple DNS debug log files efficiently using PowerShell pipelines:

```powershell
# Process all log files in a directory
Get-ChildItem "C:\Logs\*.log" | Convert-DNSDebugLogFile -OutputType Both

# Process log files with specific naming pattern
Get-ChildItem "C:\Logs\dns-*.log" |
    Convert-DNSDebugLogFile -Delimiter "," -OutputType Statistic

# Process files from multiple servers with ComputerName
Get-ChildItem "C:\Logs\DNS*.log" | ForEach-Object {
    $serverName = $_.BaseName -replace 'DNS(\d+).*', 'DNS$1'
    Convert-DNSDebugLogFile -InputFile $_.FullName `
        -ComputerName $serverName `
        -OutputType Both
}
```

#### Space-Saving Options

Compress output files and remove source logs to save disk space:

```powershell
# Compress output to ZIP archive
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -CompressOutput

# Output: C:\Logs\dns.zip (contains dns.csv, uncompressed CSV removed)

# Compress and generate statistics
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -OutputType Both `
    -CompressOutput

# Output: C:\Logs\dns.zip (contains both dns.csv and dns_statistic.csv)

# Remove source log after successful processing (use with caution!)
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -RemoveSourceFile `
    -Verbose

# Output: CSV created, then source dns.log permanently deleted
# Warning: Source files are permanently deleted. Ensure output is valid first!

# Full automated pipeline: process, compress, and cleanup
Get-ChildItem "C:\Logs\*.log" |
    Convert-DNSDebugLogFile -CompressOutput -RemoveSourceFile

# Ideal for automated log archival pipelines
```

#### Skip Header Validation

Bypass DNS debug log header validation for non-standard log formats:

```powershell
# Process files without header validation
Convert-DNSDebugLogFile -InputFile "C:\Logs\custom.log" `
    -SkipHeaderValidation

# Useful for:
# - Processing modified or custom log formats
# - Troubleshooting validation issues
# - Processing logs with non-standard headers
# Warning: May result in processing errors if file is not a valid DNS log
```

### Understanding the Output

#### CSV Data File Fields

The parsed CSV contains 16 fields extracted from each DNS log entry:

| Field        | Description                                                           | Example             |
| ------------ | --------------------------------------------------------------------- | ------------------- |
| DateTime     | Timestamp of the DNS query/response                                   | 2026-01-23 14:32:15 |
| ThreadId     | DNS Server thread ID that processed the request                       | 0ABC                |
| Context      | Internal context identifier                                           | PACKET              |
| PacketId     | Internal packet identifier                                            | 0000012345678ABC    |
| Protocol     | UDP or TCP                                                            | UDP                 |
| Direction    | Snd (Send/Response) or Rcv (Receive/Query)                            | Rcv                 |
| ClientIP     | IP address of the client making the request                           | 192.168.1.100       |
| Xid          | DNS transaction ID (hexadecimal)                                      | F8A3                |
| Type         | Query or Response (R=Response, blank=Query)                           | R                   |
| Opcode       | Q=Standard Query, N=Notify, U=Update, ?=Unknown                       | Q                   |
| FlagsHex     | DNS flags in hexadecimal                                              | 0001                |
| FlagsChar    | DNS flags as characters (A=Authoritative, T=Truncated, D/R=Recursion) | DR                  |
| ResponseCode | DNS response code (NOERROR, NXDOMAIN, SERVFAIL, etc.)                 | NOERROR             |
| QuestionType | DNS query type (A, AAAA, CNAME, MX, PTR, SOA, SRV, etc.)              | A                   |
| QuestionName | Domain name queried                                                   | www.example.com     |

#### Statistics File Fields

The optional statistics file aggregates DNS activity and contains these fields:

| Field        | Description                               | Example       |
| ------------ | ----------------------------------------- | ------------- |
| ClientIP     | Client IP address                         | 192.168.1.100 |
| Protocol     | UDP or TCP                                | UDP           |
| QuestionType | DNS query type (A, AAAA, etc.)            | A             |
| Count        | Number of queries matching these criteria | 1523          |

This aggregated view helps identify:
- Most active DNS clients
- Query type distribution (IPv4 vs IPv6, etc.)
- Protocol usage patterns
- Potential anomalies or security concerns

### Use Cases and Examples

#### Security Analysis - Detect DNS Tunneling

Identify suspicious DNS query patterns that might indicate data exfiltration:

```powershell
# Parse logs and analyze for unusually long domain names (potential tunneling)
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter ","

# Import and analyze in PowerShell
$queries = Import-Csv "C:\Logs\dns.csv" -Delimiter ","
$suspicious = $queries | Where-Object {
    $_.QuestionName.Length -gt 100 -or
    $_.QuestionName -match '\d{10,}' -or
    $_.QuestionType -eq 'TXT' -and $_.QuestionName.Length -gt 50
}
$suspicious | Export-Csv "C:\Analysis\suspicious-queries.csv" -NoTypeInformation
```

#### Performance Monitoring - Query Volume Analysis

Track DNS query volumes over time to identify patterns and capacity needs:

```powershell
# Generate statistics for trend analysis
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Statistic

# Analyze query distribution
$stats = Import-Csv "C:\Logs\dns_statistic.csv" -Delimiter ";"
$stats | Group-Object QuestionType |
    Select-Object Name, @{N='TotalQueries';E={($_.Group | Measure-Object Count -Sum).Sum}} |
    Sort-Object TotalQueries -Descending
```

#### Troubleshooting - Find Failed Queries

Investigate DNS resolution failures:

```powershell
# Parse logs and find all failed queries
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter ","

$queries = Import-Csv "C:\Logs\dns.csv" -Delimiter ","
$failures = $queries | Where-Object {
    $_.ResponseCode -ne 'NOERROR' -and $_.Type -eq 'R'
}
$failures | Group-Object ResponseCode, QuestionName |
    Select-Object Count, @{N='Error';E={$_.Values[0]}}, @{N='Domain';E={$_.Values[1]}} |
    Sort-Object Count -Descending
```

#### Compliance Reporting - Multi-Server Consolidation

Collect and consolidate DNS logs from multiple servers for audit purposes:

```powershell
# Process logs from multiple DNS servers
$dnsServers = @('DNS01', 'DNS02', 'DNS03')

foreach ($server in $dnsServers) {
    $logPath = "\\$server\C$\Windows\System32\dns\dns.log"
    if (Test-Path $logPath) {
        Convert-DNSDebugLogFile -InputFile $logPath `
            -OutputFile "C:\Audit\$server-dns.csv" `
            -ComputerName $server `
            -Delimiter ","
    }
}

# Combine all CSV files into a single database
$allQueries = Get-ChildItem "C:\Audit\*-dns.csv" |
    ForEach-Object { Import-Csv $_ -Delimiter "," }

# Generate compliance report
$allQueries | Export-Csv "C:\Audit\consolidated-dns-activity.csv" -NoTypeInformation
```

#### Automated Log Archival Pipeline

Create a scheduled task to automatically process, compress, and archive DNS logs:

```powershell
# Script for scheduled task
$logPath = "C:\Windows\System32\dns"
$archivePath = "C:\DNSArchive"

# Find log files older than 1 day
Get-ChildItem "$logPath\dns*.log" | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-1)
} | ForEach-Object {
    # Parse, compress, and remove original
    Convert-DNSDebugLogFile -InputFile $_.FullName `
        -OutputType Both `
        -CompressOutput `
        -RemoveSourceFile `
        -Verbose

    # Move ZIP to archive location
    $zipFile = $_.FullName -replace '\.log$', '.zip'
    if (Test-Path $zipFile) {
        Move-Item $zipFile $archivePath
    }
}
```

### Performance Considerations

DNSServer.DebugLogParser is optimized for processing large DNS debug log files efficiently:

**Optimization Techniques:**
- String operations instead of regex for parsing (3-5x faster)
- StreamReader/StreamWriter with 64KB buffers for efficient I/O
- Manual CSV generation to avoid Export-Csv overhead
- Efficient dictionary-based statistics collection
- Minimal memory footprint even with large files

**Expected Performance:**
- Small files (< 10MB): Nearly instant (< 1 second)
- Medium files (10-100MB): 5-30 seconds
- Large files (100MB-1GB): 30 seconds - 5 minutes
- Very large files (> 1GB): May take 10+ minutes

**Tips for Best Performance:**
- Use `-OutputType CSV` if you don't need statistics (faster)
- Process files locally rather than over network shares when possible
- Use SSD storage for both input and output locations
- For very large files, consider splitting them first
- Enable `-CompressOutput` to reduce I/O time writing large CSV files

### Compatibility

**PowerShell Versions:**
- PowerShell 5.1+ on Windows
- PowerShell 7+ on Windows (Core)

**Windows Server Versions:**
- Windows Server 2012 R2
- Windows Server 2016
- Windows Server 2019
- Windows Server 2022
- Windows Server 2025

**DNS Server Debug Log Formats:**
- Supports all standard Windows DNS Server debug log formats from 2012 R2 through 2025
- Compatible with detailed and packet logging modes
- Works with both UDP and TCP query logs

**Note:** This module is designed specifically for Windows DNS Server debug logs. It does not support BIND or other DNS server log formats.

### Frequently Asked Questions

**Q: How do I enable DNS debug logging on my DNS server?**

A: Use PowerShell or the DNS Manager console:

```powershell
# Enable debug logging via PowerShell
Set-DnsServerDiagnostics -LogFilePath "C:\Windows\System32\dns\dns.log" `
    -Queries $true -Answers $true -MaxMBFileSize 100

# Or via DNS Manager:
# 1. Open DNS Manager
# 2. Right-click server name → Properties
# 3. Debug Logging tab → Check desired options
```

**Q: The output CSV doesn't open correctly in Excel. What's wrong?**

A: By default, the module uses semicolon (`;`) delimiter. Change to comma for Excel compatibility:

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter ","
```

**Q: Can I run this on a non-DNS server to process log files?**

A: Yes! The module only requires the log file, not a running DNS server. Copy log files to any Windows machine with PowerShell and process them there.

**Q: How much disk space do I need for the CSV output?**

A: CSV files are typically 2-3x larger than the original log file. A 100MB log file will produce approximately 200-300MB CSV. Use `-CompressOutput` to reduce storage by 80-90%.

**Q: Can I import the CSV into SQL Server or other databases?**

A: Absolutely! The structured CSV format is ideal for database import:

```powershell
# Example: Import to SQL Server using dbatools
Install-Module dbatools
$csv = Import-Csv "C:\Logs\dns.csv" -Delimiter ";"
Write-DbaDataTable -SqlInstance "SQLServer" -Database "DNSLogs" `
    -Table "QueryLog" -InputObject $csv
```

**Q: Does this work with DNS audit logs or only debug logs?**

A: This module is specifically designed for DNS Server **debug logs** (text-based format). DNS audit logs (Event Viewer/EVTX format) are different and require separate tools.

**Q: Will `-RemoveSourceFile` delete my active DNS log?**

A: Yes, use with extreme caution! Stop DNS debug logging first, or work with archived copies. Never use `-RemoveSourceFile` on active log files that DNS Server is still writing to.

### Troubleshooting

**Issue: "File does not appear to be a valid DNS debug log"**

**Solution:** Verify the log file has proper DNS debug log header. Use `-SkipHeaderValidation` to bypass the check, or ensure DNS debug logging is configured correctly.

**Issue: "Access denied" errors**

**Solution:** Run PowerShell as Administrator, or copy log files to a location where you have write permissions.

**Issue: Processing is very slow**

**Solution:** Check if the log file is on a network share (slow). Copy to local disk first. Also verify your disk isn't nearly full, which can slow I/O operations significantly.

**Issue: "Cannot find path" when using pipeline**

**Solution:** When using pipeline with `-OutputFile`, the parameter cannot be bound to each item. Omit `-OutputFile` to use automatic naming:

```powershell
# This works - automatic output naming
Get-ChildItem "*.log" | Convert-DNSDebugLogFile

# This doesn't work - OutputFile conflicts with pipeline
Get-ChildItem "*.log" | Convert-DNSDebugLogFile -OutputFile "output.csv"
```

**Issue: CSV data looks corrupted or misaligned**

**Solution:** The log file may contain non-standard entries. Use `-Verbose` to see detailed parsing messages, or try `-SkipHeaderValidation` if header validation is failing incorrectly.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

**Development Setup:**
1. Fork the repository
2. Clone your fork: `git clone https://github.com/YourUsername/DNSServer.DebugLogParser.git`
3. Create a feature branch: `git checkout -b feature/amazing-feature`
4. Make your changes and test thoroughly
5. Run Pester tests: `Invoke-Pester` from the `tests` directory
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Andreas Bellstedt**
- GitHub: [@AndiBellstedt](https://github.com/AndiBellstedt)
- PowerShell Gallery: [AndiBellstedt](https://www.powershellgallery.com/profiles/AndiBellstedt)

## Acknowledgments

- Thanks to the PowerShell community for feedback and testing
- Inspired by the need for better DNS log analysis tools

