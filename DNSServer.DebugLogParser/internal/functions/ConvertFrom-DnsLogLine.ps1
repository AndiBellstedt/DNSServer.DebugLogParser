function ConvertFrom-DnsLogLine {
    <#
    .SYNOPSIS
        Parses a single DNS debug log line into structured data.

    .DESCRIPTION
        Internal helper function that parses a DNS Server debug log line and extracts
        structured information including timestamp, protocol, query type, client IP, and domain.

    .PARAMETER Line
        The log line string to parse.

    .EXAMPLE
        PS C:\> ConvertFrom-DnsLogLine -Line "20.01.2026 23:00:18 0FE0 PACKET  000002C5307CFCD0 UDP Rcv 10.0.0.2        ede1   Q [0001   D   NOERROR] A      (4)ocsp(8)digicert(3)com(0)"
        Returns a hashtable with parsed log data.

    .NOTES
        Internal function not exported from module.

        Version:    1.0.0
        Author:     Andi Bellstedt
        Date:       2026-01-23

    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]
        $Line
    )

    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    # Minimum line length check (date + time + minimal data)
    if ($Line.Length -lt 25) {
        return $null
    }

    # Parse fixed-position fields for maximum performance
    # Format: "13.01.2026 23:00:16 0FE0 PACKET  000002C53117D990 UDP Rcv 10.10.31.11     c049   Q [0001   D   NOERROR] A      (3)odc..."

    # Field 1 & 2: Date and Time (positions 0-18, format: DD.MM.YYYY HH:MM:SS)
    $dateStr = $Line.Substring(0, 10)    # DD.MM.YYYY
    $timeStr = $Line.Substring(11, 8)    # HH:MM:SS

    # Parse DateTime - German format DD.MM.YYYY
    $dateTime = $null
    $dateParts = $dateStr.Split('.')
    if ($dateParts.Count -eq 3) {
        try {
            $dateTime = [datetime]::new(
                [int]$dateParts[2],  # Year
                [int]$dateParts[1],  # Month
                [int]$dateParts[0],  # Day
                [int]$timeStr.Substring(0, 2),   # Hour
                [int]$timeStr.Substring(3, 2),   # Minute
                [int]$timeStr.Substring(6, 2)    # Second
            )
        } catch {
            return $null
        }
    } else {
        return $null
    }

    # Remaining part after datetime (position 20+)
    $remaining = $Line.Substring(20).TrimStart()

    # Split on whitespace for remaining fields
    $parts = $remaining.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)

    if ($parts.Count -lt 7) {
        return $null
    }

    # Field 3: Thread ID
    $threadId = $parts[0]

    # Field 4: Context (e.g., PACKET)
    $context = $parts[1]

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
    $queryResponse = [string]::Empty
    $opcode = [string]::Empty
    $flagsHex = [string]::Empty
    $flagsChar = [string]::Empty
    $responseCode = [string]::Empty
    $questionType = [string]::Empty
    $questionName = [string]::Empty

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
    $fqdn = ConvertTo-Fqdn -EncodedName $questionName

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
        QuestionName  = $fqdn
    }
}
