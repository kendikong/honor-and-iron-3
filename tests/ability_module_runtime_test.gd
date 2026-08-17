class_name AbilityModuleRuntimeTest
extends RefCounted

## Focused AD-2 runtime bar. These scenarios exercise AbilitySystem with authored
## modules and intentionally empty compatibility effects.

static func run_all(failures: Array[String]) -> void:
	var scenario_failures: int = failures.size()
	print("ABILITY_MODULE_SCENARIO: module_only_execution START")
	_test_module_only_execution(failures)
	_report_scenario("module_only_execution", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: base_multi_module_compatibility_order START")
	_test_base_multi_module_compatibility_order(failures)
	_report_scenario("base_multi_module_compatibility_order", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: native_multi_module_execute_order START")
	_test_base_multi_module_native_execute_order(failures)
	_report_scenario("native_multi_module_execute_order", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: upgraded_module_profile START")
	_test_upgraded_module_profile(failures)
	_report_scenario("upgraded_module_profile", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: shared_module_parity START")
	_test_shared_module_parity(failures)
	_report_scenario("shared_module_parity", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: reposition_skills_ally_only START")
	_test_reposition_skills_ally_only(failures)
	_report_scenario("reposition_skills_ally_only", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: planned_postmove_standing_aim START")
	_test_planned_postmove_standing_aim(failures)
	_report_scenario("planned_postmove_standing_aim", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: legacy_flat_targeting_compatibility START")
	_test_legacy_flat_targeting_compatibility(failures)
	_report_scenario("legacy_flat_targeting_compatibility", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: motion_range_legality START")
	_test_motion_range_legality(failures)
	_report_scenario("motion_range_legality", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: if_collided_follow_up START")
	_test_if_collided_follow_up(failures)
	_report_scenario("if_collided_follow_up", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: schema_module_round_trip START")
	_test_schema_module_round_trip(failures)
	_report_scenario("schema_module_round_trip", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: skill_card_shows_condition START")
	_test_skill_card_shows_condition(failures)
	_report_scenario("skill_card_shows_condition", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: legacy_json_import_round_trip START")
	_test_legacy_json_import_round_trip(failures)
	_report_scenario("legacy_json_import_round_trip", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: modular_base_legacy_upgrade_import START")
	_test_modular_base_legacy_upgrade_import(failures)
	_report_scenario("modular_base_legacy_upgrade_import", failures, scenario_failures)
	scenario_failures = failures.size()
	print("ABILITY_MODULE_SCENARIO: module_profile_clear_projection START")
	_test_module_profile_clear_projection(failures)
	_report_scenario("module_profile_clear_projection", failures, scenario_failures)


static func _test_module_only_execution(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_module_only", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [damage]
	var stale_legacy_effect: EffectData = EffectData.new()
	stale_legacy_effect.type = GameEnums.EffectType.DAMAGE
	stale_legacy_effect.amount = 99
	ability.effects = [stale_legacy_effect]
	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	if target.health.current_hp != 16:
		failures.append(
			"module-only runtime did not apply authored DAMAGE (HP %d, effects %d, events %d)"
			% [
				target.health.current_hp,
				AbilitySystem.compatibility_effects_for(actor, ability).size(),
				events.size(),
			]
		)
	if ability.effects.size() != 1 or ability.effects[0].amount != 99:
		failures.append("module-only runtime fixture mutated its legacy compatibility cache")
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if compatibility_view.size() != 1 or compatibility_view[0].amount != 4:
		failures.append("module-only runtime compatibility view did not derive from modules")


static func _test_base_multi_module_compatibility_order(failures: Array[String]) -> void:
	var ability: AbilityData = _ability(&"runtime_base_multi_module_order", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 3
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var push := AbilityLayer.new()
	push.effect = EffectData.new()
	push.effect.type = GameEnums.EffectType.PUSH
	push.effect.amount = 2
	damage.layers.append(push)
	ability.modules = [damage]
	ability.effects = []
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(null, ability)
	if (
		compatibility_view.size() != 2
		or compatibility_view[0].type != GameEnums.EffectType.DAMAGE
		or compatibility_view[0].amount != 3
		or compatibility_view[1].type != GameEnums.EffectType.PUSH
		or compatibility_view[1].amount != 2
	):
		failures.append("base multi-module compatibility order changed DAMAGE + PUSH")


static func _test_base_multi_module_native_execute_order(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_native_multi_module_order", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 3
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var push := AbilityLayer.new()
	push.effect = EffectData.new()
	push.effect.type = GameEnums.EffectType.PUSH
	push.effect.amount = 2
	damage.layers.append(push)
	ability.modules = [damage]
	ability.effects = []

	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	AbilitySystem.resolve_pending_pushes(board, events)

	var damage_event_index: int = -1
	var push_event_index: int = -1
	for index: int in events.size():
		var event: SimEvent = events[index]
		if event == null:
			continue
		if (
			damage_event_index < 0
			and event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("unit", -1)) == target.id
		):
			damage_event_index = index
		if (
			push_event_index < 0
			and event.type == GameEnums.SimEventType.UNIT_PUSHED
			and int(event.data.get("unit", -1)) == target.id
		):
			push_event_index = index
	if damage_event_index < 0 or push_event_index < 0 or damage_event_index >= push_event_index:
		failures.append(
			"native multi-module execute did not order DAMAGE before PUSH (events %s)"
			% _event_types(events)
		)
	if target.health.current_hp != 17 or target.position != Vector2i(5, 1):
		failures.append(
			"native multi-module execute produced HP %d at %s, expected HP 17 at (5, 1)"
			% [target.health.current_hp, target.position]
		)


static func _test_upgraded_module_profile(failures: Array[String]) -> void:
	var ability: AbilityData = _ability(&"runtime_profile_selection", GameEnums.TargetingFlags.ENEMY)
	var base: AbilityModule = AbilityModule.new()
	base.primary_type = GameEnums.EffectType.DAMAGE
	base.amount = 2
	base.min_range = 1
	base.max_range = 3
	var upgraded: AbilityModule = AbilityModule.new()
	upgraded.primary_type = GameEnums.EffectType.DAMAGE
	upgraded.amount = 7
	upgraded.min_range = 2
	upgraded.max_range = 4
	ability.modules = [base]
	ability.upgraded_modules = [upgraded]
	ability.effects = []
	ability.upgraded_effects = []
	var actor: UnitState = _unit(7, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	actor.upgraded_abilities = [ability.id]
	var active: Array[AbilityModule] = AbilitySystem.active_modules_for(actor, ability)
	if active.size() != 1 or active[0] != upgraded:
		failures.append("upgraded module profile was not selected as a complete replacement")
	var effects: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if effects.size() != 1 or effects[0].amount != 7:
		failures.append("upgraded module profile did not compile its authored amount")


static func _test_shared_module_parity(failures: Array[String]) -> void:
	var left: AbilityData = _ability(&"shared_module_left", GameEnums.TargetingFlags.ENEMY)
	var right: AbilityData = _ability(&"shared_module_right", GameEnums.TargetingFlags.ENEMY)
	for ability: AbilityData in [left, right]:
		var module := AbilityModule.new()
		module.primary_type = GameEnums.EffectType.DAMAGE
		module.amount = 5
		module.min_range = 1
		module.max_range = 4
		module.targeting_flags = GameEnums.TargetingFlags.ENEMY
		module.presentation_anim = GameEnums.PresentationAnim.SPELL
		module.ingest_runtime_key("l_shape_move", true)
		ability.modules = [module]
	var left_actor: UnitState = _unit(41, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var right_actor: UnitState = _unit(42, GameEnums.Team.ENEMY, Vector2i(5, 1), 20)
	var left_profile: Dictionary = AbilitySystem.active_modifier_profile(left_actor, left)
	var right_profile: Dictionary = AbilitySystem.active_modifier_profile(right_actor, right)
	if (
		left_profile != right_profile
		or AbilitySystem.resolve_presentation_anim(left, left_actor)
			!= AbilitySystem.resolve_presentation_anim(right, right_actor)
		or TimelineAction.timeline_column_for_ability(left)
			!= TimelineAction.timeline_column_for_ability(right)
	):
		failures.append(
			"identical authored modules diverged across ability ids in profile, animation, or timeline",
		)


static func _test_reposition_skills_ally_only(failures: Array[String]) -> void:
	DataLibrary.reset_cache()
	for unit: UnitData in DataLibrary.get_all_player_units():
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability == null or not ability.is_pre_move_planner():
				continue
			if ability.kind != GameEnums.AbilityKind.MOVEMENT_SKILL:
				continue
			var flags: int = ability.targeting_flags
			for module: AbilityModule in ability.modules:
				if module != null:
					flags |= module.targeting_flags
			for module: AbilityModule in ability.upgraded_modules:
				if module != null:
					flags |= module.targeting_flags
			if (flags & GameEnums.TargetingFlags.ENEMY) != 0:
				failures.append(
					"reposition skill %s on %s still allows ENEMY targeting"
					% [String(ability.id), String(unit.id)],
				)


static func _test_planned_postmove_standing_aim(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	actor.definition.move_points = 8
	actor.movement.max_points = 8
	actor.movement.points_left = 8
	actor.turn_start_movement_points = 8
	var steady_aim := PassiveData.new()
	steady_aim.id = &"runtime_steady_aim"
	steady_aim.modifiers = {"steady_aim": true, "steady_aim_range": 1}
	actor.active_passives = [steady_aim]
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)
	var ability: AbilityData = _ability(
		&"runtime_postmove_standing_aim",
		GameEnums.TargetingFlags.ENEMY,
	)
	var strike := AbilityModule.new()
	strike.primary_type = GameEnums.EffectType.DAMAGE
	strike.amount = 3
	strike.min_range = 1
	strike.max_range = 3
	strike.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var post_move := AbilityModule.new()
	post_move.primary_type = GameEnums.EffectType.MOVE
	post_move.execution_phase = GameEnums.ModulePhase.ON_POST
	post_move.min_range = 1
	post_move.max_range = 3
	post_move.targeting_flags = GameEnums.TargetingFlags.TILE
	ability.modules = [strike, post_move]
	var action := TimelineAction.make_ability_awaiting(
		actor.id, ability, actor.position,
	)
	action.awaiting_module_index = 1
	action.module_target_coords = [target.position]
	action.module_target_unit_ids = [target.id]
	var timeline := Timeline.new()
	timeline.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, timeline, events)
	if actor.passive_flags.get("steady_aim_triggered", false):
		failures.append(
			"planned post-move module incorrectly triggered standing aim during its prefix",
		)
	if actor.movement.points_left != 8:
		failures.append(
			"planned post-move prefix changed movement points before its movement module resolved",
		)


static func _test_legacy_flat_targeting_compatibility(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_legacy_flat", 0)
	ability.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	ability.range_tiles = 3
	var damage: EffectData = EffectData.new()
	damage.type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	ability.effects = [damage]
	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	if target.health.current_hp != 16:
		failures.append(
			"legacy flat targeting mode did not resolve DAMAGE (HP %d)" % target.health.current_hp
		)


static func _test_motion_range_legality(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	board.units = [actor]
	_place(board, actor)
	var ability: AbilityData = _ability(&"runtime_motion_range", GameEnums.TargetingFlags.TILE)
	var move: AbilityModule = AbilityModule.new()
	move.primary_type = GameEnums.EffectType.MOVE
	move.amount = 99
	move.min_range = 2
	move.max_range = 3
	move.targeting_flags = GameEnums.TargetingFlags.TILE
	ability.modules = [move]
	ability.effects = []

	var too_short: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, Vector2i(2, 1),
	)
	var too_long: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, Vector2i(5, 1),
	)
	if AbilitySystem.can_use(board, too_short):
		failures.append("module MOVE min_range did not reject a too-short destination")
	if AbilitySystem.can_use(board, too_long):
		failures.append("module MOVE max_range did not reject a too-long destination")
	for motion_type: GameEnums.EffectType in [
		GameEnums.EffectType.JUMP,
		GameEnums.EffectType.TELEPORT_CASTER,
	]:
		var shaped_ability: AbilityData = _ability(
			&"runtime_%s_range" % GameEnums.EffectType.keys()[motion_type],
			GameEnums.TargetingFlags.TILE,
		)
		var shaped_module := AbilityModule.new()
		shaped_module.primary_type = motion_type
		shaped_module.amount = 99
		shaped_module.min_range = 2
		shaped_module.max_range = 3
		shaped_module.targeting_flags = GameEnums.TargetingFlags.TILE
		shaped_ability.modules = [shaped_module]
		shaped_ability.effects = []
		if AbilitySystem.can_use(
			board, TimelineAction.make_ability(actor.id, shaped_ability, Vector2i(2, 1)),
		):
			failures.append("%s min_range did not reject a too-short destination" % motion_type)
		if AbilitySystem.can_use(
			board, TimelineAction.make_ability(actor.id, shaped_ability, Vector2i(5, 1)),
		):
			failures.append("%s max_range did not reject a too-long destination" % motion_type)


static func _test_if_collided_follow_up(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(7, 5))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(2, 1), 20)
	var blocker: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(2, 2), 20)
	blocker.active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.ROOT, 1),
	)
	board.units = [actor, blocker]
	_place(board, actor)
	_place(board, blocker)

	var ability: AbilityData = _ability(&"runtime_if_collided", GameEnums.TargetingFlags.DASH_LINE)
	var dash: AbilityModule = AbilityModule.new()
	dash.primary_type = GameEnums.EffectType.DASH
	dash.amount = 2
	dash.min_range = 1
	dash.max_range = 2
	dash.targeting_flags = GameEnums.TargetingFlags.DASH_LINE
	var follow_up: AbilityModule = AbilityModule.new()
	follow_up.primary_type = GameEnums.EffectType.MOVE
	follow_up.min_range = 1
	follow_up.max_range = 5
	follow_up.targeting_flags = GameEnums.TargetingFlags.TILE
	follow_up.gate = GameEnums.ModuleGate.IF_COLLIDED
	follow_up.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	ability.modules = [dash, follow_up]
	ability.effects = []

	if AbilitySystem._module_gate_passes(follow_up, actor, [], 0):
		failures.append("IF_COLLIDED gate passed without a collision event")
	if not AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.MOVE, actor):
		failures.append("typed metadata scan did not see gated MOVE module")
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if (
		compatibility_view.size() != 1
		or compatibility_view[0].type != GameEnums.EffectType.DASH
		or not compatibility_view[0].modifiers.has("violent_collision_recast")
	):
		failures.append("compatibility view did not stay gated-stripped for IF_COLLIDED")

	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, Vector2i(2, 3)),
		events,
	)
	var collision_seen: bool = false
	var collision_data: Dictionary = {}
	for event: SimEvent in events:
		if event != null and event.type == GameEnums.SimEventType.COLLISION:
			collision_seen = true
			collision_data = event.data
			break
	if not collision_seen:
		failures.append("IF_COLLIDED fixture did not produce collision state")
	if actor.position != Vector2i(2, 3):
		var event_types: Array[String] = []
		for event: SimEvent in events:
			event_types.append(str(event.type))
		var route: Array[Vector2i] = MovementSystem.resolve_move_path(
			board, actor, Vector2i(2, 3), [], 5, ability,
		)
		var follow_effects: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(
			follow_up,
		)
		var gate_passes: bool = AbilitySystem._module_gate_passes(
			follow_up, actor, events, 0,
		)
		failures.append(
			"IF_COLLIDED follow-up MOVE did not execute in module order (position %s, collision %s, data %s, events %s, route %s, gate %d, effect %d, passes %s)"
			% [
				actor.position, collision_seen, collision_data, event_types, route,
				follow_up.gate, follow_effects[0].type if not follow_effects.is_empty() else -1, gate_passes,
			]
		)


static func _test_schema_module_round_trip(failures: Array[String]) -> void:
	var authored: AbilityData = AbilityData.new()
	authored.id = &"schema_round_trip"
	authored.planner_group = GameEnums.PlannerGroup.ACTION
	authored.primary_resource = GameEnums.CostResource.AP
	authored.primary_value = 2
	authored.tags = [&"positioning", &"attack"]
	var module: AbilityModule = AbilityModule.new()
	module.primary_type = GameEnums.EffectType.PUSH
	module.amount = 2
	module.min_range = 1
	module.max_range = 4
	module.targeting_flags = GameEnums.TargetingFlags.ENEMY
	module.target_shape = GameEnums.TargetShape.SINGLE
	module.bonus_dmg_pct_max_hp = 0.1
	var keyword: AbilityKeyword = AbilityKeyword.new()
	keyword.keyword_id = GameEnums.AbilityKeywordId.PIERCE
	keyword.amount = 1
	module.keywords = [keyword]
	module.set_condition_hp_below_pct(50)
	var layer: AbilityLayer = AbilityLayer.new()
	layer.effect = EffectData.new()
	layer.effect.type = GameEnums.EffectType.DAMAGE
	layer.effect.amount = 1
	module.layers = [layer]
	module.l_shape_move = true
	authored.modules = [module]
	var upgraded_module: AbilityModule = module.duplicate(true) as AbilityModule
	upgraded_module.amount = 5
	authored.upgraded_modules = [upgraded_module]
	authored.upgraded_primary_value = 4
	authored.secondary_resource = GameEnums.CostResource.HP
	authored.secondary_value = 2
	authored.cost_modifier = GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N
	authored.cost_modifier_n = 2
	authored.finalize_modular()
	var payload: Dictionary = ClassLibrarySchema.ability_to_dict(authored)
	for legacy_key: String in [
		"effects", "upgraded_effects", "range_tiles", "targeting_mode",
		"targeting_flags", "target_shape",
	]:
		if payload.has(legacy_key):
			failures.append("module-first ability JSON emitted legacy key %s" % legacy_key)
	var restored: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(restored, payload)
	if restored.modules.size() != 1:
		failures.append("module-first JSON round trip lost authored module")
		return
	var restored_module: AbilityModule = restored.modules[0]
	if (
		restored.primary_value != authored.primary_value
		or restored.tags != authored.tags
		or restored_module.primary_type != module.primary_type
		or restored_module.amount != module.amount
		or restored_module.min_range != module.min_range
		or restored_module.max_range != module.max_range
		or restored_module.targeting_flags != module.targeting_flags
		or restored_module.keywords.size() != 1
		or restored_module.layers.size() != 1
		or restored_module.target_filter != GameEnums.ModuleTargetFilter.HP
		or restored_module.target_filter_hp != GameEnums.ModuleTargetFilterHp.BELOW_PCT
		or restored_module.target_filter_hp_pct != 50
		or not is_equal_approx(restored_module.bonus_dmg_pct_max_hp, 0.1)
		or not restored_module.l_shape_move
		or restored.upgraded_modules.size() != 1
		or restored.upgraded_modules[0].amount != upgraded_module.amount
		or restored.upgraded_primary_value != authored.upgraded_primary_value
		or restored.secondary_resource != authored.secondary_resource
		or restored.secondary_value != authored.secondary_value
		or restored.cost_modifier != authored.cost_modifier
		or restored.cost_modifier_n != authored.cost_modifier_n
	):
		failures.append("module-first JSON round trip changed header or module data")
	var player_text: String = CombatUiFormatters.ability_effect_bbcode(authored)
	if player_text.find("PUSH") < 0:
		failures.append("module-first player-facing formatter lost PUSH text")
	var card_lines: PackedStringArray = CombatUiFormatters.ability_skill_module_lines_bbcode(authored)
	var card_text: String = " ".join(card_lines)
	if card_text.find("TARGET HP MUST BE BELOW 50%") < 0:
		failures.append("in-game skill-list layout omitted Condition: %s" % card_text)
	var unknown_tag_payload: Dictionary = payload.duplicate(true)
	unknown_tag_payload["tags"] = ["attack", "control"]
	var unknown_tag_result: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(unknown_tag_result, unknown_tag_payload)
	if unknown_tag_result.tags.has(&"control"):
		failures.append("module-first JSON retained an unknown tag")


static func _test_skill_card_shows_condition(failures: Array[String]) -> void:
	var unit_data: UnitData = FactoryTestHelpers.build_unit(&"mercenary")
	if unit_data == null:
		failures.append("mercenary factory unit missing for skill-card Condition check")
		return
	var ability: AbilityData = null
	for candidate: AbilityData in unit_data.abilities:
		if candidate != null and candidate.id == &"mercenary_executioners_blade":
			ability = candidate
			break
	if ability == null:
		failures.append("mercenary_executioners_blade missing from factory")
		return
	var lines: PackedStringArray = CombatUiFormatters.ability_skill_module_lines_bbcode(ability)
	var joined: String = " ".join(lines)
	if joined.find("TARGET HP MUST BE BELOW 50%") < 0:
		failures.append(
			"in-game skill card omitted Condition for Executioner's Blade: %s" % joined
		)


static func _test_legacy_json_import_round_trip(failures: Array[String]) -> void:
	var legacy_effect: EffectData = EffectData.new()
	legacy_effect.type = GameEnums.EffectType.DAMAGE
	legacy_effect.amount = 6
	var legacy_payload: Dictionary = {
		"display_name": "Legacy Strike",
		"kind": GameEnums.AbilityKind.CLASS_SKILL,
		"action_point_cost": 1,
		"range_tiles": 3,
		"targeting_mode": GameEnums.TargetingMode.ENEMY_UNIT,
		"effects": ClassLibrarySchema.effects_to_dict_array([legacy_effect]),
	}
	var imported: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(imported, legacy_payload)
	if imported.modules.size() != 1 or imported.effects.size() != 1:
		failures.append("legacy effects-only JSON did not infer a modular profile")
	elif imported.modules[0].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("legacy effects-only JSON inferred the wrong module effect")
	var hybrid_payload: Dictionary = legacy_payload.duplicate(true)
	hybrid_payload["modules"] = []
	var hybrid: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(hybrid, hybrid_payload)
	if hybrid.modules.size() != 1 or hybrid.modules[0].amount != 6:
		failures.append("hybrid empty-modules JSON dropped legacy effects")


static func _test_modular_base_legacy_upgrade_import(failures: Array[String]) -> void:
	var base_module: AbilityModule = AbilityModule.new()
	base_module.primary_type = GameEnums.EffectType.DAMAGE
	base_module.amount = 2
	base_module.max_range = 3
	base_module.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var base: AbilityData = AbilityData.new()
	base.modules = [base_module]
	base.finalize_modular()
	var upgraded_effect: EffectData = EffectData.new()
	upgraded_effect.type = GameEnums.EffectType.DAMAGE
	upgraded_effect.amount = 9
	var payload: Dictionary = ClassLibrarySchema.ability_to_dict(base)
	payload.erase("upgraded_modules")
	payload["upgraded_effects"] = ClassLibrarySchema.effects_to_dict_array([upgraded_effect])
	var imported: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(imported, payload)
	if imported.upgraded_modules.size() != 1 or imported.upgraded_modules[0].amount != 9:
		failures.append("modular base plus legacy upgraded_effects lost upgrade profile")


static func _test_module_profile_clear_projection(failures: Array[String]) -> void:
	var ability: AbilityData = _ability(&"runtime_module_profile_clear", GameEnums.TargetingFlags.ENEMY)
	var module: AbilityModule = AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.amount = 4
	module.max_range = 2
	module.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [module]
	ability.upgraded_modules = [module]
	ability.finalize_modular()
	AbilityModuleBridge.clear_module_profile(ability, false)
	AbilityModuleBridge.clear_module_profile(ability, true)
	ability.finalize_modular()
	if (
		not ability.modules.is_empty()
		or not ability.upgraded_modules.is_empty()
		or not ability.effects.is_empty()
		or not ability.upgraded_effects.is_empty()
	):
		failures.append("clearing authored module profiles left stale compatibility data")


static func _ability(id: StringName, targeting_flags: int) -> AbilityData:
	var ability: AbilityData = AbilityData.new()
	ability.id = id
	ability.kind = GameEnums.AbilityKind.CLASS_SKILL
	ability.action_point_cost = 1
	ability.primary_resource = GameEnums.CostResource.AP
	ability.primary_value = 1
	ability.targeting_flags = targeting_flags
	ability.targeting_mode = (
		GameEnums.TargetingMode.DASH_LINE
		if targeting_flags == GameEnums.TargetingFlags.DASH_LINE
		else GameEnums.TargetingMode.TILE
	)
	return ability


static func _unit(
	id: int,
	team: GameEnums.Team,
	position: Vector2i,
	hp: int,
) -> UnitState:
	var unit: UnitState = UnitState.new()
	unit.id = id
	unit.team = team
	unit.position = position
	unit.definition = UnitData.new()
	unit.definition.base_defense = 0
	unit.current_defense = 0
	unit.health = HealthComponent.new(hp)
	unit.ability = AbilityComponent.new(3)
	unit.ability.points_left = unit.ability.max_points
	return unit


static func _plain_board(size: Vector2i) -> BoardState:
	var terrain: TerrainData = TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board: BoardState = BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var cell: Vector2i = Vector2i(x, y)
			board.tiles[cell] = TileState.create(cell, terrain)
	return board


static func _place(board: BoardState, unit: UnitState) -> void:
	GridSystem.set_occupant(board, unit.position, unit.id)


static func _report_scenario(label: String, failures: Array[String], before: int) -> void:
	var result: String = "PASS" if failures.size() == before else "FAIL"
	print("ABILITY_MODULE_SCENARIO: %s %s" % [label, result])


static func _event_types(events: Array[SimEvent]) -> Array[String]:
	var types: Array[String] = []
	for event: SimEvent in events:
		types.append(str(event.type) if event != null else "null")
	return types
