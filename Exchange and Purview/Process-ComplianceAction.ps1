#Requires -PSEdition Desktop

<#
.SYNOPSIS
Simplifies the process of creating compliance searching and removing unwanted emails.

	# Skips opening the page to create a Content Search
    [switch] $SkipConfigurator,
	# Skips waiting for completion and sending an email
    [switch] $SkipCompletionEmail,
	# Waits before running the deletion. This is in case you want to export or see the results.
	[switch] $PauseBeforeDeletion,
	# Where to send the completion email to.
    [string] $EmailToOnCompletion

.DESCRIPTION
A script to simplify the process of creating a Content Search, purging all findings on completion, and notifying an email adress afterwards. In order to receive an email notification, the executing terminal is required to stay open.

.PARAMETER SkipConfigurator
If true, will skip opening the web page for configuring a Content Search.

.PARAMETER SkipCompletionEmail
If true, will skip sending an email to the specified EmailToOnCompletion address. Only checked if the EmailToOnCompletion address isn't blank.

.PARAMETER PauseBeforeDeletion
If true, pauses execution before deleting all found emails. Intended for users to check the discovered emails before processing them.

.PARAMETER EmailToOnCompletion
An email address to notify when the discovered emails are deleted.

.EXAMPLE
# Opens the configurator page, waits for a search to finish, deletes all findings, then emails user@example.com upon completion.
.\Process-ComplianceAction.ps1 -EmailToOnCompletion user@example.com

.EXAMPLE
# Skips opening the configurator page, waits for a search to finish, pauses for confirmation before deleting findings; does not email a completion message.
.\Process-ComplianceAction.ps1 -SkipConfigurator -PauseBeforeDeletion
#>

param (
	# Skips opening the page to create a Content Search
    [switch] $SkipConfigurator,
	# Skips waiting for completion and sending an email
    [switch] $SkipCompletionEmail,
	# Waits before running the deletion. This is in case you want to export or see the results.
	[switch] $PauseBeforeDeletion,
	# Where to send the completion email to.
    [string] $EmailToOnCompletion
)

# SMTP configuration settings
$emailFrom = 'changeme@your_domain.com'
$emailSubject = 'Purview Compliance Action'
$emailBody = "Compliance action for #InsertUserHere# completed." # '#InsertUserHere#' will be substituted with the username of whoever started the compliance search.
$emailServer = 'mail-relay.example.local' # Your mail relay; could be Postfix, IIS SMTP, etc. Non-local relays may require editing the bottom of this script.
$emailPort = 25

# If we're not skipping the completion email, we need both a EmailToOnCompletion and configured SNMP settings
if ( -not $SkipCompletionEmail -and (([String]::IsNullOrWhiteSpace($EmailToOnCompletion) -or $emailFrom -eq 'changeme@your_domain.com')) ) {
    Write-Warning "SNMP configurations have not been completed. Please edit this script to use your proper SNMP settings!"
    exit 9
}

# Install and import the needed commands
$current = Get-InstalledModule ExchangeOnlineManagement -ErrorAction SilentlyContinue
$gallery = Get-Module ExchangeOnlineManagement
if ($null -eq $current -or ($current.Version -ne $gallery.Version) ) {
	Write-Host -ForegroundColor Cyan 'ExchangeOnlineManagement module missing or outdated. Downloading newest version.'
	Write-Host -ForegroundColor Cyan 'Please press "[A]" if prompted.'
	Install-Module ExchangeOnlineManagement -AllowClobber -Confirm:$false -Force -Scope CurrentUser
	Import-Module ExchangeOnlineManagement
} else {
	Write-Host -ForegroundColor Cyan "Up-to-date ExchangeOnlineManagement found."
}


# Close broken sessions to Exchange
Get-PSSession | Where-Object { ($_.ConfigurationName -ieq "Microsoft.Exchange") -and ($_.State -ieq "Broken" -or $_.Availability -ine "Available")  } | Remove-PSSession


# Try to create or reuse a session to exchange
$tryCreateSession = $false
try {
    # We Out-Null here to scrap the output, as we won't be using it right now. Can this be optimized for slower networks?
    Get-ComplianceSearch | Out-Null
    Write-Host -ForegroundColor Cyan "Existing Exchange Powershell session found."
} catch {
    Write-Host -ForegroundColor Cyan "No existing Exchange Powershell session found."
    $tryCreateSession = $true
}

if ($tryCreateSession) {
    "Attempting to create new Exchange Powershell session. Please login to popup. If a popup does not appear, close this Window and retry the script from a desktop version of Powershell."
    try {
        Connect-IPPSSession
		pause
    } catch {
        Write-Warning $Error[0]
        Write-Host -ForegroundColor Red "Failed to create remote session to exchange! Fix above warning and rerun script."
        pause
        exit 99
    }
}


# Need method to start a search? Perhaps just open the webpage.
# (We open a page instead of using Powershell for this as the webpage is easier for most people to configure - and it doesn't require exposing all possible parameters in this script's params.)
if ($SkipConfigurator) {
    "Skipping Content Search configurator."
} else {
    "Opening Microsoft Purview. Please create your compliance search using the online configurator."
    Start-Sleep 2
    Start-Process "https://compliance.microsoft.com/contentsearchv2?viewid=search"
	"Microsoft Purview opened. Proceed once your compliance search is created."
	pause
}


# Check if search is correct.
"Getting last compliance search (this can take a few minutes)... "
$allComplianceSearches = Get-ComplianceSearch | Select-Object Name, RunBy, CreatedTime, Status 
$foundSearch = $allComplianceSearches | Sort-Object CreatedTime | Select-Object -Last 1

$acceptAndContinue = $false
do {
    $foundSearch | Out-Host
    $response = Read-Host -Prompt "Is this the correct compliance search (y/n)?"

    switch($response) 
    { 
        { $_ -in "y", "ye", "yes"} { 
            Write-Host -ForegroundColor Green "Compliance Search Accepted"
            $acceptAndContinue = $true
        }

        { $_ -in "n", "no"} {
            $allComplianceSearches | Out-Host

            $acceptableInput = $false

            do {
                Write-Host -ForegroundColor Red "Compliance Search Denied. Please enter the name of your compliance search."
                $promptInput = Read-host -Prompt ">"

                Write-Host -ForegroundColor Cyan "Input is [$promptInput]"
            
                $sbSearch = '$_.Name -ilike "XXXXX*"'.Replace('XXXXX',$promptInput)
                $queried = $allComplianceSearches | Where-Object ([Scriptblock]::Create($sbSearch))

                if ($null -ne $queried -and $null -eq $queried[1]) {
                    # Only one result found
                    $foundSearch = $queried
                    $acceptableInput = $true
                }
            } while (-not $acceptableInput)
        }

        default { Write-Host -ForegroundColor Red "Invalid Response" } 
    }
} while (-not $acceptAndContinue)


# Await completion of search
$searchName = $foundSearch.Name
$searchStatus = "N/A"

do {
	$searchQuery = Get-ComplianceSearch -Identity $searchName
	$searchStatus = $searchQuery.Status
	"Status of Search [$searchName] is [$searchStatus]."
	
	if ($searchStatus -ine "Completed") {
		"Waiting for 5 minutes..."
		Start-Sleep 300
	}
} while ( $searchStatus -ine "Completed" )


# Wait if desired
if ($PauseBeforeDeletion) {
	"Pause before deletion requested. Continue when ready to delete."
	pause
}


# Create a purge action based on the Content Search
$compSearAction = New-ComplianceSearchAction -SearchName $($foundSearch.Name) -Purge -PurgeType HardDelete -Confirm:$false -Force
"The Compliance Action has been started."

if (-not $SkipCompletionEmail) {
    "Awaiting Completion of Compliance Action. Will email $EmailToOnCompletion when finished."
    "Do not close this window! (Minimizing is ok! It will close when finished)"
	
	
	# Await completion of search
	$compActionID = $compSearAction.Identity
	$actionStatus = "N/A"

	do {
		$actionQuery = Get-ComplianceSearchAction -Identity $compActionID
		$actionStatus = $actionQuery.Status
		"Status of Action [$($compSearAction.Name)] is [$actionStatus]."
		
		if ($actionStatus -ine "Completed") {
			"Waiting for 5 minutes..."
			Start-Sleep 300
		}
	} while ( $actionStatus -ine "Completed" )

    # Once completed...
    Send-MailMessage -From $emailFrom -To $EmailToOnCompletion -Subject $emailSubject -Body $($emailBody.Replace("#InsertUserHere#", $compSearAction.Name)) -SmtpServer $emailServer -port $emailPort
} else {
    "SkipCompletionEmail is toggled. This terminal can now be closed."
}