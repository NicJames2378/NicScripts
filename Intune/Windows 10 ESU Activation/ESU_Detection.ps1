# Written by Timothy McLaughlin, 2025

# https://learn.microsoft.com/en-us/windows/whats-new/enable-extended-security-updates#install-and-activate-the-esu-key
$ActivationIDs = @{
    1 = "f520e45e-7413-4a34-a497-d2765967d094"
    2 = "1043add5-23b1-4afb-9a0f-64343c8f3f8d"
    3 = "83d49986-add3-41d7-ba33-87c7bfb5c0fb"
}
$licensed = $false

try {
    $products = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop
} catch {
    $products = Get-WmiObject -Class SoftwareLicensingProduct
}

$esuLicensed = $products |
    Where-Object { $_.ActivationID -and ($ActivationIDs -contains $_.ActivationID) } |
    Where-Object { $_.LicenseStatus -eq 1 }

if ($esuLicensed) {
    $licensed = $true
} else {
    # Fallback: slmgr parsing
    foreach ($id in $ActivationIDs) {
        $outFile = [System.IO.Path]::GetTempFileName()
        cscript.exe //nologo "$env:windir\system32\slmgr.vbs" /dlv $id > $outFile 2>&1
        $text = Get-Content -Path $outFile -Raw
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue

        if ($text -match 'License Status:\s*Licensed') {
            $licensed = $true
            break
        }
    }
}

if ($licensed) {
    Write-Output "Compliant: ESU Licensed (via WMI or slmgr check)."
    exit 0
} else {
    Write-Output "Non-Compliant: ESU not licensed."
    exit 1
}