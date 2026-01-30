## Plan: Async Producer-Consumer Processing für DNS Log Parser (Final)

Implementiert eine 3-Stage Producer-Consumer-Pipeline als **Standard-Verarbeitungsmodus** mit parametrierbarer Queue-Kapazität, ConcurrentDictionary-Statistik, Error/Message-Queues und PS5.1/PS7-Kompatibilität.

### Steps

1. **Async-Support-Prüfung in [internal/scripts/postimport.ps1](DNSServer.DebugLogParser/internal/scripts/postimport.ps1)**: Typtest für `BlockingCollection`, setzt `$script:AsyncSupported`. Bei Modul-Import verfügbar.

2. **Parameter-Änderungen in [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1)**: Entferne `-AsyncProcessing`, füge `-SynchronousProcessing` (Switch) hinzu. `-ParserThreadCount` (Int, Default: `[Math]::Max(1, [Environment]::ProcessorCount - 2)`), `-QueueCapacity` (Int, Default: 10000). CBH aktualisieren: Async ist Standard, `-SynchronousProcessing` für Legacy-Modus.

3. **Shared Queues im `begin`-Block erstellen**: `$RecordQueue`, `$OutputQueue` (`BlockingCollection`), `$ContextStats`, `$PacketStats` (`ConcurrentDictionary[string,int]`), `$ErrorQueue` (`ConcurrentQueue[PSCustomObject]`), `$MessageQueue` (`ConcurrentQueue[string]`), `$IncrementFunc` (pre-created Delegate).

4. **Runspace-Initialisierung**: `InitialSessionState` mit `SessionStateFunctionEntry` für interne Funktionen, `SessionStateVariableEntry` für alle Shared-Objekte. `RunspacePool` mit `1` bis `$ParserThreadCount` Worker.

5. **Reader-Runspace**: Lookahead-Buffer-Logik, Record-Assembly, `$RecordQueue.Add()`. Wichtige Meldungen (Datei-Start, Header-Validation) → `$MessageQueue.Enqueue()`. Bei Fehler: `$ErrorQueue.Enqueue()`. Bei EOF: `$RecordQueue.CompleteAdding()`.

6. **Parser-Pool (N Worker)**: `foreach ($record in $RecordQueue.GetConsumingEnumerable())` → Parsing → CSV-Formatierung → `$OutputQueue.Add()` → Statistik-Update. Fehler → `$ErrorQueue.Enqueue()`.

7. **Writer-Runspace**: `foreach ($csvLine in $OutputQueue.GetConsumingEnumerable())` → `$StreamWriter.WriteLine()`. Progress deaktiviert bei Async.

8. **End-Block-Synchronisation**: Reader warten → Parser warten → `$OutputQueue.CompleteAdding()` → Writer warten. `$MessageQueue` auslesen → `Write-Verbose`. `$ErrorQueue` auslesen → `Write-Error`. Statistik-Dateien schreiben. `finally`: Dispose alle Ressourcen.

9. **Fallback bei `$script:AsyncSupported -eq $false`**: Automatisch synchronen Modus nutzen, `Write-Warning` ausgeben. Gleicher Fallback wenn `-SynchronousProcessing` explizit gesetzt.

10. **Pester-Tests in [tests/functions/Convert-DNSDebugLogFile.Tests.ps1](tests/functions/Convert-DNSDebugLogFile.Tests.ps1)**: `Context "Async Processing (Default)"`: Output-Identität (sortiert), Multi-File-Pipeline, Error-Propagation. `Context "Synchronous Processing"`: `-SynchronousProcessing` Parameter, Fallback-Warnung.

### Implementierungs-Reihenfolge

| Phase | Komponente | Dateien |
|-------|------------|---------|
| 1 | Async-Support-Check | [postimport.ps1](DNSServer.DebugLogParser/internal/scripts/postimport.ps1) |
| 2 | Parameter + CBH | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) |
| 3 | Shared Collections + InitialSessionState | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) `begin`-Block |
| 4 | Reader-ScriptBlock | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) |
| 5 | Parser-Worker-ScriptBlock | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) |
| 6 | Writer-ScriptBlock | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) |
| 7 | End-Block-Sync + Cleanup | [Convert-DNSDebugLogFile.ps1](DNSServer.DebugLogParser/functions/Convert-DNSDebugLogFile.ps1) `end`-Block |
| 8 | Pester-Tests | [Convert-DNSDebugLogFile.Tests.ps1](tests/functions/Convert-DNSDebugLogFile.Tests.ps1) |

### Architektur-Diagramm

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              MAIN THREAD (begin/end)                            │
│  - Parameter validation          - Wait for all runspaces                       │
│  - Create shared collections     - Drain MessageQueue → Write-Verbose           │
│  - Initialize RunspacePool       - Drain ErrorQueue → Write-Error               │
│  - Start Reader/Parser/Writer    - Write statistics files                       │
│  - Fallback to sync if needed    - Dispose resources                            │
└─────────────────────────────────────────────────────────────────────────────────┘
        │                                    ▲
        ▼                                    │
┌───────────────┐    ┌────────────────────────────────────┐    ┌───────────────┐
│ READER        │    │ PARSER POOL (N workers)            │    │ WRITER        │
│ (1 Runspace)  │───>│ (RunspacePool)                     │───>│ (1 Runspace)  │
├───────────────┤    ├────────────────────────────────────┤    ├───────────────┤
│ StreamReader  │    │ ConvertFrom-DnsLogLine             │    │ StreamWriter  │
│ Lookahead     │    │ ConvertTo-Fqdn                     │    │               │
│ Record Assy   │    │ ConvertTo-PacketDetailJson         │    │               │
│               │    │ CSV Format                         │    │               │
│ → RecordQueue │    │ → OutputQueue                      │    │ ← OutputQueue │
│ → MessageQueue│    │ → ContextStats/PacketStats         │    │               │
│ → ErrorQueue  │    │ → ErrorQueue                       │    │               │
└───────────────┘    └────────────────────────────────────┘    └───────────────┘
        │                         │                                    │
        ▼                         ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            SHARED CONCURRENT COLLECTIONS                        │
│  RecordQueue:  BlockingCollection[PSCustomObject] (bounded: QueueCapacity)      │
│  OutputQueue:  BlockingCollection[string] (bounded: QueueCapacity)              │
│  ContextStats: ConcurrentDictionary[string, int]                                │
│  PacketStats:  ConcurrentDictionary[string, int]                                │
│  ErrorQueue:   ConcurrentQueue[PSCustomObject]                                  │
│  MessageQueue: ConcurrentQueue[string]                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Risiken und Mitigationen

| Risiko | Mitigation |
|--------|------------|
| Deadlock bei Queue-Kapazität | Bounded Queues + `CompleteAdding()` garantiert Termination |
| Memory bei großen Dateien | Bounded Capacity, Backpressure durch BlockingCollection |
| Fehler in Runspaces verloren | ErrorQueue sammelt alle Exceptions, End-Block reportet |
| PS 5.1 Inkompatibilität | Typtest bei Import, automatischer Fallback zu Sync |
| Race Conditions bei Stats | ConcurrentDictionary mit pre-created Func Delegate |

### Entscheidungen

1. **Error-Handling**: Alle Fehler sammeln und am Ende berichten (kein Abbruch bei einzelnen Fehlern)
2. **Progress-Reporting**: Bei Async deaktiviert (Option A)
3. **Verbose/Debug-Output**: Wichtige Meldungen über `$MessageQueue` sammeln, im End-Block ausgeben
4. **Default-Modus**: Async ist Standard, `-SynchronousProcessing` Switch für Legacy-Modus
5. **Statistik**: ConcurrentDictionary mit pre-created `$IncrementFunc` Delegate
6. **Parser-Threads**: Parametrierbar via `-ParserThreadCount`, Default = `ProcessorCount - 2`
7. **Queue-Kapazität**: Parametrierbar via `-QueueCapacity`, Default = 10000 (max Throughput)
