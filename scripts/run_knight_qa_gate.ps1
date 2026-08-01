param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\KNIGHT_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\knight_meta_critic_manifest.json"

Write-Output "=== Knight QA gate (class validation - NOT planning QA) ==="
Write-Output "Spec: docs/KNIGHT_QA_GATE.md"
Write-Output ""

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
	$rowLine = ($matrixText -split "`n" | Where-Object { $_ -match $tablePattern -and $_ -match '\|' } | Select-Object -First 1)
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

Write-Output "=== Matrix summary (from docs/KNIGHT_QA_GATE.md) ==="
Write-Output ("PASS:          {0}/{1}" -f $passRows.Count, $requiredFactoryIds.Count)
Write-Output ("HARNESS_ONLY:  {0}" -f $harnessRows.Count)
Write-Output ("PLANNED/other: {0}" -f $plannedRows.Count)
Write-Output ""

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
	Write-Output ("=== Meta-critic manifest ({0} approved, threshold {1}) ===" -f $manifestApproved.Count, $manifestThreshold)
} else {
	Write-Output "[WARN] Missing manifest: docs/knight_meta_critic_manifest.json"
}

$unapprovedPass = @($passRows | Where-Object { $manifestApproved -notcontains $_ })
if ($unapprovedPass.Count -gt 0) {
	Write-Output "[FAIL] Matrix PASS without manifest approval: $($unapprovedPass -join ', ')"
	$matrixPassValid = $false
} elseif ($passRows.Count -gt $manifestApproved.Count) {
	Write-Output "[FAIL] Matrix PASS count exceeds manifest approved count."
	$matrixPassValid = $false
} else {
	$matrixPassValid = $true
}

Write-Output ""

if ($passRows.Count -lt $requiredFactoryIds.Count) {
	Write-Output "[INCOMPLETE] Knight LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-Output "HARNESS_ONLY (need Bible + [+] asserts): $($harnessRows -join ', ')"
	}
	if ($plannedRows.Count -gt 0) {
		Write-Output "PLANNED (no scenario): $($plannedRows -join ', ')"
	}
}

# Tier 1 harness - interim; green here does not imply matrix PASS
if (-not (Test-Path $GodotPath)) {
	Write-Output "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { exit 2 }
	exit 0
}

Write-Output "=== Tier 1: headless skill scenarios (harness) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-knight-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-knight-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" --script res://tests/run_skill_scenarios_only.gd" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait `
	-PassThru
Get-Content $stdoutPath
Get-Content $stderrPath

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$harnessPass = ($process.ExitCode -eq 0) -and ($testFailures.Count -eq 0)

if ($harnessPass) {
	Write-Output "--- Tier 1 harness: PASS ---"
} else {
	Write-Output "--- Tier 1 harness: FAIL ---"
	if ($testFailures.Count -gt 0) {
		$testFailures | Select-Object -First 10 | ForEach-Object { Write-Output $_ }
	}
	exit 1
}

Write-Output ""
Write-Output "=== Knight QA gate summary ==="
if (-not $matrixPassValid) {
	Write-Output "[FAIL] Matrix contains self-graded PASS rows (manifest mismatch). Fix docs or update manifest via gauntlet-critic only."
	exit 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-Output "[PASS] Knight QA gate: matrix 100% PASS + Tier 1 harness PASS."
	exit 0
}

Write-Output ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
exit 2
