# Changelog

## 1.0.0 (2026-01-23)

+ New: Initial Release
+ New: `Convert-DNSDebugLogFile` - High-performance parser for Windows DNS Server debug log files
  + Parses all 16 fields from DNS debug logs into structured CSV format
  + Supports customizable CSV delimiters (default: semicolon)
  + Optional ComputerName column for multi-server log consolidation
  + Three output modes: CSV data only, statistics only, or both
  + Statistical summaries aggregating activity by client IP, protocol, and query type
  + Pipeline support for batch processing multiple log files
  + Header validation to ensure data integrity (can be bypassed if needed)
  + Optional automatic compression of output files (ZIP format)
  + Optional removal of source files after successful processing
  + Optimized for large files (100MB+) using streaming I/O and efficient string operations
  + Compatible with PowerShell 5.1+ (Desktop and Core editions)
  + Supports Windows Server 2016+ and DNS Server 2012 R2 through 2025 log formats
