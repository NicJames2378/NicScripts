# Written by Timothy McLaughlin, 2025

# Replace with your actual ESU MAK keys!
$ESU_Keys = @{
    1 = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"  # Year 1 Key
    2 = "YYYYY-YYYYY-YYYYY-YYYYY-YYYYY"  # Year 2 Key
    3 = "ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ"  # Year 3 Key
}

# https://learn.microsoft.com/en-us/windows/whats-new/enable-extended-security-updates#install-and-activate-the-esu-key
$ActivationIDs = @{
    1 = "f520e45e-7413-4a34-a497-d2765967d094"
    2 = "1043add5-23b1-4afb-9a0f-64343c8f3f8d"
    3 = "83d49986-add3-41d7-ba33-87c7bfb5c0fb"
}

foreach ($year in 1..3) {
    $key = $ESU_Keys[$year]
    $id = $ActivationIDs[$year]

    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Output "No ESU key provided for Year $year. Skipping..."
        continue
    }

    Write-Output "Installing ESU MAK key for Year $year..."
    cscript.exe $env:windir\system32\slmgr.vbs /ipk $key

    Write-Output "Activating ESU MAK key for Year $year..."
    cscript.exe $env:windir\system32\slmgr.vbs /ato $id

    Start-Sleep -Seconds 10
    $outFile = [System.IO.Path]::GetTempFileName()
    cscript.exe //nologo "$env:windir\system32\slmgr.vbs" /dlv $id > $outFile 2>&1
    $activationResult = Get-Content -Path $outFile -Raw
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    if ($activationResult -match 'License Status:\s*Licensed') {
        Write-Output "ESU Year $year activation successful."
    } else {
        Write-Output "ESU Year $year activation failed or not eligible."
    }
}
