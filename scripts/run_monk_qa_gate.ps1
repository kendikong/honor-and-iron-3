param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$latestGateLog = Join-Path $projectRoot "qa_monk_gate_latest.txt"
$gateLogLines = New-Object System.Collections.Generic.List[string]

function Write-GateLine([string]$Line) {
	Write-Output $Line
	[void]$gateLogLines.Add($Line)
}

function Save-GateLog() {
	$canonical = Join-Path $projectRoot "qa_monk_gate_canonical.txt"
	$gateLogLines | Set-Content -Path $canonical -Encoding utf8
	$tmp = Join-Path $projectRoot "qa_monk_gate_latest.tmp"
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

$matrixDoc = Join-Path $projectRoot "docs\MONK_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\monk_meta_critic_manifest.json"

Write-GateLine "=== Monk QA gate (class validation - NOT planning QA) ==="
Write-GateLine "Spec: docs/MONK_QA_GATE.md"
Write-GateLine ""

$requiredFactoryIds = @(
	"way_of_the_weaver", "monk_leap", "monk_scorching_kick", "monk_thunder_palm",
	"monk_yin_yang_flurry", "monk_chakra_shift", "monk_phase_throw",
	"monk_flying_crane_kick", "monk_spirit_palm", "monk_soul_punch",
	"monk_hundred_fists", "monk_mantra_of_peace", "monk_inner_fire",
	"monk_void_step", "monk_cyclone_sweep", "monk_updraft", "monk_geyser_strike",
	"elemental_attunement", "chakra_burn", "elemental_harmony", "catalyst",
	"elemental_shield", "weavers_resonance", "mind_over_matter", "inner_peace",
	"zen_defense", "perfect_form", "vaulting_strike", "flowing_ki",
	"evasive_acrobat", "momentum_transfer", "light_step"
)

if (-not (Test-Path $matrixDoc)) {
	Write-GateLine "[FAIL] Missing matrix doc: $matrixDoc"
	Exit-Gate 3
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

Write-GateLine "=== Matrix summary (from docs/MONK_QA_GATE.md) ==="
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
	} elseif ($null -ne $manifest.threshold) {
		$manifestThreshold = [int]$manifest.threshold
	}
	foreach ($row in $manifest.approved_rows) {
		if ($row -is [string]) {
			$manifestApproved += $row
		} elseif ($null -ne $row.factory_id) {
			$manifestApproved += [string]$row.factory_id
		}
	}
	Write-GateLine ("=== Meta-critic manifest ({0} approved, threshold {1}) ===" -f $manifestApproved.Count, $manifestThreshold)
} else {
	Write-GateLine "[WARN] Missing manifest: docs/monk_meta_critic_manifest.json"
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
	Write-GateLine "[INCOMPLETE] Monk LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-GateLine "HARNESS_ONLY (need Bible + [+] asserts): $($harnessRows -join ', ')"
	}
	if ($plannedRows.Count -gt 0) {
		Write-GateLine "PLANNED (no scenario): $($plannedRows -join ', ')"
	}
}

if (-not (Test-Path $GodotPath)) {
	Write-GateLine "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { Exit-Gate 2 }
	Exit-Gate 0
}

Write-GateLine "=== Tier 1: headless skill scenarios (harness) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-monk-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-monk-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/MonkQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -PassThru -NoNewWindow
$process.WaitForExit()
$process.Refresh()
$exitCode = [int]$process.ExitCode
Get-Content $stdoutPath | ForEach-Object { Write-GateLine $_ }
Get-Content $stderrPath | ForEach-Object { Write-GateLine $_ }

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$harnessPass = ($exitCode -eq 0 -and $testFailures.Count -eq 0 -and $scriptErrors.Count -eq 0)

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
Write-GateLine "=== Monk QA gate summary ==="
if (-not $matrixPassValid) {
	Write-GateLine "[FAIL] Matrix contains self-graded PASS rows (manifest mismatch). Fix docs or update manifest via gauntlet-critic only."
	Exit-Gate 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-GateLine ""
	Write-GateLine "=== Tier 2: live Monk acceptance ==="
	$liveScript = Join-Path $PSScriptRoot "run_monk_live_qa.ps1"
	if (-not (Test-Path $liveScript)) {
		Write-GateLine "[FAIL] Missing Tier 2 runner: $liveScript"
		Exit-Gate 4
	}
	& $liveScript -GodotPath $GodotPath
	$liveExit = $LASTEXITCODE
	if ($liveExit -ne 0) {
		Write-GateLine "[FAIL] Tier 2 live Monk QA exit $liveExit"
		Exit-Gate $liveExit
	}
	Write-GateLine "--- Tier 2 live: PASS ---"
	Write-GateLine "[PASS] Monk QA gate: matrix 100% PASS + Tier 1 harness PASS + Tier 2 live PASS."
	Exit-Gate 0
}

Write-GateLine ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
Exit-Gate 2
