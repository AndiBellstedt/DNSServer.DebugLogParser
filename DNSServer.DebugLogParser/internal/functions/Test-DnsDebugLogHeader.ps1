function Test-DnsDebugLogHeader {
    <#
    .SYNOPSIS
        Validates if a file contains a valid DNS debug log header and returns header line count.

    .DESCRIPTION
        Internal helper function that checks if a file starts with a valid DNS Server debug log header.
        The header should contain "Message logging started" or similar DNS debug log markers.
        Returns the number of header lines to skip (typically 30) or 0 if invalid.

    .PARAMETER Path
        Path to the file to validate.

    .EXAMPLE
        PS C:\> Test-DnsDebugLogHeader -Path "C:\Windows\System32\dns\dns.log"

        Returns 30 if the file has a valid DNS debug log header, 0 if invalid.

    .NOTES
        Internal function not exported from module.
        Version: 1.0.0
        Author: Andi Bellstedt
        Date: 2026-01-23
    #>
    [CmdletBinding()]
    [OutputType([int])]
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

        # DNS debug log header contains date/time and "DNS Server log file creation" or "Message logging started"
        # German format: DD.MM.YYYY HH:MM:SS or US format: M/d/yyyy h:mm:ss tt
        if ($firstLine -match '^\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}.*DNS Server log file creation') {
            # German format with "DNS Server log file creation"
            return 30
        } elseif ($firstLine -match '^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}:\d{2}\s+(AM|PM).*Message logging started') {
            # US format with "Message logging started"
            return 30
        } else {
            # Invalid DNS log
            return 0
        }
    } catch {
        return 0
    }
}
