function Test-DnsDebugLogHeader {
    <#
    .SYNOPSIS
        Validates if a file contains a valid DNS debug log header.

    .DESCRIPTION
        Internal helper function that checks if a file starts with a valid DNS Server debug log header.
        The header should contain "Message logging started" or similar DNS debug log markers.

    .PARAMETER Path
        Path to the file to validate.

    .EXAMPLE
        PS C:\> Test-DnsDebugLogHeader -Path "C:\Windows\System32\dns\dns.log"

        Returns $true if the file has a valid DNS debug log header.

    .NOTES
        Internal function not exported from module.
        Version: 1.0.0
        Author: Andi Bellstedt
        Date: 2026-01-23
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    try {
        $reader = [System.IO.StreamReader]::new($Path, [System.Text.Encoding]::UTF8)
        $firstLine = $reader.ReadLine()
        $reader.Close()
        $reader.Dispose()

        # DNS debug log header contains date/time and "Message logging started"
        if ($firstLine -match '^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}:\d{2}\s+(AM|PM).*Message logging started') {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}
