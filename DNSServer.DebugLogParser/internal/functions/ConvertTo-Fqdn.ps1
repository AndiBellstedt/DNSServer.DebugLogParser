function ConvertTo-Fqdn {
    <#
    .SYNOPSIS
        Converts a DNS name format to Fully Qualified Domain Name (FQDN).

    .DESCRIPTION
        Internal helper function that converts DNS server log name format to standard FQDN.
        Handles DNS log format with length prefixes and converts to dotted notation.

    .PARAMETER Name
        DNS name string in log format to convert.

    .EXAMPLE
        PS C:\> ConvertTo-Fqdn -Name "(7)example(3)com(0)"

        Returns: example.com

    .NOTES
        Internal function not exported from module.
        Version: 1.0.0
        Author: Andi Bellstedt
        Date: 2026-01-23
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -eq '(0)') {
        return '.'
    }

    # Remove parentheses and numbers (length indicators)
    $parts = @()
    $inParen = $false
    $currentPart = ''

    for ($i = 0; $i -lt $Name.Length; $i++) {
        $char = $Name[$i]

        if ($char -eq '(') {
            $inParen = $true
            if ($currentPart.Length -gt 0) {
                $parts += $currentPart
                $currentPart = ''
            }
        } elseif ($char -eq ')') {
            $inParen = $false
        } elseif (-not $inParen) {
            $currentPart += $char
        }
    }

    if ($currentPart.Length -gt 0) {
        $parts += $currentPart
    }

    # Join parts with dots, remove trailing dot if it's just (0)
    $fqdn = $parts -join '.'
    if ($fqdn -eq '') {
        return '.'
    }

    return $fqdn
}
