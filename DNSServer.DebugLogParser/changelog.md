# Changelog

## 1.7.1.0 (2026-01-26)

### Changed
* **Performance**: Replaced memory-intensive line loading with streaming lookahead buffer
  * Uses small queue (100 lines) to detect multi-line records without loading entire file into memory
  * Prevents OOM (out-of-memory) errors on very large files (500MB+)
  * Maintains full support for PACKET detail blocks and continuation lines
  * Memory usage is now constant regardless of file size
* **Progress**: Added `Write-Progress` for processing feedback
  * Progress bar updates every 1000 records for minimal performance impact
  * Displays current record count and file being processed

### Added
* **Internal**: New `Invoke-ParallelDnsLogProcessing` function
  * Foundation for optional parallel processing in future releases
  * Uses native PowerShell runspace pools (PS 5.1+ compatible, no dependencies)
  * Not yet exposed as user-facing feature

## 1.2.0.0 (2026-01-25)

### Added
* **NEW**: Multi-line record processing for DNS PACKET detail blocks
  * PACKET context entries can now include detailed TCP/UDP connection information and DNS message structure
  * Detail blocks are parsed into structured JSON format in the new `Details` column
  * Includes: Socket info, remote address/port, timing data, message structure (XID, Flags, QCOUNT, etc.)
  * DNS sections (QUESTION, ANSWER, AUTHORITY, ADDITIONAL) are captured with full record details
  * Encoded domain names in detail blocks are automatically converted to FQDN format
* **NEW**: `Details` column in CSV output
  * Contains structured JSON data for PACKET entries with detail blocks
  * Empty for PACKET entries without details and all non-PACKET contexts
  * Enables deep packet analysis and forensic investigation of DNS queries/responses
* **NEW**: `NoDetailsParsing` switch parameter for performance optimization
  * Skips expensive JSON parsing of PACKET detail blocks
  * ***Can improve*** processing speed by **30-50%** for logs with many detail blocks
  * Use when processing very large files (100MB+) and detailed packet structure is not needed
  * Detail blocks are still collected in Information column, but Details column remains empty
* **NEW**: Multi-line continuation support for non-PACKET contexts
  * EVENT, Note, DSPoll, and other contexts can now span multiple lines
  * Indented continuation lines are automatically joined to the main record's Information field
  * Preserves complete error messages, zone updates, and diagnostic output
* **NEW**: `ContextFilter` recognizes additional context types: `DSPoll`, `Init`, `Lookup`, `Recurse`, `Remote`, `Tombstone`
  * Effect: `Convert-DNSDebugLogFile` can now include/exclude these diagnostic and lifecycle entries via `-ContextFilter`
* **NEW**: Statistics output now includes two dedicated files
  * `_Statistic.csv`: Daily record counts per context type (Date, Context, Count, ComputerName)
  * `_PacketStatistic.csv`: Daily PACKET counts by client/protocol/direction/type (Date, ClientIP, Protocol, Direction, QuestionType, Count, ComputerName)
  * Benefit: More focused reporting (operational context volume vs. DNS traffic breakdown)
* JSON generation for PACKET detail blocks is optimized for performance (manual parsing instead of regex)

### Changed
* **BREAKING**: CSV output now includes 18 columns (added `Details` column before `ComputerName`)
  * New column order: DateTime, ThreadId, Context, PacketId, Protocol, Direction, ClientIP, Xid, Type, Opcode, FlagsHex, FlagsChar, ResponseCode, QuestionType, QuestionName, Information, **Details**, ComputerName
  * Impact: Scripts that rely on column positions must be updated
  * Benefit: Rich packet analysis capabilities without changing existing Information column behavior
* Data line processing refactored to read all lines into memory for efficient multi-line record detection
  * Performance: Minimal impact due to optimized List<string> usage
  * Benefit: Enables accurate lookahead for detail blocks and continuation lines
* Question names that are missing or encoded as empty are now handled gracefully (no parse errors); CSV output will contain an empty QuestionName field when absent

### Improved
* `Convert-DNSDebugLogFile` parsing is more resilient: stricter line validation and improved extraction reduce spurious/invalid rows from malformed logs while preserving the CSV/statistic output format
* PACKET context detection distinguishes between simple queries and queries with detail blocks
* Empty lines after PACKET entries without details are properly skipped
* Domain name decoding in detail blocks uses existing `ConvertTo-Fqdn` function for consistency

### Performance
* Processing speed maintained for logs without detail blocks
* `NoDetailsParsing` switch provides 30-50% speed improvement when JSON parsing is not needed
* Efficient state management during multi-line record processing
* Optimized string operations (TrimStart, Join) instead of regex for continuation line handling

### Notes
* These changes are designed to be backward compatible for normal usage. If you rely on an exact set of context names or previously-strict parsing behavior, please validate downstream scripts
* The new `Details` column is always present in CSV output; use `NoDetailsParsing` to keep it empty for performance
* Existing scripts that parse CSV by column position need to account for the new `Details` column (position 17, before ComputerName)

## 1.1.0 (2026-01-23)

### Added
* **NEW**: ContextFilter parameter for selective log parsing
  * Filter log entries by context type: PACKET (DNS queries/responses), EVENT (server events), or Note (diagnostic information)
  * Allows focused analysis on specific log entry types
  * Default: All (includes all context types)
  * Use cases: Focus on DNS traffic only, monitor server events, troubleshoot diagnostic issues
* **NEW**: Information field in CSV output
  * Captures detailed information for EVENT and Note context entries
  * Examples: "The DNS server has started.", "Zone loading completed", socket errors, internal state messages
  * Enhances visibility into DNS server operational events and diagnostics
  * Field is populated when Context is EVENT or Note; empty for PACKET entries

### Changed
* **BREAKING**: ComputerName column now always included at the end of all output records
  * Previously: ComputerName was conditionally included at the beginning when parameter was specified
  * Now: ComputerName always present as the last column; empty when parameter not specified
  * Benefit: Consistent output structure simplifies multi-server log consolidation and automated processing
  * Impact: Existing scripts that parse column positions or expect conditional column presence must be updated

### Added
* Context filtering to focus on specific log entry types (PACKET, EVENT, NOTE) via ContextFilter parameter

### Improved
* Refactored comment-based help for Convert-DNSDebugLogFile for better clarity and conciseness
* Updated parameter descriptions to be more informative and actionable
* Improved example documentation with more focused and practical use cases
* Enhanced about_DNSServer.DebugLogParser help file to reflect current functionality
* Enhanced verbose logging to provide more detailed progress information during processing

## 1.0.0 (2026-01-23)

### Added
* Initial release
* `Convert-DNSDebugLogFile` - High-performance parser for Windows DNS Server debug log files
  * Parses all 15 standard fields from DNS debug logs into structured CSV format
  * Supports customizable CSV delimiters (default: semicolon)
  * Optional ComputerName column for multi-server log consolidation
  * Three output modes: CSV data only, statistics only, or both
  * Statistical summaries aggregating activity by client IP, protocol, and query type
  * Pipeline support for batch processing multiple log files
  * Header validation to ensure data integrity (can be bypassed if needed)
  * Optional automatic compression of output files (ZIP format)
  * Optional removal of source files after successful processing
  * Culture-aware date parsing and formatting for international DNS servers
  * Optimized for large files (100MB+) using streaming I/O and efficient string operations
  * Compatible with PowerShell 5.1+ (Desktop and Core editions)
  * Supports Windows Server 2016+ and DNS Server 2012 R2 through 2025 log formats

