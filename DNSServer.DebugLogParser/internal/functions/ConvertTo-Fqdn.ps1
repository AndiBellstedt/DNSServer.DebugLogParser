function ConvertTo-Fqdn {
    <#
    .SYNOPSIS
        Converts a DNS name format to Fully Qualified Domain Name (FQDN).

    .DESCRIPTION
        Internal helper function that converts DNS server log name format to standard FQDN.
        Handles DNS log format with length prefixes and converts to dotted notation.

    .PARAMETER EncodedName
        DNS name string in encoded log format to convert. Format uses length-prefixed labels like (7)example(3)com(0).

    .EXAMPLE
        PS C:\> ConvertTo-Fqdn -EncodedName "(7)example(3)com(0)"

        Returns: example.com

    .NOTES
        Internal function not exported from module.

        Version:    1.0.1.1
        Author:     Andi Bellstedt, Copilot
        Date:       2026-01-25
        Keywords:   DNS, DebugLog, Parser, LogParser, Internal, FQDN

    .LINK
        https://github.com/AndiBellstedt/DNSServer.DebugLogParser

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]
        $EncodedName
    )

    if ([string]::IsNullOrWhiteSpace($EncodedName)) {
        return [string]::Empty
    }

    # Fast string parsing without regex
    $result = [System.Text.StringBuilder]::new(256)
    $i = 0
    $len = $EncodedName.Length

    while ($i -lt $len) {
        # Find opening parenthesis
        $openParen = $EncodedName.IndexOf('(', $i)
        if ($openParen -eq -1) { break }

        # Find closing parenthesis
        $closeParen = $EncodedName.IndexOf(')', $openParen)
        if ($closeParen -eq -1) { break }

        # Extract the number (length indicator)
        $lengthStr = $EncodedName.Substring($openParen + 1, $closeParen - $openParen - 1)

        # Check if it's the terminating (0)
        if ($lengthStr -eq '0') { break }

        # Extract the label that follows
        $labelStart = $closeParen + 1
        $nextParen = $EncodedName.IndexOf('(', $labelStart)

        if ($nextParen -eq -1) {
            $label = $EncodedName.Substring($labelStart)
        } else {
            $label = $EncodedName.Substring($labelStart, $nextParen - $labelStart)
        }

        # Append with dot separator
        if ($result.Length -gt 0) {
            $null = $result.Append('.')
        }
        $null = $result.Append($label)

        $i = if ($nextParen -eq -1) { $len } else { $nextParen }
    }

    return $result.ToString()
}
