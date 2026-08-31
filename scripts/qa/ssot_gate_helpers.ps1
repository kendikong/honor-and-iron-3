. (Join-Path $PSScriptRoot "qa_suspend_guard.ps1"); Assert-QaNotSuspended
Set-StrictMode -Version Latest

function New-SsotViolation {
	param(
		[Parameter(Mandatory = $true)][string]$Contract,
		[Parameter(Mandatory = $true)][string]$Kind,
		[Parameter(Mandatory = $true)][string]$Rule,
		[Parameter(Mandatory = $true)][string]$File,
		[Parameter(Mandatory = $true)][int]$Line,
		[Parameter(Mandatory = $true)][string]$Owner,
		[Parameter(Mandatory = $true)][string]$CompetingPath,
		[Parameter(Mandatory = $true)][string]$Correction
	)
	$fields = [ordered]@{
		kind = $Kind
		contract = $Contract
		file = $File
		line = $Line
		rule = $Rule
		owner = $Owner
		competing_path = $CompetingPath
		correction = $Correction
	}
	$encoded = $fields.GetEnumerator() | ForEach-Object {
		$value = ([string]$_.Value) -replace '\\', '\\' -replace '"', '\"'
		'{0}="{1}"' -f $_.Key, $value
	}
	return "[SSOT VIOLATION] " + ($encoded -join " ")
}

function Add-SsotViolation {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[System.Collections.Generic.List[string]]$Failures,
		[Parameter(Mandatory = $true)][string]$Contract,
		[Parameter(Mandatory = $true)][string]$Kind,
		[Parameter(Mandatory = $true)][string]$Rule,
		[Parameter(Mandatory = $true)][string]$File,
		[Parameter(Mandatory = $true)][int]$Line,
		[Parameter(Mandatory = $true)][string]$Owner,
		[Parameter(Mandatory = $true)][string]$CompetingPath,
		[Parameter(Mandatory = $true)][string]$Correction
	)
	$Failures.Add((New-SsotViolation `
		-Contract $Contract `
		-Kind $Kind `
		-Rule $Rule `
		-File $File `
		-Line $Line `
		-Owner $Owner `
		-CompetingPath $CompetingPath `
		-Correction $Correction))
}

function Get-SsotRelativePath {
	param(
		[Parameter(Mandatory = $true)][string]$ProjectRoot,
		[Parameter(Mandatory = $true)][string]$Path
	)
	return $Path.Substring($ProjectRoot.Length + 1) -replace '\\', '/'
}

function Write-SsotGateResult {
	param(
		[Parameter(Mandatory = $true)][string]$GateName,
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[System.Collections.Generic.List[string]]$Failures
	)
	if ($Failures.Count -gt 0) {
		Write-Output "--- ${GateName}: FAIL ($($Failures.Count)) ---"
		foreach ($failure in $Failures) {
			Write-Output $failure
			if ($failure -notmatch '^\[SSOT VIOLATION\]') {
				Write-Output (New-SsotViolation `
					-Contract ($GateName -replace '\s+', '_').ToLowerInvariant() `
					-Kind "structural" `
					-Rule "legacy_structural_failure" `
					-File "gate:$GateName" `
					-Line 0 `
					-Owner $GateName `
					-CompetingPath $failure `
					-Correction "Repair the canonical owner path; do not suppress or skip this failure.")
			}
		}
		return
	}
	Write-Output "--- ${GateName}: PASS ---"
}
