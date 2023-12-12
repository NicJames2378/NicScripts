<#
.SYNOPSIS
Process all folders in a directory and create a report for which ones are actively used Active Directory Home Directory folders.

.DESCRIPTION
This script will go through all directories (non-recursively) in a folder and attempt to match them to a user's the Home Directory property in Active Directory.
There are multiple configurable properties to audit by, which can be toggled with parameter switches. Any unset parameters will be skipped when auditing.
The script will attempt to locate any Home Directories which don't match a 'standard' (default 70% used) structure scheme.

Defining multiple Audit parameters will result in multiple conditions being tested in an "OR" comparison. This can be further parsed by piping the output to a Where-Object clause.

Report columns:
    Path.................... [String]  The path as defined in Active Directory
    AssociatedAccount....... [String]  The account associated in Active Directory
    AADisabled.............. [Boolean] Whether the Associated Account has been disabled in Active Directory
    Accessible.............. [Boolean] Whether the path could be accessed. This could be flawed (eg, the account running the script has no permissions to the path)
    DaysSinceLastAccessed... [Int]     How long it has been since the home directory was last accessed
    ExceedsAccessLimit...... [Boolean] Whether the directory exceeds the defined time since last access
    IsCommonPath............ [Boolean] Whether the normalized home directory path matches the majority of other paths. Useful if you've ever change the Home Directory UNC paths and missed a user.

.PARAMETER ADCredentials
If defined, this script will use the supplied credentials to check against Active Directory, rather than those of the logged in user context.
NOTE: These credentials are not used to access the network share!

.PARAMETER UnusedInDays
The report will flag all directories which have not been accessed in this many days. Defaults to 120.

.PARAMETER AccountDisabledForDays
The report will flag all directories associated with accounts which have been disabled for this many days. Defaults to 90.

.EXAMPLE
# Generate a report of all home directories and flag any unused in 30 days.
.\Test-ADHomeFolders.ps1 -UnusedInDays 30

.EXAMPLE
# Generate a report of all home directories and flag any who's account has been disabled for approximately 3 months.
.\Test-ADHomeFolders.ps1 -AccountDisabledForDays 92

.EXAMPLE
# Generate a report of all home directories and flag any unused in 30 days OR who's account has been disabled for approximately 6 months. Additionally, prompt for domain credentials before running.
.\Test-ADHomeFolders.ps1 -ADCredentials $(Get-Credential) -UnusedInDays 30 -AccountDisabledForDays 183
#>

param (
    [Parameter(Position = 0)]
    [PSCredential] $ADCredentials,

    [Parameter(ParameterSetName = "Audit", Position = 11)]
    [int] $UnusedInDays = 120,

    [Parameter(ParameterSetName = "Audit", Position = 12)]
    [int] $AccountDisabledForDays = 90,

    [Parameter(ParameterSetName = "Audit", Position = 21)]
    [switch] $NormalizeSlashes
)

function Format-TrimmedPath {
    param (
        [string] $Path
    )

    if($NormalizeSlashes) {
        return $Path.Substring(0, $Path.LastIndexOf($Path[0])).ToLower().Replace('/','\')
    } else {
        return $Path.Substring(0, $Path.LastIndexOf($Path[0])).ToLower()
    }
}

$allHomeDirectories = [System.Collections.Generic.List[PSCustomObject]]::new()
$standardSchemeRatio = 0.7

$homeDirQuery = $null
if ($null -ne $ADCredentials) {
    $homeDirQuery = Get-ADUser -Properties HomeDirectory -Filter * -Credential $ADCredentials
} else {
    $homeDirQuery = Get-ADUser -Properties HomeDirectory -Filter *
}

$homeDirQuery | Where-Object { $null -ne $_.HomeDirectory } | Select-Object SamAccountName,UserPrincipalName,HomeDirectory,Enabled | ForEach-Object {
	$folder = $_.HomeDirectory.Split($_.HomeDirectory[0])[-1]
	$name = $_.SamAccountName
	if ($folder -ne $name) {
		Write-Verbose "Home Mismatch: $($_.UserPrincipalName): $folder"
	}
    
    # Report connectivity (imperfect!)
    $accessible = $null
    try {
        $accessible = Test-Path $_.HomeDirectory
    } catch [System.Management.Automation.PSNotSupportedException] {
        # Unable to reach the path using the supplied account. 
        $accessible = $false
    }

    $allHomeDirectories.Add([PSCustomObject]@{
        Path = $_.HomeDirectory
        AssociatedAccount = $_.SamAccountName
        AADisabled = !$_.Enabled
        Accessible = $accessible        
    })
}


Write-Verbose "Home directory reachability report. Note that this could be invalid if the account scanning does not have permissions."
if ($null -ne $ADCredentials) {
    Write-Verbose "Scanning as user [$($ADCredentials.UserName)]"
} else {
    Write-Verbose "Scanning as user [$($env:USERDOMAIN)\$($env:USERNAME)]"
}

$counts = $allHomeDirectories | ForEach-Object { Format-TrimmedPath $_.Path } | Group-Object
for ($i = 0; $i -lt $allHomeDirectories.Count; $i++) {
    # If able to connect, check stats on the folder
    if ($allHomeDirectories[$i].Accessible) {
        $lastAccessDate = [DateTime]((Get-Item -LiteralPath $allHomeDirectories[$i].Path).LastAccessTime)
        $daysSinceLastAccess = [System.Math]::Round(( (Get-Date) - $lastAccessDate).TotalDays, 2)
        $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name DaysSinceLastAccessed -Value $daysSinceLastAccess
        $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name ExceedsAccessLimit -Value ($daysSinceLastAccess -ge $UnusedInDays)
    }

    # Check if the path seems to be a standard path
    $pathIsMajority = ($counts | Where-Object { $_.Name -eq (Format-TrimmedPath $allHomeDirectories[$i].Path) }).Count -gt ($allHomeDirectories.Count * $standardSchemeRatio)
    $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name IsCommonPath -Value $pathIsMajority
}

$allHomeDirectories