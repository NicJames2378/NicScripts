#Requires -Module ActiveDirectory

<#
.SYNOPSIS
    Processes a CSV file containing user data and updates Active Directory (AD) users' employee numbers based on the data in the CSV. The CSV file is validated, and the results are logged.

.DESCRIPTION
    This script allows you to update the employee number for Active Directory users based on a CSV file. The CSV file must include email addresses and employee numbers, but additional columns for first name and last name can be provided for clearer logging. The script provides options to override the AD search base and server, and it will export the updated results to a specified path.
    By default, this script assumes column names match AD property names as it was designed to allow someone to export all AD users, update the spreadsheet, and reimport.

.PARAMETER UsersCsvPath
    The full path to the CSV file containing user data, including the necessary columns: EmailAddress (default email) and EmployeeNumber (default employeeNumber).

.PARAMETER OverrideSearchBase
    Optional. Specify an alternate Active Directory search base to use during user lookups. If not provided, the default search base will be used.

.PARAMETER OverrideServer
    Optional. Specify an alternate Active Directory server to query. If not provided, the default server will be used.

.PARAMETER ExportPath
    Optional. Specify the path where the output CSV file will be exported. If not provided, the file will be exported to the user's "temp" folder. If the path does not end with `.csv`, the script will append a timestamp to the filename.

.PARAMETER CsvHeaderMappings
    Optional. A hashtable of custom header mappings for the CSV file. By default, the script expects the following mappings:
    - 'FirstName' = 'givenName'
    - 'LastName' = 'sn'
    - 'EmailAddress' = 'email'
    - 'EmployeeNumber' = 'employeeNumber'

    You can customize these mappings if your CSV uses different headers.

.EXAMPLE
    .\Update-ADEmployeeNumber.ps1 -UsersCsvPath "C:\path\to\users.csv" -OverrideServer "adserver.domain.com" -ExportPath "C:\path\to\export.csv"
    This example processes the CSV file at "C:\path\to\users.csv" and updates the employee numbers in Active Directory for users found in the file. The results will be saved to "C:\path\to\export.csv".

.EXAMPLE
    .\Update-ADEmployeeNumber.ps1 -UsersCsvPath "C:\path\to\users.csv" -OverrideSearchBase "OU=Users,DC=domain,DC=com"
    This example processes the CSV file and overrides the Active Directory search base.

.NOTES
    Author: Nicholas James
    Script Version: 1.0
    Date: 2025-04-21
    Prerequisites:
        - The `ActiveDirectory` PowerShell module must be installed and available on the system.
        - The script must be run with permissions to modify Active Directory objects.
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Full path to the CSV file containing user data.")]
    [ValidateNotNullOrEmpty()]
    [string] $UsersCsvPath,

    [Parameter(HelpMessage = "Optional: Specify an alternate Active Directory search base.")]
    [ValidateNotNullOrEmpty()]
    [string] $OverrideSearchBase,

    [Parameter(HelpMessage = "Optional: Specify an alternate Active Directory server.")]
    [ValidateNotNullOrEmpty()]
    [string] $OverrideServer,

    [Parameter(HelpMessage = "Optional: Path to export output or results.")]
    [string] $ExportPath = $env:TEMP,

    [Parameter(HelpMessage = "Optional: Custom header mappings for the CSV file.")]
    [hashtable] $CsvHeaderMappings = @{
        FirstName = 'givenName'
        LastName = 'sn'
        EmailAddress = 'email'
        EmployeeNumber = 'employeeNumber'
    }
)

function Add-Result {
    param (
        [Parameter(Mandatory)]
        $Object,
        [Parameter(Mandatory)]
        [string]$Message
    )
    Write-Verbose $Message
    $Object | Add-Member -MemberType NoteProperty -Name "Result" -Value $Message -Force | Out-Null
}

$ADSearchParams = @{}
# Build AD Search Params
if (-not [String]::IsNullOrWhiteSpace($OverrideSearchBase)) { $ADSearchParams['SearchBase'] = $OverrideSearchBase }
if (-not [String]::IsNullOrWhiteSpace($OverrideServer)) { $ADSearchParams['Server'] = $OverrideServer }

# Debug Logging
if ($ADSearchParams.Count -gt 0) {
    Write-Verbose "AD Search Paramaters provided."
    Write-Verbose $ADSearchParams
}

if (-not $ExportPath.EndsWith(".csv")) {
    $ExportPath = Join-Path -Path $ExportPath -ChildPath "UpdatedUsers_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
}

# Parse CSV and validate header mappings
$csv = Import-Csv -Path $UsersCsvPath -ErrorAction Stop
$headers = ($csv | Get-Member -MemberType NoteProperty).Name
$requiredKeys = 'EmailAddress', 'EmployeeNumber'
$errorMessageTemplate = "Supplied CsvHeaderMapping [%0] missing for property [%1]"

# Validate required headers
$mappingError = $false
foreach ($key in $requiredKeys) {
    if ($CsvHeaderMappings[$key] -notin $headers) {
        $mappingError = $true
        Write-Warning ($errorMessageTemplate.Replace('%0', $CsvHeaderMappings[$key]).Replace('%1', $key))
    }
}
$optionalKeys = $CsvHeaderMappings.Keys | Where-Object { $_ -notin $requiredKeys }
foreach ($key in $optionalKeys) {
    if ($CsvHeaderMappings[$key] -notin $headers) {
        Write-Verbose "Optional field mapping [$key] not found in CSV. Logging will be less detailed."
        $CsvHeaderMappings[$key] = $null  # Safe to reference later
    }
}
if ($mappingError) {
    throw "Unable to verify required header fields. Please verify your CsvHeaderMappings parameter."
}

# Iterate CSV
$csv | ForEach-Object {
    $firstName = if ($CsvHeaderMappings.FirstName) { $_.($CsvHeaderMappings.FirstName) } else { '[UnknownFirst]' }
    $lastName  = if ($CsvHeaderMappings.LastName)  { $_.($CsvHeaderMappings.LastName) }  else { '[UnknownLast]' }
    $email     = $_.($CsvHeaderMappings.EmailAddress)
    $empnum    = $_.($CsvHeaderMappings.EmployeeNumber)
    Write-Verbose "Processing [$lastName,$firstName] ($email)"

    # Validate email and employee number
    if ([String]::IsNullOrWhiteSpace($email)) {
        Add-Result -Object $_ -Message 'Email Address field not provided.'
        continue
    }
    if ([String]::IsNullOrWhiteSpace($empnum)) {
        Add-Result -Object $_ -Message 'Employee Number field not provided.'
        continue
    }
    
    # Locate user by Email
    try {
        $aduser = Get-ADUser @ADSearchParams -Filter "emailaddress -eq '$email'" -ErrorAction Stop
        if ($null -eq $aduser) {
            Add-Result -Object $_ -Message "Failed to lookup email address in AD."
        }
    } catch {
        Add-Result -Object $_ -Message "Error during AD lookup process."
        continue
    }
    
    # Update employee number in AD
    try {
        Set-ADUser -Identity $aduser -EmployeeNumber $empnum
        Add-Result -Object $_ -Message 'Success'
    } catch {
        Add-Result -Object $_ -Message 'Failed to set EmployeeNumber property in AD.'
    }
}

Write-Verbose 'Writing modified CSV as log..'
$csv | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Output "Output file saved to '$ExportPath'"