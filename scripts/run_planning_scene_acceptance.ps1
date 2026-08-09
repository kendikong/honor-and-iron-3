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
Write-Output "[Tier 3 LIVE] LIVE_QA_PROFILE=fast (swap test excluded; use run_swap_planning_acceptance.ps1 explicitly)."
Write-Output "[Tier 3 LIVE] GdUnit + TestBattle scene, hidden window (NoNewWindow, not Godot --headless)."

# GdUnitCmdTool only accepts -a/-i/etc. --godot_binary is runtest.cmd-only (stripped before invoke).
$godotArgs = @(
	"--path", $projectRoot,
	"-s", "-d",
	$cmdTool,
	"-a", $suite,
	"-i", $swapTest
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-tier3-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-tier3-live.stderr.log"
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Tier 3 live TestBattle acceptance"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Tier 3 live TestBattle acceptance stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

if (Test-GdUnitCmdSucceeded -ExitCode $exitCode -LogPaths @($stdoutPath, $stderrPath)) {
	Write-Output "[PASS] Tier 3 TestBattle scene acceptance"
	exit 0
}
if ($null -eq $exitCode -or $exitCode -eq '') {
	Write-Output "[FAIL] Tier 3 TestBattle scene acceptance (GdUnit failures or incomplete; exit code unavailable)"
} else {
	Write-Output "[FAIL] Tier 3 TestBattle scene acceptance (exit $exitCode)"
}
exit 1
