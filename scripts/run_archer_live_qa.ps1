param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_archer_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Archer live QA: Godot executable not found: $GodotPath"
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
$godotArgs = @(
	"--path", $projectRoot,
	"--headless",
	"-s", "-d",
	$cmdTool,
	"-a", $suite,
	"--ignoreHeadlessMode"
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-archer-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-archer-live.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru -NoNewWindow
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
if ($process.ExitCode -ne 0) {
	Write-Output "[FAIL] Archer live QA: Godot exit code $($process.ExitCode)"
	exit 1
}
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'FAILED|^\[FAIL\]|SCRIPT ERROR:' |
		ForEach-Object { $_.Line }
)
if ($failures.Count -gt 0) {
	Write-Output "[FAIL] Archer live QA"
	exit 1
}
Write-Output "[PASS] Archer live QA: 15 active skills through preview/commit"
exit 0
