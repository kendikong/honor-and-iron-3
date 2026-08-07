param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot "qa_lancer_gate_latest.txt"
$required = @(
	"lancer_push", "lancer_piercing_charge", "lancer_sweeping_halberd",
	"lancer_vaulting_leap", "lancer_run_down", "lancer_rallying_cry",
	"lancer_flanking_maneuver", "lancer_brace", "lancer_harpoon_toss",
	"lancer_glorious_charge", "lancer_pole_vault", "lancer_line_breaker",
	"lancer_spear_wall", "lancer_meteor_drop", "kinetic_charge",
	"unstoppable_mass", "canto", "frontline_defense", "flanking_strike",
	"plunging_attack", "crashing_impact", "pole_plant", "spear_drop",
	"springboard", "sweet_spot", "reach_advantage", "disengage",
	"zone_of_control", "leverage"
)
$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$line) {
	Write-Output $line
	[void]$lines.Add($line)
}
function Finish([int]$code) {
	$lines | Set-Content -Path $logPath -Encoding utf8
	exit $code
}

Log "=== Lancer QA gate (class validation - NOT planning QA) ==="
Log "Spec: docs/LANCER_QA_GATE.md"
Log ("Rows: {0}" -f $required.Count)
if (-not (Test-Path $GodotPath)) {
	Log "[SKIP] Godot not found at: $GodotPath"
	Log "[FAIL] Headless scenario suite was not run."
	Finish 1
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-lancer-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-lancer-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/LancerQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru
Get-Content $stdoutPath | ForEach-Object { Log $_ }
Get-Content $stderrPath | ForEach-Object { Log $_ }
$failures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]|SCRIPT ERROR:' -ErrorAction SilentlyContinue)
if ($process.ExitCode -ne 0 -or $failures.Count -gt 0) {
	Log "[FAIL] Lancer Tier 1 scenarios"
	Finish 1
}
Log "[PASS] Lancer QA gate: 29 Bible rows + modular bridge smoke"
Finish 0
