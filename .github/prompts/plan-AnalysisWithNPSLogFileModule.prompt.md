## PERFORMANCE ANALYSIS - NPSLogFile vs Current Implementation

### Current Implementation Issues (1.33x speedup):
1. **Single-threaded Reader bottleneck**: One thread reads entire file sequentially
2. **Complex 3-stage pipeline**: Reader → RecordQueue → Parsers → OutputQueue → Writer
3. **Sequential I/O**: File reading happens in one thread, limiting throughput
4. **Queue overhead**: BlockingCollection operations add latency
5. **Parser starvation**: Parsers wait for Reader to feed records

### NPSLogFile Architecture (Proven Fast):
1. **Batch-based processing**: File divided into batches (200 - 2000 lines/batch)
2. **Parallel I/O**: Each runspace reads its own batch (no shared Reader)
3. **Simple architecture**: MainThread reads & creates batches → Runspaces process batches → MainThread collects results
4. **No queues**: Direct batch → runspace → results
5. **Dynamic batch size**: Adjusts based on file size (10MB + → 2000 lines/batch)
```
NPSLogFile Pattern:
Main Thread: Read batch → Create PowerShell → BeginInvoke() → ... → EndInvoke() & collect
Read batch → Create PowerShell → BeginInvoke() → ... → EndInvoke() & collect
Read batch → Create PowerShell → BeginInvoke() → ... → EndInvoke() & collect
(Multiple batches processing in parallel)

Current Pattern:
Main Thread: Wait for Reader → Wait for Parsers → Wait for Writer
Reader:    Read ALL lines → Queue records → Complete
Parsers:   Wait for records → Process → Queue output
Writer:    Wait for output → Write ALL lines
(Sequential dependencies, Reader bottleneck)
```

### Recommended Refactoring:
1. **Remove Reader/Parser/Writer pipeline**
2. **Implement batch-based approach**:
- Main thread reads file in chunks (e.g., 1000-5000 lines per batch)
- Each batch spawns a runspace to parse lines
- Runspaces return parsed CSV lines
- Main thread collects and writes output
3. **Benefits**:
- No single-threaded bottleneck
- Simpler code (no BlockingCollection, no CompleteAdding)
- Better parallelism (multiple batches processed simultaneously)
- Expected speedup: 2-4x on multi-core systems
