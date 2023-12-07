param (
    [Parameter(Mandatory, Position = 0)]
    [string] $ADHomeFolderPath,

    [Parameter(Position = 1)]
    [string] $OwnerName
)


$ownerObject = $null
$ErrorActionPreference = "Stop"
pause

# Test ACL capabilities
if (-not ([string]::IsNullOrWhiteSpace($OwnerName))) {
    "OwnerName is defined. Will attempt to set new folder owners."
    
    try {
        $ownerObject = New-Object System.Security.Principal.Ntaccount($OwnerName)

        # This is safe because we never save the ACL back!
        $tempAcl = Get-Acl 'C:\Windows\System32\cmd.exe'
        $tempAcl.SetOwner($ownerObject)

        "Succeeded testing ACL capabilities. Will attempt to change owners!"
    } catch {
        Write-Warning "Failed to test setting owner permissions. Aborting!"
        continue
    }
}


Get-ChildItem $ADHomeFolderPath -Directory | ForEach-Object {
    $hf = $_
    $folderPath = $hf.FullName
    $acl = Get-Acl $folderPath

    # Set Owner
    if ($null -ne $ownerObject) {
        $acl.SetOwner($ownerObject)
    }


    # Lookup username in AD
    try {
        $adUser = Get-ADUser -Identity $hf.Name
        $user = $adUser.UserPrincipalName
    } catch {
        Write-Warning "BAD_USER [$($hf.Name)] - Skipping path [$($hf.FullName)]"
        return
    }


    # Remove all ACEs
    $acesRemove = $acl.Access | Where-Object { $_.IsInherited -eq $false }
    foreach ($ace in $acesRemove) {
        $acl.RemoveAccessRuleAll($ace)
    }
    Set-Acl -AclObject $acl $folderPath


    # Set new perms
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlag = [System.Security.AccessControl.PropagationFlags]::InheritOnly
    $objType = [System.Security.AccessControl.AccessControlType]::Allow 
    $permission = $user, "Modify", $inheritanceFlag, $propagationFlag, $objType
    $aceNew = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($aceNew)
    Set-Acl $folderPath $acl


    "Fully processed $folderPath"
}