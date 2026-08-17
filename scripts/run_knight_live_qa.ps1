param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Knight live QA: Godot executable not found: $GodotPath"
	exit 2
}

$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
$suite = "res://tests/live_knight_class_test.gd"
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-knight-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-knight-live.stderr.log"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")

$process = Start-Process -FilePath $GodotPath -ArgumentList $args `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }
if ($process.ExitCode -ne 0) {
	Write-Output "[FAIL] Knight live QA exit $($process.ExitCode)"
	exit 1
}
Write-Output "[PASS] Knight live QA: all active rows loaded; Defensive Formation [+] overlay/commit/sim parity; Seismic Stomp overlay parity"
exit 0
