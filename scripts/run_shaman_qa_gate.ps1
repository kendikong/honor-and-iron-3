param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixPath = Join-Path $projectRoot "docs\SHAMAN_QA_GATE.md"
$required = @(
	"hexing_presence", "echoing_spirits", "spiritual_offering", "spiritual_guardian",
	"miasma_resonance", "voodoo_conduit", "voodoo_doll", "spirit_link", "pain_sharing",
	"sympathetic_magic", "chain_reaction", "soul_collector", "hexing_touch",
	"ritual_sacrifice", "soul_burn", "soul_weaver", "shaman_usher",
	"shaman_curse_of_weakness", "shaman_healing_totem", "shaman_flame_totem",
	"shaman_bloodlust", "shaman_hex", "shaman_voodoo_link", "shaman_terrify",
	"shaman_miasma", "shaman_bone_spear", "shaman_ancestral_spirit",
	"shaman_totem_guard", "shaman_sympathetic_bond", "shaman_earthbind_totem",
	"shaman_soul_siphon", "shaman_pain_spike"
)

$lines = New-Object System.Collections.Generic.List[string]
function Log([string]$line) {
	Write-Output $line
	[void]$lines.Add($line)
}

Log "=== Shaman QA gate ==="
Log "Spec: docs/SHAMAN_QA_GATE.md"
if (-not (Test-Path $matrixPath)) {
	Log "[FAIL] Missing Shaman matrix: $matrixPath"
	exit 1
}

$missingRows = @($required | Where-Object { (Get-Content $matrixPath -Raw) -notmatch [regex]::Escape("``$_``") })
$missingScenarios = @()
foreach ($id in $required) {
	$folder = if ($id -eq "hexing_presence" -or $id -in $required[1..15]) { "passives" } else { "skills" }
	$path = Join-Path $projectRoot "tests\$folder\${id}_scenario.gd"
	if (-not (Test-Path $path)) { $missingScenarios += "$folder/$id" }
}
if ($missingRows.Count -gt 0) { Log "[FAIL] Matrix rows missing: $($missingRows -join ', ')" }
if ($missingScenarios.Count -gt 0) { Log "[FAIL] Scenario files missing: $($missingScenarios -join ', ')" }
if ($missingRows.Count -gt 0 -or $missingScenarios.Count -gt 0) { exit 1 }

if (-not (Test-Path $GodotPath)) {
	Log "[INCOMPLETE] Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-shaman-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-shaman-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath -ArgumentList @(
	"--headless", "--path", $projectRoot, "res://tests/ShamanQaGate.tscn"
) -WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$exitCode = $process.ExitCode
$output = @()
if (Test-Path $stdoutPath) { $output += Get-Content $stdoutPath }
if (Test-Path $stderrPath) { $output += Get-Content $stderrPath }
$output | ForEach-Object { Log ([string]$_) }
$canonical = Join-Path $projectRoot "qa_shaman_gate_canonical.txt"
$latest = Join-Path $projectRoot "qa_shaman_gate_latest.txt"
$lines | Set-Content -Path $canonical -Encoding utf8
$lines | Set-Content -Path $latest -Encoding utf8
$outputText = $output -join "`n"
if ($outputText -notmatch '\[PASS\] Shaman QA gate: factory matrix' -or
	$outputText -match '\[FAIL\] Shaman QA gate:') {
	Log "[FAIL] Shaman QA gate exit code $exitCode"
	exit $exitCode
}
Log "[PASS] Shaman Tier 1 gate"
& (Join-Path $PSScriptRoot "run_shaman_live_qa.ps1") -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Log "[FAIL] Shaman Tier 2 live gate exit code $LASTEXITCODE"
	exit $LASTEXITCODE
}
Log "[PASS] Shaman QA gate: Tier 1 + Tier 2"
exit 0
