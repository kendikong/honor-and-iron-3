param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$latestGateLog = Join-Path $projectRoot "qa_archer_gate_latest.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonical = Join-Path $projectRoot "qa_archer_gate_canonical.txt"
	$gateLogLines | Set-Content -Path $canonical -Encoding utf8
	$tmp = Join-Path $projectRoot "qa_archer_gate_latest.tmp"
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

$matrixDoc = Join-Path $projectRoot "docs\ARCHER_QA_GATE.md"
$requiredFactoryIds = @(
	"archer_sidestep", "archer_power_shot", "archer_volley", "archer_pinning_arrow",
	"archer_piercing_shot", "archer_toxic_spore_arrow", "archer_grapple_arrow",
	"archer_explosive_arrow", "archer_hunters_mark", "archer_repelling_shot",
	"archer_bear_trap", "archer_suppressing_fire", "archer_caltrop_trap",
	"archer_parting_shot", "archer_scouts_eye",
	"lightfoot", "overwatch", "high_ground", "patient_hunter", "true_sight",
	"piercing_momentum", "camouflage", "area_denial", "caltrop_expert", "zone_control",
	"sticky_mud", "fletching_hoarder", "prey_sighted", "barrage", "target_painter", "rapid_fire"
)

Write-GateLine "=== Archer QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/ARCHER_QA_GATE.md"
Write-GateLine ""

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

Write-GateLine "=== Matrix summary (from docs/ARCHER_QA_GATE.md) ==="
Write-GateLine ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-GateLine ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-GateLine ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-GateLine ""

if ($passRows.Count -lt $requiredFactoryIds.Count) {
	Write-GateLine "[INCOMPLETE] Archer LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-GateLine ("HARNESS_ONLY rows: {0}" -f $harnessRows.Count)
	}
	if ($plannedRows.Count -gt 0) {
		Write-GateLine "PLANNED (no scenario): $($plannedRows -join ', ')"
	}
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix check only."
	Exit-Gate 2
}

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
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-archer-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-archer-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/ArcherQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Archer Tier 1 harness"
if ($exitCode -eq 130) {
	Write-GateLine "[CANCEL] Archer Tier 1 harness stopped by ESC."
	Exit-Gate 130
}
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
Get-Content $stderrPath | ForEach-Object { Write-GateLine $_ }

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$harnessPass = Test-GodotQaHarnessSucceeded -ExitCode $exitCode -LogPaths @($stdoutPath, $stderrPath)

if ($harnessPass) {
	Write-GateLine "--- Tier 1 harness: PASS ---"
} else {
	Write-GateLine "--- Tier 1 harness: FAIL ---"
	if ($testFailures.Count -gt 0) {
		$testFailures | Select-Object -First 10 | ForEach-Object { Write-GateLine $_ }
	}
	if ($scriptErrors.Count -gt 0) {
		Write-GateLine "[FAIL] Godot SCRIPT ERROR lines detected ($($scriptErrors.Count)):"
		$scriptErrors | Select-Object -First 10 | ForEach-Object { Write-GateLine $_ }
	}
	Exit-Gate 1
}

Write-GateLine ""
Write-GateLine "=== Tier 2: live Archer acceptance ==="
$liveScript = Join-Path $PSScriptRoot "run_archer_live_qa.ps1"
if (-not (Test-Path $liveScript)) {
	Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
	Exit-Gate 4
}
& $liveScript -GodotPath $GodotPath
$liveExit = $LASTEXITCODE
if ($liveExit -ne 0) {
	Write-GateLine "[FAIL] Tier 2 live Archer QA exit $liveExit"
	Exit-Gate $liveExit
}
Write-GateLine "--- Tier 2 live: PASS ---"

if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine "[PASS] Archer QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Tier 1+2 automated green; matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 0
