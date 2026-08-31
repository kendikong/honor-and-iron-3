Set-StrictMode -Version Latest

function Get-QaSuspendFlagPath {
	param(
		[string]$ProjectRoot = ""
	)
	if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
		$guardDir = $PSScriptRoot
		if ([string]::IsNullOrWhiteSpace($guardDir)) {
			$guardDir = Split-Path -Parent $MyInvocation.MyCommand.Path
		}
		$ProjectRoot = Split-Path -Parent (Split-Path -Parent $guardDir)
	}
	return Join-Path $ProjectRoot "docs\qa\QA_SUSPENDED.flag"
}


function Test-QaSuspended {
	param(
		[string]$ProjectRoot = ""
	)
	return Test-Path -LiteralPath (Get-QaSuspendFlagPath -ProjectRoot $ProjectRoot)
}


function Assert-QaNotSuspended {
	param(
		[string]$ProjectRoot = "",
		[switch]$Force
	)
	if ($Force) {
		return
	}
	$flagPath = Get-QaSuspendFlagPath -ProjectRoot $ProjectRoot
	if (-not (Test-Path -LiteralPath $flagPath)) {
		return
	}
	$detail = ""
	try {
		$detail = (Get-Content -LiteralPath $flagPath -Raw).Trim()
	} catch {
		$detail = "(could not read flag file)"
	}
	Write-Output "[QA SUSPENDED] Automated QA is disabled until planning SSOT architecture is 100% compliant."
	Write-Output "[QA SUSPENDED] Sentinel: docs/qa/QA_SUSPENDED.flag"
	if ($detail -ne "") {
		Write-Output "[QA SUSPENDED] $detail"
	}
	Write-Output "[QA SUSPENDED] Re-enable: owner deletes the flag and says QA is re-enabled in chat."
	throw [System.InvalidOperationException]::new(
		"QA SUSPENDED: automated QA is disabled by docs/qa/QA_SUSPENDED.flag."
	)
}


# Load-only when dot-sourced; callers must invoke Assert-QaNotSuspended explicitly.
