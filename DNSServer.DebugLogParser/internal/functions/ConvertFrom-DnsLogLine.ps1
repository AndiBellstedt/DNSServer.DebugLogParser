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
        $dateStr = "$($parts[0]) $($parts[1]) $($parts[2])"
        $timestamp = $null
        try {
            $timestamp = [datetime]::ParseExact($dateStr, 'M/d/yyyy h:mm:ss tt', [System.Globalization.CultureInfo]::InvariantCulture)
        } catch {
            # If parse fails, try alternate format
            try {
                $timestamp = [datetime]::Parse($dateStr)
            } catch {
                return $null
            }
        }

        # Parse remaining fields
        $threadId = $parts[3]
        $context = $parts[4]
        $packetId = if ($parts[5] -match '^\d+$') { $parts[5] } else { '' }
        $protocol = $parts[6]
        $direction = $parts[7]
        $clientIp = $parts[8]
        $port = $parts[9]

        # Find query type and domain
        $queryType = ''
        $domain = ''
        $flags = ''

        # Look for query type (A, AAAA, PTR, etc.) and domain
        for ($i = 10; $i -lt $parts.Count; $i++) {
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
