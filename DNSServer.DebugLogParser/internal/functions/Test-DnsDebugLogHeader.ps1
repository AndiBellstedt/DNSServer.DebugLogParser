function Test-DnsDebugLogHeader {
    <#
    .SYNOPSIS
        Validates if a file contains a valid DNS debug log header and returns header line count.

    .DESCRIPTION
        Internal helper function that checks if a file starts with a valid DNS Server debug log header.
        Checks the first few lines of the file to ensure they match the standard DNS debug log format:
            - Line 1: "DNS Server log file creation at <timestamp>"
            - Line 2: "Log file wrap at <timestamp>" or empty line
            - Line 3: Empty line (or line 4 if line 2 had wrap message)
            - Next: "Message logging key (for packets - other items use a subset of these fields):"
            - Next: Tab + "Field #  Information         Values"

            The function validates the essential header components and returns the number of header
            lines to skip (typically 30 for standard logs). Returns 0 if validation fails.

            Supports both standard DNS debug logs and detailed logs with additional UDP/TCP information.

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
        $reader = [System.IO.StreamReader]::new($Path, [System.Text.Encoding]::UTF8, $true)

        # Read first several lines to validate header structure
        $lines = @()
        for ($i = 0; $i -lt 10; $i++) {
            $line = $reader.ReadLine()
            if ($null -eq $line) {
                break
            }
            $lines += $line
        }

        $reader.Close()
        $reader.Dispose()

        # Need at least 5 lines to validate
        if ($lines.Count -lt 5) {
            return 0
        }

        # Line 1: Must start with "DNS Server log file creation at" with timestamp
        # Use StartsWith for better performance than regex
        if (-not $lines[0].StartsWith('DNS Server log file creation at ')) {
            return 0
        }
        # Quick validation: line should be at least 47 chars ("DNS Server log file creation at DD.MM.YYYY HH:MM:SS")
        if ($lines[0].Length -lt 47) {
            return 0
        }

        # Line 2: Can be "Log file wrap at" or empty line
        $lineOffset = 0
        if ($lines[1].StartsWith('Log file wrap at')) {
            $lineOffset = 1
            # If line 2 is wrap message, line 3 should be empty
            if (-not [string]::IsNullOrWhiteSpace($lines[2])) {
                return 0
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($lines[1])) {
            return 0
        }

        # Find the "Message logging key" line (should be at index 2+offset or 3+offset)
        $messageKeyIndex = -1
        for ($i = (2 + $lineOffset); $i -lt $lines.Count; $i++) {
            if ($lines[$i].StartsWith('Message logging key (for packets')) {
                $messageKeyIndex = $i
                break
            }
        }

        if ($messageKeyIndex -eq -1) {
            return 0
        }

        # Next line after "Message logging key" should contain "Field #"
        $fieldHeaderIndex = $messageKeyIndex + 1
        if ($fieldHeaderIndex -ge $lines.Count) {
            return 0
        }

        # Use Contains for better performance than regex with \s+ pattern
        $fieldHeaderLine = $lines[$fieldHeaderIndex].TrimStart()
        if (-not $fieldHeaderLine.StartsWith('Field #') -or -not $fieldHeaderLine.Contains('Information')) {
            return 0
        }

        # Valid DNS debug log - return standard header line count
        # Standard DNS debug log has 29 lines of header + 1 empty line = 30 total
        return 30

    } catch {
        return 0
    }
}
