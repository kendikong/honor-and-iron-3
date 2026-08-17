param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$latestGateLog = Join-Path $projectRoot "qa_cleric_gate_latest.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonical = Join-Path $projectRoot "qa_cleric_gate_canonical.txt"
	$gateLogLines | Set-Content -Path $canonical -Encoding utf8
	$tmp = Join-Path $projectRoot "qa_cleric_gate_latest.tmp"
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

$matrixDoc = Join-Path $projectRoot "docs\CLERIC_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\cleric_meta_critic_manifest.json"

Write-GateLine "=== Cleric QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/CLERIC_QA_GATE.md"
Write-GateLine ""

$requiredFactoryIds = @(
	"selfless_siphon", "cleric_guardian_step", "cleric_holy_light", "cleric_smite",
	"cleric_cleansing_aura", "cleric_sanctuary", "cleric_blinding_ray",
	"cleric_divine_hammer", "cleric_life_link", "cleric_prayer_of_fortitude",
	"cleric_resurrection", "cleric_consecrate_ground", "cleric_holy_wrath",
	"cleric_divine_guidance", "cleric_shield_of_faith", "cleric_martyrs_chains",
	"blood_donation", "sacred_shield", "divine_blessing", "frontline_medic",
	"armor_of_faith", "divine_overflow", "divine_intervention", "holy_ground",
	"prayer", "purity", "martyrs_blood", "divine_retribution", "holy_radiance",
	"retribution", "zealous_protection"
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

Write-GateLine "=== Matrix summary (from docs/CLERIC_QA_GATE.md) ==="
Write-GateLine ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-GateLine ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-GateLine ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-GateLine ""

$manifestApproved = @()
$matrixPassValid = $true
if (Test-Path $manifestPath) {
	$manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
	foreach ($row in $manifest.approved_rows) {
		if ($null -ne $row.factory_id) {
			$manifestApproved += [string]$row.factory_id
		}
	}
	Write-GateLine ("=== Meta-critic manifest ({0} approved) ===" -f $manifestApproved.Count)
} else {
	Write-GateLine "[WARN] Missing manifest: docs/cleric_meta_critic_manifest.json"
}

$unapprovedPass = @($passRows | Where-Object { $manifestApproved -notcontains $_ })
if ($unapprovedPass.Count -gt 0) {
	Write-GateLine "[FAIL] Matrix PASS without manifest approval: $($unapprovedPass -join ', ')"
	$matrixPassValid = $false
} elseif ($passRows.Count -gt $manifestApproved.Count) {
	Write-GateLine "[FAIL] Matrix PASS count exceeds manifest approved count."
	$matrixPassValid = $false
}

Write-GateLine ""

. (Join-Path $PSScriptRoot "qa_gate_matrix_helpers.ps1")
$scenarioMissing = Test-MatrixScenarioFiles -ProjectRoot $projectRoot -MatrixDocPath $matrixDoc -RequiredFactoryIds $requiredFactoryIds
if ($scenarioMissing.Count -gt 0) {
	Write-GateLine "[FAIL] PASS matrix rows missing scenario files:"
	$scenarioMissing | ForEach-Object { Write-GateLine "  $_" }
	Exit-Gate 3
}
$manifestErrors = Test-ManifestScore -ManifestPath $manifestPath
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
	Write-GateLine "[INCOMPLETE] Cleric LOCK requires all factory rows PASS (meta-critic approved)."
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { Exit-Gate 2 }
	Exit-Gate 0
}

Write-GateLine "=== Typed module conversion contracts ==="
$typedContracts = @(
	"res://tests/run_extra_rules_conversion_contract.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd"
)
foreach ($typedContract in $typedContracts) {
	$contractTag = [IO.Path]::GetFileNameWithoutExtension($typedContract)
	$contractStdout = Join-Path $env:TEMP ("honor-and-iron-cleric-$contractTag.stdout.log")
	$contractStderr = Join-Path $env:TEMP ("honor-and-iron-cleric-$contractTag.stderr.log")
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

Write-GateLine "=== AOE footprint contract (all classes) ==="
$aoeGate = Join-Path $PSScriptRoot "run_aoe_footprint_qa_gate.ps1"
& $aoeGate -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Write-GateLine "[FAIL] AOE footprint contract gate exit $LASTEXITCODE"
	Exit-Gate 5
}
Write-GateLine "--- AOE footprint contract: PASS ---"
Write-GateLine ""

Write-GateLine "=== Tier 1: headless skill scenarios (harness) ==="
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-cleric-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-cleric-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/ClericQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Cleric Tier 1 harness"
if ($exitCode -eq 130) {
	Write-GateLine "[CANCEL] Cleric Tier 1 harness stopped by ESC."
	Exit-Gate 130
}
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
Get-Content $stderrPath | ForEach-Object { Write-GateLine $_ }

$harnessPass = Test-GodotQaHarnessSucceeded -ExitCode $exitCode -LogPaths @($stdoutPath, $stderrPath)
if (-not $harnessPass) {
	Write-GateLine "--- Tier 1 harness: FAIL ---"
	Exit-Gate 1
}
Write-GateLine "--- Tier 1 harness: PASS ---"

if (-not $matrixPassValid) {
	Write-GateLine "[FAIL] Matrix contains PASS rows without manifest approval."
	Exit-Gate 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine ""
	Write-GateLine "=== Tier 2: live Cleric acceptance ==="
	$liveScript = Join-Path $PSScriptRoot "run_cleric_live_qa.ps1"
	& $liveScript -GodotPath $GodotPath
	if ($LASTEXITCODE -ne 0) {
		Write-GateLine "[FAIL] Tier 2 live Cleric QA exit $LASTEXITCODE"
		Exit-Gate $LASTEXITCODE
	}
	Write-GateLine "--- Tier 2 live: PASS ---"
	Write-GateLine "[PASS] Cleric QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
