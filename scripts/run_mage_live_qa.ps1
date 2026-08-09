param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_mage_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Mage live QA: Godot executable not found: $GodotPath"
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mage-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mage-live.stderr.log"
$godotArgs = @("--path", $projectRoot, "--headless", "-s", "-d",
	$cmdTool, "-a", $suite, "--ignoreHeadlessMode")
$process = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -Wait -PassThru -NoNewWindow
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'FAILED|^\[FAIL\]|SCRIPT ERROR:' |
		ForEach-Object { $_.Line }
)
if ($process.ExitCode -ne 0 -or $failures.Count -gt 0) {
	Write-Output "[FAIL] Mage live QA"
	exit 1
}
Write-Output "[PASS] Mage live QA: all 16 base and [+] abilities through preview/commit"
exit 0
