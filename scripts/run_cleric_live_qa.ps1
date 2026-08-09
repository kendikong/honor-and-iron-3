param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_cleric_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Cleric live QA: Godot executable not found: $GodotPath"
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-cleric-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-cleric-live.stderr.log"
$godotArgs = @("--path", $projectRoot, "--headless", "-s", "-d",
	$cmdTool, "-a", $suite, "--ignoreHeadlessMode")
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Cleric live QA"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Cleric live QA stopped by ESC."
	exit 130
}
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'FAILED|^\[FAIL\]|SCRIPT ERROR:' |
		ForEach-Object { $_.Line }
)
if ($exitCode -ne 0 -or $failures.Count -gt 0) {
	Write-Output "[FAIL] Cleric live QA"
	exit 1
}
Write-Output "[PASS] Cleric live QA: 15 Bible abilities through preview/commit"
exit 0
