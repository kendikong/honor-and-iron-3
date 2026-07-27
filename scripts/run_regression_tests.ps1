param(
	[Parameter(Mandatory = $true)]
	[string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$resultPath = Join-Path $env:APPDATA "Godot\app_userdata\Honor and Iron 3\regression_test_result.txt"

if (Test-Path $resultPath) {
	Remove-Item $resultPath -Force
}

& $GodotPath --headless --path $projectRoot --script res://tests/regression_test.gd

$report = @()
$complete = $false
for ($attempt = 0; $attempt -lt 60; $attempt++) {
	if (Test-Path $resultPath) {
		$report = Get-Content $resultPath
		$failures = $report | Where-Object {
			$_ -like "[[]BRIDGE[]]*" -or $_ -like "[[]SIM[]]*"
		}
		if (($report -contains "PASS") -or $failures.Count -gt 0) {
			$complete = $true
			break
		}
	}
	Start-Sleep -Milliseconds 500
}

if (-not $complete) {
	Write-Error "Regression runner did not finish within 30 seconds."
	exit 1
}

$report | ForEach-Object { Write-Output $_ }

if ($report.Count -eq 1 -and $report[0] -eq "PASS") {
	exit 0
}

exit 1
