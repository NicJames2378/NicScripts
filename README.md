# NicScripts

Various Scripts for making life easier. Includes files in various formats, but primarily in PowerShell.

Suggestions, recommendations, and pull requests highly appreciated!

  
  
# Tips
Below are some tips when it comes to using these scripts. They aren't requirements, but do make use a lot simpler.

## PowerShell
For ease of use (especially on more complex scripts), I recommend creating a PSD1 file containing your preset parameters, and then splatting those parameters at execution time.

  

For an example using `/CISA Vulnerability Management/Get-CisaReport.ps1`:

1. Mirror or download the repository to a secure local directory

2. Create the file **/CISA Vulnerability Management/params_Get-CisaReport.psd1**

3. Give it contents such as:

```powershell
@{
	ConfigPath = 'C:\\scripts\\CISA\\cisa_config.csv'
	OutputPath = 'C:\\scripts\\CISA\\Outputs'
	UseNumericName = $true
	BulkAssignments = $true
}
```

> [!TIP]
> Make sure you properly escape any required characters! The hashtable will be parsed as a standard PowerShell object.

Then, when calling the script from PowerShell, do it like so:
```powershell
# Read parameters from PSD1 file
$params = Import-PowerShellDataFile .\params_Get-CisaReport.psd1

# Splat them at the script, and add any additionals after.
.\Get-CisaReport.ps1 @params -BulletinUrl "https://www.cisa.gov/news-events/bulletins/sb24-331"
```