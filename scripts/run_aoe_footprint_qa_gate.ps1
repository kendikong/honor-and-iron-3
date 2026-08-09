param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

Write-Output "=== AOE footprint QA gate (geometry + scenario/live audits) ==="
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-aoe-footprint.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-aoe-footprint.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/AoeFootprintQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "AOE footprint gate"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] AOE footprint gate stopped by ESC."
	exit 130
}
Get-Content $stdoutPath
Get-Content $stderrPath

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$pass = ($exitCode -eq 0) -and ($testFailures.Count -eq 0) -and ($scriptErrors.Count -eq 0)

if ($pass) {
	Write-Output "--- AOE footprint gate: PASS ---"
	exit 0
}

Write-Output "--- AOE footprint gate: FAIL ---"
if ($testFailures.Count -gt 0) {
	$testFailures | Select-Object -First 20 | ForEach-Object { Write-Output $_ }
}
exit 1
