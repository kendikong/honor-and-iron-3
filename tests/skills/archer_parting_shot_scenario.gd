class_name ArcherPartingShotScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/archer_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Bible: Parting Shot — RANGE 3 ATK 2, then MOVE 2 to chosen tile; [+] GHOST on retreat.
## Globals: modular DAMAGE + MOVE (NEW_AIM); AbilitySystem.set_module_target + Simulator.
## Modules: M0 DAMAGE enemy aim + M1 MOVE tile aim (NEW_AIM)
## Planning tier: B
## Data/Sim delegate: tests/archer_qa_harness_scenarios.gd::run_parting_shot


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"archer_parting_shot")


static func _sim_contract(failures: Array[String]) -> void:
	_Scenarios.run_parting_shot(failures)
	_run_postmove_planning_contract(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"archer_parting_shot")


static func _run_postmove_planning_contract(failures: Array[String]) -> void:
	const TAG := "parting_shot/postmove"
	const _Lib := preload("res://tests/movement_planning_smoke_lib.gd")
	const _Fixture := preload("res://tests/class_planning_checklist_harness.gd")
	const _Checklist := preload("res://tests/planning_checklist_harness.gd")
	const _Timeline := preload("res://tests/movement_timeline_qa_harness.gd")
	var actor_pos: Vector2i = Vector2i(2, 3)
	var enemy_pos: Vector2i = Vector2i(4, 3)
	var postmove_cell: Vector2i = Vector2i(2, 5)
	var fix: Dictionary = _Fixture.wire_board(
		&"archer", actor_pos, enemy_pos, Vector2i(-1, -1), &"archer_parting_shot",
	)
	if fix.is_empty():
		_Checklist.assert_fail(failures, TAG, "failed to wire planning board")
		return
	fix.director.auto_run = true
	var idx: int = _Checklist.select_ability(fix, &"archer_parting_shot")
	if idx < 0:
		_Checklist.assert_fail(failures, TAG, "Parting Shot missing on fixture")
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
		"Parting Shot attack commit must succeed at %s" % enemy_pos,
	)
	_Checklist.assert_skill_timeline_columns(
		failures, "%s/timeline/columns" % TAG, fix.director, unit_id, ability, commit_slots,
	)
	if _Timeline.action_movement_needs_pre_or_post_leg(ability):
		_Lib._restore_movement_mp(fix, 2)
		_Timeline.commit_run_postmove_headless(failures, fix, ability, postmove_cell, TAG)
		_Timeline.assert_pre_or_post_leg_if_needed(
			failures, "%s/timeline" % TAG, fix.director, unit_id, ability,
		)
	_Timeline.assert_move_preview_origin(failures, TAG, fix, unit_id, ability)
