param(
	[string]$OverlayPath = "",
	[string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "ssot_gate_helpers.ps1")
$overlayGd = if ($OverlayPath -ne "") { $OverlayPath } else {
	Join-Path $projectRoot "presentation\tactical_planning_overlay.gd"
}
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$hoverGd = Join-Path $projectRoot "presentation\planning_hover_preview.gd"
$tilesGd = Join-Path $projectRoot "presentation\planning_preview_tiles.gd"

Write-Output "=== Action Range / Latest Stand SSOT structural gate ==="
Write-Output "Spec: docs/design/planning/ACTION_RANGE_LATEST_STAND.md"

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $hoverGd)) {
	$failures.Add("[FAIL] missing presentation/planning_hover_preview.gd")
}
if (-not (Test-Path -LiteralPath $tilesGd)) {
	$failures.Add("[FAIL] missing presentation/planning_preview_tiles.gd")
}
if (-not (Test-Path -LiteralPath $inputGd)) {
	$failures.Add("[FAIL] missing presentation/combat_planning_input.gd")
}
if (-not (Test-Path -LiteralPath $overlayGd)) {
	$failures.Add("[FAIL] missing presentation/tactical_planning_overlay.gd")
}

$inputText = if (Test-Path -LiteralPath $inputGd) { Get-Content -LiteralPath $inputGd -Raw } else { "" }
$overlayText = if (Test-Path -LiteralPath $overlayGd) { Get-Content -LiteralPath $overlayGd -Raw } else { "" }
$tilesText = if (Test-Path -LiteralPath $tilesGd) { Get-Content -LiteralPath $tilesGd -Raw } else { "" }

$requiredInput = @(
	@{ label = "hover bundle seal"; pattern = "_HoverPreviewBundle\.seal\(" },
	@{ label = "paint resolver on settle"; pattern = "PlanningPreviewTiles\.resolve_paint\(" },
	@{ label = "settled hover revision accessor"; pattern = "func settled_hover_revision_key\(\)" }
)
foreach ($req in $requiredInput) {
	if ($inputText -notmatch $req.pattern) {
		$failures.Add("[FAIL] input required missing: $($req.label)")
	}
}

if ($overlayText -notmatch "get_settled_hover_preview\(\)") {
	$failures.Add("[FAIL] overlay does not read sealed hover bundle")
}
if ($overlayText -notmatch "matches_paint_context\(") {
	$failures.Add("[FAIL] overlay does not validate settled paint context")
}
if ($overlayText -notmatch "settled\.move_tiles") {
	$failures.Add("[FAIL] overlay does not consume sealed movement paint")
}
if ($tilesText -notmatch "static func resolve_paint\(" -or $tilesText -notmatch "static func action_range_tiles\(") {
	$failures.Add("[FAIL] PlanningPreviewTiles does not own settled action-range paint")
}
if ($tilesText -notmatch "static func resolve_move_tiles\(") {
	$failures.Add("[FAIL] PlanningPreviewTiles does not own settled movement paint")
}

$rangeFn = [regex]::Match($overlayText, "func _planning_action_range_tiles_for_unit\([\s\S]*?\nfunc ")
if (-not $rangeFn.Success) {
	$failures.Add("[FAIL] could not parse _planning_action_range_tiles_for_unit")
} else {
	$rangeBody = ($rangeFn.Value -split "`n" | Where-Object { $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' })
	$rangeJoined = $rangeBody -join "`n"
	if ($rangeJoined -match "base_board") {
		$failures.Add("[FAIL] _planning_action_range_tiles_for_unit references base_board")
	}
}

$blastFn = [regex]::Match($overlayText, "func _compute_hover_blast_action_range_tiles\([\s\S]*?\nfunc ")
if ($blastFn.Success) {
	$blastBody = ($blastFn.Value -split "`n" | Where-Object { $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' })
	$blastJoined = $blastBody -join "`n"
	if ($blastJoined -match "base_board") {
		$failures.Add("[FAIL] _compute_hover_blast_action_range_tiles references base_board")
	}
}

if ($failures.Count -gt 0) {
	Write-SsotGateResult "Action range latest stand SSOT gate" $failures | Out-Null
	exit 1
}

Write-Output "--- Action range SSOT gate: PASS ---"
exit 0
