param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_planning_scene_test.gd"
$swapTest = "live_planning_scene_test.gd:test_live_swap_session"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: Godot executable not found: $GodotPath"
	exit 2
}
if (-not (Test-Path (Join-Path $projectRoot "tests\live_planning_scene_test.gd"))) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: live suite is unavailable."
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
Write-Output "[Tier 3] LIVE_QA_PROFILE=fast (swap test excluded; use run_swap_planning_acceptance.ps1 explicitly)."
Write-Output "[Tier 3] Headless GdUnit (no Godot window)."

# GdUnitCmdTool only accepts -a/-i/etc. --godot_binary is runtest.cmd-only (stripped before invoke).
$godotArgs = @(
	"--path", $projectRoot,
	"--headless",
	"-s", "-d",
	$cmdTool,
	"-a", $suite,
	"-i", $swapTest,
	"--ignoreHeadlessMode"
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-tier3.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-tier3.stderr.log"
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Tier 3 TestBattle acceptance"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Tier 3 TestBattle acceptance stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

if ($null -eq $exitCode) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: Godot exit code unavailable."
	exit 2
}
if ($exitCode -ne 0) {
	Write-Output "[FAIL] Tier 3 TestBattle scene acceptance (exit $exitCode)"
	exit $exitCode
}
Write-Output "[PASS] Tier 3 TestBattle scene acceptance"
exit 0
