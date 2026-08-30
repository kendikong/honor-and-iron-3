param(
	[string]$InputPath = "",
	[string]$PaintPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$paintGd = if ($PaintPath -ne "") { $PaintPath } else {
	Join-Path $projectRoot "presentation\planning_settled_paint.gd"
}

Write-Output "=== AOE Footprint SSOT structural gate ==="

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $paintGd)) {
	$failures.Add("[FAIL] missing presentation/planning_settled_paint.gd")
}

$paintText = if (Test-Path -LiteralPath $paintGd) { Get-Content -LiteralPath $paintGd -Raw } else { "" }
$inputText = if (Test-Path -LiteralPath $inputGd) { Get-Content -LiteralPath $inputGd -Raw } else { "" }

if ($paintText -notmatch "planning_blast_tiles_at_target") {
	$failures.Add("[FAIL] settled paint must seal blast via AbilitySystem.planning_blast_tiles_at_target")
}
if ($paintText -notmatch "blast_tiles") {
	$failures.Add("[FAIL] settled paint missing blast_tiles field")
}
if ($inputText -notmatch "_SettledPaintBundle\.seal\(|PlanningSettledPaint\.seal\(") {
	$failures.Add("[FAIL] input does not seal footprint paint at settle")
}

if ($failures.Count -gt 0) {
	Write-Output "--- Footprint SSOT gate: FAIL ($($failures.Count)) ---"
	foreach ($line in $failures) { Write-Output $line }
	exit 1
}

Write-Output "--- Footprint SSOT gate: PASS ---"
exit 0
