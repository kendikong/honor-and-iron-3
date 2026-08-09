param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_planning_scene_test.gd"
$swapOnly = "live_planning_scene_test.gd:test_live_swap_session"
$bibleTest = "live_planning_scene_test.gd:test_live_planning_bible_multi_knight_session"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Swap planning acceptance: Godot executable not found: $GodotPath"
	exit 2
}
if (-not (Test-Path (Join-Path $projectRoot "tests\live_planning_scene_test.gd"))) {
	Write-Output "[INCOMPLETE] Swap planning acceptance: live suite is unavailable."
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
Write-Output "[Swap Tier 3] LIVE_QA_PROFILE=fast - running test_live_swap_session only (bible test ignored)."
Write-Output "[Swap Tier 3] Do not run run_planning_qa_gate.ps1 while iterating swap fixes. Use this script until PASS."

$godotArgs = @(
	"--path", $projectRoot,
	"-s", "-d",
	"--remote-debug", "tcp://127.0.0.1:0",
	$cmdTool,
	"-a", $suite,
	"-i", $bibleTest,
	"-c"
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-swap-tier3.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-swap-tier3.stderr.log"
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Swap planning acceptance"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Swap planning acceptance stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

if ($null -eq $exitCode) {
	Write-Output "[INCOMPLETE] Swap planning acceptance: Godot exit code unavailable."
	exit 2
}
if ($exitCode -ne 0) {
	Write-Output "[FAIL] Swap planning acceptance - test_live_swap_session (exit $exitCode)"
	exit $exitCode
}
Write-Output "[PASS] Swap planning acceptance - test_live_swap_session"
exit 0
