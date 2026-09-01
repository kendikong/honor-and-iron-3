param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[switch]$LiveTier3
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "qa_suspend_guard.ps1"); Assert-QaNotSuspended

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

Write-Output ""
Write-Output "=== Planning SSOT structural gates ==="
$ssotGates = Join-Path $PSScriptRoot "run_planning_ssot_gates.ps1"
& $ssotGates
if ($LASTEXITCODE -ne 0) {
	Write-Output "--- Planning SSOT structural gates: FAIL ---"
	exit 1
}
Write-Output "--- Planning SSOT structural gates: PASS ---"
Write-Output ""

Write-Output "=== AOE footprint contract (geometry + scenario/live audits) ==="
$aoeGate = Join-Path $PSScriptRoot "run_aoe_footprint_qa_gate.ps1"
& $aoeGate -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Write-Output "--- AOE footprint contract: FAIL ---"
	exit 1
}
Write-Output "--- AOE footprint contract: PASS ---"
Write-Output ""

$tier3Pass = $false
$tier3Label = ""

if ($LiveTier3) {
	Write-Output "=== Planning: TestBattle live acceptance (GdUnit4) ==="
	$sceneGate = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
	if (-not (Test-Path $sceneGate)) {
		Write-Error "[INCOMPLETE] Tier 3 live runner missing: $sceneGate"
		exit 2
	}
	& $sceneGate -GodotPath $GodotPath
	$sceneExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
	if ($sceneExit -eq 2) {
		$tier3Label = "INCOMPLETE (live)"
		Write-Output "--- Planning live: INCOMPLETE ---"
	} elseif ($sceneExit -eq 130) {
		Write-Output "--- Planning live: CANCELLED (ESC) ---"
		exit 130
	} elseif ($sceneExit -eq 0) {
		$tier3Pass = $true
		$tier3Label = "PASS (live)"
		Write-Output "--- Planning live: PASS ---"
	} else {
		$tier3Label = "FAIL (live, exit $sceneExit)"
		Write-Output "--- Planning live: FAIL (exit $sceneExit) ---"
	}
} else {
	Write-Output "=== Planning: headless fixture parity (T3 mimic - live bible checklist mirror) ==="
	Write-Output "Use -LiveTier3 for GdUnit TestBattle acceptance (F5 parity)."
	$mimicGate = Join-Path $PSScriptRoot "run_t3_mimic_headless.ps1"
	if (-not (Test-Path $mimicGate)) {
		Write-Error "[INCOMPLETE] T3 mimic headless runner missing: $mimicGate"
		exit 2
	}
	& $mimicGate -GodotPath $GodotPath
	if ($LASTEXITCODE -ne 0) {
		$tier3Label = "FAIL (headless)"
		Write-Output "--- Planning headless parity: FAIL ---"
		exit 1
	}
	$tier3Pass = $true
	$tier3Label = "PASS (headless)"
	Write-Output "--- Planning headless parity: PASS ---"
}

Write-Output ""
Write-Output "=== Planning QA gate summary ==="
Write-Output ("Planning behavioral: {0}" -f $tier3Label)

if (-not $tier3Pass) {
	exit 1
}
Write-Output "[PASS] Planning QA gate."
exit 0
