param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$latestGateLog = Join-Path $projectRoot "qa_lancer_gate_latest.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonical = Join-Path $projectRoot "qa_lancer_gate_canonical.txt"
	$gateLogLines | Set-Content -Path $canonical -Encoding utf8
	$tmp = Join-Path $projectRoot "qa_lancer_gate_latest.tmp"
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

$matrixDoc = Join-Path $projectRoot "docs\LANCER_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\lancer_meta_critic_manifest.json"

Write-GateLine "=== Lancer QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/LANCER_QA_GATE.md"
Write-GateLine ""

$requiredFactoryIds = @(
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

Write-GateLine "=== Matrix summary (from docs/LANCER_QA_GATE.md) ==="
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
	Write-GateLine "[WARN] Missing manifest: docs/lancer_meta_critic_manifest.json"
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

if ($passRows.Count -lt $requiredFactoryIds.Count) {
	Write-GateLine "[INCOMPLETE] Lancer LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-GateLine "HARNESS_ONLY: $($harnessRows -join ', ')"
	}
	if ($plannedRows.Count -gt 0) {
		Write-GateLine "PLANNED: $($plannedRows -join ', ')"
	}
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { Exit-Gate 2 }
	Exit-Gate 0
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
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-lancer-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-lancer-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/LancerQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Lancer Tier 1 harness"
if ($exitCode -eq 130) {
	Write-GateLine "[CANCEL] Lancer Tier 1 harness stopped by ESC."
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
Write-GateLine "=== Lancer QA gate summary ==="
if (-not $matrixPassValid) {
	Write-GateLine "[FAIL] Matrix contains PASS rows without manifest approval."
	Exit-Gate 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine ""
	Write-GateLine "=== Tier 2: live Lancer acceptance ==="
	$liveScript = Join-Path $PSScriptRoot "run_lancer_live_qa.ps1"
	if (-not (Test-Path $liveScript)) {
		Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
		Exit-Gate 4
	}
	& $liveScript -GodotPath $GodotPath
	$liveExit = $LASTEXITCODE
	if ($liveExit -ne 0) {
		Write-GateLine "[FAIL] Tier 2 live Lancer QA exit $liveExit"
		Exit-Gate $liveExit
	}
	Write-GateLine "--- Tier 2 live: PASS ---"
	Write-GateLine "[PASS] Lancer QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
