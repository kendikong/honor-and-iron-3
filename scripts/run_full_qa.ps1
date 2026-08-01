param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
	$ReportPath = Join-Path $projectRoot "qa_full_report_latest.txt"
}

$log = New-Object System.Collections.Generic.List[string]
function Write-QaLine([string]$Line) {
	Write-Output $Line
	$log.Add($Line) | Out-Null
}

Write-QaLine "Honor and Iron - full QA run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-QaLine "Godot: $GodotPath"
Write-QaLine ""

$planningGate = Join-Path $PSScriptRoot "run_planning_qa_gate.ps1"
$regression = Join-Path $PSScriptRoot "run_regression_tests.ps1"

Write-QaLine "########## PLANNING QA GATE ##########"
try {
	& powershell.exe -NoProfile -File $planningGate -GodotPath $GodotPath 2>&1 | ForEach-Object { Write-QaLine "$_" }
	$planningExit = $LASTEXITCODE
} catch {
	Write-QaLine "Planning gate error: $_"
	$planningExit = 1
}

Write-QaLine ""
Write-QaLine "########## SIM/BRIDGE REGRESSION ##########"
try {
	& powershell.exe -NoProfile -File $regression -GodotPath $GodotPath 2>&1 | ForEach-Object { Write-QaLine "$_" }
	$regressionExit = $LASTEXITCODE
} catch {
	Write-QaLine "Regression error: $_"
	$regressionExit = 1
}

Write-QaLine ""
Write-QaLine "########## FULL QA SUMMARY ##########"
Write-QaLine ("Planning gate exit: {0}" -f $planningExit)
Write-QaLine ("Regression exit:    {0}" -f $regressionExit)

$overallPass = ($planningExit -eq 0) -and ($regressionExit -eq 0)
Write-QaLine ("Overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" }))

$log | Set-Content -Path $ReportPath -Encoding UTF8
Write-QaLine ""
Write-QaLine "Report written: $ReportPath"

if ($planningExit -eq 2) { exit 2 }
if (-not $overallPass) { exit 1 }
exit 0
