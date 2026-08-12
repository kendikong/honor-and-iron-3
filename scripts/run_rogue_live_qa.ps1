param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Rogue live QA: Godot executable not found: $GodotPath"
	exit 2
}

$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
$suite = "res://tests/live_rogue_class_test.gd"
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-rogue-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-rogue-live.stderr.log"
$args = @("--path", $projectRoot, "--headless", "-s", $cmdTool, "-a", $suite, "--ignoreHeadlessMode")
$process = Start-Process -FilePath $GodotPath -ArgumentList $args -WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$exitCode = $process.ExitCode
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }
if ($null -eq $exitCode -or $exitCode -eq "") {
	$summary = Get-Content $stdoutPath -Raw
	$exitCode = 1
	if ($summary -match "Overall Summary:.*0 failures") {
		$exitCode = 0
	}
}
if ($exitCode -ne 0) {
	Write-Output "[FAIL] Rogue live QA exit code $exitCode"
	exit $exitCode
}
Write-Output "[PASS] Rogue live QA: factory loaded in TestBattle"
exit 0
