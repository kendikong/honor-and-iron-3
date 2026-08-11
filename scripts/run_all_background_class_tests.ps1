param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $projectRoot "reports\ability_data_gauntlet\all_background_verification_latest.txt"
$errPath = Join-Path $projectRoot "reports\ability_data_gauntlet\all_background_verification_latest.stderr.txt"
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path $outDir)) {
	New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$log = New-Object System.Collections.Generic.List[string]
function Write-Log([string]$Line) {
	Write-Output $Line
	[void]$log.Add($Line)
}

$summary = @{}
$items = @(
	@{ N = "Knight"; P = "run_knight_qa_gate.ps1" },
	@{ N = "Bruiser"; P = "run_bruiser_qa_gate.ps1" },
	@{ N = "Lancer"; P = "run_lancer_qa_gate.ps1" },
	@{ N = "Archer"; P = "run_archer_qa_gate.ps1" },
	@{ N = "Mage"; P = "run_mage_qa_gate.ps1" },
	@{ N = "Cleric"; P = "run_cleric_qa_gate.ps1" },
	@{ N = "PlanningHeadless"; P = "run_planning_qa_gate.ps1" },
	@{ N = "Regression"; P = "run_regression_tests.ps1" }
)

foreach ($item in $items) {
	Write-Log "=== $($item.N) ==="
	$scriptPath = Join-Path $PSScriptRoot $item.P
	if (-not (Test-Path $scriptPath)) {
		Write-Log "[FAIL] Missing runner: $scriptPath"
		$summary[$item.N] = 127
		continue
	}
	try {
		& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -GodotPath $GodotPath 2>&1 | ForEach-Object { Write-Log "$_" }
		$code = $LASTEXITCODE
		if ($null -eq $code) { $code = 1 }
		$summary[$item.N] = $code
		Write-Log "EXIT $($item.N)=$code"
	} catch {
		Write-Log "[FAIL] $($item.N): $($_.Exception.Message)"
		$summary[$item.N] = 1
	}
	Write-Log ""
}

Write-Log "=== SUMMARY ==="
foreach ($key in @("Knight", "Bruiser", "Lancer", "Archer", "Mage", "Cleric", "PlanningHeadless", "Regression")) {
	if ($summary.ContainsKey($key)) {
		Write-Log ("{0}={1}" -f $key, $summary[$key])
	}
}
$anyFail = $false
foreach ($v in $summary.Values) {
	if ($v -ne 0) { $anyFail = $true; break }
}
Write-Log ("OVERALL={0}" -f $(if ($anyFail) { "FAIL" } else { "PASS" }))

$log | Set-Content -Path $outPath -Encoding UTF8
"" | Set-Content -Path $errPath -Encoding UTF8

if ($anyFail) { exit 1 }
exit 0
