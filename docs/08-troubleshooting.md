# Troubleshooting

[← Back to index](index.md)

## Common issues and solutions

### “The file is not a valid DNS debug log file”

- Ensure you’re converting an actual DNS Server debug log.
- The file should start with `Message logging started at` or contain DNS query entries.
- If you’re certain the file is valid but the header differs, use `-SkipHeaderValidation`.

### Output file is empty or incomplete

- Confirm the input file contains valid log entries.
- Some logs may only contain header information if no queries occurred.
- Verify the log file isn’t corrupted and contains actual query data.

### Processing is very slow

- Ensure sufficient memory and that the disk is not heavily loaded.
- Consider processing smaller log files.
- Consider `-CompressOutput` with scheduled processing to handle smaller batches.

### “Access denied” errors

- Run PowerShell with appropriate permissions to read the source log files and write to the destination directory.
- DNS log files may require administrator access.

### Compressed output is larger than expected

- Logs with many unique values compress less efficiently; this can be normal.
- ZIP compression still typically achieves substantial reduction.

### Statistics file doesn’t match expectations

- Verify you’re using `-OutputType Both` or `-OutputType Statistic`.
- Statistics are aggregated counts (daily groupings), so values represent totals.

## Reporting issues

If you encounter problems not covered here:

1. Verify you’re using the latest version of the module.
2. Check GitHub Issues for similar problems.
3. Collect diagnostic information:
   - PowerShell version (`$PSVersionTable`)
   - Module version (`Get-Module DNSServer.DebugLogParser`)
   - Sample log file (if possible)
   - Full error message and stack trace
4. Open a new GitHub issue with details.
