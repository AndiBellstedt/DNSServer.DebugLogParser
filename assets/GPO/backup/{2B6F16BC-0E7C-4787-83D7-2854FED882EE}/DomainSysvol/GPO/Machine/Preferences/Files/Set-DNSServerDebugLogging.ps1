<#
.SYNOPSIS
    Configures DNS Server Debug Logging settings.

.DESCRIPTION
    This script sets the DNS Server Debug Logging parameters to specified values.
    It first checks if the DNS Server service is running, then retrieves the current
    diagnostics settings and compares them with the desired settings. Only the settings
    that differ from the current configuration are applied.

.NOTES
    Version  : 1.0.0.0
    Author   : Andi Bellstedt, Copilot
    Date     : 2026-01-24
    Keywords : Microsoft Windows Server, DNSServer, DNS, DebugLog, LogParser

#>

# Specify the desired DNS Server Debug Logging Parameters
$dnsDebugLogParameter = @{
    "SaveLogsToPersistentStorage"          = $false
    "Queries"                              = $true
    "Answers"                              = $false
    "Notifications"                        = $true
    "Update"                               = $true
    "QuestionTransactions"                 = $true
    "UnmatchedResponse"                    = $false
    "SendPackets"                          = $false
    "ReceivePackets"                       = $true
    "TcpPackets"                           = $true
    "UdpPackets"                           = $true
    "FullPackets"                          = $False
    "FilterIPAddressList"                  = $null
    "EventLogLevel"                        = 4
    "UseSystemEventLog"                    = $False
    "EnableLoggingToFile"                  = $true
    "EnableLogFileRollover"                = $true
    "LogFilePath"                          = "C:\Administration\Logs\DNSServer\DnsDebugLog_$($env:COMPUTERNAME).$((Get-CimInstance -ClassName "win32_computersystem").Domain)_.log"
    "MaxMBFileSize"                        = (10 * 1mb)
    "WriteThrough"                         = $false
    "EnableLoggingForLocalLookupEvent"     = $false
    "EnableLoggingForPluginDllEvent"       = $false
    "EnableLoggingForRecursiveLookupEvent" = $false
    "EnableLoggingForRemoteServerEvent"    = $false
    "EnableLoggingForServerStartStopEvent" = $false
    "EnableLoggingForTombstoneEvent"       = $false
    "EnableLoggingForZoneDataWriteEvent"   = $false
    "EnableLoggingForZoneLoadingEvent"     = $false
}

# Check if the DNS Server service is running
$service = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
$Error.clear()

# Only proceed if the DNS Server service is running
if ($service -and $service.Status -eq 'Running') {

    # Get current DNS Server Diagnostics settings
    $dnsServerDiagnostics = Get-DnsServerDiagnostics
    $paramsToSet = $dnsDebugLogParameter.Clone()

    # Compare current settings with desired settings and remove matching ones
    foreach ($key in $dnsDebugLogParameter.Keys) {
        if ([string]($dnsServerDiagnostics.$key) -like [string]($dnsDebugLogParameter.$key)) {
            $paramsToSet.Remove($key)
        }
    }

    # If there are any settings to change, apply them
    if ($paramsToSet.Keys) {
        Set-DnsServerDiagnostics @paramsToSet -ErrorAction Stop
    }
}
if ($Error.Count -gt 0) {
    throw 1, "Errors occurred while configuring DNS Server Debug Logging settings: $($Error | Out-String)"
}
