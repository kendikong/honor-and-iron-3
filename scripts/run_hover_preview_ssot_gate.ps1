param(
	[string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$bundleGd = Join-Path $projectRoot "presentation\planning_hover_preview.gd"

Write-Output "=== Hover Preview Carried SSOT structural gate ==="
Write-Output "Spec: docs/design/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md"

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $bundleGd)) {
	$failures.Add("[FAIL] missing presentation/planning_hover_preview.gd (PlanningHoverPreview bundle)")
}
if (-not (Test-Path -LiteralPath $inputGd)) {
	$failures.Add("[FAIL] missing presentation/combat_planning_input.gd")
	exit 1
}

$text = Get-Content -LiteralPath $inputGd -Raw

$requiredSnippets = @(
	@{ label = "HoverPreviewBundle field"; pattern = "_settled_hover_preview:\s*_HoverPreviewBundle" },
	@{ label = "get_settled_hover_preview accessor"; pattern = "func get_settled_hover_preview\(\)" },
	@{ label = "HoverPreviewBundle.seal on settle"; pattern = "_HoverPreviewBundle\.seal\(" },
	@{ label = "ratify rejects missing bundle"; pattern = "no sealed hover preview" },
	@{ label = "settled preview apply path"; pattern = "func _apply_settled_preview_result\(" }
)
foreach ($req in $requiredSnippets) {
	if ($text -notmatch $req.pattern) {
		$failures.Add("[FAIL] required missing: $($req.label)")
	}
}

$forbiddenPatterns = @(
	@{ label = "paint-before-settle comment"; pattern = "## Paint preview_paths in memory first" },
	@{ label = "preserve-merge function"; pattern = "func _apply_preview_result_preserving_hover_paths" },
	@{ label = "commit fill move waypoints"; pattern = "func _ensure_move_waypoints_on_commit_slots" },
	@{ label = "commit fill ability waypoints"; pattern = "func _ensure_movement_waypoints_on_commit_slots" },
	@{ label = "commit ratify painted route"; pattern = "func _ratify_painted_route_on_commit_slots" },
	@{ label = "authoritative merge payload"; pattern = "func _authoritative_move_hover_paths_payload" }
)
foreach ($ban in $forbiddenPatterns) {
	if ($text -match $ban.pattern) {
		$failures.Add("[FAIL] forbidden still present: $($ban.label) ($($ban.pattern))")
	}
}

$postCommitMatch = [regex]::Match($text, "func _apply_post_commit_hover_truth\(\)[\s\S]*?\nfunc ")
if ($postCommitMatch.Success -and $postCommitMatch.Value -match "_refresh_hover_interaction_preview") {
	$failures.Add("[FAIL] post-commit still refreshes hover geometry (_refresh_hover_interaction_preview)")
}

# Click path must not rebuild slots when bundle missing (no _final_commit_slots_for_interaction in _commit_at_cell body).
$commitMatch = [regex]::Match($text, "func _commit_at_cell\([\s\S]*?\nfunc ")
if ($commitMatch.Success) {
	$commitBody = $commitMatch.Value
	if ($commitBody -match "_final_commit_slots_for_interaction\(") {
		$failures.Add("[FAIL] _commit_at_cell still rebuilds via _final_commit_slots_for_interaction")
	}
	if ($commitBody -match "_ensure_move_waypoints_on_commit_slots|_ratify_painted_route_on_commit_slots") {
		$failures.Add("[FAIL] _commit_at_cell still calls commit-time waypoint invent")
	}
} else {
	$failures.Add("[FAIL] could not parse _commit_at_cell for structural audit")
}

if ($failures.Count -gt 0) {
	Write-Output "--- SSOT structural gate: FAIL ($($failures.Count)) ---"
	foreach ($line in $failures) { Write-Output $line }
	exit 1
}

Write-Output "--- SSOT structural gate: PASS ---"
exit 0
