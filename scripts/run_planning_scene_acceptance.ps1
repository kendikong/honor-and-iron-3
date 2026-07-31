param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $projectRoot "addons\gdUnit4\runtest.cmd"
$suite = "res://tests/live_planning_scene_test.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: Godot executable not found: $GodotPath"
	exit 2
}
if (-not (Test-Path $runner) -or -not (Test-Path (Join-Path $projectRoot "tests\live_planning_scene_test.gd"))) {
	Write-Output "[INCOMPLETE] Tier 3 TestBattle acceptance: GdUnit4 runner or live suite is unavailable."
	exit 2
}

Push-Location $projectRoot
try {
	& $runner --godot_binary $GodotPath -a $suite
	$exitCode = $LASTEXITCODE
}
finally {
	Pop-Location
}

if ($exitCode -ne 0) {
	Write-Output "[FAIL] Tier 3 TestBattle scene acceptance"
	exit $exitCode
}
Write-Output "[PASS] Tier 3 TestBattle scene acceptance"
