param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_lancer_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Lancer live QA: Godot executable not found: $GodotPath"
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
$godotArgs = @(
	"--path", $projectRoot,
	"-s", "-d",
	"--remote-debug", "tcp://127.0.0.1:0",
	$cmdTool,
	"-a", $suite
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-lancer-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-lancer-live.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru -NoNewWindow

if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$errors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)(SCRIPT ERROR:|ERROR:)' |
		Where-Object {
			$_.Line -notmatch 'resources still in use' -and
			$_.Line -notmatch 'Remote Debugger' -and
			$_.Line -notmatch 'remote port number'
		} |
		ForEach-Object { $_.Line }
)
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' |
		ForEach-Object { $_.Line }
)
if ($process.ExitCode -ne 0 -or $errors.Count -gt 0 -or $failures.Count -gt 0) {
	Write-Output "[FAIL] Lancer live QA"
	exit 1
}
Write-Output "[PASS] Lancer live QA"
exit 0
