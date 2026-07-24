# Examples

[← Back to index](index.md)

These examples mirror the scenarios described in the module’s about-help.

## Example 1: Basic log conversion

This command converts a standard DNS debug log file into a CSV format. By default, the output file will be created in the same directory as the input file, with `.csv` appended to the filename.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Windows\System32\dns\dns.log"
```

## Example 2: Custom output location

You can specify a different destination for the converted file using the `-OutputFile` parameter. This is useful when you want to separate your source logs from the processed data.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -OutputFile "D:\Processed\dns_data.csv"
```

## Example 3: Generate statistics

Use the `-OutputType Both` parameter to generate both the detailed CSV log and a summary statistics file. The statistics file includes counts of query types, response codes, and other high-level metrics.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -OutputType Both
```

## Example 4: Multi-server log consolidation

This example demonstrates how to process logs from multiple servers via SMB/UNC network shares. The `-ComputerName` parameter adds a column to the output, allowing you to identify which server generated the log entries when merging data later.

```powershell
Get-ChildItem "\\DNSServer01\C$\DNS\dns*.log" |
    Convert-DNSDebugLogFile -ComputerName "DNSServer01" -OutputType Both

Get-ChildItem "\\DNSServer02\C$\DNS\dns*.log" |
    Convert-DNSDebugLogFile -ComputerName "DNSServer02" -OutputType Both
```

The module supports SMB/UNC source paths. Ensure the account running the command has access to the share. If the newest file is still open and being written by DNS Server, handle it with care; prefer a rotated, closed log when a complete snapshot is required.

## Example 5: Batch processing with pipeline

You can pipe multiple file objects into `Convert-DNSDebugLogFile`. This command finds all `.log` files in a directory and converts them one by one.

```powershell
Get-ChildItem "C:\DNSLogs\*.log" | Convert-DNSDebugLogFile
```

## Example 6: Automated processing with compression

For automated workflows or to save disk space, use `-CompressOutput` to zip the resulting CSV. Adding `-RemoveSourceFile` deletes the original log file after successful conversion.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" `
    -CompressOutput -RemoveSourceFile
```

## Example 7: Custom delimiter for Excel

The default delimiter is a semicolon (`;`). If your regional Excel settings prefer a comma, or if you need to import the data into a tool that expects commas, use the `-Delimiter` parameter.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -Delimiter ","
```

## Example 8: International log processing

DNS debug logs are formatted according to the server's system locale. Use `-InputCulture` to specify the locale of the source file if it differs from your current system. `-OutputCulture` controls the format of dates and numbers in the generated CSV.

```powershell
# Parse a log from a German Windows server
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns-german.log" -InputCulture 'de-DE'

# Parse a Swedish log and output in US format
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns-swedish.log" -InputCulture 'sv-SE' -OutputCulture 'en-US'

# Output dates in ISO format
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputCulture ([System.Globalization.CultureInfo]::InvariantCulture)
```

## Example 9: Statistics only

If you only need the summary metrics and not the full transaction log, use `-OutputType Statistic`. This is much faster and generates a smaller output file containing only the aggregate data.

```powershell
Convert-DNSDebugLogFile -InputFile "C:\Logs\dns.log" -OutputType Statistic
```

## Example 10: Scheduled task example

This script creates a Windows Scheduled Task that runs daily at 2:00 AM. It imports the module and processes the log file, compressing the output and removing the original to maintain hygiene.

```powershell
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -Command `
    `\"Import-Module DNSServer.DebugLogParser; `
    Convert-DNSDebugLogFile -InputFile 'C:\DNS\dns.log' `
    -CompressOutput -RemoveSourceFile`\""

$Trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"

Register-ScheduledTask -TaskName "Process DNS Logs" -Action $Action -Trigger $Trigger `
    -Description "Convert DNS debug logs to CSV daily"
```

## Example 11: Advanced security analysis workflow (SQL Server)

This advanced workflow shows how to convert a log file and then import it into a SQL Server database for deep analysis. It includes a sample SQL query to detect potential tunneling or amplification attacks by looking for high volumes of TXT records.

```powershell
# What you upload:
# Convert-DNSDebugLogFile writes a CSV file (by default next to the input file).
# That generated CSV is the data you import into SQL Server.

# Step 0: Create a target table once (run in SQL Server)
# Tip: For best interoperability, write DateTime in ISO format.
# Convert-DNSDebugLogFile -OutputCulture 'sv-SE' makes DateTime like: 2026-01-28 14:30:52

# Example table definition (simplified types; adjust to your needs)
$createTableSql = @'
IF OBJECT_ID('dbo.DNSQueries','U') IS NULL
BEGIN
    CREATE TABLE dbo.DNSQueries (
        DateTime      datetime2(0)   NOT NULL,
        ThreadId      int            NULL,
        Context       nvarchar(20)   NULL,
        PacketId      int            NULL,
        Protocol      nvarchar(10)   NULL,
        Direction     nvarchar(10)   NULL,
        ClientIP      nvarchar(64)   NULL,
        Xid           nvarchar(16)   NULL,
        Type          nvarchar(16)   NULL,
        Opcode        nvarchar(16)   NULL,
        FlagsHex      nvarchar(16)   NULL,
        FlagsChar     nvarchar(16)   NULL,
        ResponseCode  nvarchar(32)   NULL,
        QuestionType  nvarchar(32)   NULL,
        QuestionName  nvarchar(512)  NULL,
        Information   nvarchar(max)  NULL,
        Details       nvarchar(max)  NULL,
        ComputerName  nvarchar(256)  NULL
    );
END
'@

# Step 1: Convert log to CSV (this CSV is what you upload)
$csvPath = 'C:\Logs\dns.csv'
Convert-DNSDebugLogFile -InputFile 'C:\Logs\dns.log' -ComputerName 'DNS01' -OutputType CSV -OutputFile $csvPath -OutputCulture 'sv-SE'

# Step 2: Import the generated CSV into SQL Server (PoC approach)
# Note: Import-Csv loads the file into memory. For very large logs, use a streaming IDataReader approach instead.
$delimiter = ';'
$rows = Import-Csv -Path $csvPath -Delimiter $delimiter

$dataTable = [System.Data.DataTable]::new()
foreach ($columnName in $rows[0].PSObject.Properties.Name) {
    $null = $dataTable.Columns.Add($columnName, [string])
}
foreach ($row in $rows) {
    $newRow = $dataTable.NewRow()
    foreach ($column in $dataTable.Columns) {
        $columnName = $column.ColumnName
        $newRow[$columnName] = $row.$columnName
    }
    $null = $dataTable.Rows.Add($newRow)
}

$connectionString = 'Server=SQLServer;Database=DNSLogs;Integrated Security=True'
$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$connection.Open()

try {
    # Create table if needed
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = $createTableSql
    $null = $cmd.ExecuteNonQuery()

    # Bulk insert
    $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
    $bulkCopy.DestinationTableName = 'dbo.DNSQueries'
    foreach ($column in $dataTable.Columns) {
        $null = $bulkCopy.ColumnMappings.Add($column.ColumnName, $column.ColumnName)
    }
    $bulkCopy.WriteToServer($dataTable)
}
finally {
    $connection.Close()
}

# Step 3: Query for suspicious activity
Invoke-Sqlcmd -Query "
SELECT ComputerName, ClientIP, QuestionName, COUNT(*) as QueryCount
FROM DNSQueries
WHERE QuestionType = 'TXT'
GROUP BY ComputerName, ClientIP, QuestionName
HAVING COUNT(*) > 100
ORDER BY QueryCount DESC" `
    -ServerInstance "SQLServer" -Database "DNSLogs"
```
