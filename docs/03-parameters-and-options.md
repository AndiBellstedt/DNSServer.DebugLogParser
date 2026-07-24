# Parameters and Options (Conceptual)

[← Back to index](index.md)

This page describes the most common customization options supported by the module.

For the definitive, up-to-date parameter list, use:

```powershell
Get-Help Convert-DNSDebugLogFile -Full
```

## Delimiter

Change the CSV delimiter from the default semicolon (`;`) to comma, tab, or any other character. This helps with compatibility across regions and tooling (for example Excel).

## ComputerName

Adds a `ComputerName` column to the output, useful when consolidating logs from multiple DNS servers into a single dataset.

## Input files

The module supports local paths and SMB/UNC paths. It can also read a log that is open by the DNS Server or another process.

> [!WARNING]
> Handle active logs with care: their content can change during conversion, which can leave the final record incomplete or omit records written after the file is read. Prefer rotated, closed logs and do not use source-file removal for an active log.

## OutputType

Choose to generate:

- CSV data file only
- Statistics files only
- Both data and statistics files (default)

## ContextFilter

Limit which context types are included in output. Useful to focus on Packet traffic or on operational/diagnostic contexts.

## NoDetailsParsing

Keeps the `Details` column empty (skips parsing Packet detail blocks into JSON) to improve processing performance for very large files.

## InputCulture

Specify the culture/locale of the DNS server where the log was generated. DNS debug logs use the local date format of the Windows server, which varies by region.

Examples:

- German (`de-DE`): `DD.MM.YYYY HH:MM:SS`
- US English (`en-US`): `M/D/YYYY H:MM:SS AM/PM`
- Swedish (`sv-SE`): `YYYY-MM-DD HH:MM:SS`
- UK English (`en-GB`): `DD/MM/YYYY HH:MM:SS`

Use this when processing logs from servers with different regional settings than your local machine.

## OutputCulture

Specify the culture/locale for formatting dates in the output CSV files. Use InvariantCulture for ISO format (`YYYY-MM-DD`) for maximum cross-platform compatibility.

## Compression

Automatically compress output CSV files into ZIP archives to save disk space. CSV compresses extremely well (often 90%+ reduction), which is helpful for retention and transfer.

## Source file removal

Automatically delete source log files after successful conversion. This helps manage disk space when processing logs on a schedule.

## Header validation

The module validates that input files are valid DNS debug logs by checking the header. This can be bypassed if needed for unusual log formats.
