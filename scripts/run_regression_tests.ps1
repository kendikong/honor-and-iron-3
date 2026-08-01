param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$resultPath = Join-Path $env:APPDATA "Godot\app_userdata\Honor and Iron 3\regression_test_result.txt"

if (Test-Path $resultPath) {
	Remove-Item $resultPath -Force
}

Write-Output "=== Sim/bridge regression (headless) ==="
& $GodotPath --headless --path $projectRoot --script res://tests/regression_test.gd

$report = @()
$complete = $false
$maxWaitSec = 90
$attempts = $maxWaitSec * 2
for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
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
	Write-Error "Regression runner did not finish within $maxWaitSec seconds."
	exit 1
}

$report | ForEach-Object { Write-Output $_ }

$bridgeFails = @($report | Where-Object { $_ -like "[[]BRIDGE[]]*" })
$simFails = @($report | Where-Object { $_ -like "[[]SIM[]]*" })

Write-Output ""
Write-Output "=== Regression summary ==="
if ($report.Count -eq 1 -and $report[0] -eq "PASS") {
	Write-Output "Regression: PASS"
	exit 0
}
Write-Output ("Regression: FAIL ({0} bridge, {1} sim)" -f $bridgeFails.Count, $simFails.Count)
exit 1
