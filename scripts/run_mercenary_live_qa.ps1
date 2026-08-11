param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_mercenary_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Mercenary live QA: Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mercenary-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mercenary-live.stderr.log"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")
$process = Start-Process -FilePath $GodotPath -ArgumentList $args `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$errors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:|^\[FAIL\]|FAILED')
if ($process.ExitCode -ne 0 -or $errors.Count -gt 0) {
	Write-Output "[FAIL] Mercenary live QA"
	exit 1
}
Write-Output "[PASS] Mercenary live QA: all active skills through preview/commit"
exit 0
