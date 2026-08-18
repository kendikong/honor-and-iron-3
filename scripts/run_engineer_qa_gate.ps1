param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\ENGINEER_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\engineer_meta_critic_manifest.json"

Write-Output "=== Engineer QA gate (CLASS_QA_BIBLE) ==="
Write-Output "Spec: docs/CLASS_QA_BIBLE.md (instance: docs/ENGINEER_QA_GATE.md)"
Write-Output ""

$requiredFactoryIds = @(
	"engineer_recall", "engineer_dismantle", "engineer_sludge_bomb",
	"engineer_construct_turret", "engineer_frag_bomb", "engineer_magnetic_mine",
	"engineer_tesla_barricade", "engineer_flak_cannon", "engineer_wrench_smack",
	"engineer_emp_grenade", "engineer_rocket_launcher", "engineer_scrap_shield",
	"engineer_manual_detonation", "engineer_overdrive_injection", "engineer_barbed_wire",
	"blueprint_tread", "turret_syndrome", "automation", "master_builder",
	"reinforced_constructs", "shield_generator", "blast_shielding",
	"explosive_expert", "chain_reaction", "shrapnel", "expanded_blast",
	"scrap_mechanic", "recycling_protocol", "overclock",
	"overclocked_maintenance", "field_technician"
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

Write-Output "=== Matrix summary (from docs/ENGINEER_QA_GATE.md) ==="
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
	Write-Output ("=== Meta-critic manifest ({0} approved, threshold {1}, last_round {2}, last_score {3}, {4}) ===" -f `
		$manifestApproved.Count, $manifestThreshold, `
		$manifest.last_critic_round, $manifest.last_score, $manifest.last_result)
} else {
	Write-Output "[WARN] Missing manifest: docs/engineer_meta_critic_manifest.json"
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
$scenarioMissing = Test-MatrixScenarioFiles `
	-ProjectRoot $projectRoot -MatrixDocPath $matrixDoc `
	-RequiredFactoryIds $requiredFactoryIds
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

Write-Output "=== Typed module conversion contracts ==="
foreach ($typedContract in @(
	"res://tests/run_extra_rules_conversion_contract.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd"
)) {
	$contractTag = [IO.Path]::GetFileNameWithoutExtension($typedContract)
	$contractStdout = Join-Path $env:TEMP ("honor-and-iron-engineer-$contractTag.stdout.log")
	$contractStderr = Join-Path $env:TEMP ("honor-and-iron-engineer-$contractTag.stderr.log")
	$contractProcess = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $projectRoot, "--script", $typedContract) `
		-RedirectStandardOutput $contractStdout `
		-RedirectStandardError $contractStderr `
		-Wait -PassThru
	$contractExit = $contractProcess.ExitCode
	if (Test-Path $contractStdout) { Get-Content -Path $contractStdout }
	if (Test-Path $contractStderr) { Get-Content -Path $contractStderr }
	if ($contractExit -ne 0) {
		Write-Output "[FAIL] Typed contract failed: $typedContract (exit $contractExit)"
		exit 5
	}
}
Write-Output "--- Typed module conversion contracts: PASS ---"
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
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-engineer-tier1.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-engineer-tier1.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/EngineerQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
$process.WaitForExit()
$process.Refresh()
$exitCode = [int]$process.ExitCode
Get-Content $stdoutPath
# Keep diagnostics in the temp stderr log; the canonical gate snapshot is
# structured stdout while pass/fail evaluation still reads both streams.

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$harnessPass = ($exitCode -eq 0 -and $testFailures.Count -eq 0 -and $scriptErrors.Count -eq 0)

if ($harnessPass) {
	Write-Output "--- Tier 1 harness: PASS ---"
} else {
	Write-Output "--- Tier 1 harness: FAIL ---"
	if ($testFailures.Count -gt 0) {
		$testFailures | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
	}
	if ($scriptErrors.Count -gt 0) {
		Write-Output "[FAIL] Godot SCRIPT ERROR lines detected ($($scriptErrors.Count)):"
		$scriptErrors | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
	}
	exit 1
}

Write-Output ""
Write-Output "=== Tier 2: live Engineer acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_engineer_live_qa.ps1"
& $liveScript -GodotPath ($GodotPath -replace '_console', '')
if ($LASTEXITCODE -ne 0) {
	Write-Output "[FAIL] Engineer Tier 2 live gate exit $LASTEXITCODE"
	exit 4
}
Write-Output "[PASS] Engineer Tier 2 live preview/factory gate"

Write-Output ""
Write-Output "=== Engineer QA gate summary ==="
if (-not $matrixPassValid) {
	Write-Output "[INCOMPLETE] Harness PASS but matrix PASS rows lack meta-critic manifest approval."
	exit 2
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-Output "[PASS] Engineer QA gate: matrix 31/31 + Tier 1 harness + Tier 2 live + AOE footprint PASS (automated bar; owner sign-off separate per CLASS_QA_SIGNOFF.md)."
	exit 0
}

Write-Output ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
exit 2
