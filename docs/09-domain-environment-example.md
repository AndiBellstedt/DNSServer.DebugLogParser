# Practical Example: Domain Environment (GPO-driven collection and conversion)

[← Back to index](index.md)

This document outlines a practical, end-to-end example of running DNSServer.DebugLogParser in an Active Directory domain environment, focused on converting Windows DNS Server debug logs on domain controllers.

This example is accompanied by the ZIP archive `assets/GPO/T0-C-Analytics-DNSDebugLogging.zip` (and its extracted backup in `assets/GPO/backup/`), which provides the policy artifacts used to implement the workflow described here.

## Scenario

- Multiple domain controllers (DCs) host the DNS Server role.
- DNS debug logging is enabled and configured consistently on each DC via a scheduled task (writing log files to `C:\Administration\Logs\DNSServer`).
- A centrally managed process converts logs into CSV for:
  - security analytics
  - operational reporting
  - troubleshooting
  - compliance/retention

## Target outcomes

- Consistent conversion settings across all DCs
- Predictable output location and naming
- Optional compression to reduce storage footprint
- Optional statistics outputs for quick daily rollups
- Minimal operational risk (idempotent runs, safe cleanup)

## Suggested architecture

### Collection model: local convert + central pull

1. Each DC writes DNS debug logs to disk with rollover enabled.
2. Each DC converts its rotated `*.log` files to CSV+statistics and compresses them to `*.zip` on a schedule (Task Scheduler).
3. Outputs are written next to the log files (same folder) so the pipeline stays simple.
3. A central server pulls or ingests results (for example file share ingestion, SIEM forwarder, scheduled robocopy, or an agent-based collector).

This model minimizes network reads of large raw log files and keeps parsing close to the data.

## GPO workflow

The workflow is implemented through Group Policy (computer configuration) to ensure consistent settings across all domain controllers.

Reference implementation (from the backup you provided):

- GPO name: `T0-C-Analytics-DNSDebugLogging`
- GPO link target: `corp.company.com/Domain Controllers`
- Item filter (both file + tasks): only applies if `C:\Windows\System32\dns.exe` exists

### 1) Prerequisites (folders + module)

The provided GPO assumes these folders already exist:

- `C:\Administration\Scripts`
- `C:\Administration\Logs\DNSServer`

The provided GPO also assumes the module is already available on the DCs (because the conversion task calls `Convert-DNSDebugLogFile` without an explicit `Import-Module`). Recommended approaches:

- Install DNSServer.DebugLogParser on the DCs. For example, from PowerShell Gallery (if policy allows).
- Deploy the module via internal repo / file share so it is discoverable in `$env:PSModulePath`

### 2) Deploy the debug logging configuration script (GPP Files)

The GPO deploys the script:

- Source (in SYSVOL via GPP): `%GptPath%\Preferences\Files\Set-DNSServerDebugLogging.ps1`
- Target (on each DC): `C:\Administration\Scripts\Set-DNSServerDebugLogging.ps1`

This is implemented in the GPP Files preference item (see `assets/GPO/backup/{2B6F16BC-0E7C-4787-83D7-2854FED882EE}/DomainSysvol/GPO/Machine/Preferences/Files/Files.xml`).

### 3) Scheduled task: configure DNS debug logging

The GPO creates a scheduled task named `Set-DNSServerDebugLogging`.

- Runs as: `SYSTEM`
- Trigger: daily (start boundary `2025-03-01T00:00:01`)
- Action:
  - `powershell.exe -ExecutionPolicy RemoteSigned -command " & { C:\Administration\Scripts\Set-DNSServerDebugLogging.ps1 }"`
  - Working directory: `C:\Administration\Scripts`

The script configures DNS debug logging via `Get-DnsServerDiagnostics` / `Set-DnsServerDiagnostics` and (notably):

- Enables logging to file + rollover
- Writes to: `C:\Administration\Logs\DNSServer\DnsDebugLog_<COMPUTERNAME>.<Domain>_.log`
- Captures primarily query-related activity (queries + notifications + updates + question transactions) and excludes full packet logging


### 4) Scheduled task: convert rotated debug logs to compressed CSV

The GPO creates a scheduled task named `Convert-DNSDebugLogs`.

- Runs as: `System`
- Trigger: daily (start boundary `2026-01-01T00:30:00`)
- Working directory: `C:\Administration\Logs\DNSServer`
- Action (conceptually, formatted for readability):

```powershell
Get-ChildItem .\*.log |
  Sort-Object lastwritetime, Name -Descending |
  Select-Object -Skip 1 |
  Convert-DNSDebugLogFile `
    -ComputerName $env:COMPUTERNAME `
    -Delimiter ';' `
    -OutputType Both `
    -ContextFilter Packet `
    -OutputCulture sv-SE `
    -CompressOutput
```

Design notes:

- `Select-Object -Skip 1` intentionally avoids processing the newest (active) log file.
- Because `Convert-DNSDebugLogFile` defaults `-OutputFile` to “same folder, same name, `.csv`”, outputs land next to the `*.log` inputs.
- With `-CompressOutput`, each processed log produces a `*.zip` (and the intermediate CSVs are removed).
- The task throws if `$Error.Count -gt 0` to signal a failed run.

### 5) Central ingestion

Options (pick one):

- File share ingestion: DC writes (or copies) `C:\Administration\Logs\DNSServer\*.zip` to `\\fileserver\share\dns\$env:COMPUTERNAME\...` (ensure secure ACLs)
- Pull model: central job reads `\\dc\C$\Administration\Logs\DNSServer\*.zip` (least preferred; requires admin shares)
- Agent forwarder: SIEM / log pipeline that ships the `*.zip` outputs

## Operational considerations

- Least privilege: tasks run as SYSTEM; ensure SYSTEM can write to `C:\Administration\Logs\DNSServer`.
- Signing policy: `Set-DNSServerDebugLogging` forces `-ExecutionPolicy RemoteSigned`.
- Disk usage: `-CompressOutput` helps significantly, but this workflow does not remove source logs; plan retention and cleanup.
- Re-processing behavior: the conversion task processes “all but newest” `*.log` each day; this is simple and robust, but may reprocess old logs repeatedly.
- Multi-DC consolidation: `-ComputerName $env:COMPUTERNAME` is included so consolidated datasets remain traceable.
- Validation: header validation remains enabled by default (recommended).

## Validate and adapt (using the ZIP)

Use `assets/GPO/T0-C-Analytics-DNSDebugLogging.zip` as the reference implementation and align the following aspects to your environment:

- Target scope: which DCs / OUs receive the policy
- Execution identity: confirm both scheduled tasks run as intended (SYSTEM) and that the configured logon type works in your environment
- Paths: confirm `C:\Administration\Scripts` and `C:\Administration\Logs\DNSServer` match your standards
- Retention: decide whether to keep raw logs and for how long (especially if enabling cleanup options)
- Ingestion: confirm where CSV/ZIP outputs are written and how they are collected centrally

If you want to validate the exact GPO configuration without importing it, the authoritative sources in this repo are:

- `assets/GPO/backup/manifest.xml` (backup metadata)
- `assets/GPO/backup/{2B6F16BC-0E7C-4787-83D7-2854FED882EE}/gpreport.xml` (human-readable full report)
- `assets/GPO/backup/{2B6F16BC-0E7C-4787-83D7-2854FED882EE}/DomainSysvol/GPO/Machine/Preferences/Files/Files.xml` (file deployment)
- `assets/GPO/backup/{2B6F16BC-0E7C-4787-83D7-2854FED882EE}/DomainSysvol/GPO/Machine/Preferences/Files/Set-DNSServerDebugLogging.ps1` (script content)
- `assets/GPO/backup/{2B6F16BC-0E7C-4787-83D7-2854FED882EE}/DomainSysvol/GPO/Machine/Preferences/ScheduledTasks/ScheduledTasks.xml` (scheduled tasks)
