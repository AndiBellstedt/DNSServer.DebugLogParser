function ConvertFrom-DnsLogLine {
    <#
    .SYNOPSIS
        Parses a single DNS debug log line into structured data.

    .DESCRIPTION
        Internal helper function that parses a DNS Server debug log line and extracts
        structured information including timestamp, protocol, query type, client IP, and domain.

    .PARAMETER Line
        The log line string to parse.

    .PARAMETER IncludeRawLine
        Include the original raw log line in the output.

    .EXAMPLE
        PS C:\> ConvertFrom-DnsLogLine -Line "1/23/2026 10:15:30 AM 1234 PACKET UDP Rcv 192.168.1.100 1234 Q [0001 D NOERROR] A (7)example(3)com(0)"

        Returns a hashtable with parsed log data.

    .NOTES
        Internal function not exported from module.
        Version: 1.0.0
        Author: Andi Bellstedt
        Date: 2026-01-23

    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Line,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeRawLine
    )

    # Skip empty lines or comment lines
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) {
        return $null
    }

    try {
        # DNS debug log format (space-delimited):
        # Date Time ThreadID Context PacketID Protocol Direction ClientIP Port QueryType Flags QueryName
        # Example: 1/23/2026 10:15:30 AM 1234 PACKET 0001 UDP Rcv 192.168.1.100 1234 Q [0001 D NOERROR] A (7)example(3)com(0)

        $parts = $Line -split '\s+', 20

        if ($parts.Count -lt 10) {
            return $null
        }

        # Extract timestamp
        $dateStr = "$($parts[0]) $($parts[1])"
        $timestamp = $null
        try {
            # Try German format first: DD.MM.YYYY HH:MM:SS
            $timestamp = [datetime]::ParseExact($dateStr, 'dd.MM.yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        } catch {
            # If parse fails, try US format with AM/PM: M/d/yyyy h:mm:ss tt
            try {
                $dateStr = "$($parts[0]) $($parts[1]) $($parts[2])"
                $timestamp = [datetime]::ParseExact($dateStr, 'M/d/yyyy h:mm:ss tt', [System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                # Last resort: try generic parse
                try {
                    $timestamp = [datetime]::Parse($dateStr)
                } catch {
                    return $null
                }
            }
        }

        # Parse remaining fields (adjust indices based on date format)
        # German format has 2 date fields (date + time), US format has 3 (date + time + AM/PM)
        $dateFieldCount = if ($parts[0] -match '^\d{2}\.\d{2}\.\d{4}$') { 2 } else { 3 }

        $threadId = $parts[$dateFieldCount]
        $context = $parts[$dateFieldCount + 1]
        $packetId = $parts[$dateFieldCount + 2]
        $protocol = $parts[$dateFieldCount + 3]
        $direction = $parts[$dateFieldCount + 4]
        $clientIp = $parts[$dateFieldCount + 5]
        $port = $parts[$dateFieldCount + 6]

        # Find query type and domain
        $queryType = ''
        $domain = ''
        $flags = ''

        # Look for query type (A, AAAA, PTR, etc.) and domain
        $startIndex = $dateFieldCount + 7
        for ($i = $startIndex; $i -lt $parts.Count; $i++) {
            if ($parts[$i] -match '^\[.*\]$') {
                $flags = $parts[$i]
            } elseif ($parts[$i] -match '^(A|AAAA|PTR|MX|NS|CNAME|SOA|TXT|SRV)$') {
                $queryType = $parts[$i]
                # Next part should be domain
                if ($i + 1 -lt $parts.Count) {
                    $domain = ConvertTo-Fqdn -Name $parts[$i + 1]
                }
                break
            }
        }

        # Build result
        $result = @{
            Timestamp = $timestamp
            ThreadId  = $threadId
            Context   = $context
            PacketId  = $packetId
            Protocol  = $protocol
            Direction = $direction
            ClientIP  = $clientIp
            Port      = $port
            QueryType = $queryType
            Flags     = $flags
            Domain    = $domain
        }

        if ($IncludeRawLine) {
            $result['RawLine'] = $Line
        }

        return $result
    } catch {
        return $null
    }
}
