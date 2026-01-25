function ConvertTo-PacketDetailJson {
    <#
    .SYNOPSIS
        Converts DNS PACKET detail lines into a structured JSON object.

    .DESCRIPTION
        Internal helper function that parses the indented detail block following a DNS PACKET
        log entry and converts it into a structured JSON object for storage and analysis.

        The detail block contains TCP/UDP connection information, message structure, and
        DNS section data (Question, Answer, Authority, Additional sections).

        PERFORMANCE: Uses StringBuilder for efficient string concatenation and manual parsing
        instead of regex for maximum throughput when processing large log files.

    .PARAMETER DetailLines
        An array of detail lines to parse. Relative leading indentation must be preserved
        exactly as in the original log, as the parser uses indentation to determine nesting.

    .EXAMPLE
        PS C:\> $detailLines = @(
            'Socket = 848',
            'Remote addr 10.10.0.11, port 60580',
            'Message:',
            '  XID       0x0001'
        )
        PS C:\> ConvertTo-PacketDetailJson -DetailLines $detailLines

        Returns a JSON string representing the parsed detail structure.

    .NOTES
        Internal function not exported from module.

        Version:    1.0.1.0
        Author:     Andi Bellstedt, Copilot
        Date:       2026-01-25
        Keywords:   DNS, DebugLog, Parser, LogParser, Internal, JSON

    .LINK
        https://github.com/AndiBellstedt/DNSServer.DebugLogParser

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [System.Collections.Generic.List[string]]
        $DetailLines
    )

    # Early return for empty input
    if ($null -eq $DetailLines -or $DetailLines.Count -eq 0) {
        return [string]::Empty
    }

    # Build structured data object using ordered hashtable for predictable JSON output
    $detailObject = [ordered]@{}
    $messageObject = [ordered]@{}
    $flagsObject = $null

    # Track current section for DNS sections (QUESTION, ANSWER, etc.)
    $currentSectionName = $null
    $currentSectionData = $null
    $currentRecord = $null

    # State tracking
    $inMessage = $false

    for ($i = 0; $i -lt $DetailLines.Count; $i++) {
        $rawLine = $DetailLines[$i]

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }

        # Calculate indentation level (each 2 spaces = 1 level)
        $trimmedLine = $rawLine.TrimStart()
        $indentSpaces = $rawLine.Length - $trimmedLine.Length
        $indentLevel = [Math]::Floor($indentSpaces / 2)

        # Check for Message section start (top-level)
        if ($trimmedLine -eq 'Message:') {
            $inMessage = $true
            continue
        }

        # Check for DNS section headers (inside Message)
        if ($inMessage -and $trimmedLine -match '^(QUESTION|ANSWER|AUTHORITY|ADDITIONAL) SECTION:$') {
            # Save previous section if exists
            if ($null -ne $currentSectionName -and $null -ne $currentSectionData) {
                $messageObject[$currentSectionName] = $currentSectionData.ToArray()
            }
            $currentSectionName = $Matches[1]
            $currentSectionData = [System.Collections.Generic.List[object]]::new()
            $currentRecord = $null
            continue
        }

        # Handle "empty" marker for sections
        if ($trimmedLine -eq 'empty' -and $null -ne $currentSectionData) {
            # Empty section - keep it as empty array
            continue
        }

        # Parse based on context
        if ($null -ne $currentSectionData) {
            # Inside a DNS section (QUESTION, ANSWER, etc.)

            if ($trimmedLine.StartsWith('Offset = ')) {
                # New record in section: "Offset = 0x000c, RR count = 0"
                $currentRecord = [ordered]@{}

                # Parse offset and RR count
                $parts = $trimmedLine.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
                foreach ($part in $parts) {
                    $kvp = $part.Trim().Split('=', 2)
                    if ($kvp.Count -eq 2) {
                        $currentRecord[$kvp[0].Trim() -replace ' ', ''] = $kvp[1].Trim()
                    }
                }
                $currentSectionData.Add($currentRecord)
            } elseif ($trimmedLine.StartsWith('Name = ') -and $null -ne $currentRecord) {
                # Name property for current record
                $nameValue = $trimmedLine.Substring(7)
                # Convert encoded name to FQDN
                $currentRecord['Name'] = ConvertTo-Fqdn -EncodedName $nameValue
            } elseif ($trimmedLine -match '^(\S+)\s+(.+)$' -and $null -ne $currentRecord) {
                # Other record properties (QTYPE, QCLASS, etc.)
                $currentRecord[$Matches[1]] = $Matches[2].Trim()
            }
        } elseif ($inMessage) {
            # Inside Message section but before any DNS section

            # Check if this is a Flags sub-property (higher indent level)
            if ($indentLevel -ge 2 -and $null -ne $flagsObject) {
                # Sub-property of Flags (QR, OPCODE, AA, TC, RD, RA, Z, CD, AD, RCODE)
                if ($trimmedLine -match '^(\S+)\s+(.+)$') {
                    $flagsObject[$Matches[1]] = $Matches[2].Trim()
                }
            } elseif ($trimmedLine -match '^(\S+)\s+(.+)$') {
                # Message-level property
                $key = $Matches[1]
                $value = $Matches[2].Trim()

                if ($key -eq 'Flags') {
                    # Start collecting flag sub-properties
                    $flagsObject = [ordered]@{ 'Value' = $value }
                    $messageObject[$key] = $flagsObject
                } else {
                    $messageObject[$key] = $value
                }
            }
        } else {
            # Top-level connection properties (before Message:)

            $eqPos = $trimmedLine.IndexOf(' = ')
            if ($eqPos -gt 0) {
                # Simple "Key = Value" format
                $key = $trimmedLine.Substring(0, $eqPos).Trim()
                $value = $trimmedLine.Substring($eqPos + 3).Trim()

                # Normalize key to remove spaces for JSON compatibility
                $jsonKey = $key -replace ' ', ''
                $detailObject[$jsonKey] = $value
            } elseif ($trimmedLine.Contains('=') -and $trimmedLine.Contains(',')) {
                # Multiple key=value pairs: "Time Query=179992, Queued=0, Expire=0"
                $spacePos = $trimmedLine.IndexOf(' ')
                if ($spacePos -gt 0) {
                    $keyPart = $trimmedLine.Substring(0, $spacePos)
                    $valuePart = $trimmedLine.Substring($spacePos + 1)

                    # Parse comma-separated key=value pairs
                    $pairs = $valuePart.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
                    $pairObject = [ordered]@{}
                    foreach ($pair in $pairs) {
                        $kvp = $pair.Trim().Split('=', 2)
                        if ($kvp.Count -eq 2) {
                            $pairObject[$kvp[0].Trim()] = $kvp[1].Trim()
                        }
                    }
                    $detailObject[$keyPart] = $pairObject
                }
            } elseif ($trimmedLine -match '^(\S+)\s+(.+)$') {
                # "Key Value" format (e.g., "Remote addr 10.10.0.11, port 60580")
                $detailObject[$Matches[1]] = $Matches[2].Trim()
            }
        }
    }

    # Save last section if exists
    if ($null -ne $currentSectionName -and $null -ne $currentSectionData) {
        $messageObject[$currentSectionName] = $currentSectionData.ToArray()
    }

    # Add Message object if we collected any message data
    if ($messageObject.Count -gt 0) {
        $detailObject['Message'] = $messageObject
    }

    # Convert to JSON using ConvertTo-Json for proper escaping
    # Use -Compress for minimal output size (important for CSV storage)
    # Use -Depth 5 to handle nested structures
    if ($detailObject.Count -gt 0) {
        try {
            return ConvertTo-Json -InputObject $detailObject -Compress -Depth 5 -ErrorAction Stop
        } catch {
            # Fallback: Return empty string if JSON conversion fails
            return [string]::Empty
        }
    }

    return [string]::Empty
}
