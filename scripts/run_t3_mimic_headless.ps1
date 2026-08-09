param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath"
}

Write-Output "=== Fixture Parity Suite (headless — NOT Tier 3 LIVE) ==="

. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-t3-mimic.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-t3-mimic.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless", "--path", $projectRoot, "res://tests/T3MimicHeadless.tscn" `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "T3 mimic headless"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] T3 mimic headless stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
if ($exitCode -ne 0 -or $testFailures.Count -gt 0 -or $scriptErrors.Count -gt 0) {
	Write-Output "[FAIL] Fixture Parity Suite (exit $exitCode, $($testFailures.Count) fails)"
	exit 1
}
	Write-Output "[PASS] Fixture Parity Suite"
exit 0
