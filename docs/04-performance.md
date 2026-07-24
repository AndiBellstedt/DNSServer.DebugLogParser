# Performance

[← Back to index](index.md)

DNSServer.DebugLogParser is optimized for processing large DNS debug logs (tested with 100MB+ files).

## Optimization techniques

- Uses `StreamReader` with 64KB buffers for efficient file reading
- Uses `StreamWriter` with 64KB buffers for efficient file writing
- Employs string operations (`.Substring()`, `.IndexOf()`) instead of regex
- Manually constructs CSV to avoid `Export-Csv` overhead
- Uses hashtables for fast statistical aggregation
- Processes files in a single pass to minimize I/O operations

## Practical guidance

- Prefer processing rotated logs (for example 50–200MB chunks) to keep run times predictable.
- The module can read a log that is still open, but this must be handled with care: the file can change during conversion. Prefer rotated, closed logs when complete, repeatable output is required.
- Use `-NoDetailsParsing` when you don’t need packet-detail JSON and want maximum throughput.
- Consider `-CompressOutput` for long-term storage; CSV usually compresses very well.
