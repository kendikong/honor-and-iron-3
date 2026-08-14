class_name ClassScenarioPlanningContract
extends RefCounted

## Tier B planning + movement smoke entry for per-row class scenarios (CLASS_QA_BIBLE.md §3 Layer C).

const _Fixture := preload("res://tests/class_planning_checklist_harness.gd")
const _Checklist := preload("res://tests/planning_checklist_harness.gd")
const _MovementRegistry := preload("res://tests/movement_planning_smoke_registry.gd")
const _AoeHarness := preload("res://tests/aoe_footprint_qa_harness.gd")


static func run_for_factory(failures: Array[String], factory_id: StringName) -> void:
	if _MovementRegistry.has_entry(factory_id):
		_MovementRegistry.run_for_factory_id(failures, factory_id)
		return
	var class_id: StringName = _class_id_from_factory(factory_id)
	if class_id == &"":
		return
	run_tier_b_commit_smoke(failures, class_id, factory_id)


static func run_tier_b_commit_smoke(
	failures: Array[String],
	class_id: StringName,
	factory_id: StringName,
) -> void:
	var ability: AbilityData = _AoeHarness.find_ability_by_id(factory_id)
	if ability == null:
		_Checklist.assert_fail(
			failures, "%s/planning/missing_ability" % factory_id,
			"ability not found for planning contract",
		)
		return
	var layout: Dictionary = _layout_for(factory_id, ability)
	var actor_pos: Vector2i = layout.actor_pos
	var enemy_pos: Vector2i = layout.enemy_pos
	var ally_pos: Vector2i = layout.ally_pos
	var commit_cell: Vector2i = layout.commit_cell
	var verify_no_jump: bool = layout.verify_no_jump
	var select_only: bool = layout.get("select_only", false)
	var fix: Dictionary = _Fixture.wire_board(
		class_id, actor_pos, enemy_pos, ally_pos, factory_id,
	)
	if fix.is_empty():
		_Checklist.assert_fail(failures, "%s/planning/wire" % factory_id, "fixture wire failed")
		return
	_apply_beast_planning_setup(fix, factory_id)
	_apply_engineer_planning_setup(fix, factory_id)
	fix.director.auto_run = true
	var idx: int = _Checklist.select_ability(fix, factory_id)
	_Checklist.assert_true(
		failures, "%s/planning/select" % factory_id,
		idx >= 0, "%s must be selectable" % factory_id,
	)
	if idx < 0:
		return
	var blue: Array[Vector2i] = _Checklist.collect_blue_tiles(fix)
	_Checklist.assert_true(
		failures, "%s/planning/blue_tiles" % factory_id,
		not blue.is_empty(), "blue move tiles must show after ability select",
	)
	if select_only:
		return
	_Checklist.hover(fix, commit_cell)
	if _AoeHarness.ability_requires_footprint_qa(ability):
		_assert_shaped_footprint(failures, factory_id, fix, ability, commit_cell)
	var hover_slots: Dictionary = _Checklist.slots_for_hover(fix, commit_cell)
	if _Checklist._slots_invalid(hover_slots):
		_Checklist.assert_fail(
			failures, "%s/planning/invalid_slots" % factory_id,
			"no valid commit slots at %s" % commit_cell,
		)
		return
	_Checklist.assert_slots_match_preview_commit(
		failures, "%s/planning/hover_click_parity" % factory_id, fix, commit_cell,
	)
	if verify_no_jump:
		_Checklist.assert_commit_no_jump(
			failures, "%s/planning/no_jump" % factory_id, fix, commit_cell,
		)


static func _layout_for(factory_id: StringName, ability: AbilityData) -> Dictionary:
	var actor_pos: Vector2i = Vector2i(2, 3)
	var enemy_pos: Vector2i = Vector2i(5, 3)
	var ally_pos: Vector2i = Vector2i(-1, -1)
	var commit_cell: Vector2i = enemy_pos
	var verify_no_jump: bool = true
	var select_only: bool = false
	match factory_id:
		&"bruiser_meat_shield", &"archer_repelling_shot":
			ally_pos = Vector2i(3, 3)
			commit_cell = ally_pos
			enemy_pos = Vector2i(6, 3)
			verify_no_jump = false
		&"bruiser_cleave", &"bruiser_earthshatter":
			actor_pos = Vector2i(3, 3)
			enemy_pos = Vector2i(4, 3)
			commit_cell = Vector2i(4, 3)
		&"lancer_sweeping_halberd":
			actor_pos = Vector2i(3, 3)
			enemy_pos = Vector2i(4, 3)
			commit_cell = Vector2i(4, 3)
		&"mage_time_warp":
			ally_pos = Vector2i(3, 3)
			commit_cell = ally_pos
			enemy_pos = Vector2i(-1, -1)
		&"mage_density_shift":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(5, 3)
			commit_cell = Vector2i(4, 3)
			verify_no_jump = false
		&"cleric_holy_light", &"cleric_life_link", &"cleric_prayer_of_fortitude":
			ally_pos = Vector2i(3, 3)
			commit_cell = ally_pos
		&"cleric_resurrection":
			ally_pos = Vector2i(3, 3)
			commit_cell = ally_pos
			verify_no_jump = false
		&"cleric_divine_guidance", &"cleric_shield_of_faith":
			ally_pos = Vector2i(3, 3)
			commit_cell = ally_pos
		&"cleric_martyrs_chains":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(5, 3)
			commit_cell = Vector2i(5, 3)
			select_only = true
		&"mercenary_swift_strike":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(5, 3)
			commit_cell = enemy_pos
			verify_no_jump = false
		&"mercenary_acrobatic_vault":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(5, 3)
			commit_cell = enemy_pos
			verify_no_jump = false
		&"mercenary_executioners_blade":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(3, 3)
			commit_cell = enemy_pos
			select_only = true
		&"mercenary_tactical_retreat":
			actor_pos = Vector2i(4, 3)
			commit_cell = Vector2i(1, 3)
			verify_no_jump = false
		&"beast_feral_drag":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(3, 3)
			commit_cell = Vector2i(3, 3)
			select_only = true
		&"beast_savage_bite":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(3, 3)
			commit_cell = Vector2i(3, 3)
			select_only = true
		&"beast_reposition":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(3, 3)
			commit_cell = Vector2i(3, 3)
			verify_no_jump = false
		&"engineer_recall":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(-1, -1)
			commit_cell = Vector2i(3, 3)
			verify_no_jump = false
		&"engineer_wrench_smack", &"engineer_manual_detonation", &"engineer_overdrive_injection":
			actor_pos = Vector2i(2, 3)
			ally_pos = Vector2i(3, 3)
			commit_cell = Vector2i(3, 3)
			enemy_pos = Vector2i(-1, -1)
			verify_no_jump = false
		&"engineer_sludge_bomb", &"engineer_frag_bomb", &"engineer_emp_grenade":
			actor_pos = Vector2i(5, 5)
			enemy_pos = Vector2i(6, 5)
			commit_cell = Vector2i(6, 5)
			select_only = true
		&"engineer_scrap_shield":
			actor_pos = Vector2i(2, 3)
			ally_pos = Vector2i(3, 3)
			commit_cell = Vector2i(3, 3)
			enemy_pos = Vector2i(-1, -1)
			select_only = true
		&"engineer_construct_turret", &"engineer_magnetic_mine", &"engineer_tesla_barricade":
			actor_pos = Vector2i(2, 3)
			commit_cell = Vector2i(4, 3)
			enemy_pos = Vector2i(-1, -1)
		&"beast_bestial_roar":
			actor_pos = Vector2i(3, 3)
			enemy_pos = Vector2i(4, 3)
			commit_cell = Vector2i(4, 3)
		&"mercenary_flank_and_run":
			actor_pos = Vector2i(2, 3)
			enemy_pos = Vector2i(4, 3)
			commit_cell = Vector2i(2, 5)
			verify_no_jump = false
		_:
			if ability.targeting_flags & GameEnums.TargetingFlags.SELF:
				commit_cell = actor_pos
			elif ability.targeting_flags & GameEnums.TargetingFlags.ALLY:
				ally_pos = Vector2i(3, 3)
				commit_cell = ally_pos
			elif ability.targeting_flags & GameEnums.TargetingFlags.TILE:
				if ability.target_shape != GameEnums.TargetShape.SINGLE:
					actor_pos = Vector2i(3, 3)
					enemy_pos = Vector2i(4, 3)
					commit_cell = Vector2i(4, 3)
				else:
					commit_cell = Vector2i(4, 3)
					if ability.targeting_flags & GameEnums.TargetingFlags.ENEMY:
						enemy_pos = commit_cell
	if enemy_pos.x < 0:
		enemy_pos = Vector2i(-1, -1)
	if ally_pos.x < 0:
		ally_pos = Vector2i(-1, -1)
	return {
		"actor_pos": actor_pos,
		"enemy_pos": enemy_pos,
		"ally_pos": ally_pos,
		"commit_cell": commit_cell,
		"verify_no_jump": verify_no_jump,
		"select_only": select_only,
	}


static func _assert_shaped_footprint(
	failures: Array[String],
	factory_id: StringName,
	fix: Dictionary,
	ability: AbilityData,
	hover_cell: Vector2i,
) -> void:
	var actor: UnitState = _Checklist.projected_unit(fix, 1)
	if actor == null:
		return
	var origin: Vector2i = actor.position
	var board: BoardState = fix.board
	var blast: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, origin, hover_cell, ability.target_shape, ability.target_shape_size,
	)
	_Checklist.assert_true(
		failures, "%s/planning/footprint_tiles" % factory_id,
		not blast.is_empty(),
		"shaped ability must have blast footprint at hover",
	)
	if not blast.is_empty():
		_Checklist.assert_red_includes_cell(
			failures, "%s/planning/red_blast_tile" % factory_id,
			fix, ability, origin, blast[0],
		)


static func _apply_engineer_planning_setup(fix: Dictionary, factory_id: StringName) -> void:
	var actor: UnitState = fix.get("actor")
	var board: BoardState = fix.get("board")
	if actor == null or board == null:
		return
	match factory_id:
		&"engineer_recall":
			var construct := UnitState.create(
				90, DataLibrary.get_unit(&"construct_turret"), GameEnums.Team.PLAYER, Vector2i(4, 3),
			)
			construct.passive_flags["engineer_owner_id"] = actor.id
			construct.passive_flags["engineer_construct_kind"] = &"construct_turret"
			board.add_unit(construct)
			GridSystem.set_occupant(board, construct.position, construct.id)
			fix.director.base_board = board.clone()
			fix.director.projected_state = board.clone()
		&"engineer_wrench_smack", &"engineer_manual_detonation", &"engineer_overdrive_injection":
			var target := UnitState.create(
				91, DataLibrary.get_unit(&"construct_turret"), GameEnums.Team.PLAYER, Vector2i(3, 3),
			)
			target.passive_flags["engineer_owner_id"] = actor.id
			target.passive_flags["engineer_construct_kind"] = &"construct_turret"
			board.add_unit(target)
			GridSystem.set_occupant(board, target.position, target.id)
			fix.director.base_board = board.clone()
			fix.director.projected_state = board.clone()
		&"engineer_scrap_shield":
			actor.scrap = 2
		&"engineer_flak_cannon":
			actor.scrap = 2
			actor.upgraded_abilities.append(&"engineer_flak_cannon")


static func _apply_beast_planning_setup(fix: Dictionary, factory_id: StringName) -> void:
	if factory_id not in [&"beast_savage_bite", &"beast_bestial_roar"]:
		return
	var enemy: UnitState = fix.get("enemy")
	if enemy == null:
		return
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1))


static func _class_id_from_factory(factory_id: StringName) -> StringName:
	var text := String(factory_id)
	if text.begins_with("beast_"):
		return &"beast_rider"
	for prefix: String in ["bruiser", "archer", "lancer", "mage", "cleric", "knight", "mercenary", "monk", "engineer"]:
		if text.begins_with(prefix + "_") or text == prefix:
			return StringName(prefix)
	return &""
