<#
.SYNOPSIS
Generates a CSV of basic AD User Data, useful for importing to other systems.

.DESCRIPTION
Using a simple filtering solution, generate an export of basic AD user information. This script was designed to automate the process of obtaining user data in a certain format for injesting into other systems.
For compatibility, ObjectGUIDs are encoded with a Base64 format compatible with Okta, adapted from RCFED's implementation: https://rcfed.com/Utilities/Base64GUID

Feel free to modify to better suit your needs.

.PARAMETER SearchBase
The Active Directory OU to search within. Searches the entire domain if omitted.

.PARAMETER ExportPath
A directory path for where you want to save your generated spreadsheet.
Defaults to %userprofile%/Downloads.

.PARAMETER IncludeDisabledAccounts
If enabled, will include disabled accounts as well as enabled.

.PARAMETER IncludeInfinitePasswords
If enabled, will include accounts with the PasswordNeverExpires attribute.
Typically, this is disabled to omit service accounts.

.PARAMETER LimitEmailSuffix
If supplied, this value will be used to filter email suffixes.
The applied filter is "*@$LimitEmailSuffix"

.PARAMETER AdvancedFilter
If supplied, this value will be used instead of generating a filter from the QuickFilter parameter set.

.PARAMETER CsvUsername
Name used for the Username column.

.PARAMETER CsvGivenName
Name used for the GivenName column.

.PARAMETER CsvSurame
Name used for the Surname column.

.PARAMETER CsvPager
Name used for the Pager column.

.PARAMETER CsvDepartment
Name used for the Department column.

.PARAMETER CsvEmailAddress
Name used for the EmailAddress column.

.PARAMETER CsvObjectGUID
Name used for the ObjectGUID column.

#>

[CmdletBinding(DefaultParameterSetName = 'QuickFilter')]
param (
    [string] $SearchBase = $null,
    [string] $SearchServer = $null,
    [string] $ExportPath = (Join-Path $env:USERPROFILE Downloads),

    [Parameter(ParameterSetName = 'QuickFilter')]
    [switch] $IncludeDisabledAccounts = $false,
    [Parameter(ParameterSetName = 'QuickFilter')]
    [switch] $IncludeInfinitePasswords = $false,
    [Parameter(ParameterSetName = 'QuickFilter')]
    [string] $LimitEmailSuffix = $null,

    [Parameter(ParameterSetName = 'AdvancedFilter')]
    [string] $AdvancedFilter = $null,

    [string] $CsvUsername       = "Username",
    [string] $CsvGivenName      = "FirstName",
    [string] $CsvSurame         = "LastName",
    [string] $CsvPager          = "Pager",
    [string] $CsvDepartment     = "Department",
    [string] $CsvEmailAddress   = "EmailAddress",
    [string] $CsvObjectGUID     = "ObjectGUID"
)

function GUIDBase64Encode {
    # Adapted from common.min.js on https://rcfed.com/Utilities/Base64GUID
    param (
        [string]$GUID,
        [switch]$LittleEndian
    )

    $hexlist = "0123456789abcdef"
    $b64list = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    $s = ""
    $r = ""

    try {
        $s = $GUID -replace '[^0-9a-f]', '' -replace '([a-f0-9]{8})([a-f0-9]{4})([a-f0-9]{4})([a-f0-9]{4})([a-f0-9]{12})', '$1$2$3$4$5'
        $s = $s.ToLower()

        if ($s.Length -ne 32) { return "error01" }

        if ($LittleEndian) {
            $s = $s.Substring(6, 2) + $s.Substring(4, 2) + $s.Substring(2, 2) + $s.Substring(0, 2) + `
                 $s.Substring(10, 2) + $s.Substring(8, 2) + $s.Substring(14, 2) + $s.Substring(12, 2) + `
                 $s.Substring(16)
        }

        $s += "0"
        $i = 0

        while ($i -lt 33) {
            $a = [int]($hexlist.IndexOf($s[$i++]) -shl 8) -bor [int]($hexlist.IndexOf($s[$i++]) -shl 4) -bor [int]($hexlist.IndexOf($s[$i++]))
            $p = [math]::Floor($a / 64)
            $q = $a -band 63
            $r += $b64list[$p] + $b64list[$q]
        }

        return $r + "=="
    } catch {
        return "error02"
    }
}

$filter = $null

if ($PSCmdlet.ParameterSetName -eq 'QuickFilter') {
    $filters = @()
    if (-not $IncludeDisabledAccounts) { $filters += {(Enabled -eq $true)} }
    if (-not $IncludeInfinitePasswords) { $filters += {(PasswordNeverExpires -eq $false)} }
    if (-not [string]::IsNullOrWhiteSpace($LimitEmailSuffix)) { $filters += "(EmailAddress -like '*@$LimitEmailSuffix')" }
    $filter = $filters -join " -and "
} elseif ($PSCmdlet.ParameterSetName -eq 'AdvancedFilter') {
    $filter = $AdvancedFilter
}
"Using filter: $filter"

if ([string]::IsNullOrWhiteSpace($SearchBase)) {
    "SearchBase not supplied..."
    if ([string]::IsNullOrWhiteSpace($SearchServer)) {
        "SearchServer not supplied. Attempting to find default..."
        $users = Get-ADUser -Filter $filter -Properties PasswordNeverExpires, Manager, GivenName, Surname, EmailAddress, Department, pager
    } else {
        $users = Get-ADUser -Server $SearchServer -Filter $filter -Properties PasswordNeverExpires, Manager, GivenName, Surname, EmailAddress, Department, pager
    }
} else {
    "SearchBase: $SearchBase"
    if ([string]::IsNullOrWhiteSpace($SearchServer)) {
        "SearchServer not supplied. Attempting to find default..."
        $users = Get-ADUser -SearchBase $SearchBase -Filter $filter -Properties PasswordNeverExpires, Manager, GivenName, Surname, EmailAddress, Department, pager
    } else {
        $users = Get-ADUser -SearchBase $SearchBase -Server $SearchServer -Filter $filter -Properties PasswordNeverExpires, Manager, GivenName, Surname, EmailAddress, Department, pager
    }    
}

$users | 
    Where-Object { $_.Manager -ne $null } | 
    Sort-Object userprincipalname | 
    Select-Object -Property @{n=$CsvUsername; e={$_.EmailAddress.Split('@')[0]}},
                            @{n=$CsvGivenName; e='GivenName'},
                            @{n=$CsvSurame; e='Surname'},
                            @{n=$CsvPager; e={$_.pager.ToUpper()}},
                            @{n=$CsvDepartment; e='Department'},
                            @{n=$CsvEmailAddress; e={$_.EmailAddress.ToLower()}},
                            @{n=$CsvObjectGUID;  e={GUIDBase64Encode -GUID $_.ObjectGUID -LittleEndian}} |
    Export-Csv -Path (Join-Path $ExportPath "AdUserDataExport.csv")