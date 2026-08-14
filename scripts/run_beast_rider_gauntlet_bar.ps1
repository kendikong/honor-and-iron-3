param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[string]$OutPath = "reports/beast_rider_gauntlet_latest.stdout.txt"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$gateScript = Join-Path $PSScriptRoot "run_beast_rider_qa_gate.ps1"
$outFile = Join-Path $projectRoot $OutPath
$outDir = Split-Path -Parent $outFile
if (-not (Test-Path $outDir)) {
	New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

& $gateScript -GodotPath $GodotPath *>&1 | Tee-Object -FilePath $outFile
$gateExit = $LASTEXITCODE

$lines = @(Get-Content -Path $outFile)
$raw = Get-Content -Path $outFile -Raw
$proofs = @(
	"--- Tier 1 harness: PASS ---",
	"--- AOE footprint contract: PASS ---",
	"[PASS] Beast Rider Tier 2 live preview/factory gate",
	"0 failures",
	"test_live_beast_rider_every_skill",
	"[PASS] Beast Rider QA gate: matrix 32/32 + Tier 1 harness + Tier 2 live + AOE footprint PASS"
)
$missing = @()
foreach ($proof in $proofs) {
	if ($raw -notmatch [regex]::Escape($proof)) {
		$missing += $proof
	}
}
if ($lines.Count -lt 300) {
	$missing += "stdout line count $($lines.Count) -lt 300"
}
if ($missing.Count -gt 0) {
	Write-Output "[FAIL] Gauntlet BAR artifact incomplete:"
	$missing | ForEach-Object { Write-Output "  $_" }
	exit 5
}

Write-Output "[PASS] Gauntlet BAR artifact: $($lines.Count) lines -> $OutPath"
exit $gateExit
