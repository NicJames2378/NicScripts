param (
    [Parameter(ParameterSetName = "Audit", Position = 0)]
    [string] $ADHomeFolderPath,

    [Parameter(ParameterSetName = "Audit", Position = 1)]
    [int] $UnusedInDays = -1,

    [Parameter(ParameterSetName = "Audit", Position = 2)]
    [int] $AccountDisabledForDays = -1
)

$allHomeDirectories = [System.Collections.Generic.List[PSCustomObject]]::new()

Get-ADUser -Properties HomeDirectory -Filter * | Where-Object { $null -ne $_.HomeDirectory } | Select-Object SamAccountName,UserPrincipalName,HomeDirectory,Enabled | 
ForEach-Object {
	$folder = $_.HomeDirectory.Split($_.HomeDirectory[0])[-1]
	$name = $_.SamAccountName
	if ($folder -ne $name) {
		"Home Mismatch: $($_.UserPrincipalName): $folder"
	}
    
    $allHomeDirectories.Add([PSCustomObject]@{
        Path = $_.HomeDirectory
        AssociatedAccountEnabled = $_.Enabled
    })
}


"Home directory reachability report. Note that this could be invalid if the account scanning does not have permissions."
"Scanning as user [$($env:USERDOMAIN)\$($env:USERNAME)]"

for ($i = 0; $i -lt $allHomeDirectories.Count; $i++) {
    # Report connectivity (imperfect!)
    $reachable = Test-Path $allHomeDirectories[$i].Path
    $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name Reachable -Value $reachable

    # If able to connect, check stats on the folder
    if ($reachable) {
        $daysSinceLastAccess = [System.Math]::Round(((Get-Date) - ((Get-Item -LiteralPath $allHomeDirectories[$i].Path).LastAccessTime)).TotalDays, 2)
        $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name DaysSinceLastAccessed -Value $daysSinceLastAccess
    } else {
        $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name DaysSinceLastAccessed -Value '-'
    }

    # Check if the path seems to be a standard path
    $counts = $allHomeDirectories | ForEach-Object { $_.Path.Substring(0, $_.Path.LastIndexOf($_.Path[0])).ToLower() -replace '/', '\' } | Group-Object
    $pathIsMajority = $counts[0].Count -gt ($allHomeDirectories.Count * 0.7)

    $allHomeDirectories[$i] | Add-Member -MemberType NoteProperty -Name IsCommonPath -Value $pathIsMajority
}

$allHomeDirectories | Format-Table -AutoSize