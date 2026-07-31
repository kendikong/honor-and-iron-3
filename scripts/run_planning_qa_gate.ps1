param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/PlanningQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait `
	-PassThru
$godotExit = $process.ExitCode
Get-Content $stdoutPath
Get-Content $stderrPath

$testFailures = Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]'
$scriptErrors = Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)SCRIPT ERROR:'
$leakDiagnostics = Select-String -Path $stdoutPath, $stderrPath -Pattern 'WARNING: .*leaked|ERROR: .*resources still in use'
$runtimeErrors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)ERROR:' |
		Where-Object { $_.Line -notmatch 'resources still in use' }
)
if ($godotExit -ne 0 -or $null -ne $testFailures -or $null -ne $scriptErrors -or $runtimeErrors.Count -gt 0) {
	if ($null -ne $testFailures) {
		Write-Error "Planning QA test failures:"
		$testFailures | ForEach-Object { Write-Error $_.Line }
	}
	if ($null -ne $scriptErrors) {
		Write-Error "Planning QA script errors:"
		$scriptErrors | ForEach-Object { Write-Error $_.Line }
	}
	if ($runtimeErrors.Count -gt 0) {
		Write-Error "Planning QA runtime errors:"
		$runtimeErrors | ForEach-Object { Write-Error $_.Line }
	}
	exit 1
}
if ($null -ne $leakDiagnostics) {
	Write-Warning "Planning QA passed assertions; engine reported residual leaks (not gate-blocking):"
	$leakDiagnostics | ForEach-Object { Write-Warning $_.Line }
}

$sceneGate = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
if (-not (Test-Path $sceneGate)) {
	Write-Error "[INCOMPLETE] Tier 3 TestBattle scene acceptance runner is missing."
	exit 2
}
& $sceneGate -GodotPath $GodotPath
$sceneExit = $LASTEXITCODE
if ($sceneExit -eq 2) {
	Write-Error "[INCOMPLETE] Tier 1/2 contracts passed, but Tier 3 TestBattle scene acceptance was unavailable."
	exit 2
}
if ($sceneExit -ne 0) {
	Write-Error "[FAIL] Tier 1/2 contracts passed, but Tier 3 TestBattle scene acceptance failed."
	exit $sceneExit
}
Write-Output "[PASS] Planning QA gate: Tier 1/2 contracts and Tier 3 TestBattle acceptance."
exit 0
