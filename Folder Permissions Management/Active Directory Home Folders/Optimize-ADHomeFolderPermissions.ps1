<#
.SYNOPSIS
Process all folders in a directory and assign permissions to an Active Directory user based on the folder's name.

.DESCRIPTION
This script will go through all directories (non-recursively) in a folder and attempt to correct all ACEs based on the folder's name. 
It can optionally set inheritance and change ownership.
If it is unable to lookup a user in Active Directory, it will skip making any changes to the directory.

Any child directory within the ADHomeFolderPath beginning with an '_' will be ignored. This is useful if you have manually configured a folder for management tools or admin files.

.PARAMETER ADHomeFolderPath
The path where all Active Directory Home Directories for accounts are stored. The execution context of this script must have "Full Control" permissions to this path.
Any child directory within the ADHomeFolderPath beginning with an '_' will be ignored. This is useful if you have manually configured a folder for management tools or admin files.

.PARAMETER OwnerName
A translatable NTAccount to assign ownership of all folders to. 
If unspecified, no owner information will be changed. 
If invalid, the script will abort.

.PARAMETER SetStandardInheritance
If enabled, will set the default Access Rule Protection properties to
    isProtected = $false
    preserveInheritance = $true
This effectively enabled inheritance from the parent directory, and cascades it to all children.

.PARAMETER WhatIf
If true, the script will not make any changes and instead run a "mock" execution.

.EXAMPLE
# Process the E:\Staff folder to fix folder permissions and set standard inheritance. This is a typical execution method, as administrative permissions can be set on the E:\Staff folder and inheritance will cascade them.
.\Optimize-ADHomeFolderPermissions.ps1 -ADHomeFolderPath E:\Staff\ -SetStandardInheritance

.EXAMPLE
# Process the E:\Staff folder to fix folder permissions and set the owner. Inheritance will not be changed.
.\Optimize-ADHomeFolderPermissions.ps1 -ADHomeFolderPath E:\Staff\ -OwnerName "domain.local\FileAdmin01"

.EXAMPLE
# Mock process the E:\Staff folder to fix folder permissions, set the owner, and toggle inheritance. This will not make any actual changes.
.\Optimize-ADHomeFolderPermissions.ps1 -ADHomeFolderPath E:\Staff\ -OwnerName "domain.local\FileAdmin01" -SetStandardInheritance -WhatIf
#>

param (
    [Parameter(Mandatory, Position = 0)]
    [string] $ADHomeFolderPath,

    [Parameter(Position = 1)]
    [string] $OwnerName,

    [Parameter(Position = 2)]
    [switch] $SetStandardInheritance,

    [Parameter(Position = 99)]
    [switch] $WhatIf
)


$ownerObject = $null
$ErrorActionPreference = "Stop"

# Test ACL capabilities
if (-not ([string]::IsNullOrWhiteSpace($OwnerName))) {
    "OwnerName is defined. Will attempt to set new folder owners."
    
    try {
        $ownerObject = New-Object System.Security.Principal.Ntaccount($OwnerName)

        # This is safe because we never save the ACL back! It simply tests whether the executing account has the ability to set an ACL.
        $tempAcl = Get-Acl 'C:\Windows\System32\cmd.exe'
        $tempAcl.SetOwner($ownerObject)

        "Succeeded testing ACL capabilities. Will attempt to change owners!"
    } catch {
        Write-Warning "Failed to test setting owner permissions. Aborting!"
        continue
    }
}


Get-ChildItem $ADHomeFolderPath -Directory -Exclude "_*" | ForEach-Object {
    $hf = $_
    $folderPath = $hf.FullName
    $acl = Get-Acl $folderPath

    # Set Owner
    if ($null -ne $ownerObject) {
        if ($WhatIf) {
            "WHATIF: Setting owner to $OwnerName for $folderPath"
        } else {
            $acl.SetOwner($ownerObject)
        }
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


    # Set new perms
    <#
        ╔═════════════╦═════════════╦═══════════════════════════════╦════════════════════════╦══════════════════╦═══════════════════════╦═════════════╦═════════════╗
        ║             ║ folder only ║ folder, sub-folders and files ║ folder and sub-folders ║ folder and files ║ sub-folders and files ║ sub-folders ║    files    ║
        ╠═════════════╬═════════════╬═══════════════════════════════╬════════════════════════╬══════════════════╬═══════════════════════╬═════════════╬═════════════╣
        ║ Propagation ║ none        ║ none                          ║ none                   ║ none             ║ InheritOnly           ║ InheritOnly ║ InheritOnly ║
        ║ Inheritance ║ none        ║ Container|Object              ║ Container              ║ Object           ║ Container|Object      ║ Container   ║ Object      ║
        ╚═════════════╩═════════════╩═══════════════════════════════╩════════════════════════╩══════════════════╩═══════════════════════╩═════════════╩═════════════╝
    #>
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    $objType = [System.Security.AccessControl.AccessControlType]::Allow 
    $permission = $user, "Modify", $inheritanceFlag, $propagationFlag, $objType
    $aceNew = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($aceNew)


    # Set inheritance
    if ($SetStandardInheritance) {
        $acl.SetAccessRuleProtection($false, $true)
    }
    
    if ($WhatIf) {
        Write-Output "WHATIF: Setting ACL on $folderPath"
    } else {
        Set-Acl $folderPath $acl
        "Fully processed $folderPath"
    }
}