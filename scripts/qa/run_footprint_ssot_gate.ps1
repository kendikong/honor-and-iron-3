param(
	[string]$InputPath = "",
	[string]$TilesPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$tilesGd = if ($TilesPath -ne "") { $TilesPath } else {
	Join-Path $projectRoot "presentation\planning_preview_tiles.gd"
}

Write-Output "=== AOE Footprint SSOT structural gate ==="

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $tilesGd)) {
	$failures.Add("[FAIL] missing presentation/planning_preview_tiles.gd")
}

$tilesText = if (Test-Path -LiteralPath $tilesGd) { Get-Content -LiteralPath $tilesGd -Raw } else { "" }
$inputText = if (Test-Path -LiteralPath $inputGd) { Get-Content -LiteralPath $inputGd -Raw } else { "" }

if ($tilesText -notmatch "static func resolve_paint\(") {
	$failures.Add("[FAIL] PlanningPreviewTiles must own settled paint resolution")
}
if ($tilesText -notmatch "static func blast_tiles\(" -or $tilesText -notmatch "planning_blast_tiles_at_target") {
	$failures.Add("[FAIL] PlanningPreviewTiles must own AbilitySystem blast footprint")
}
if ($inputText -notmatch "PlanningPreviewTiles\.resolve_paint\(" -or $inputText -notmatch "_HoverPreviewBundle\.seal\(") {
	$failures.Add("[FAIL] input does not carry footprint paint in sealed hover bundle")
}

if ($failures.Count -gt 0) {
	Write-Output "--- Footprint SSOT gate: FAIL ($($failures.Count)) ---"
	foreach ($line in $failures) { Write-Output $line }
	exit 1
}

Write-Output "--- Footprint SSOT gate: PASS ---"
exit 0
