class_name BruiserChargeStrikeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")


## Bible: Charge Strike — MOVE 2 | ATK 3 | PUSH 1; [+] GHOST during MOVE, ATK +2 through terrain.
## Globals: EffectType.MOVE + DAMAGE + PUSH; ghost_move / bonus_dmg_from_terrain modifiers on upgrade.
## Modules: M0 MOVE + M1 DAMAGE + M2 PUSH (see bruiser_factory)
## Planning tier: B
## Data/Sim delegate: tests/bruiser_qa_harness_scenarios.gd::run_charge_strike


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_charge_strike")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_charge_strike(failures)
		_run_postmove_planning_contract(failures)


static func _run_postmove_planning_contract(failures: Array[String]) -> void:
	const TAG := "charge_strike/postmove"
	const _Lib := preload("res://tests/movement_planning_smoke_lib.gd")
	const _Fixture := preload("res://tests/class_planning_checklist_harness.gd")
	const _Checklist := preload("res://tests/planning_checklist_harness.gd")
	const _Timeline := preload("res://tests/movement_timeline_qa_harness.gd")
	var actor_pos: Vector2i = Vector2i(1, 3)
	var enemy_pos: Vector2i = Vector2i(3, 3)
	var postmove_cell: Vector2i = Vector2i(1, 3)
	var fix: Dictionary = _Fixture.wire_board(
		&"bruiser", actor_pos, enemy_pos, Vector2i(-1, -1), &"bruiser_charge_strike",
	)
	if fix.is_empty():
		_Checklist.assert_fail(failures, TAG, "failed to wire planning board")
		return
	fix.director.auto_run = true
	var idx: int = _Checklist.select_ability(fix, &"bruiser_charge_strike")
	if idx < 0:
		_Checklist.assert_fail(failures, TAG, "Charge Strike missing on fixture")
		return
	var ability: AbilityData = fix.actor.active_abilities[idx]
	_Checklist.hover(fix, enemy_pos)
	var hover_slots: Dictionary = _Checklist.slots_for_hover(fix, enemy_pos)
	if _Checklist._slots_invalid(hover_slots):
		_Checklist.assert_fail(
			failures, TAG, "invalid commit slots at %s before post-move test" % enemy_pos,
		)
		return
	var unit_id: int = fix.director.selected_unit_id
	var commit_slots: Dictionary = _Checklist.commit_production(fix, enemy_pos)
	_Checklist.assert_true(
		failures, "%s/skill_commit" % TAG,
		not _Checklist._slots_invalid(commit_slots),
		"Charge Strike skill commit must succeed at %s" % enemy_pos,
	)
	_Checklist.assert_skill_timeline_columns(
		failures, "%s/timeline/columns" % TAG, fix.director, unit_id, ability, commit_slots,
	)
	_Lib._restore_movement_mp(fix, 2)
	_Timeline.commit_run_postmove_headless(failures, fix, ability, postmove_cell, TAG)
	_Timeline.assert_pre_or_post_leg_if_needed(
		failures, "%s/timeline" % TAG, fix.director, unit_id, ability,
	)
	_Timeline.assert_move_preview_origin(failures, TAG, fix, unit_id, ability)
	_Lib._assert_charge_strike_modules(failures, fix, TAG, enemy_pos, postmove_cell)
