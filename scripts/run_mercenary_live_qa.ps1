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

$latestLiveLog = Join-Path $projectRoot "qa_mercenary_live_latest.txt"
$liveLogLines = New-Object System.Collections.Generic.List[string]

function Write-LiveLine([string]$Line) {
	Write-Output $Line
	[void]$liveLogLines.Add($Line)
}

function Save-LiveLog() {
	$liveLogLines | Set-Content -Path $latestLiveLog -Encoding utf8
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mercenary-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mercenary-live.stderr.log"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath -ArgumentList $args `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Mercenary live QA"
if (Test-Path $stdoutPath) { Get-Content $stdoutPath | ForEach-Object { Write-LiveLine $_ } }
if (Test-Path $stderrPath) { Get-Content $stderrPath | ForEach-Object { Write-LiveLine $_ } }

$errors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:|^\[FAIL\]|FAILED')
$passed = Select-String -Path $stdoutPath, $stderrPath -Pattern 'PASSED' -Quiet
if ($exitCode -eq 130 -or $errors.Count -gt 0 -or -not $passed) {
	Write-LiveLine "[FAIL] Mercenary live QA"
	Save-LiveLog
	Write-Output "[FAIL] Mercenary live QA"
	exit 1
}
Write-LiveLine "[PASS] Mercenary live QA: all active skills through preview/commit"
Save-LiveLog
Write-Output "[PASS] Mercenary live QA: all active skills through preview/commit"
exit 0
