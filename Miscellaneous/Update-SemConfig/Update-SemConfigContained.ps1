<#
.SYNOPSIS
Creates a SEM LogForwarder config file located adjacent to the script.

.DESCRIPTION
Asks the user for an IP address of a syslog server. If unable to resolve the DNS name, will prompt for 
that as well. Finally, will create the configuration file located in the same folder.

Generated file is named "ForwarderConfig.cfg".

.EXAMPLE
Update-SemConfig.ps1 
#>


$ConfigFileName = ".\ForwarderConfig.cfg"
$xmlContents = @"
<?xml version="1.0" encoding="utf-8"?>
<LogForwarderSettings xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="1.1.13">
  <EventLogSubscriptions>
    <EventLogSubscription>
      <channels>
        <string>Security</string>
      </channels>
      <types>
        <int>1</int>
        <int>2</int>
        <int>4</int>
      </types>
      <sources />
      <eventIDs>
        <string>1102</string>
        <!--Security Log Cleared -->
        <string>4624</string>
        <!--Successful Logon-->
        <string>4625</string>
        <!--Failed Logon-->
        <string>4648</string>
        <!--Logon Attempt with Explicit Credentials-->
        <string>4675</string>
        <!--Privileged Account Logon-->
        <string>4720</string>
        <!--User Account Created-->
        <string>4722</string>
        <!--User Account Enabled-->
        <string>4723</string>
        <!--User Attempted to Change Password-->
        <string>4724</string>
        <!--Privileged User Attempted to Reset Password-->
        <string>4725</string>
        <!--User Account Disabled-->
        <string>4726</string>
        <!--User Account Deleted-->
        <string>4732</string>
        <!--A User Was Added to a Privileged Group-->
        <string>4740</string>
        <!--User Account Has Been Locked Out-->
        <string>4771</string>
        <!--Kerberos Pre-Authentication Failed-->
        <string>4776</string>
        <!--NTLM Authentication Attempt-->
      </eventIDs>
      <categories />
      <keywords />
      <users />
      <computers />
      <facility>1</facility>
      <enabled>true</enabled>
      <name>Security logs</name>
      <description>Windows Security Event Log</description>
      <HidePreview>0</HidePreview>
    </EventLogSubscription>
    <!--
    <EventLogSubscription>
      <channels>
        <string>System</string>
      </channels>
      <types>
        <int>1</int>
        <int>2</int>
        <int>4</int>
      </types>
      <sources />
      <eventIDs>
        <string>3000</string>
        <string>1500</string>
      </eventIDs>
      <categories />
      <keywords />
      <users />
      <computers />
      <facility>1</facility>
      <enabled>true</enabled>
      <name>System logs</name>
      <description>Windows System Event Log</description>
      <HidePreview>0</HidePreview>
    </EventLogSubscription>
    -->
    <!--
    <EventLogSubscription>
      <channels>
        <string>Application</string>
      </channels>
      <types>
        <int>1</int>
        <int>2</int>
        <int>4</int>
      </types>
      <sources />
      <eventIDs>
        <string>500</string>
        <string>2048</string>
        <string>1014</string>
      </eventIDs>
      <categories />
      <keywords />
      <users />
      <computers />
      <facility>1</facility>
      <enabled>true</enabled>
      <name>Application logs</name>
      <description>Windows Application Event Log</description>
      <HidePreview>0</HidePreview>
    </EventLogSubscription>
    -->
  </EventLogSubscriptions>
  <SyslogServers>
    <SyslogServer>
      <serverName>SERVERNAME</serverName>
      <IPAddress>IPADDRESS</IPAddress>
      <Port>514</Port>
      <enabled>true</enabled>
      <SendMode>0</SendMode>
      <SourceFormat>0</SourceFormat>
    </SyslogServer>
  </SyslogServers>
  <DebugMode>false</DebugMode>
</LogForwarderSettings>
"@


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
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$file = Join-Path -Path $scriptPath -ChildPath $ConfigFileName
$xml = [xml]$xmlContents

# Write new values to in-meomry XML
$xml.LogForwarderSettings.SyslogServers.SyslogServer.serverName = $dnsName
$xml.LogForwarderSettings.SyslogServers.SyslogServer.IPAddress = $ip.ToString()

# Overwrite XML file on disk
$xml.Save($file)
Write-Output "Config file has been created: $file"