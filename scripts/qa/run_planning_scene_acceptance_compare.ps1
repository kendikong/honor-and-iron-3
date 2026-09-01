param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

Write-Output "=== Compare: planning live vs headless T3 mimic ==="
Write-Output "LIVE     = run_planning_scene_acceptance.ps1 (GdUnit + TestBattle)"
Write-Output "HEADLESS = run_t3_mimic_headless.ps1 (same bible checklist, fixture board)"
Write-Output ""

$liveScript = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
$headlessScript = Join-Path $PSScriptRoot "run_t3_mimic_headless.ps1"

Write-Output "--- Planning live ---"
& $liveScript -GodotPath $GodotPath
$liveExit = $LASTEXITCODE

Write-Output ""
Write-Output "--- Planning headless T3 mimic ---"
& $headlessScript -GodotPath $GodotPath
$headlessExit = $LASTEXITCODE

function Count-Fails([string]$stdoutPath) {
	if (-not (Test-Path $stdoutPath)) { return 0 }
	return @(
		Select-String -Path $stdoutPath -Pattern '^\[FAIL\]' -ErrorAction SilentlyContinue
	).Count
}

Write-Output ""
Write-Output "=== Summary ==="
Write-Output ("Live:     exit={0} fails={1}" -f $liveExit, (Count-Fails (Join-Path $env:TEMP "honor-and-iron-tier3-live.stdout.log")))
Write-Output ("Headless: exit={0} fails={1}" -f $headlessExit, (Count-Fails (Join-Path $env:TEMP "honor-and-iron-t3-mimic.stdout.log")))

if ($liveExit -ne 0 -or $headlessExit -ne 0) {
	exit 1
}
Write-Output "[PASS] Both suites passed."
exit 0
