param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_monk_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Monk live QA: Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-monk-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-monk-live.stderr.log"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")
$process = Start-Process -FilePath $GodotPath -ArgumentList $args `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$process.Refresh()
$exitCode = [int]$process.ExitCode
$stdoutText = Get-Content $stdoutPath -Raw
$stderrText = Get-Content $stderrPath -Raw
Get-Content $stdoutPath
Get-Content $stderrPath
if ($stdoutText -match 'FAILED' -or $stderrText -match 'FAILED') {
	Write-Output "[FAIL] Monk live QA reported test failures"
	exit 100
}
if ($exitCode -ne 0) {
	Write-Output "[FAIL] Monk live QA exit $exitCode"
	exit $exitCode
}
Write-Output "[PASS] Monk live QA: every active skill overlay + commit parity"
exit 0
