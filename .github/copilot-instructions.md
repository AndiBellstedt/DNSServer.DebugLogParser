# DNSServer.DebugLogParser - AI Agent Guide

# General information, first things first
- always check for additional personal instruction files and respect them as well

## Project Overview
PowerShell module that parses Windows DNS Server debug log files into structured CSV format for analytics and reporting. Single-function module optimized for high-performance log processing (100MB+ files).

## Architecture

### Module Structure (PSFramework Template Pattern)
```
DNSServer.DebugLogParser/
├── functions/              # Public exported functions (1 function per file)
│   └── Convert-DNSDebugLogFile.ps1
├── internal/
│   ├── functions/         # Private helper functions (not exported)
│   └── scripts/           # Module initialization scripts (run once on import)
└── DNSServer.DebugLogParser.psd1  # Module manifest
```

**Critical**: The `.psm1` file automatically dot-sources all scripts in order: internal functions → public functions → internal scripts. Never manually add imports.

### Build System
Located in `build/` directory, uses PSFramework.NuGet tooling:

1. **Prerequisites**: `.\build\prerequisites.ps1` - Installs dependencies (Pester, PSScriptAnalyzer, PSModuleDevelopment)
2. **Validate**: `.\build\validate.ps1` - Runs Pester tests via `tests\pester.ps1`
3. **Build**: `.\build\build.ps1` - Compiles module into `publish/` directory, handles auto-versioning and function exports
4. **Publish**: `.\build\publish.ps1` - Publishes to PSGallery (requires `-ApiKey`)
5. **Release**: `.\build\release.ps1` - Creates GitHub release

## Development Workflows

### Testing
Run from `tests/` directory:
```powershell
.\pester.ps1                        # Run all tests
.\pester.ps1 -Output Detailed       # Verbose output
.\pester.ps1 -TestFunctions $false  # Skip function-specific tests
```

Tests organized as:
- `tests/general/` - Manifest validation, PSScriptAnalyzer, file integrity, help completeness
- `tests/functions/` - Per-function tests (when created)

**Testing Pattern**: Uses Pester 5.x with `[PesterConfiguration]`, outputs JUnit XML to `TestResults/`.

### CI/CD Pipelines
- **build.yml**: Runs on push to main/master - validates (PS 5.1 + 7), builds, publishes to PSGallery, creates GitHub release
- **validate.yml**: Runs on all other branches and PRs - validates only, no publish

Both workflows run on `windows-latest` and test against PowerShell 5.1 (Desktop) and 7.x (Core).

### Version Management
Controlled by `config.psd1`:
```powershell
@{
    AutoVersion = $false       # If true, build.ps1 auto-increments version from PSGallery
    ExportFunctions = $false   # If true, build.ps1 auto-generates FunctionsToExport
    GithubRelease = $true      # Create GitHub release after publish
}
```

When `ExportFunctions = $false` (current), manually maintain `FunctionsToExport` in `.psd1` manifest. Manifest tests validate sync with `functions/*.ps1` files.

## PowerShell Coding Standards

### Naming Conventions (from global standards)
- **Functions**: PascalCase, Verb-Noun format (`Convert-DNSDebugLogFile`)
- **Parameters**: PascalCase with common names (`-ComputerName` not `-Computer`)
- **Variables**:
  - Param block: PascalCase
  - Internal: camelCase
  - Constants: ALL_CAPS
- **No Pluralization**: Use singular names + "List" suffix for arrays (`$fileList` not `$files`)
- **Aliases**: Use generously for parameter flexibility (see `Convert-DNSDebugLogFile` for examples)

### Comment-Based Help
Every function requires comprehensive CBH with:
- Synopsis (one-line summary)
- Description (detailed explanation with use cases, performance notes, compatibility)
- Parameter descriptions (include defaults, validation, warnings)
- Multiple examples (5-10+) showing real-world usage patterns
- Notes (version, author, date, keywords)
- Link (GitHub URL)

### Error Handling & Logging
- **PSFramework Preferred**: Use `Write-PSFMessage` when PSFramework is available
- **Standard Approach**: Use `Write-Verbose`, `Write-Warning`, `Write-Error` for non-PSFramework code
- **Try/Catch**: Only for commands that throw terminating errors
- **Throw**: Use for terminating errors with contextual info
- **Never Log**: Passwords, tokens, hashes, or PII

### Performance Optimization Patterns
From `Convert-DNSDebugLogFile.ps1`:
- **StreamReader/StreamWriter**: Use with 64KB buffers for large files
- **String Operations**: Prefer `.Substring()`, `.IndexOf()` over regex
- **Manual CSV Generation**: Avoid `Export-Csv` overhead for high-volume data
- **Hashtable Statistics**: Use `[hashtable]` for fast aggregation

## Module Manifest Best Practices

### Required Fields to Maintain
```powershell
ModuleVersion = '1.0.0'           # Manually increment or AutoVersion
Author = 'Andi Bellstedt'
Copyright = 'Copyright (c) YYYY Andi Bellstedt. All rights reserved.'
Description = 'Clear, concise summary'
PowerShellVersion = '5.1'          # Minimum supported version
CompatiblePSEditions = @('Desktop', 'Core')
FunctionsToExport = @('Convert-DNSDebugLogFile')  # When ExportFunctions=$false
PrivateData.PSData.Tags = @('DNSServer', 'DNS', 'DebugLog', 'Parser', 'LogParser')
```

### URI Configuration
```powershell
LicenseUri   = 'https://github.com/AndiBellstedt/DNSServer.DebugLogParser/blob/main/LICENSE'
ProjectUri   = 'https://github.com/AndiBellstedt/DNSServer.DebugLogParser'
IconUri      = 'https://github.com/AndiBellstedt/DNSServer.DebugLogParser/raw/main/assets/DNSServer.DebugLogParser_128x128.png'
ReleaseNotes = 'https://github.com/AndiBellstedt/DNSServer.DebugLogParser/blob/main/DNSServer.DebugLogParser/changelog.md'
```

## Key Patterns & Conventions

### Pipeline Support
Functions should support:
```powershell
[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[Alias('FullName', 'FilePath', 'InputPath', 'File', 'Path')]
[string[]]
$InputFile
```

This allows: `Get-ChildItem *.log | Convert-DNSDebugLogFile`

### Parameter Validation
Use attributes generously:
- `[ValidateSet()]` for enumerated choices
- `[ValidateLength()]` for string constraints
- `[Alias()]` for parameter name flexibility
- `[ValidateScript()]` for complex validation

### Explicit Output Determination
Track user intent vs. defaults (from `Convert-DNSDebugLogFile.ps1`):
```powershell
$explicitOutputFile = -not [string]::IsNullOrEmpty($OutputFile)
# Then adjust behavior based on pipeline context
```

## Common Tasks

### Adding a New Public Function
1. Create `DNSServer.DebugLogParser/functions/New-Function.ps1` (one function per file)
2. Add comprehensive CBH with 5+ examples
3. If `ExportFunctions = $false`, manually add to `FunctionsToExport` in `.psd1`
4. Create `tests/functions/New-Function.Tests.ps1` with Pester 5.x tests
5. Run `.\tests\pester.ps1` to validate

### Adding Internal Helper Functions
1. Create in `DNSServer.DebugLogParser/internal/functions/` (not exported)
2. Keep focused and reusable
3. Document purpose with inline comments

### Running Full Build Pipeline Locally
```powershell
.\build\prerequisites.ps1   # Install dependencies
.\build\validate.ps1        # Run tests
.\build\build.ps1           # Compile to publish/
# .\build\publish.ps1 -LocalRepo  # Create .nupkg without publishing
```

### Updating Dependencies
Add to `RequiredModules` in `.psd1`, then `prerequisites.ps1` auto-installs them.

## Project-Specific Context

**Problem Domain**: Windows DNS Server debug logs are human-readable text but not analytics-ready. This module transforms them into structured CSV for Excel, Power BI, SQL, etc.

**Performance Focus**: Designed for 100MB+ files using streaming I/O and string operations instead of regex.

**Single-Function Philosophy**: Module currently exports only `Convert-DNSDebugLogFile`. If adding features, consider if they should be separate parameters vs. new functions.

**Windows-Only**: DNS Server debug logs are Windows-specific. No cross-platform considerations needed for core functionality.
