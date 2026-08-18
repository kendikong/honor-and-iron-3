param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\KNIGHT_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\knight_meta_critic_manifest.json"

$latestGateLog = Join-Path $projectRoot "qa_knight_gate_latest.txt"
$canonicalGateLog = Join-Path $projectRoot "qa_knight_gate_canonical.txt"
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

Write-GateLine "=== Knight QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/KNIGHT_QA_GATE.md)"
Write-GateLine ""

# Expected factory rows that must reach PASS before LOCK (from knight_factory.gd)
$requiredFactoryIds = @(
	"knight_swap",
	"knight_shield_bash", "knight_phalanx_stance", "knight_taunting_strike",
	"knight_seismic_stomp", "knight_fortify", "knight_bowling_charge",
	"knight_iron_grip", "knight_redirect_strike", "knight_indomitable_will",
	"knight_retaliation_protocol", "knight_shield_slam", "knight_defensive_formation",
	"knight_chain_hook", "knight_trampling_advance",
	"collision_retaliator", "thorny_carapace", "concussive_shatter",
	"kinetic_momentum", "stand_ground", "indestructible_bastion", "shield_mastery",
	"kinetic_armor", "kinetic_converter", "kinetic_redirection", "bulwark",
	"living_barricade", "shield_wall", "rallying_presence", "intercept_tactics"
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

Write-GateLine "=== Matrix summary (from docs/KNIGHT_QA_GATE.md) ==="
Write-GateLine ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-GateLine ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-GateLine ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-GateLine ""

$manifestApproved = @()
$manifestThreshold = 95
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
	Write-GateLine "[WARN] Missing manifest: docs/knight_meta_critic_manifest.json"
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
	$scenarioMissing | ForEach-Object { Write-Output "  $_" }
	Exit-Gate 3
}
$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath
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

if ($passRows.Count -lt $requiredFactoryIds.Count) {
	Write-GateLine "[INCOMPLETE] Knight LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-GateLine "HARNESS_ONLY (need Bible + [+] asserts): $($harnessRows -join ', ')"
	}
	if ($plannedRows.Count -gt 0) {
		Write-GateLine "PLANNED (no scenario): $($plannedRows -join ', ')"
	}
}

# Tier 1 harness - interim; green here does not imply matrix PASS
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
	$contractStdout = Join-Path $env:TEMP ("honor-and-iron-knight-$contractTag.stdout.log")
	$contractStderr = Join-Path $env:TEMP ("honor-and-iron-knight-$contractTag.stderr.log")
	$contractProcess = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $projectRoot, "--script", $typedContract) `
		-RedirectStandardOutput $contractStdout `
		-RedirectStandardError $contractStderr `
		-Wait -PassThru
	$contractExit = $contractProcess.ExitCode
	if (Test-Path $contractStdout) { Get-Content -Path $contractStdout }
	if (Test-Path $contractStderr) { Get-Content -Path $contractStderr }
	if ($contractExit -ne 0) {
		Write-GateLine "[FAIL] Typed contract failed: $typedContract (exit $contractExit)"
		Exit-Gate 5
	}
}
Write-GateLine "--- Typed module conversion contracts: PASS ---"
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
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-knight-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-knight-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/KnightQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Knight Tier 1 harness"
if ($exitCode -eq 130) {
	Write-GateLine "[CANCEL] Knight Tier 1 harness stopped by ESC."
	Exit-Gate 130
}
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
# Keep diagnostics in the temp stderr log; the canonical gate snapshot is
# structured stdout while pass/fail evaluation still reads both streams.

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$harnessPass = Test-GodotQaHarnessSucceeded -ExitCode $exitCode -LogPaths @($stdoutPath, $stderrPath)

if ($harnessPass) {
	Write-GateLine "--- Tier 1 harness: PASS ---"
} else {
	Write-GateLine "--- Tier 1 harness: FAIL ---"
	if ($testFailures.Count -gt 0) {
		$testFailures | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
	}
	if ($scriptErrors.Count -gt 0) {
		Write-GateLine "[FAIL] Godot SCRIPT ERROR lines detected ($($scriptErrors.Count)):"
		$scriptErrors | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
	}
	Exit-Gate 1
}

Write-GateLine ""
Write-GateLine "=== Tier 2: live Knight acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_knight_live_qa.ps1"
if (-not (Test-Path $liveScript)) {
	Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
	Exit-Gate 4
}
& $liveScript -GodotPath $GodotPath | ForEach-Object { Write-GateLine $_ }
$liveExit = $LASTEXITCODE
if ($liveExit -ne 0) {
	Write-GateLine "[FAIL] Tier 2 live Knight QA exit $liveExit"
	Exit-Gate $liveExit
}
Write-GateLine "--- Tier 2 live: PASS ---"

Write-GateLine ""
Write-GateLine "=== Knight QA gate summary ==="
if (-not $matrixPassValid) {
	Write-GateLine "[FAIL] Matrix contains self-graded PASS rows (manifest mismatch). Fix docs or update manifest via gauntlet-critic only."
	Exit-Gate 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine "[PASS] Knight QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
