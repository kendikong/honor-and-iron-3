param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Engineer live QA: Godot executable not found: $GodotPath"
	exit 2
}

$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
$suite = "res://tests/live_engineer_class_test.gd"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")
& $GodotPath @args
if ($LASTEXITCODE -ne 0) {
	Write-Output "[FAIL] Engineer live QA exit code $LASTEXITCODE"
	exit $LASTEXITCODE
}
Write-Output "[PASS] Engineer live QA: factory and shaped overlay acceptance"
exit 0
