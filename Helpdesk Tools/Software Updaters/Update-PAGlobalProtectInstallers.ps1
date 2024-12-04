#Requires -Version 7

<#
.SYNOPSIS
Programatically downloads GlobalProtect VPN installers from a PA-VM appliance.

.DESCRIPTION
Programatically downloads GlobalProtect VPN installers from a PA-VM appliance and saves them to a temporary folder.

Requires PowerShell 7 to avoid certificate errors which occur when accessing the VPN page without using the NAT'd address.

Download path can be overridden via a parameter.
Does not require authentication to obtain the installers.
Does not perform version checking, and simply overwrites existing installer files.

.PARAMETER PaloAddress
Network address to the Palo Alto PA-VM appliance to obtain installers from. Can be an IP or FQDN.
Parsed as 'http://$PaloAddress/'

.PARAMETER DownloadPath
The location to save the installers to. 
Defaults to '(Join-Path $env:TEMP "GlobalProtect")'

.EXAMPLE
Update-PAGlobalProtectInstallers.ps1 -PaloAddress 192.168.0.200
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$PaloAddress,
    [string]$DownloadPath = (Join-Path $env:TEMP "GlobalProtect")
)

$downloadUris = @(
    [PSCustomObject]@{Name='GlobalProtect32.msi';Uri="http://$PaloAddress/global-protect/getmsi.esp?version=32&platform=windows"}
    [PSCustomObject]@{Name='GlobalProtect64.msi';Uri="http://$PaloAddress/global-protect/getmsi.esp?version=64&platform=windows"}
    [PSCustomObject]@{Name='GlobalProtectMac.pkg';Uri="http://$PaloAddress/global-protect/getmsi.esp?version=none&platform=mac"}
)

New-Item -Path $DownloadPath -ItemType Directory -Force
Set-Location $DownloadPath

"Beginning file downloads. This may take some time."
$downloadUris | ForEach-Object {
    Invoke-WebRequest -Uri $_.Uri -OutFile (Join-Path $DownloadPath $_.Name) -SkipCertificateCheck
}

"Files downloaded to $DownloadPath"