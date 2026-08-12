param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrix = Join-Path $projectRoot "docs\ROGUE_QA_GATE.md"
if (-not (Test-Path $matrix)) {
	Write-Output "[FAIL] Missing docs/ROGUE_QA_GATE.md"
	exit 2
}

$required = @(
	"rogue_slip_past", "rogue_shadow_step", "rogue_kidney_strike", "rogue_smoke_bomb",
	"rogue_evasive_strike", "rogue_grappling_hook", "rogue_switcheroo", "rogue_blindside",
	"rogue_throat_slit", "rogue_amnesia_dust", "rogue_death_mark", "rogue_lethal_flourish",
	"rogue_shadow_swap", "rogue_kidnap", "rogue_shuriken_volley", "rogue_poison_flask",
	"pass", "backstab", "blink_mastery", "lethal_position", "shadow_strike",
	"killing_intent", "shadow_clone", "phase_shift", "blink_strike", "shadow_meld",
	"shadow_slip", "miasma_spreader", "panic_cascade", "debuff_overload", "mind_static",
	"board_scrambler"
)
$text = Get-Content -Raw $matrix
$missing = @($required | Where-Object { $text -notmatch [regex]::Escape($_) })
if ($missing.Count -gt 0) {
	$missing | ForEach-Object { Write-Output "[FAIL] Missing matrix row: $_" }
	exit 3
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[SKIP] Godot not found at $GodotPath - matrix/scenario file check passed."
	exit 0
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/RogueQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
$code = $process.ExitCode
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }
if ($null -eq $code -or $code -eq "") {
	$summary = Get-Content $stdoutPath -Raw
	$code = 1
	if ($summary -match "\[PASS\] Rogue QA gate") {
		$code = 0
	}
}
if ($code -ne 0) {
	Write-Output "[FAIL] Rogue Tier 1 exit code $code"
	exit $code
}
Write-Output "[PASS] Rogue Tier 1 headless gate"
exit 0
