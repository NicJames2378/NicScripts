<#
.SYNOPSIS
Parses the Okta API for the newest Okta Installer for Windows, on the General Availability branch.

.DESCRIPTION
Parses the Okta API for the newest Okta Installer for Windows, on the General Availability branch. This script will check Okta APIs for the latest file, download it to a specified location, and validate the file hashes.

.PARAMETER OktaSubdomain
The subdomain for youur organization in Okta. Read as 'https://{OktaSubdomain}.okta.com'

.PARAMETER OutputPath
A directory path for where you want to save your downloaded installer. Defaults to $env:TEMP.

.EXAMPLE
# Download the installer for a hypothetical "superduperorg" to a "C:\temp" directory.
Get-OktaWindowsInstaller -OktaSubdomain 'superduperorg' -OutputPath 'c:\temp'
#>

param (
    [Parameter(Mandatory=$True)]
    [string] $OktaSubdomain,
    [string] $OutputPath = $env:TEMP
)

"Scraping API for latest Windows release..."
$artifacts = Invoke-WebRequest -Uri "https://$OktaSubdomain.okta.com/api/v1/artifacts/WINDOWS_OKTA_VERIFY/latest?releaseChannel=GA"
$fileInfo = $artifacts.Content | ConvertFrom-Json
$dlUri = "https://$OktaSubdomain.okta.com$($fileInfo.files.href)"

"Saving release to system..."
$dlPath = (Join-Path $OutputPath $(Split-Path $dlUri -Leaf))
Invoke-WebRequest -Uri $dlUri -OutFile $dlPath
"File saved as '$dlPath'!"

"Verifying release hash..."
$sourceHashes = $fileInfo.files.fileHashes
$fileHashes = @{
    'SHA-256' = (Get-FileHash -Path $dlPath -Algorithm SHA256).Hash
    'SHA-512' = (Get-FileHash -Path $dlPath -Algorithm SHA512).Hash
}

$validation = 0
if ($sourceHashes.'SHA-256' -ieq $fileHashes.'SHA-256') {
    "Validation passed for SHA256!"
    $validation += 1
} else {
    Write-Warning "Validation failed for SHA256!"
}

if ($sourceHashes.'SHA-512' -ieq $fileHashes.'SHA-512') {
    "Validation passed for SHA512!"
    $validation += 1
} else {
    Write-Warning "Validation failed for SHA512!"
}

if ($validation -ge 2) {
    "All validations passed!"
} else {
    Write-Warning "One or more validations failed! File may be corrupted or damaged. Please retry script."
    Remove-Item -Path $dlPath -Force -ErrorAction SilentlyContinue
}