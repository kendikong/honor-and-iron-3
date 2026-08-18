param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\ROGUE_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\rogue_meta_critic_manifest.json"

Write-Output "=== Rogue QA gate (class validation - NOT planning QA) ==="
Write-Output "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/ROGUE_QA_GATE.md)"
Write-Output ""

$requiredFactoryIds = @(
	"rogue_slip_past", "rogue_shadow_step", "rogue_kidney_strike", "rogue_smoke_bomb",
	"rogue_evasive_strike", "rogue_grappling_hook", "rogue_switcheroo", "rogue_blindside",
	"rogue_throat_slit", "rogue_amnesia_dust", "rogue_death_mark", "rogue_lethal_flourish",
	"rogue_shadow_swap", "rogue_kidnap", "rogue_shuriken_volley", "rogue_poison_flask",
	"pass", "backstab", "blink_mastery", "lethal_position", "shadow_strike",
	"killing_intent", "shadow_clone", "phase_shift", "blink_strike", "shadow_meld",
	"shadow_slip", "miasma_spreader", "panic_cascade", "debuff_overload", "mind_static",
	"board_scrambler"
)

if (-not (Test-Path $matrixDoc)) {
	Write-Error "[FAIL] Missing matrix doc: $matrixDoc"
}

$matrixText = Get-Content -Path $matrixDoc -Raw
$passRows = @()
$plannedRows = @()
$harnessRows = @()

foreach ($id in $requiredFactoryIds) {
	$escaped = [regex]::Escape($id)
	$tablePattern = '`\s*' + $escaped + '\s*`'
	$rowLine = (
		$matrixText -split "`n" |
		Where-Object {
			$_ -match $tablePattern -and $_ -match '\|' -and $_ -match '\|\s*(PASS|HARNESS_ONLY|PLANNED|N/A)\s*\|'
		} |
		Select-Object -First 1
	)
	if ($null -eq $rowLine -or $rowLine.Trim().Length -eq 0) {
		$plannedRows += $id
		continue
	}
	if ($rowLine -match '\|\s*PASS\s*\|') {
		$passRows += $id
	} elseif ($rowLine -match '\|\s*HARNESS_ONLY\s*\|') {
		$harnessRows += $id
	} else {
		$plannedRows += $id
	}
}

Write-Output "=== Matrix summary (from docs/ROGUE_QA_GATE.md) ==="
Write-Output ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-Output ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-Output ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-Output ""

$manifestApproved = @()
$manifestThreshold = 88
if (Test-Path $manifestPath) {
	$manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
	if ($null -ne $manifest.pass_threshold) {
		$manifestThreshold = [int]$manifest.pass_threshold
	}
	foreach ($row in $manifest.approved_rows) {
		if ($null -ne $row.factory_id) {
			$manifestApproved += [string]$row.factory_id
		}
	}
	Write-Output ("=== Meta-critic manifest ({0} approved, threshold {1}) ===" -f $manifestApproved.Count, $manifestThreshold)
} else {
	Write-Output "[WARN] Missing manifest: docs/rogue_meta_critic_manifest.json"
}

$unapprovedPass = @($passRows | Where-Object { $manifestApproved -notcontains $_ })
$matrixPassValid = $true
if ($unapprovedPass.Count -gt 0) {
	Write-Output "[FAIL] Matrix PASS without manifest approval: $($unapprovedPass -join ', ')"
	$matrixPassValid = $false
} elseif ($passRows.Count -gt $manifestApproved.Count -and $manifestApproved.Count -gt 0) {
	Write-Output "[FAIL] Matrix PASS count exceeds manifest approved count."
	$matrixPassValid = $false
}

Write-Output ""

. (Join-Path $PSScriptRoot "qa_gate_matrix_helpers.ps1")
$scenarioMissing = Test-MatrixScenarioFiles -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc -RequiredFactoryIds $requiredFactoryIds
if ($scenarioMissing.Count -gt 0) {
	Write-Output "[FAIL] PASS matrix rows missing scenario files:"
	$scenarioMissing | ForEach-Object { Write-Output "  $_" }
	exit 3
}
$manifestErrors = @()
if ($manifestApproved.Count -gt 0) {
	$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath
} else {
	Write-Output "[WARN] Manifest has no approved_rows - skipping last_score gate until gauntlet-critic >= $manifestThreshold"
}
if ($manifestErrors.Count -gt 0) {
	Write-Output "[FAIL] Meta-critic manifest gate:"
	$manifestErrors | ForEach-Object { Write-Output "  $_" }
	exit 3
}
$contractErrors = Test-PassRowScenarioContracts -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc
if ($contractErrors.Count -gt 0) {
	Write-Output "[FAIL] PASS scenario contract shallow (CLASS_QA_BIBLE.md ss8.2):"
	$contractErrors | ForEach-Object { Write-Output "  $_" }
	exit 3
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[SKIP] Godot not found at: $GodotPath - matrix/contract check only."
	if (-not $matrixPassValid) { exit 3 }
	if ($passRows.Count -lt $requiredFactoryIds.Count) { exit 2 }
	exit 0
}

Write-Output "=== Typed conversion contracts ==="
$conversionEntrypoints = @(
	"res://tests/run_extra_rules_conversion_contract.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd",
	"res://tests/run_ability_module_bridge_test.gd"
)
foreach ($entrypoint in $conversionEntrypoints) {
	Write-Output "[QA] $entrypoint"
	$conversionStdout = Join-Path $env:TEMP "honor-and-iron-rogue-conversion.stdout.log"
	$conversionStderr = Join-Path $env:TEMP "honor-and-iron-rogue-conversion.stderr.log"
	$conversionProcess = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $projectRoot, "--script", $entrypoint) `
		-WorkingDirectory $projectRoot -RedirectStandardOutput $conversionStdout `
		-RedirectStandardError $conversionStderr -PassThru -Wait -NoNewWindow
	Get-Content $conversionStdout
	Get-Content $conversionStderr
	if ([int]$conversionProcess.ExitCode -ne 0) {
		Write-Output "[FAIL] Typed conversion contract exit $($conversionProcess.ExitCode) ($entrypoint)"
		exit 4
	}
}
Write-Output "--- Typed conversion contracts: PASS ---"
Write-Output ""

Write-Output "=== AOE footprint contract (all classes) ==="
$aoeGate = Join-Path $PSScriptRoot "run_aoe_footprint_qa_gate.ps1"
& $aoeGate -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Write-Output "[FAIL] AOE footprint contract gate exit $LASTEXITCODE"
	exit 5
}
Write-Output "--- AOE footprint contract: PASS ---"
Write-Output ""

Write-Output "=== Tier 1: headless skill scenarios (harness) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/RogueQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
$code = $process.ExitCode
Get-Content $stdoutPath
Get-Content $stderrPath
if ($null -eq $code -or $code -eq "") {
	$summary = Get-Content $stdoutPath -Raw
	$code = 1
	if ($summary -match "\[PASS\] Rogue QA gate") {
		$code = 0
	}
}
$harnessPass = ($code -eq 0)

if ($harnessPass) {
	Write-Output "--- Tier 1 harness: PASS ---"
} else {
	Write-Output "--- Tier 1 harness: FAIL (exit $code) ---"
	exit 1
}

Write-Output ""
Write-Output "=== Tier 2: live Rogue acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_rogue_live_qa.ps1"
if (-not (Test-Path $liveScript)) {
	Write-Output "[FAIL] Missing Tier 2 runner: $liveScript"
	exit 4
}
& $liveScript -GodotPath $GodotPath
$liveExit = $LASTEXITCODE
if ($liveExit -ne 0) {
	Write-Output "[FAIL] Tier 2 live Rogue QA exit $liveExit"
	exit $liveExit
}
Write-Output "--- Tier 2 live: PASS ---"

Write-Output ""
Write-Output "=== Rogue QA gate summary ==="
if (-not $matrixPassValid) {
	Write-Output "[INCOMPLETE] Harness PASS but matrix PASS rows lack meta-critic manifest approval."
	exit 2
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-Output "[PASS] Rogue QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	exit 0
}

Write-Output ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
exit 2
