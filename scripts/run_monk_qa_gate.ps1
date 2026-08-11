param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\MONK_QA_GATE.md"
$required = @(
	"way_of_the_weaver", "monk_leap", "monk_scorching_kick", "monk_thunder_palm",
	"monk_yin_yang_flurry", "monk_chakra_shift", "monk_phase_throw",
	"monk_flying_crane_kick", "monk_spirit_palm", "monk_soul_punch",
	"monk_hundred_fists", "monk_mantra_of_peace", "monk_inner_fire",
	"monk_void_step", "monk_cyclone_sweep", "monk_updraft", "monk_geyser_strike",
	"elemental_attunement", "chakra_burn", "elemental_harmony", "catalyst",
	"elemental_shield", "weavers_resonance", "mind_over_matter", "inner_peace",
	"zen_defense", "perfect_form", "vaulting_strike", "flowing_ki",
	"evasive_acrobat", "momentum_transfer", "light_step"
)

Write-Output "=== Monk QA gate (class validation) ==="
if (-not (Test-Path $matrixDoc)) {
	Write-Output "[FAIL] Missing docs/MONK_QA_GATE.md"
	exit 3
}

$missing = @()
foreach ($id in $required) {
	$scenario = if ($id -eq "way_of_the_weaver" -or $id -in @(
		"elemental_attunement", "chakra_burn", "elemental_harmony", "catalyst",
		"elemental_shield", "weavers_resonance", "mind_over_matter", "inner_peace",
		"zen_defense", "perfect_form", "vaulting_strike", "flowing_ki",
		"evasive_acrobat", "momentum_transfer", "light_step"
	)) {
		$passiveFile = if ($id -eq "momentum_transfer") {
			"monk_momentum_transfer_scenario.gd"
		} else {
			"$id`_scenario.gd"
		}
		Join-Path $projectRoot "tests\passives\$passiveFile"
	} else {
		Join-Path $projectRoot "tests\skills\$id`_scenario.gd"
	}
	if (-not (Test-Path $scenario)) { $missing += $id }
}
if ($missing.Count -gt 0) {
	Write-Output "[FAIL] Missing scenario files: $($missing -join ', ')"
	exit 3
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-monk-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-monk-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/MonkQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$process.Refresh()
$exitCode = [int]$process.ExitCode
Get-Content $stdoutPath
Get-Content $stderrPath
if ($exitCode -ne 0) {
	Write-Output "[FAIL] Monk Tier 1 harness exit $exitCode"
	exit $exitCode
}
Write-Output "[PASS] Monk Tier 1 headless factory/scenario gate"
Write-Output "[INCOMPLETE] Monk matrix remains 0/32 PASS; LOCK is intentionally not claimed."
exit 0
