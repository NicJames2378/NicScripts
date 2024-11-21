<#
.SYNOPSIS
Outputs a table of computer access event logs.

.DESCRIPTION
Outputs a table of computer access event logs for the purposes of finding out how often a computer is accessed, locked, unlocked, and used. 
Specifically, checks for log IDs: 4800-4803, 7001-7002

If running as a non-adminsitrative account, all Security events will be omitted. This includes information about system lock status and screensavers.

.PARAMETER DaysToCheck
How many days (in the past) to check through while looking for logs. Defaults to the last 30 days.

.EXAMPLE
# Checks the previous 180 days worth of logs, and shows output as a table.
Read-ComputerAccessEvents.ps1 -DaysToCheck 180 | Format-Table -Autosize

.EXAMPLE
# Checks the previous 90 days worth of logs, and saves the output as a CSV.
Read-ComputerAccessEvents.ps1 -DaysToCheck 180 | Export-Csv "access_events.csv"
#>

param (
    [int]$DaysToCheck = 30
)

$dateFrom = [DateTime]::Today.AddDays(-$DaysToCheck);

$propUser = @{n="User";e={(New-Object System.Security.Principal.SecurityIdentifier ($_.Properties.Value -ilike "*-*-*-*-*-*-*")).Translate([System.Security.Principal.NTAccount])}}
$propAction = @{n="Action";e={
    switch ($_.Id) {
        4800 { "Machine Locked" }
        4801 { "Machine Unlocked" }
        4802 { "Screensaver invoked" }
        4803 { "Screensaver dismissed" }
        7001 { "Logon" }
        7002 { "Logoff" }
        default {$_.Message.Split("`n")[0]}
    }
}}
$propTimestamp = @{n="Time";e={$_.TimeCreated}}
$propMessage = @{n="Message"; e={$_.Message.Split("`n")[0]}}

Get-WinEvent -FilterHashtable @{logname=@('Security','System'); id=@(4800,4801,4802,4803,7001,7002); starttime=$dateFrom} | Select-Object $propTimestamp, $propUser, $propAction, $propMessage, LogName, LevelDisplayName | Sort-Object -Descending $propTimestamp.n
