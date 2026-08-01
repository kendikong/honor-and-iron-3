param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_planning_scene_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: Godot executable not found: $GodotPath"
	exit 2
}
if (-not (Test-Path (Join-Path $projectRoot "tests\live_planning_scene_test.gd"))) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: live suite is unavailable."
	exit 2
}

Write-Output "[Tier 3] Single live TestBattle run (GdUnit once; no second log-copy Godot boot)."

# GdUnitCmdTool only accepts -a/-i/etc. --godot_binary is runtest.cmd-only (stripped before invoke).
$godotArgs = @(
	"--path", $projectRoot,
	"-s", "-d",
	"--remote-debug", "tcp://127.0.0.1:0",
	$cmdTool,
	"-a", $suite
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-tier3.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-tier3.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru -NoNewWindow
$exitCode = $process.ExitCode
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
