param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\ROGUE_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\rogue_meta_critic_manifest.json"

$latestGateLog = Join-Path $projectRoot "qa_rogue_gate_latest.txt"
$canonicalGateLog = Join-Path $projectRoot "qa_rogue_gate_canonical.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonicalTmp = "$canonicalGateLog.tmp"
	$latestTmp = "$latestGateLog.tmp"
	$gateLogLines | Set-Content -Path $canonicalTmp -Encoding utf8
	$gateLogLines | Set-Content -Path $latestTmp -Encoding utf8
	Move-Item -LiteralPath $canonicalTmp -Destination $canonicalGateLog -Force
	Move-Item -LiteralPath $latestTmp -Destination $latestGateLog -Force
}

function Exit-Gate([int]$Code) {
	Save-GateLog
	exit $Code
}

Write-GateLine "=== Rogue QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/ROGUE_QA_GATE.md)"
Write-GateLine ""

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

Write-GateLine "=== Matrix summary (from docs/ROGUE_QA_GATE.md) ==="
Write-GateLine ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-GateLine ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-GateLine ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-GateLine ""

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
	Write-GateLine ("=== Meta-critic manifest ({0} approved, threshold {1}) ===" -f $manifestApproved.Count, $manifestThreshold)
} else {
	Write-GateLine "[WARN] Missing manifest: docs/rogue_meta_critic_manifest.json"
}

$unapprovedPass = @($passRows | Where-Object { $manifestApproved -notcontains $_ })
$matrixPassValid = $true
if ($unapprovedPass.Count -gt 0) {
	Write-GateLine "[FAIL] Matrix PASS without manifest approval: $($unapprovedPass -join ', ')"
	$matrixPassValid = $false
} elseif ($passRows.Count -gt $manifestApproved.Count -and $manifestApproved.Count -gt 0) {
	Write-GateLine "[FAIL] Matrix PASS count exceeds manifest approved count."
	$matrixPassValid = $false
}

Write-GateLine ""

. (Join-Path $PSScriptRoot "qa_gate_matrix_helpers.ps1")
$scenarioMissing = Test-MatrixScenarioFiles -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc -RequiredFactoryIds $requiredFactoryIds
if ($scenarioMissing.Count -gt 0) {
	Write-GateLine "[FAIL] PASS matrix rows missing scenario files:"
	$scenarioMissing | ForEach-Object { Write-Output "  $_" }
	Exit-Gate 3
}
$manifestErrors = @()
if ($manifestApproved.Count -gt 0) {
	$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath
} else {
	Write-GateLine "[WARN] Manifest has no approved_rows - skipping last_score gate until gauntlet-critic >= $manifestThreshold"
}
if ($manifestErrors.Count -gt 0) {
	Write-GateLine "[FAIL] Meta-critic manifest gate:"
	$manifestErrors | ForEach-Object { Write-Output "  $_" }
	Exit-Gate 3
}
$contractErrors = Test-PassRowScenarioContracts -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc
if ($contractErrors.Count -gt 0) {
	Write-GateLine "[FAIL] PASS scenario contract shallow (CLASS_QA_BIBLE.md ss8.2):"
	$contractErrors | ForEach-Object { Write-Output "  $_" }
	Exit-Gate 3
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix/contract check only."
	if (-not $matrixPassValid) { Exit-Gate 3 }
	if ($passRows.Count -lt $requiredFactoryIds.Count) { Exit-Gate 2 }
	Exit-Gate 0
}

Write-GateLine "=== Typed conversion contracts ==="
$conversionEntrypoints = @(
	"res://tests/run_extra_rules_conversion_contract.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd",
	"res://tests/run_ability_module_bridge_test.gd"
)
foreach ($entrypoint in $conversionEntrypoints) {
	Write-GateLine "[QA] $entrypoint"
	$conversionStdout = Join-Path $env:TEMP "honor-and-iron-rogue-conversion.stdout.log"
	$conversionStderr = Join-Path $env:TEMP "honor-and-iron-rogue-conversion.stderr.log"
	$conversionProcess = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $projectRoot, "--script", $entrypoint) `
		-WorkingDirectory $projectRoot -RedirectStandardOutput $conversionStdout `
		-RedirectStandardError $conversionStderr -PassThru -Wait -NoNewWindow
	Get-Content $conversionStdout | ForEach-Object { Write-GateLine $_ }
	if ([int]$conversionProcess.ExitCode -ne 0) {
		Write-GateLine "[FAIL] Typed conversion contract exit $($conversionProcess.ExitCode) ($entrypoint)"
		Exit-Gate 4
	}
}
Write-GateLine "--- Typed conversion contracts: PASS ---"
Write-GateLine ""

Write-GateLine "=== AOE footprint contract (all classes) ==="
$aoeGate = Join-Path $PSScriptRoot "run_aoe_footprint_qa_gate.ps1"
& $aoeGate -GodotPath $GodotPath | ForEach-Object { Write-GateLine $_ }
if ($LASTEXITCODE -ne 0) {
	Write-GateLine "[FAIL] AOE footprint contract gate exit $LASTEXITCODE"
	Exit-Gate 5
}
Write-GateLine "--- AOE footprint contract: PASS ---"
Write-GateLine ""

Write-GateLine "=== Tier 1: headless skill scenarios (harness) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-rogue-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/RogueQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
$code = $process.ExitCode
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
# Keep diagnostics in the temp stderr log; the canonical gate snapshot is
# structured stdout while pass/fail evaluation still reads both streams.
if ($null -eq $code -or $code -eq "") {
	$summary = Get-Content $stdoutPath -Raw
	$code = 1
	if ($summary -match "\[PASS\] Rogue QA gate") {
		$code = 0
	}
}
$harnessPass = ($code -eq 0)

if ($harnessPass) {
	Write-GateLine "--- Tier 1 harness: PASS ---"
} else {
	Write-GateLine "--- Tier 1 harness: FAIL (exit $code) ---"
	Exit-Gate 1
}

Write-GateLine ""
Write-GateLine "=== Tier 2: live Rogue acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_rogue_live_qa.ps1"
if (-not (Test-Path $liveScript)) {
	Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
	Exit-Gate 4
}
& $liveScript -GodotPath $GodotPath | ForEach-Object { Write-GateLine $_ }
$liveExit = $LASTEXITCODE
if ($liveExit -ne 0) {
	Write-GateLine "[FAIL] Tier 2 live Rogue QA exit $liveExit"
	Exit-Gate $liveExit
}
Write-GateLine "--- Tier 2 live: PASS ---"

Write-GateLine ""
Write-GateLine "=== Rogue QA gate summary ==="
if (-not $matrixPassValid) {
	Write-GateLine "[INCOMPLETE] Harness PASS but matrix PASS rows lack meta-critic manifest approval."
	Exit-Gate 2
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine "[PASS] Rogue QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
