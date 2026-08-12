param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\BEAST_RIDER_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\beast_rider_meta_critic_manifest.json"

Write-Output "=== Beast Rider QA gate (CLASS_QA_BIBLE) ==="
Write-Output "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/BEAST_RIDER_QA_GATE.md)"

$requiredFactoryIds = @(
	"beast_reposition", "beast_pounce", "beast_feral_drag", "beast_maul",
	"beast_bestial_roar", "beast_raking_claws", "beast_rest_recover",
	"beast_intimidate", "beast_fetch", "beast_savage_bite", "beast_run_down",
	"beast_thrash", "beast_defensive_posture", "beast_airlift",
	"beast_tail_swipe", "beast_meteor_drop",
	"gallop", "isolation_tactics", "terminal_velocity", "snatch_and_grab",
	"safe_landing", "aerial_superiority", "mount_resilience", "beasts_instinct",
	"territorial", "intimidating_presence", "dive_bomber", "pack_hunter",
	"blood_scent", "vantage_striker", "predatory_drive", "furious_charge"
)

if (-not (Test-Path $matrixDoc)) {
	Write-Error "[FAIL] Missing matrix doc: $matrixDoc"
}
if (-not (Test-Path $manifestPath)) {
	Write-Error "[FAIL] Missing meta-critic manifest: $manifestPath"
}

. (Join-Path $PSScriptRoot "qa_gate_matrix_helpers.ps1")
$scenarioMissing = Test-MatrixScenarioFiles `
	-ProjectRoot $projectRoot -MatrixDocPath $matrixDoc `
	-RequiredFactoryIds $requiredFactoryIds
if ($scenarioMissing.Count -gt 0) {
	$scenarioMissing | ForEach-Object { Write-Output "[FAIL] $_" }
	exit 3
}

$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath
if ($manifestErrors.Count -gt 0) {
	$manifestErrors | ForEach-Object { Write-Output "[FAIL] $_" }
	exit 3
}

$matrixText = Get-Content -Path $matrixDoc -Raw
$passRows = @($requiredFactoryIds | Where-Object {
	$matrixText -match ('`\s*' + [regex]::Escape($_) + '\s*`[^\r\n]*\|\s*PASS\s*\|')
})
Write-Output ("PASS: {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
if ($passRows.Count -ne $requiredFactoryIds.Count) {
	Write-Output "[FAIL] Beast Rider matrix is not 100% PASS."
	exit 2
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[SKIP] Godot not found at: $GodotPath - matrix/contract check only."
	exit 0
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-beast-rider-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-beast-rider-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList @("--headless", "--path", $projectRoot, "res://tests/BeastRiderQaGate.tscn") `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
Get-Content $stdoutPath
Get-Content $stderrPath
if ($process.ExitCode -ne 0) {
	Write-Output "[FAIL] Beast Rider Tier 1 harness exit $($process.ExitCode)"
	exit 1
}
Write-Output "[PASS] Beast Rider Tier 1: 32 row scenarios"

$liveScript = Join-Path $PSScriptRoot "run_beast_rider_live_qa.ps1"
& $liveScript -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Write-Output "[FAIL] Beast Rider Tier 2 live gate exit $LASTEXITCODE"
	exit 4
}
Write-Output "[PASS] Beast Rider Tier 2 live preview/factory gate"
exit 0
