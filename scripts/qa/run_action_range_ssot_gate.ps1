param(
	[string]$OverlayPath = "",
	[string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$overlayGd = if ($OverlayPath -ne "") { $OverlayPath } else {
	Join-Path $projectRoot "presentation\tactical_planning_overlay.gd"
}
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$paintGd = Join-Path $projectRoot "presentation\planning_settled_paint.gd"

Write-Output "=== Action Range / Latest Stand SSOT structural gate ==="
Write-Output "Spec: docs/design/planning/ACTION_RANGE_LATEST_STAND.md"

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $paintGd)) {
	$failures.Add("[FAIL] missing presentation/planning_settled_paint.gd")
}
if (-not (Test-Path -LiteralPath $inputGd)) {
	$failures.Add("[FAIL] missing presentation/combat_planning_input.gd")
}
if (-not (Test-Path -LiteralPath $overlayGd)) {
	$failures.Add("[FAIL] missing presentation/tactical_planning_overlay.gd")
}

$inputText = if (Test-Path -LiteralPath $inputGd) { Get-Content -LiteralPath $inputGd -Raw } else { "" }
$overlayText = if (Test-Path -LiteralPath $overlayGd) { Get-Content -LiteralPath $overlayGd -Raw } else { "" }

$requiredInput = @(
	@{ label = "settled paint field"; pattern = "_settled_paint:\s*PlanningSettledPaint|_SettledPaintBundle" },
	@{ label = "get_settled_paint accessor"; pattern = "func get_settled_paint\(\)" },
	@{ label = "PlanningSettledPaint.seal on settle"; pattern = "_SettledPaintBundle\.seal\(|PlanningSettledPaint\.seal\(" }
)
foreach ($req in $requiredInput) {
	if ($inputText -notmatch $req.pattern) {
		$failures.Add("[FAIL] input required missing: $($req.label)")
	}
}

if ($overlayText -notmatch "get_settled_paint\(\)") {
	$failures.Add("[FAIL] overlay does not read sealed paint bundle")
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
	Write-Output "--- Action range SSOT gate: FAIL ($($failures.Count)) ---"
	foreach ($line in $failures) { Write-Output $line }
	exit 1
}

Write-Output "--- Action range SSOT gate: PASS ---"
exit 0
