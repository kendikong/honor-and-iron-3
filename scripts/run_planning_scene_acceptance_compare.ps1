param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

Write-Output "=== Compare: Tier 3 LIVE vs planning headless contracts ==="
Write-Output "LIVE  = run_planning_scene_acceptance.ps1 (GdUnit + TestBattle, hidden window)"
Write-Output "HEADLESS = run_planning_headless_contracts.ps1 (PlanningQaGate.tscn fixtures)"
Write-Output ""

$liveScript = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
$headlessScript = Join-Path $PSScriptRoot "run_planning_headless_contracts.ps1"

Write-Output "--- Tier 3 LIVE ---"
& $liveScript -GodotPath $GodotPath
$liveExit = $LASTEXITCODE

Write-Output ""
Write-Output "--- Planning headless contracts ---"
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
Write-Output ("Tier 3 LIVE: exit={0} fails={1}" -f $liveExit, (Count-Fails (Join-Path $env:TEMP "honor-and-iron-tier3-live.stdout.log")))
Write-Output ("Headless contracts: exit={0} fails={1}" -f $headlessExit, (Count-Fails (Join-Path $env:TEMP "honor-and-iron-planning-headless.stdout.log")))

if ($liveExit -ne 0 -or $headlessExit -ne 0) {
	exit 1
}
Write-Output "[PASS] Both suites passed."
exit 0
