param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\MERCENARY_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\mercenary_meta_critic_manifest.json"

$requiredFactoryIds = @(
	"predatory_momentum", "mercenary_pullback", "mercenary_swift_strike",
	"mercenary_defense_strike", "mercenary_blade_storm", "mercenary_caltrop_toss",
	"mercenary_feint", "mercenary_riposte_strike", "mercenary_sever",
	"mercenary_second_wind", "mercenary_tactical_retreat",
	"mercenary_executioners_blade", "mercenary_precision_strike",
	"mercenary_flank_and_run", "mercenary_hamstring", "mercenary_acrobatic_vault",
	"mercenary_duelists_challenge", "calculated_strike", "weapon_master",
	"dual_wield_momentum", "precision_edge", "duelists_focus",
	"tactical_versatility", "swift_feet", "hit_and_run", "evasive",
	"flanking_maneuver", "dirty_fighting", "executioner", "blood_scent",
	"ruthless", "coup_de_grace"
)

if (-not (Test-Path $matrixDoc)) { Write-Output "[FAIL] Missing matrix doc"; exit 3 }
if (-not (Test-Path $manifestPath)) { Write-Output "[FAIL] Missing meta-critic manifest"; exit 3 }

$matrixText = Get-Content -Path $matrixDoc -Raw
$manifestText = Get-Content -Path $manifestPath -Raw
$missing = @()
foreach ($id in $requiredFactoryIds) {
	if ($matrixText -notmatch [regex]::Escape($id)) {
		$missing += $id
	}
	if ($manifestText -notmatch ([regex]::Escape($id))) {
		$missing += "$id/manifest"
	}
}
if ($missing.Count -gt 0) {
	$missing | ForEach-Object { Write-Output "[FAIL] Missing Mercenary QA row: $_" }
	exit 3
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Godot executable not found: $GodotPath"
	exit 2
}

$qaWindowHelpers = Join-Path $PSScriptRoot "qa_window_placement.ps1"
. $qaWindowHelpers
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mercenary-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mercenary-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/MercenaryQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Mercenary Tier 1 harness"
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$harnessPass = Test-GodotQaHarnessSucceeded `
	-ExitCode $exitCode `
	-LogPaths @($stdoutPath, $stderrPath) `
	-PassPattern '^\[PASS\] Mercenary QA gate:'
if (-not $harnessPass) {
	Write-Output "[FAIL] Mercenary Tier 1 harness"
	exit 1
}
Write-Output "[PASS] Mercenary Tier 1: factory, modular upgrades, Simulator, and per-row scenarios"
exit 0
