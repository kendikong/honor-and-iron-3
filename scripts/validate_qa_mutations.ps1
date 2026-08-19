param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-QaGate {
	$outFile = Join-Path $env:TEMP ("qa_gate_{0}.txt" -f [guid]::NewGuid().ToString("N"))
	$errFile = "$outFile.err"
	. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
	$p = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $root, "res://tests/PlanningQaGate.tscn") `
		-PassThru `
		-RedirectStandardOutput $outFile `
		-RedirectStandardError $errFile
	$exitCode = Wait-GodotProcessWithEscCancel -Process $p -Label "Planning QA mutation gate"
	if ($exitCode -eq 130) {
		if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
		if (Test-Path $errFile) { Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
		return @{ ExitCode = 130; Fails = @("[CANCEL] ESC"); Count = 0; Output = "[CANCEL] ESC" }
	}
	$all = ""
	if (Test-Path $outFile) {
		$raw = Get-Content $outFile -Raw
		if ($null -ne $raw) { $all = $raw }
		Remove-Item $outFile -Force -ErrorAction SilentlyContinue
	}
	if (Test-Path $errFile) {
		$rawErr = Get-Content $errFile -Raw
		if ($null -ne $rawErr) { $all += "`n" + $rawErr }
		Remove-Item $errFile -Force -ErrorAction SilentlyContinue
	}
	$fails = @([regex]::Matches($all, '\[FAIL\][^\r\n]*') | ForEach-Object { $_.Value })
	return @{ ExitCode = $exitCode; Fails = $fails; Count = $fails.Count; Output = $all }
}

function Normalize-Newlines([string]$text) {
	return $text -replace "`r`n", "`n"
}

function Set-Patch($rel, $old, $new) {
	$path = Join-Path $root $rel
	$o = Normalize-Newlines $old
	$n = Normalize-Newlines $new
	for ($attempt = 0; $attempt -lt 8; $attempt++) {
		$c = Normalize-Newlines ([IO.File]::ReadAllText($path))
		if (-not $c.Contains($o)) { throw "Anchor not found in $rel`n--- expected ---`n$o" }
		try {
			[IO.File]::WriteAllText($path, $c.Replace($o, $n))
			return
		}
		catch [System.IO.IOException] {
			if ($attempt -ge 7) { throw }
			Start-Sleep -Milliseconds 400
		}
	}
}

Write-Host "=== Baseline ===" -ForegroundColor Cyan
$base = Invoke-QaGate
if ($base.Count -gt 0 -or $base.Output -notmatch '\[PASS\]') {
	Write-Host $base.Output
	throw "Baseline must PASS (found $($base.Count) fails)"
}
Write-Host "PASS (exit 0)"

$mutations = @(
	@{
		Name = "1_red_always_visible"
		File = "presentation/combat_planning_input.gd"
		Old = @"
	if ability == null or AbilitySystem.is_run_ability(ability) or AbilitySystem.is_wait_ability(ability):
		return false
"@
		New = @"
	if ability == null or AbilitySystem.is_run_ability(ability) or AbilitySystem.is_wait_ability(ability):
		return false
	return true  # QA_MUT
"@
		ExpectMinFails = 1
	},
	@{
		Name = "2_bash_no_approach"
		File = "presentation/combat_director.gd"
		Old = "	return _find_approach_tile(proj, actor, target.position, rng, preferred_tile)"
		New = "	return actor.position  # QA_MUT"
		ExpectMinFails = 3
	},
	@{
		Name = "3_no_ap_spend"
		File = "core/systems/ability_system.gd"
		Old = @"
static func _spend_ability_cost(actor: UnitState, ability: AbilityData, board: BoardState = null) -> void:
	if actor == null or ability == null:
		return
		
	var ap_cost = get_action_point_cost(actor, ability, board)
			
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			actor.movement.points_left -= ability.movement_point_cost
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			actor.ability.points_left -= ap_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			actor.ability.points_left -= ap_cost
"@
		New = @"
static func _spend_ability_cost(actor: UnitState, ability: AbilityData, board: BoardState = null) -> void:
	if actor == null or ability == null:
		return
		
	var ap_cost = get_action_point_cost(actor, ability, board)
			
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			actor.movement.points_left -= ability.movement_point_cost
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			actor.ability.points_left -= ap_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			pass  # QA_MUT
"@
		ExpectMinFails = 1
	},
	@{
		Name = "4_skip_promote"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _promote_intent_preview_after_commit() -> void:
	_suppress_post_commit_hover_refresh = true
"@
		New = @"
func _promote_intent_preview_after_commit() -> void:
	return  # QA_MUT
	_suppress_post_commit_hover_refresh = true
"@
		ExpectMinFails = 1
	},
	@{
		Name = "5_push_reversed"
		File = "core/systems/physics_system.gd"
		Old = @"
static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
"@
		New = @"
static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	direction = -direction  # QA_MUT
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
"@
		ExpectMinFails = 4
	},
	@{
		Name = "6_hook_wrong_stand"
		File = "presentation/combat_director.gd"
		Old = @"
	var rng: int = actor.get_ability_range(ability)
	if GridSystem.manhattan(actor.position, target.position) <= rng:
		return actor.position
	return _find_approach_tile(proj, actor, target.position, rng, preferred_tile)
"@
		New = @"
	var rng: int = actor.get_ability_range(ability)
	if GridSystem.manhattan(actor.position, target.position) <= rng:
		return preferred_tile  # QA_MUT
	return _find_approach_tile(proj, actor, target.position, rng, preferred_tile)
"@
		ExpectMinFails = 1
	},
	@{
		Name = "7_invalid_sim_passes"
		Coverage = "preview_commit_valid, OOB commit, invalid_slots_block_commit"
		File = "presentation/combat_director.gd"
		Old = @"
		if int(e.data.get("actor", -1)) == unit_id:
			return e.data.get("reason", "cannot_use_ability") as String
	return ""
"@
		New = @"
		if int(e.data.get("actor", -1)) == unit_id:
			return ""  # QA_MUT
	return ""
"@
		ExpectMinFails = 1
	},
	@{
		Name = "8_undo_clears_premove"
		Coverage = "undo_action_keeps_premove, undo_movement_action_preserves_premove"
		File = "presentation/combat_director.gd"
		Old = @"
					var removed: TimelineAction = plan_action.entries[i]
					plan_action.remove_at(i)
					_begin_undo_plan_refresh(unit_id)
"@
		New = @"
					var removed: TimelineAction = plan_action.entries[i]
					plan_action.remove_at(i)
					plan_pre_move.clear()  # QA_MUT
					_begin_undo_plan_refresh(unit_id)
"@
		ExpectMinFails = 1
	},
	@{
		Name = "9_cursor_empty"
		Coverage = "cursor walk/run/composite, click_drop_cursor_parity, scenario phase3"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _cursor_icon_from_commit_slots(slots: Dictionary, unit: UnitState = null) -> String:
	if _is_invalid_dict(slots):
		return PlanningIcons.GLYPH_NULL
"@
		New = @"
func _cursor_icon_from_commit_slots(slots: Dictionary, unit: UnitState = null) -> String:
	return ""  # QA_MUT
	if _is_invalid_dict(slots):
		return PlanningIcons.GLYPH_NULL
"@
		ExpectMinFails = 3
	},
	@{
		Name = "10_no_blue_tiles"
		Coverage = "blue move tiles, scenario phase1, drag walk, MP budget"
		File = "presentation/tactical_planning_overlay.gd"
		Old = @"
			_hover_move_tiles = MovementSystem.get_reachable_tiles(
				move_board,
				move_from,
				move_budget,
				mt,
				move_cost,
				null,
			)
"@
		New = @"
			_hover_move_tiles = []  # QA_MUT
"@
		ExpectMinFails = 1
	},
	@{
		Name = "11_trample_no_awaiting"
		Coverage = "trample e2e, trample scenario, awaiting_plan_refresh, action_range awaiting"
		File = "presentation/combat_director.gd"
		Old = @"
func find_awaiting_action(unit_id: int) -> TimelineAction:
	if unit_id < 0:
		return null
"@
		New = @"
func find_awaiting_action(unit_id: int) -> TimelineAction:
	return null  # QA_MUT
	if unit_id < 0:
		return null
"@
		ExpectMinFails = 5
	},
	@{
		Name = "12_drag_no_append"
		Coverage = "waypoint_paint_order, trample paint/commit, drop_commit_preserves_drag_route"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _extend_drag_route(cell: Vector2i) -> void:
	if _drag_route.is_empty():
		return
"@
		New = @"
func _extend_drag_route(cell: Vector2i) -> void:
	return  # QA_MUT
	if _drag_route.is_empty():
		return
"@
		ExpectMinFails = 4
	},
	@{
		Name = "13_click_slots_invalid"
		Coverage = "hover_click_drop_slot_parity, click_drop_parity_*, commit_plan_matches_hover"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _final_commit_slots_for_click_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
) -> Dictionary:
	if _director == null or _director.board == null or unit_id < 0:
"@
		New = @"
func _final_commit_slots_for_click_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
) -> Dictionary:
	return {"invalid": "QA_MUT"}  # QA_MUT
	if _director == null or _director.board == null or unit_id < 0:
"@
		ExpectMinFails = 5
	},
	@{
		Name = "14_walk_sim_wrong_dest"
		Coverage = "walk/trample sim, click_drop_commit_sim, committed_walk_preview_matches_sim"
		File = "core/systems/movement_system.gd"
		Old = "	unit.position = path[path.size() - 1]"
		New = "	unit.position = from  # QA_MUT"
		ExpectMinFails = 5
	},
	@{
		Name = "15_ability_no_cache_clear"
		Coverage = "ability_switch_clears_preview_cache, ability_scroll_clears_hover_preview_cache"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _on_ability_selected(_index: int) -> void:
	if _director == null:
		return
	_invalidate_planning_hover_cache(false)
"@
		New = @"
func _on_ability_selected(_index: int) -> void:
	return  # QA_MUT
	if _director == null:
		return
	_invalidate_planning_hover_cache(false)
"@
		ExpectMinFails = 1
	},
	@{
		Name = "16_ghost_never_clears"
		Coverage = "timeline_ghost_clears_when_committed, timeline_ghost_slots"
		File = "presentation/combat_planning_input.gd"
		Old = @"
	var intent: Dictionary = _duplicate_commit_slots(_intent_snapshot_slots)
	var committed: Dictionary = _committed_plan_slots(unit_id)
	for col: String in ["pre", "action", "post"]:
"@
		New = @"
	var intent: Dictionary = _duplicate_commit_slots(_intent_snapshot_slots)
	return intent  # QA_MUT
	var committed: Dictionary = _committed_plan_slots(unit_id)
	for col: String in ["pre", "action", "post"]:
"@
		ExpectMinFails = 1
	},
	@{
		Name = "17_strip_waypoints_on_commit"
		Coverage = "trample_commit_preserves_waypoints, full_slot_signature, trample_paint_commit_sim"
		File = "presentation/combat_director.gd"
		Old = @"
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				actions.append(action)
				plans.append(_slot_plan_for_action(action))
"@
		New = @"
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				action.waypoints.clear()  # QA_MUT
				actions.append(action)
				plans.append(_slot_plan_for_action(action))
"@
		ExpectMinFails = 2
	},
	@{
		Name = "18_run_never_required"
		Coverage = "run_economy scenario, action_range_auto_run_ap_gate, planning_display_ap_run"
		File = "core/systems/ability_system.gd"
		Old = @"
static func movement_requires_run(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> bool:
	if unit == null or unit.has_run_boost():
		return false
"@
		New = @"
static func movement_requires_run(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> bool:
	return false  # QA_MUT
	if unit == null or unit.has_run_boost():
		return false
"@
		ExpectMinFails = 2
	},
	@{
		Name = "19_oob_click_allows_empty"
		Coverage = "click_drop_parity_oob, out_of_range_hover_is_invalid, invalid_slots_block_commit"
		File = "presentation/combat_planning_input.gd"
		Old = @"
	if not _director.board.is_in_bounds(cell):
		return {"invalid": "Out of bounds."}
	if selected_phase_action_exhausted(unit_id):
		return _empty_commit_slots()
	var unit_at: UnitState = _unit_at_input_cell(cell)
"@
		New = @"
	if not _director.board.is_in_bounds(cell):
		return _empty_commit_slots()  # QA_MUT
	if selected_phase_action_exhausted(unit_id):
		return _empty_commit_slots()
	var unit_at: UnitState = _unit_at_input_cell(cell)
"@
		ExpectMinFails = 1
	},
	@{
		Name = "20_drag_corridor_direct"
		Coverage = "jump_drag_autocorrect, stale_hover_updates_commit_waypoints, shield_bash stale approach"
		File = "core/systems/movement_system.gd"
		Old = @"
) -> Array[Vector2i]:
	if start == goal:
		return []
	var corridor: Array[Vector2i] = []
"@
		New = @"
) -> Array[Vector2i]:
	return [goal]  # QA_MUT
	if start == goal:
		return []
	var corridor: Array[Vector2i] = []
"@
		ExpectMinFails = 1
	},
	@{
		Name = "21_drop_slots_invalid"
		Coverage = "click_drop_drag_walk_sim_parity, click_drop_drag_bash_enemy_parity, drop_commit"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _final_commit_slots_for_drop_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	legal_move_tiles: Array[Vector2i],
) -> Dictionary:
	if _director == null or _director.board == null or unit_id < 0:
"@
		New = @"
func _final_commit_slots_for_drop_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	legal_move_tiles: Array[Vector2i],
) -> Dictionary:
	return {"invalid": "QA_MUT"}  # QA_MUT
	if _director == null or _director.board == null or unit_id < 0:
"@
		ExpectMinFails = 3
	},
	@{
		Name = "22_display_mp_wrong"
		Coverage = "planning_display_mp_left, planning_input MP display"
		File = "presentation/combat_planning_input.gd"
		Old = "	return AbilitySystem.planning_display_mp_left(committed, live_actor, live_valid)"
		New = "	return 999  # QA_MUT"
		ExpectMinFails = 1
	},
	@{
		Name = "23_committed_run_reclassified_as_walk"
		Coverage = "intent_contract/bowling_run, committed run timeline AP projection"
		File = "core/systems/ability_system.gd"
		Old = "	var needs_run: bool = force_run or movement_requires_run(board, actor, premove_cell, [])"
		New = "	var needs_run: bool = movement_requires_run(board, actor, premove_cell, [])  # QA_MUT"
		ExpectMinFails = 1
	}
)

$report = @()
foreach ($m in $mutations) {
	Write-Host "`n=== $($m.Name) ===" -ForegroundColor Yellow
	Set-Patch $m.File $m.Old $m.New
	$patched = Normalize-Newlines ([IO.File]::ReadAllText((Join-Path $root $m.File)))
	if ($patched -notmatch 'QA_MUT') { throw "Patch did not apply for $($m.Name)" }
	try {
		$r = Invoke-QaGate
		$ok = ($r.ExitCode -ne 0) -and ($r.Count -ge $m.ExpectMinFails)
		$report += [pscustomobject]@{
			Mutation = $m.Name
			Coverage = $m.Coverage
			Exit = $r.ExitCode
			FailCount = $r.Count
			Expected = $(if ($ok) { "CAUGHT" } else { "MISSED" })
			Sample = ($r.Fails | Select-Object -First 3) -join " | "
		}
		if ($ok) { Write-Host "CAUGHT ($($r.Count) failures)" -ForegroundColor Green }
		else {
			Write-Host "MISSED (exit=$($r.ExitCode) fails=$($r.Count), need >=$($m.ExpectMinFails))" -ForegroundColor Red
			if ($r.Count -gt 0) { $r.Fails | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" } }
		}
	}
	finally {
		Set-Patch $m.File $m.New $m.Old
	}
}

Write-Host "`n=== Post-revert baseline ===" -ForegroundColor Cyan
$final = Invoke-QaGate
if ($final.ExitCode -ne 0) { throw "Revert incomplete (exit $($final.ExitCode))" }
Write-Host "PASS"

$report | Format-Table -AutoSize
$report | ConvertTo-Json | Set-Content (Join-Path $root "tests/qa_mutation_report.json")
$missed = @($report | Where-Object { $_.Expected -eq "MISSED" })
if ($missed.Count -gt 0) {
	Write-Host "`n$($missed.Count) mutation(s) MISSED - QA gap" -ForegroundColor Red
	exit 1
}
Write-Host "`nAll mutations caught by QA gate." -ForegroundColor Green
exit 0
