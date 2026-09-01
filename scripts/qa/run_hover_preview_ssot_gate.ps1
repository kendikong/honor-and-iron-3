param(
	[string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "ssot_gate_helpers.ps1")
$inputGd = if ($InputPath -ne "") { $InputPath } else {
	Join-Path $projectRoot "presentation\combat_planning_input.gd"
}
$bundleGd = Join-Path $projectRoot "presentation\planning_hover_preview.gd"

Write-Output "=== Hover Preview Carried SSOT structural gate ==="
Write-Output "Spec: docs/design/planning/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md"

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
	@{ label = "ratify rejects missing bundle"; pattern = "no settled hover preview" },
	@{ label = "single sealed intent ratify"; pattern = "ratify_sealed_intent\(" },
	@{ label = "settled preview apply path"; pattern = "func _apply_settled_preview_result\(" },
	@{ label = "sealed movement paint"; pattern = "move_tiles" },
	@{ label = "authoritative preview paths accessor"; pattern = "func _authoritative_preview_paths\(\)" },
	@{ label = "authoritative route accessor"; pattern = "func _authoritative_route_for_unit\(" }
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
	@{ label = "authoritative merge payload"; pattern = "func _authoritative_move_hover_paths_payload" },
	@{ label = "ghost voluntary walk writer"; pattern = "func _write_voluntary_walk_preview_path" }
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
	if ($commitBody -match "_intent_snapshot_matches_interaction|_finalize_commit_slots|_paint_intent_slots_before_commit|commit_from_slots\(") {
		$failures.Add("[FAIL] _commit_at_cell still has snapshot/finalize commit rebuild")
	}
} else {
	$failures.Add("[FAIL] could not parse _commit_at_cell for structural audit")
}

$interactMatch = [regex]::Match($text, "func _commit_at_interaction_cell\([\s\S]*?\nfunc ")
if ($interactMatch.Success) {
	$interactBody = $interactMatch.Value
	if ($interactBody -match "_final_commit_slots_for_click|_slots_with_facing_for_commit|_intent_snapshot_matches_interaction") {
		$failures.Add("[FAIL] _commit_at_interaction_cell still rebuilds slots at click")
	}
} else {
	$failures.Add("[FAIL] could not parse _commit_at_interaction_cell for structural audit")
}

$dropMatch = [regex]::Match($text, "func _process_unit_drop\([\s\S]*?\nfunc ")
if ($dropMatch.Success) {
	$dropBody = $dropMatch.Value
	if ($dropBody -match "_commit_at_cell\(") {
		$failures.Add("[FAIL] _process_unit_drop still calls _commit_at_cell (drag must use _commit_at_interaction_cell)")
	}
	if ($dropBody -match "_route_waypoints_for_commit\(\)") {
		$failures.Add("[FAIL] _process_unit_drop still injects drop-time route waypoints")
	}
	if ($dropBody -notmatch "_commit_at_interaction_cell\(") {
		$failures.Add("[FAIL] _process_unit_drop missing _commit_at_interaction_cell (drag == hover)")
	}
} else {
	$failures.Add("[FAIL] could not parse _process_unit_drop for drag/hover parity audit")
}

$harnessPath = Join-Path $projectRoot "tests\harness\planning_checklist_harness.gd"
if (-not (Test-Path -LiteralPath $harnessPath)) {
	$harnessPath = Join-Path $projectRoot "tests\planning_checklist_harness.gd"
}
if (Test-Path -LiteralPath $harnessPath) {
	$harnessText = Get-Content -LiteralPath $harnessPath -Raw
	$hoverFn = [regex]::Match($harnessText, 'static func slots_for_hover\([\s\S]*?\n\n')
	if ($hoverFn.Success -and $hoverFn.Value -match '_final_commit_slots_for_interaction\(') {
		$failures.Add("[FAIL] planning_checklist_harness slots_for_hover still rebuilds with empty waypoints")
	}
	$clickFn = [regex]::Match($harnessText, 'static func slots_for_click\([\s\S]*?\n\n')
	if ($clickFn.Success -and $clickFn.Value -match '_final_commit_slots_for_click') {
		$failures.Add("[FAIL] planning_checklist_harness slots_for_click still rebuilds at click")
	}
}

if ($failures.Count -gt 0) {
	Write-SsotGateResult "Hover preview carried SSOT gate" $failures | Out-Null
	exit 1
}

Write-Output "--- SSOT structural gate: PASS ---"
exit 0
