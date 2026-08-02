param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$matrixDoc = Join-Path $projectRoot "docs\BRUISER_QA_GATE.md"
$manifestPath = Join-Path $projectRoot "docs\bruiser_meta_critic_manifest.json"

Write-Output "=== Bruiser QA gate (class validation - NOT planning QA) ==="
Write-Output "Spec: docs/BRUISER_QA_GATE.md"
Write-Output ""

# Expected factory rows that must reach PASS before LOCK (from bruiser_factory.gd)
$requiredFactoryIds = @(
	"bruiser_push_through",
	"bruiser_charge_strike", "bruiser_concussion_blow", "bruiser_cleave", "bruiser_suplex",
	"bruiser_adrenaline_surge", "bruiser_earthshatter", "bruiser_meat_shield", "bruiser_frenzy",
	"bruiser_guttural_roar", "bruiser_headbutt", "bruiser_blood_boil", "bruiser_violent_collision",
	"bruiser_crimson_whirlwind", "bruiser_belly_flop", "bruiser_breaching_dash",
	"cellular_regeneration", "blood_for_blood", "adrenaline_junkie", "enraged", "last_stand",
	"colossal_mass", "overwhelming_bulk", "thrill_of_pain", "momentum_of_titan", "scar_tissue",
	"momentum_transfer", "crowd_breaker", "juggernaut", "battering_ram", "unstoppable_force"
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

Write-Output "=== Matrix summary (from docs/BRUISER_QA_GATE.md) ==="
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
	Write-Output "[WARN] Missing manifest: docs/bruiser_meta_critic_manifest.json"
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
	Write-Output "[INCOMPLETE] Bruiser LOCK requires all factory rows PASS (meta-critic approved)."
	if ($harnessRows.Count -gt 0) {
		Write-Output "HARNESS_ONLY (need Bible + [+] asserts): $($harnessRows -join ', ')"
	}
	if ($plannedRows.Count -gt 0) {
		Write-Output "PLANNED (no scenario): $($plannedRows -join ', ')"
	}
}

if (-not (Test-Path $GodotPath)) {
	Write-Output "[SKIP] Godot not found at: $GodotPath - matrix check only."
	if ($passRows.Count -lt $requiredFactoryIds.Count) { exit 2 }
	exit 0
}

Write-Output "=== Tier 1: headless skill scenarios (harness) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-bruiser-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-bruiser-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/BruiserQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait `
	-PassThru
Get-Content $stdoutPath
Get-Content $stderrPath

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' | ForEach-Object { $_.Line })
$harnessPass = ($process.ExitCode -eq 0) -and ($testFailures.Count -eq 0) -and ($scriptErrors.Count -eq 0)

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
Write-Output "=== Bruiser QA gate summary ==="
if (-not $matrixPassValid) {
	Write-Output "[FAIL] Matrix contains self-graded PASS rows (manifest mismatch). Fix docs or update manifest via gauntlet-critic only."
	exit 3
}
if ($passRows.Count -eq $requiredFactoryIds.Count) {
	Write-Output "[PASS] Bruiser QA gate: matrix 100% PASS + Tier 1 harness PASS."
	exit 0
}

Write-Output ('[INCOMPLETE] Harness PASS but matrix not LOCK-ready ({0}/{1} PASS rows).' -f $passRows.Count, $requiredFactoryIds.Count)
exit 2
