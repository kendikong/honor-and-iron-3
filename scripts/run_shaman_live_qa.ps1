param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Shaman live QA: Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-shaman-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-shaman-live.stderr.log"
$args = @(
	"--path", $projectRoot, "--headless", "-s",
	"res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
	"-a", "res://tests/live_shaman_class_test.gd", "--ignoreHeadlessMode"
)
$process = Start-Process -FilePath $GodotPath -ArgumentList $args `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$exitCode = $process.ExitCode
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$stdout = Get-Content $stdoutPath -Raw
$esc = [regex]::Escape([string][char]27)
$normalized = [regex]::Replace($stdout, "${esc}\[[0-9;]*[A-Za-z]", "")
if ($normalized -notmatch 'Overall Summary:\s+.*0 failures') {
	Write-Output "[FAIL] Shaman live QA"
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'FAILED|SCRIPT ERROR:|^\[FAIL\]|Overall Summary:' |
		Select-Object -First 12 | ForEach-Object { Write-Output $_.Line }
	exit 1
}
Write-Output "[PASS] Shaman live QA: all authored skills through preview/commit"
exit 0
