param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath"
}

Write-Output "=== Planning headless contracts (fixture harness - NOT live TestBattle) ==="
Write-Output "Suite: PlanningQaGate.tscn (planning_qa_gate_test, intent contracts, drag E2E, etc.)"
Write-Output "This is the headless mirror of planning rules; Tier 3 LIVE is live_planning_scene_test.gd."

. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-planning-headless.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-planning-headless.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless", "--path", $projectRoot, "res://tests/PlanningQaGate.tscn" `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Planning headless contracts"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Planning headless contracts stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
if (-not (Test-GodotQaHarnessSucceeded -ExitCode $exitCode -LogPaths @($stdoutPath, $stderrPath))) {
	Write-Output "[FAIL] Planning headless contracts (exit $exitCode, $($testFailures.Count) fails)"
	exit 1
}
Write-Output "[PASS] Planning headless contracts"
exit 0
