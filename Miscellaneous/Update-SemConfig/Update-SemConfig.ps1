<#
.SYNOPSIS
Updates a SEM LogForwarder config file located adjacent to the script.

.DESCRIPTION
Asks the user for an IP address of a Kiwi Syslog NG server. If unable to resolve the DNS name, will prompt for 
that as well. Finally, will update the configuration file located in the same folder.

Default config file name is 

.PARAMETER ConfigFileName
The name of the config file to process. Should be located in the same folder as this script.

.EXAMPLE
# Run with default filename
Update-SemConfig.ps1 

.EXAMPLE
# Run with custom filename
Update-SemConfig.ps1 -ConfigFileName "SpecialConfigFile.cfg"
#>

param (
    [string] $ConfigFileName = ".\LogForwarderSettings.cfg"
)

if (-not (Test-Path $ConfigFileName)) {
    Write-Warning "Could not validate the existence of config file [$ConfigFileName]. Aborting!"
    pause
    exit
}

# ===============
# Get IP Address
# ===============
$ipValid = $false
do {
    $ip = Read-Host "`nEnter the IP address of your Kiwi Syslog NG Server"

    try {
        $ip = [ipaddress]$ip
        $ipValid = $true
    } catch {
        "Please enter a valid IP address."
    }
} while (-not $ipValid)



# =============
# Get DNS Name 
# =============
$dnsValid = $false

# Try to lookup name using DNS settings
try {
    $dns = Resolve-DnsName $ip
} catch { # Ask for input if a lookup fails
    Write-Output "Could not lookup a DNS name for $ip."
}

# Only accept a lookup if there is only one entry found matching. Otherwise, require a manual input.
if ($dns.Length -eq 1) {
    do {
        $dnsCorrect = (Read-Host "Found DNS name of $($dns.NameHost). Is this correct? (y/n)").ToLower()
    } while ( -not ($dnsCorrect -in @("y","n")) )
    
    if ($dnsCorrect -eq 'y') {
        $dnsValid = $true
        $dnsName = $dns.NameHost
    }
}

if (-not $dnsValid) { # if there are 0 or multiple DNS matches found
    do {
        $dnsName = Read-Host "`nEnter the DNS name of your Kiwi Syslog NG Server"

        if (-not (Test-Connection -ComputerName $dnsName -Count 1 -ErrorAction SilentlyContinue)) {
            Write-Output "Failed to ping $dnsName. Please verify connectivity and try again."
        } else {
            $dnsValid = $true
        }

    } while (-not $dnsValid)
}

# Output for clarity
Write-Output "Using server [$dnsName] at IP [$ip]!"



# =================
# Process XML File
# =================
$file = Get-Item $ConfigFileName
$xml = [xml](Get-Content -Path $file)

# Write new values to in-meomry XML
$xml.LogForwarderSettings.SyslogServers.SyslogServer.serverName = $dnsName
$xml.LogForwarderSettings.SyslogServers.SyslogServer.IPAddress = $ip.ToString()

# Overwrite XML file on disk
$xml.Save($file.FullName)
Write-Output 'Config file has been updated!'