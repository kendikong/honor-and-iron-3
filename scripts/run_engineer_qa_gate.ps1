param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\ENGINEER_QA_GATE.md"

Write-Output "=== Engineer QA gate (class validation - NOT planning QA) ==="
Write-Output "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/ENGINEER_QA_GATE.md)"

$requiredFactoryIds = @(
	"engineer_recall", "engineer_dismantle", "engineer_sludge_bomb",
	"engineer_construct_turret", "engineer_frag_bomb", "engineer_magnetic_mine",
	"engineer_tesla_barricade", "engineer_flak_cannon", "engineer_wrench_smack",
	"engineer_emp_grenade", "engineer_rocket_launcher", "engineer_scrap_shield",
	"engineer_manual_detonation", "engineer_overdrive_injection", "engineer_barbed_wire",
	"blueprint_tread", "turret_syndrome", "automation", "master_builder",
	"reinforced_constructs", "shield_generator", "blast_shielding",
	"explosive_expert", "chain_reaction", "shrapnel", "expanded_blast",
	"scrap_mechanic", "recycling_protocol", "overclock",
	"overclocked_maintenance", "field_technician"
)

if (-not (Test-Path $matrixDoc)) {
	Write-Error "[FAIL] Missing matrix doc: $matrixDoc"
	exit 3
}

$matrixText = Get-Content -Path $matrixDoc -Raw
$missingRows = @()
$harnessRows = @()
foreach ($id in $requiredFactoryIds) {
	$escaped = [regex]::Escape($id)
	$row = ($matrixText -split "`n" | Where-Object {
		$_ -match ('`\s*' + $escaped + '\s*`') -and $_ -match '\|'
	} | Select-Object -First 1)
	if ($null -eq $row) {
		$missingRows += $id
	} elseif ($row -match 'HARNESS_ONLY') {
		$harnessRows += $id
	}
}
if ($missingRows.Count -gt 0) {
	Write-Output "[FAIL] Missing matrix rows: $($missingRows -join ', ')"
	exit 3
}
Write-Output ("Matrix: PASS 0/{0}; HARNESS_ONLY {1}; PLANNED 0" -f $requiredFactoryIds.Count, $harnessRows.Count)

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Godot executable not found: $GodotPath"
	exit 2
}

$args = @("--headless", "--path", $projectRoot, "res://tests/EngineerQaGate.tscn")
& $GodotPath @args
if ($LASTEXITCODE -ne 0) {
	Write-Output "[FAIL] Engineer Tier 1 harness exit code $LASTEXITCODE"
	exit $LASTEXITCODE
}
Write-Output "--- Tier 1 harness: PASS ---"
Write-Output "[INCOMPLETE] Engineer matrix is HARNESS_ONLY until Tier 2 live and meta-critic promotion."
exit 2
