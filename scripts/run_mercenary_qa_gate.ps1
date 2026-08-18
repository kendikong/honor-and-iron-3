param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$latestGateLog = Join-Path $projectRoot "qa_mercenary_gate_latest.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonical = Join-Path $projectRoot "qa_mercenary_gate_canonical.txt"
	$gateLogLines | Set-Content -Path $canonical -Encoding utf8
	$tmp = Join-Path $projectRoot "qa_mercenary_gate_latest.tmp"
	$gateLogLines | Set-Content -Path $tmp -Encoding utf8
	try {
		if (Test-Path $latestGateLog) {
			Remove-Item -LiteralPath $latestGateLog -Force -ErrorAction Stop
		}
		Move-Item -LiteralPath $tmp -Destination $latestGateLog -Force -ErrorAction Stop
	} catch {
		if (Test-Path $tmp) {
			Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
		}
	}
}

function Exit-Gate([int]$Code) {
	Save-GateLog
	exit $Code
}

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

Write-GateLine "=== Mercenary QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/MERCENARY_QA_GATE.md"
Write-GateLine ""
Write-GateLine "=== Matrix summary (from docs/MERCENARY_QA_GATE.md) ==="
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
	Write-GateLine "[WARN] Missing manifest: docs/mercenary_meta_critic_manifest.json"
}

$unapprovedPass = @($passRows | Where-Object { $manifestApproved -notcontains $_ })
if ($unapprovedPass.Count -gt 0) {
	Write-GateLine "[FAIL] Matrix PASS without manifest approval: $($unapprovedPass -join ', ')"
	$matrixPassValid = $false
} elseif ($passRows.Count -gt $manifestApproved.Count) {
	Write-GateLine "[FAIL] Matrix PASS count exceeds manifest approved count."
	$matrixPassValid = $false
} else {
	$matrixPassValid = $true
}

Write-GateLine ""

. (Join-Path $PSScriptRoot "qa_gate_matrix_helpers.ps1")
$scenarioMissing = Test-MatrixScenarioFiles -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc -RequiredFactoryIds $requiredFactoryIds
if ($scenarioMissing.Count -gt 0) {
	Write-GateLine "[FAIL] PASS matrix rows missing scenario files:"
	$scenarioMissing | ForEach-Object { Write-GateLine "  $_" }
	Exit-Gate 3
}
$minGauntletScore = 88
if (Test-Path $manifestPath) {
	$manifestPreview = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
	if ($null -ne $manifestPreview.pass_threshold) {
		$minGauntletScore = [int]$manifestPreview.pass_threshold
	}
}
$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath -MinScore $minGauntletScore
if ($manifestErrors.Count -gt 0) {
	Write-GateLine "[FAIL] Meta-critic manifest gate:"
	$manifestErrors | ForEach-Object { Write-GateLine "  $_" }
	Exit-Gate 3
}
$contractErrors = Test-PassRowScenarioContracts -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc
if ($contractErrors.Count -gt 0) {
	Write-GateLine "[FAIL] PASS scenario contract shallow (CLASS_QA_BIBLE.md ss8.2):"
	$contractErrors | ForEach-Object { Write-GateLine "  $_" }
	Exit-Gate 3
}

if ($passRows.Count -lt $requiredFactoryIds.Count) {
	Write-GateLine "[INCOMPLETE] Mercenary LOCK requires all factory rows PASS (meta-critic approved)."
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { Exit-Gate 2 }
	Exit-Gate 0
}

Write-GateLine "=== Typed module conversion contracts ==="
foreach ($typedContract in @(
	"res://tests/run_extra_rules_conversion_contract.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd"
)) {
	$contractTag = [IO.Path]::GetFileNameWithoutExtension($typedContract)
	$contractStdout = Join-Path $env:TEMP ("honor-and-iron-mercenary-$contractTag.stdout.log")
	$contractStderr = Join-Path $env:TEMP ("honor-and-iron-mercenary-$contractTag.stderr.log")
	$contractProcess = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $projectRoot, "--script", $typedContract) `
		-RedirectStandardOutput $contractStdout `
		-RedirectStandardError $contractStderr `
		-Wait -PassThru
	$contractExit = $contractProcess.ExitCode
	if (Test-Path $contractStdout) {
		Get-Content -Path $contractStdout | ForEach-Object { Write-GateLine ([string]$_) }
	}
	if (Test-Path $contractStderr) {
		Get-Content -Path $contractStderr | ForEach-Object { Write-GateLine ([string]$_) }
	}
	if ($contractExit -ne 0) {
		Write-GateLine "[FAIL] Typed contract failed: $typedContract (exit $contractExit)"
		Exit-Gate 5
	}
}
Write-GateLine "--- Typed module conversion contracts: PASS ---"
Write-GateLine ""

Write-GateLine "=== Tier 1: headless Mercenary scenarios (harness) ==="
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mercenary-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mercenary-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/MercenaryQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Mercenary Tier 1 harness"
if ($exitCode -eq 130) {
	Write-GateLine "[CANCEL] Mercenary Tier 1 harness stopped by ESC."
	Exit-Gate 130
}
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
# Keep diagnostics in the temp stderr log; the canonical gate snapshot is
# structured stdout while pass/fail evaluation still reads both streams.

$harnessPass = Test-GodotQaHarnessSucceeded `
	-ExitCode $exitCode `
	-LogPaths @($stdoutPath, $stderrPath) `
	-PassPattern '^\[PASS\] Mercenary QA gate:'
if (-not $harnessPass) {
	Write-GateLine "[FAIL] Mercenary Tier 1 harness"
	Exit-Gate 1
}
Write-GateLine "--- Tier 1 harness: PASS ---"

Write-GateLine ""
Write-GateLine "=== Tier 2: live Mercenary acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_mercenary_live_qa.ps1"
if (-not (Test-Path $liveScript)) {
	Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
	Exit-Gate 4
}
& $liveScript -GodotPath $GodotPath
$liveExit = $LASTEXITCODE
if ($liveExit -ne 0) {
	Write-GateLine "[FAIL] Tier 2 live Mercenary QA exit $liveExit"
	Exit-Gate $liveExit
}
Write-GateLine "--- Tier 2 live: PASS ---"

Write-GateLine ""
Write-GateLine "=== Mercenary QA gate summary ==="
if (-not $matrixPassValid) {
	Write-GateLine "[FAIL] Matrix contains self-graded PASS rows (manifest mismatch)."
	Exit-Gate 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine "[PASS] Mercenary QA gate: matrix + typed contracts + Tier 1 harness + Tier 2 live PASS"
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
