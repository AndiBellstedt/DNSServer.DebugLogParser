function ConvertFrom-DnsLogLine {
    <#
    .SYNOPSIS
        Parses a single DNS debug log line into structured data.

    .DESCRIPTION
        Internal helper function that parses a DNS Server debug log line and extracts
        structured information including timestamp, protocol, query type, client IP, and domain.

        Supports culture-aware date/time parsing to handle DNS debug logs from servers
        with different regional settings (e.g., German DD.MM.YYYY, US MM/DD/YYYY, Swedish YYYY-MM-DD).

        Supports filtering by context type: PACKET, EVENT, Note, DSPOLL, INIT, LOOKUP, RECURSE, REMOTE, and TOMBSTN.

    .PARAMETER Line
        The log line string to parse.

    .PARAMETER Culture
        The culture to use for parsing date/time values. Defaults to CurrentCulture.
        DNS Server debug logs use the date format of the Windows locale on the source server.

    .PARAMETER ContextFilter
        Filters the log lines by context type. Accepts single or multiple values.
        Valid values: 'All', 'Packet', 'Event', 'Note', 'DSPoll', 'Init', 'Lookup', 'Recurse', 'Remote', 'Tombstone'
        Default is 'All' which processes all context types.
        When multiple values are specified (not including 'All'), only log lines matching one of the specified contexts are returned.

    .EXAMPLE
        PS C:\> ConvertFrom-DnsLogLine -Line "20.01.2026 23:00:18 0FE0 PACKET  000002C5307CFCD0 UDP Rcv 10.0.0.2        ede1   Q [0001   D   NOERROR] A      (4)ocsp(8)digicert(3)com(0)"

        DateTime      : 1/20/2026 11:00:18 PM
        ThreadId      : 0FE0
        Context       : PACKET
        PacketId      : 000002C5307CFCD0
        Protocol      : UDP
        Direction     : Rcv
        RemoteIP      : 10.0.0.2
        Xid           : ede1
        QueryResponse :
        Opcode        : Q
        FlagsHex      : 0001
        FlagsChar     : D
        ResponseCode  : NOERROR
        QuestionType  : A
        QuestionName  : ocsp.digicert.com
        Information   :

    .EXAMPLE
        PS C:\> ConvertFrom-DnsLogLine -Line "20.01.2026 23:00:18 0518 EVENT   The DNS server has started."

        DateTime      : 1/20/2026 11:00:18 PM
        ThreadId      : 0518
        Context       : EVENT
        PacketId      :
        Protocol      :
        Direction     :
        RemoteIP      :
        Xid           :
        QueryResponse :
        Opcode        :
        FlagsHex      :
        FlagsChar     :
        ResponseCode  :
        QuestionType  :
        QuestionName  :
        Information   : The DNS server has started.

    .EXAMPLE
        PS C:\> ConvertFrom-DnsLogLine -Line "20.01.2026 23:00:18 5C8 Note: got GQCS failure on a dead socket context status=995, socket=612, pcon=00000020F4B18490, state=-1, IP=::"

        DateTime      : 1/20/2026 11:00:18 PM
        ThreadId      : 5C8
        Context       : NOTE
        PacketId      :
        Protocol      :
        Direction     :
        RemoteIP      :
        Xid           :
        QueryResponse :
        Opcode        :
        FlagsHex      :
        FlagsChar     :
        ResponseCode  :
        QuestionType  :
        QuestionName  :
        Information   : got GQCS failure on a dead socket context status=995, socket=612, pcon=00000020F4B18490, state=-1, IP=::

    .NOTES
        Internal function not exported from module.

        Version:    1.4.0.0
        Author:     Andi Bellstedt, Copilot
        Date:       2026-01-25
        Keywords:   DNS, DebugLog, Parser, LogParser, Internal

    .LINK
        https://github.com/AndiBellstedt/DNSServer.DebugLogParser

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]
        $Line,

        [System.Globalization.CultureInfo]
        $Culture = [System.Globalization.CultureInfo]::CurrentCulture,

        [ValidateSet('All', 'Packet', 'Event', 'Note', 'DSPoll', 'Init', 'Lookup', 'Recurse', 'Remote', 'Tombstone')]
        [string[]]
        $ContextFilter = @('All')
    )

    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    # Skip lines that starts with whitespaces
    if ($Line.IndexOf(' ') -eq 0) { return $null }

    # Skip lines that starts with "TCP" or "UDP" (non-standard format)
    if ($Line.StartsWith('TCP') -or $Line.StartsWith('UDP')) { return $null }

    # Skip orphaned "Response packet" lines (continuation lines without date prefix)
    if ($Line.StartsWith('Response packet')) { return $null }

    # Minimum line length check (date + time + minimal data)
    if ($Line.Length -lt 25) { return $null }

    # Parse fixed-position fields for maximum performance
    # The date/time portion occupies positions 0-18 or 0-19 depending on format
    # Supported formats (based on Windows locale):
    #   DD.MM.YYYY HH:MM:SS (German, position 20)
    #   DD/MM/YYYY HH:MM:SS (UK/Austrian, position 20)
    #   YYYY-MM-DD HH:MM:SS (Swedish/ISO, position 20)
    #   M/D/YYYY H:MM:SS or MM/DD/YYYY HH:MM:SS (US, variable length)

    # Find the first whitespace after position 8 to locate the date/time boundary
    # The time portion always ends before the thread ID (hex like 0FE0)
    $firstSpace = $Line.IndexOf(' ')
    if ($firstSpace -lt 6 -or $firstSpace -gt 12) { return $null }

    # Extract date string
    $dateStr = $Line.Substring(0, $firstSpace)

    # Find second space to get time portion
    $secondSpace = $Line.IndexOf(' ', $firstSpace + 1)
    if ($secondSpace -eq -1 -or $secondSpace - $firstSpace -lt 6) { return $null }

    $timeStr = $Line.Substring($firstSpace + 1, $secondSpace - $firstSpace - 1)

    # Track where the datetime portion ends for parsing the remaining fields
    $dateTimeEndPosition = $secondSpace

    # Check for AM/PM designator (12-hour clock format, e.g., en-US culture)
    # AM/PM follows immediately after the time with a space separator
    $thirdSpace = $Line.IndexOf(' ', $secondSpace + 1)
    if ($thirdSpace -ne -1) {
        $potentialAmPm = $Line.Substring($secondSpace + 1, $thirdSpace - $secondSpace - 1)
        if ($potentialAmPm -eq 'AM' -or $potentialAmPm -eq 'PM') {
            $timeStr = "$($timeStr) $($potentialAmPm)"
            $dateTimeEndPosition = $thirdSpace
        }
    }

    # Parse DateTime using culture-aware approach without regex
    # Use TryParse with the specified culture for maximum compatibility
    $dateTime = [datetime]::MinValue
    $dateTimeStr = "$($dateStr) $($timeStr)"

    # Try culture-specific parsing first (high performance path)
    if (-not [datetime]::TryParse($dateTimeStr, $Culture.DateTimeFormat, [System.Globalization.DateTimeStyles]::None, [ref]$dateTime)) {
        # Fallback: Try invariant culture for ISO format (YYYY-MM-DD)
        if (-not [datetime]::TryParse($dateTimeStr, [System.Globalization.CultureInfo]::InvariantCulture.DateTimeFormat, [System.Globalization.DateTimeStyles]::None, [ref]$dateTime)) {
            return $null
        }
    }

    # Remaining part after datetime (uses correct position whether AM/PM was present or not)
    $remaining = $Line.Substring($dateTimeEndPosition).TrimStart()

    # Split on whitespace for remaining fields to detect context type
    $parts = $remaining.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)

    # Assume invalid if less than 2 parts. At least Thread ID and Context are required.
    if ($parts.Count -lt 2) { return $null }

    # Field 3: Thread ID (always first part)
    $threadId = $parts[0]

    # Detect context type from the second part
    $contextRaw = $parts[1]
    $context = [string]::Empty
    $information = [string]::Empty

    # Initialize all PACKET-specific fields as empty
    $packetId = [string]::Empty
    $protocol = [string]::Empty
    $direction = [string]::Empty
    $remoteIp = [string]::Empty
    $xid = [string]::Empty
    $queryResponse = [string]::Empty
    $opcode = [string]::Empty
    $flagsHex = [string]::Empty
    $flagsChar = [string]::Empty
    $responseCode = [string]::Empty
    $questionType = [string]::Empty
    $questionName = [string]::Empty

    # Context type mapping for information-extraction contexts: Raw context keyword -> Context name and keyword length
    # Note: PACKET is handled separately due to completely different parsing logic
    $contextMap = @{
        'EVENT'   = @{ Name = 'Event'; KeywordLength = 5 }
        'DSPOLL'  = @{ Name = 'DSPoll'; KeywordLength = 6 }
        'INIT'    = @{ Name = 'Init'; KeywordLength = 4 }
        'LOOKUP'  = @{ Name = 'Lookup'; KeywordLength = 6 }
        'RECURSE' = @{ Name = 'Recurse'; KeywordLength = 7 }
        'REMOTE'  = @{ Name = 'Remote'; KeywordLength = 6 }
        'TOMBSTN' = @{ Name = 'Tombstone'; KeywordLength = 7 }
        'Note:'   = @{ Name = 'Note'; KeywordLength = 5 }
    }

    # Determine context type and apply filter
    if ($contextRaw -eq 'PACKET') {
        $context = 'Packet'

        # Apply context filter - check if 'All' is in array or if current context is in filter array
        if ($ContextFilter -notcontains 'All' -and $ContextFilter -notcontains $context) { return $null }

        # Check for information-only PACKET records (e.g., "Response packet XXX does not match any outstanding query")
        # Standard PACKET format requires at least 7 parts: ThreadId, PACKET, PacketId, Protocol, Direction, RemoteIP, Xid
        # Information-only packets have format: ThreadId, PACKET, followed by message text
        # Detect by checking if parts[3] is NOT a valid protocol indicator (UDP/TCP)
        if ($parts.Count -lt 7 -or ($parts[3] -ne 'UDP' -and $parts[3] -ne 'TCP')) {
            # Information-only PACKET record - extract everything after "PACKET" as information
            $packetIndex = $remaining.IndexOf('PACKET')
            if ($packetIndex -gt -1) {
                $information = $remaining.Substring($packetIndex + 6).TrimStart()
            }
            # Return with empty packet-specific fields but with information populated
            return [PSCustomObject]@{
                DateTime      = $dateTime
                ThreadId      = $threadId
                Context       = $context
                PacketId      = $packetId
                Protocol      = $protocol
                Direction     = $direction
                RemoteIP      = $remoteIp
                Xid           = $xid
                QueryResponse = $queryResponse
                Opcode        = $opcode
                FlagsHex      = $flagsHex
                FlagsChar     = $flagsChar
                ResponseCode  = $responseCode
                QuestionType  = $questionType
                QuestionName  = $questionName
                Information   = $information
            }
        }

        # Process standard PACKET context

        # Field 5: Internal packet identifier
        $packetId = $parts[2]

        # Field 6: UDP/TCP indicator
        $protocol = $parts[3]

        # Field 7: Send/Receive indicator
        $direction = $parts[4]

        # Field 8: Remote IP
        $remoteIp = $parts[5]

        # Field 9: Xid (hex)
        $xid = $parts[6]

        # Fields 10-16: Variable position based on Query/Response
        $partIndex = 7

        # Check for Response indicator "R"
        if ($partIndex -lt $parts.Count -and $parts[$partIndex] -eq 'R') {
            $queryResponse = 'R'
            $partIndex++
        }

        # Field 11: Opcode (Q, N, U, ?)
        if ($partIndex -lt $parts.Count) {
            $opcode = $parts[$partIndex]
            $partIndex++
        }

        # Fields 12-14: Flags section in brackets [FlagsHex FlagsChar ResponseCode]
        # Format: [8081 DR NOERROR] or [8085 A DR NOERROR]
        # Find the bracket section
        $bracketStart = $remaining.IndexOf('[')
        $bracketEnd = $remaining.IndexOf(']')

        if ($bracketStart -gt -1 -and $bracketEnd -gt $bracketStart) {
            $bracketContent = $remaining.Substring($bracketStart + 1, $bracketEnd - $bracketStart - 1).Trim()
            $flagParts = $bracketContent.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)

            if ($flagParts.Count -ge 1) {
                $flagsHex = $flagParts[0]
            }
            # ResponseCode is always last (NOERROR, NXDOMAIN, etc.)
            # FlagsChar is everything between FlagsHex and ResponseCode
            if ($flagParts.Count -ge 2) {
                $responseCode = $flagParts[$flagParts.Count - 1]
                if ($flagParts.Count -gt 2) {
                    $flagsChar = [string]::Join('', $flagParts[1..($flagParts.Count - 2)])
                }
            }
        }

        # Field 15 & 16: Question Type and Name (after the bracket)
        if ($bracketEnd -gt -1 -and $bracketEnd + 1 -lt $remaining.Length) {
            $afterBracket = $remaining.Substring($bracketEnd + 1).TrimStart()
            $afterParts = $afterBracket.Split([char[]]@(' ', "`t"), 2, [StringSplitOptions]::RemoveEmptyEntries)

            if ($afterParts.Count -ge 1) {
                $questionType = $afterParts[0]
            }
            if ($afterParts.Count -ge 2) {
                $questionName = $afterParts[1].Trim()
            }
        }

        # Convert question name to FQDN
        if ($questionName) {
            $questionName = ConvertTo-Fqdn -EncodedName $questionName
        }

    } elseif ($contextMap.ContainsKey($contextRaw)) {
        # Handle all information-extraction context types uniformly
        $contextInfo = $contextMap[$contextRaw]
        $context = $contextInfo.Name

        # Apply context filter - check if 'All' is in array or if current context is in filter array
        if ($ContextFilter -notcontains 'All' -and $ContextFilter -notcontains $context) { return $null }

        # Extract information text (everything after the context keyword with leading whitespace trimmed)
        $keywordIndex = $remaining.IndexOf($contextRaw)
        if ($keywordIndex -gt -1) {
            $information = $remaining.Substring($keywordIndex + $contextInfo.KeywordLength).TrimStart()
        }

    } else {
        # Unknown context type - treat as "raw" generic information

        # Apply context filter - only include unknown types if 'All' is specified
        if ($ContextFilter -notcontains 'All') { return $null }

        $context = $contextRaw

        # Remove Thread ID and Context from parts to get remaining information
        $parts = $parts[2..($parts.Count - 1)]

        # Put all in the information block
        $information = ($parts -join ' ').Trim()
    }

    # Return parsed object using ordered hashtable for performance
    return [PSCustomObject]@{
        DateTime      = $dateTime
        ThreadId      = $threadId
        Context       = $context
        PacketId      = $packetId
        Protocol      = $protocol
        Direction     = $direction
        RemoteIP      = $remoteIp
        Xid           = $xid
        QueryResponse = $queryResponse
        Opcode        = $opcode
        FlagsHex      = $flagsHex
        FlagsChar     = $flagsChar
        ResponseCode  = $responseCode
        QuestionType  = $questionType
        QuestionName  = $questionName
        Information   = $information
    }
}
