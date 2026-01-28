# Output Formats

[← Back to index](index.md)

DNSServer.DebugLogParser can generate two types of output:

- A CSV data file containing all parsed entries
- Optional statistics files for daily aggregation

To see real-world examples of each output type, check the sample output files in the [assets/ExampleData](../assets/ExampleData) folder.

## CSV data file

Example output files:

- en-US (no details): [WithComputerName](../assets/ExampleData/en-us%20-%20dnsdebug-dc01%20-%20WithComputerName.csv), [NoComputerName](../assets/ExampleData/en-us%20-%20dnsdebug-dc01%20-%20NoComputerName.csv)
- de-DE (no details): [WithComputerName](../assets/ExampleData/de-de%20-%20dnsdebug-dc01%20-%20WithComputerName%20-%20NoDetails.csv), [NoComputerName](../assets/ExampleData/de-de%20-%20dnsdebug-dc01%20-%20NoComputerName%20-%20NoDetails.csv)
- de-DE (with details / `Details` JSON populated for Packet detail blocks): [WithComputerName](../assets/ExampleData/de-de%20-%20dnsdebug-dc01%20-%20WithComputerName%20-%20WithDetails.csv), [NoComputerName](../assets/ExampleData/de-de%20-%20dnsdebug-dc01%20-%20NoComputerName%20-%20WithDetails.csv)

The CSV data file contains all parsed log entries with the following columns:

- `DateTime`: Date and time of the DNS query/response
- `ThreadId`: Internal DNS server thread identifier
- `Context`: Operation context (for example Packet, Event, Note, DSPoll, Init, Lookup, Recurse, Remote, Tombstone)
- `PacketId`: DNS packet identifier
- `Protocol`: UDP or TCP
- `Direction`: `Rcv` (received/query) or `Snd` (sent/response)
- `ClientIP`: Client IP address
- `Xid`: Transaction ID (hex)
- `Type`: Query or Response
- `Opcode`: Standard, Notify, Update, or Unknown
- `FlagsHex`: Query/response flags (hex)
- `FlagsChar`: Flags decoded (Authoritative, Truncated, RecursionDesired, RecursionAvailable)
- `ResponseCode`: NOERROR, NXDOMAIN, SERVFAIL, etc.
- `QuestionType`: DNS record type (A, AAAA, MX, PTR, etc.)
- `QuestionName`: Domain name queried
- `Information`: Additional information (for Event/Note/etc.; for Packet detail blocks, contains the TCP/UDP detail header line)
- `Details`: JSON data for Packet entries that include detail blocks (empty otherwise)
- `ComputerName`: Source server name (always present; empty if not specified)

Note: The `ComputerName` column is always included at the end of each record to ensure consistent output structure. This facilitates multi-server log consolidation scenarios.

## Statistics files (optional)

Example output files:

- Context statistics: [en-US (WithComputerName)](../assets/ExampleData/en-us%20-%20dnsdebug-dc01_Statistic%20-%20WithComputerName.csv), [en-US (NoComputerName)](../assets/ExampleData/en-us%20-%20dnsdebug-dc01_Statistic%20-%20NoComputerName.csv), [de-DE (WithComputerName)](../assets/ExampleData/de-de%20-%20dnsdebug-dc01_Statistic%20-%20WithComputerName.csv), [de-DE (NoComputerName)](../assets/ExampleData/de-de%20-%20dnsdebug-dc01_Statistic%20-%20NoComputerName.csv)
- Packet statistics: [en-US (WithComputerName)](../assets/ExampleData/en-us%20-%20dnsdebug-dc01_PacketStatistic%20-%20WithComputerName.csv), [en-US (NoComputerName)](../assets/ExampleData/en-us%20-%20dnsdebug-dc01_PacketStatistic%20-%20NoComputerName.csv), [de-DE (WithComputerName)](../assets/ExampleData/de-de%20-%20dnsdebug-dc01_PacketStatistic%20-%20WithComputerName.csv), [de-DE (NoComputerName)](../assets/ExampleData/de-de%20-%20dnsdebug-dc01_PacketStatistic%20-%20NoComputerName.csv)

When statistics are generated, two separate files are created:

### 1) Context statistics (`*_Statistic.csv`)

Columns:

- `Date`: Date (`yyyy-MM-dd`)
- `Context`: Context name (for example Packet, Event, Note)
- `Count`: Number of records
- `ComputerName`: Source server name

### 2) Packet statistics (`*_PacketStatistic.csv`)

Columns:

- `Date`: Date (`yyyy-MM-dd`)
- `ClientIP`: Client IP address
- `Protocol`: UDP or TCP
- `Direction`: `Rcv` or `Snd`
- `QuestionType`: DNS record type
- `Count`: Number of records
- `ComputerName`: Source server name
