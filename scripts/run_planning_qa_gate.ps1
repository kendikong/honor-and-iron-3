param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[switch]$IncludeLegacyTier12,
	[switch]$LiveTier3
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

$tier12Label = "DISABLED (legacy - not gate-blocking)"
if ($IncludeLegacyTier12) {
	Write-Output "=== Tier 1/2: planning contracts (headless, legacy - informational only) ==="
	. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
	$stdoutPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stdout.log"
	$stderrPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stderr.log"
	$process = Start-Process -FilePath $GodotPath `
		-ArgumentList "--headless --path `"$projectRoot`" res://tests/PlanningQaGate.tscn" `
		-RedirectStandardOutput $stdoutPath `
		-RedirectStandardError $stderrPath `
		-PassThru
	$legacyExit = Wait-GodotProcessWithEscCancel -Process $process -Label "Planning Tier 1/2 legacy"
	if ($legacyExit -eq 130) {
		Write-Output "[CANCEL] Planning Tier 1/2 legacy stopped by ESC."
		exit 130
	}
	Get-Content $stdoutPath
	# Keep diagnostics in the temp stderr log; gate output remains structured
	# while pass/fail evaluation still reads both streams.

	$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
	$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)SCRIPT ERROR:' | ForEach-Object { $_.Line })
	$runtimeErrors = @(
		Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)ERROR:' |
			Where-Object { $_.Line -notmatch 'resources still in use' } |
			ForEach-Object { $_.Line }
	)
	$legacyPass = (
		Test-GodotQaHarnessSucceeded -ExitCode $legacyExit -LogPaths @($stdoutPath, $stderrPath)
	) -and ($runtimeErrors.Count -eq 0)
	if ($legacyPass) {
		Write-Output "--- Tier 1/2 (legacy): PASS ---"
		$tier12Label = "PASS (legacy informational)"
	} else {
		Write-Output "--- Tier 1/2 (legacy): FAIL (expected - not gate-blocking) ---"
		if ($testFailures.Count -gt 0) {
			Write-Output "Assertion failures ($($testFailures.Count)) (first 10):"
			$testFailures | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
		}
		$tier12Label = "FAIL - $($testFailures.Count) failures (legacy, ignored)"
	}
} else {
	Write-Output "=== Tier 1/2: DISABLED (legacy headless fixture contracts) ==="
	Write-Output "Use -IncludeLegacyTier12 to run locally for archaeology only; failures do not block the gate."
}

Write-Output ""
Write-Output "=== AOE footprint contract (geometry + scenario/live audits) ==="
$aoeGate = Join-Path $PSScriptRoot "run_aoe_footprint_qa_gate.ps1"
& $aoeGate -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
	Write-Output "--- AOE footprint contract: FAIL ---"
	exit 1
}
Write-Output "--- AOE footprint contract: PASS ---"
Write-Output ""

if ($LiveTier3) {
	Write-Output "=== Tier 3: TestBattle scene acceptance (GdUnit4 LIVE) ==="
	Write-Output "Note: default gate uses headless fixture suites; -LiveTier3 opts into F5-parity live runner."
	$sceneGate = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
	if (-not (Test-Path $sceneGate)) {
		Write-Error "[INCOMPLETE] Tier 3 live runner missing: $sceneGate"
		exit 2
	}
	& $sceneGate -GodotPath $GodotPath
	$sceneExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
	$tier3Pass = $false
	$tier3Incomplete = $false
	if ($sceneExit -eq 2) {
		$tier3Incomplete = $true
		Write-Output "--- Tier 3 LIVE: INCOMPLETE ---"
	} elseif ($sceneExit -eq 130) {
		Write-Output "--- Tier 3 LIVE: CANCELLED (ESC) ---"
		exit 130
	} elseif ($sceneExit -eq 0) {
		$tier3Pass = $true
		Write-Output "--- Tier 3 LIVE: PASS ---"
	} else {
		Write-Output "--- Tier 3 LIVE: FAIL (exit $sceneExit) ---"
	}
	$tier3Label = if ($tier3Incomplete) { "INCOMPLETE (live)" } elseif ($tier3Pass) { "PASS (live)" } else { "FAIL (live)" }
} else {
	Write-Output "=== Tier 3: headless fixture suites (PlanningQaGate + T3 mimic) ==="
	Write-Output "Use -LiveTier3 for GdUnit TestBattle acceptance (owner F5 parity)."
	$headlessGate = Join-Path $PSScriptRoot "run_planning_headless_contracts.ps1"
	$mimicGate = Join-Path $PSScriptRoot "run_t3_mimic_headless.ps1"
	if (-not (Test-Path $headlessGate)) {
		Write-Error "[INCOMPLETE] Headless planning contracts runner missing: $headlessGate"
		exit 2
	}
	if (-not (Test-Path $mimicGate)) {
		Write-Error "[INCOMPLETE] T3 mimic headless runner missing: $mimicGate"
		exit 2
	}
	& $headlessGate -GodotPath $GodotPath
	if ($LASTEXITCODE -ne 0) {
		Write-Output "--- Tier 3 headless contracts: FAIL ---"
		exit 1
	}
	Write-Output "--- Tier 3 headless contracts: PASS ---"
	Write-Output ""
	& $mimicGate -GodotPath $GodotPath
	if ($LASTEXITCODE -ne 0) {
		Write-Output "--- Tier 3 fixture parity: FAIL ---"
		exit 1
	}
	Write-Output "--- Tier 3 fixture parity: PASS ---"
	$tier3Pass = $true
	$tier3Label = "PASS (headless fixtures)"
}

Write-Output ""
Write-Output "=== Planning QA gate summary ==="
Write-Output ("Tier 1/2: {0}" -f $tier12Label)
Write-Output ("Tier 3:   {0}" -f $tier3Label)

if (-not $tier3Pass) {
	exit 1
}
Write-Output "[PASS] Planning QA gate."
exit 0
