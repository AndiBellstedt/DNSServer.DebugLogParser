# Changelog

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

