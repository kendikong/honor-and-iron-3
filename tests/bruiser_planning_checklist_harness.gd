class_name BruiserPlanningChecklistHarness
extends RefCounted

## Bruiser planning fixtures — delegates to global class harness.

const _ClassFixture := preload("res://tests/class_planning_checklist_harness.gd")
const _Drag := preload("res://tests/planning_drag_e2e_harness.gd")


static func wire_board(
	bruiser_pos: Vector2i,
	enemy_pos: Vector2i = Vector2i(-1, -1),
	ally_pos: Vector2i = Vector2i(-1, -1),
	ability_id: StringName = &"",
) -> Dictionary:
	return _ClassFixture.wire_board(
		&"bruiser", bruiser_pos, enemy_pos, ally_pos, ability_id,
	)
