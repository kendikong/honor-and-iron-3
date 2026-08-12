class_name ArcherQaHarnessPassives
extends RefCounted

const H := preload("res://tests/archer_qa_harness.gd")


static func run_single_passive(passive_id: StringName, failures: Array[String]) -> void:
	_run_passive_blocks(failures, passive_id)


static func run_lightfoot(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"lightfoot")


static func run_overwatch(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"overwatch")


static func run_high_ground(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"high_ground")


static func run_patient_hunter(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"patient_hunter")


static func run_true_sight(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"true_sight")


static func run_piercing_momentum(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"piercing_momentum")


static func run_camouflage(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"camouflage")


static func run_area_denial(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"area_denial")


static func run_caltrop_expert(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"caltrop_expert")


static func run_zone_control(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"zone_control")


static func run_sticky_mud(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"sticky_mud")


static func run_fletching_hoarder(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"fletching_hoarder")


static func run_prey_sighted(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"prey_sighted")


static func run_barrage(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"barrage")


static func run_target_painter(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"target_painter")


static func run_rapid_fire(failures: Array[String]) -> void:
	_run_passive_blocks(failures, &"rapid_fire")


static func _passive_should_run(only_id: StringName, block_id: StringName) -> bool:
	return only_id == StringName() or only_id == block_id


static func _place_enemy(board: BoardState, unit_id: int, pos: Vector2i) -> UnitState:
	var definition := H.archer_unit_data()
	var enemy := UnitState.create(
		unit_id, definition, GameEnums.Team.ENEMY, pos,
		{"active_abilities": [DataLibrary.get_universal_run()]},
	)
	board.units.append(enemy)
	GridSystem.set_occupant(board, pos, unit_id)
	enemy.movement.points_left = enemy.movement.max_points
	return enemy


static func _run_passive_blocks(failures: Array[String], only_id: StringName = &"") -> void:
	if _passive_should_run(only_id, &"lightfoot"):
		var passive := H.factory_passive(&"lightfoot")
		H.assert_true(failures, "lightfoot/modifiers", not passive.modifiers.is_empty())
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var board := H.make_plain_board(Vector2i(10, 6))
		var steady_aim := H.place_archer(
			board, 1, Vector2i(1, 2),
			{"active_abilities": [basic], "active_passives": [passive]},
		)
		H.assert_true(
			failures, "lightfoot/steady_aim_range",
			steady_aim.get_ability_range(basic) == 2,
		)
		var events: Array[SimEvent] = []
		MovementSystem.execute_move(
			board, TimelineAction.make_move(steady_aim.id, Vector2i(2, 2)), events,
		)
		H.assert_true(
			failures, "passive/lightfoot/range_after_move",
			steady_aim.get_ability_range(basic) == 1,
		)

	if _passive_should_run(only_id, &"overwatch"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(2, 1),
			{"active_abilities": [basic], "active_passives": [H.factory_passive(&"overwatch")]},
		)
		archer.ability.points_left = archer.ability.max_points
		var enemy := _place_enemy(board, 2, Vector2i(6, 1))
		var hp_before := enemy.health.current_hp
		var plan := Timeline.new()
		plan.add(TimelineAction.make_move(enemy.id, Vector2i(4, 1)))
		var events: Array[SimEvent] = []
		Simulator.simulate_player_turn(board, plan, events)
		H.assert_true(
			failures, "passive/overwatch/zone_entry_damage",
			enemy.health.current_hp < hp_before
			or archer.passive_flags.get("overwatch_used", false),
		)
		var wpn_board := H.make_plain_board(Vector2i(8, 4))
		var wpn_basic := DataLibrary._make_class_basic_attack(&"archer")
		var low_wpn := H.place_archer(
			wpn_board, 20, Vector2i(2, 1),
			{"active_abilities": [wpn_basic], "active_passives": [H.factory_passive(&"overwatch")]},
		)
		if low_wpn.definition != null and low_wpn.definition.equipped_weapon != null:
			low_wpn.definition.equipped_weapon.might = 0
		low_wpn.ability.points_left = low_wpn.ability.max_points
		var high_wpn := H.place_archer(
			wpn_board, 21, Vector2i(2, 3),
			{"active_abilities": [wpn_basic], "active_passives": [H.factory_passive(&"overwatch")]},
		)
		if high_wpn.definition != null and high_wpn.definition.equipped_weapon != null:
			high_wpn.definition.equipped_weapon.might = 5
		high_wpn.ability.points_left = high_wpn.ability.max_points
		var low_enemy := _place_enemy(wpn_board, 22, Vector2i(6, 1))
		var high_enemy := _place_enemy(wpn_board, 23, Vector2i(6, 3))
		var low_hp := low_enemy.health.current_hp
		var high_hp := high_enemy.health.current_hp
		var low_plan := Timeline.new()
		low_plan.add(TimelineAction.make_move(low_enemy.id, Vector2i(4, 1)))
		var high_plan := Timeline.new()
		high_plan.add(TimelineAction.make_move(high_enemy.id, Vector2i(4, 3)))
		var low_events: Array[SimEvent] = []
		var high_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(wpn_board, low_plan, low_events)
		Simulator.simulate_player_turn(wpn_board, high_plan, high_events)
		var low_loss := low_hp - low_enemy.health.current_hp
		var high_loss := high_hp - high_enemy.health.current_hp
		var low_wpn_dmg := CombatSystem.calculate_scaled_damage(
			low_wpn, 1, GameEnums.StatType.PHYSICAL, wpn_board,
		)
		var high_wpn_dmg := CombatSystem.calculate_scaled_damage(
			high_wpn, 1, GameEnums.StatType.PHYSICAL, wpn_board,
		)
		H.assert_true(
			failures,
			"passive/overwatch/wpn_scales",
			high_loss - low_loss >= high_wpn_dmg - low_wpn_dmg,
			"Overwatch damage must scale with equipped weapon might",
		)

	if _passive_should_run(only_id, &"zone_control"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(2, 1),
			{"active_abilities": [basic], "active_passives": [H.factory_passive(&"zone_control")]},
		)
		var enemy := _place_enemy(board, 2, Vector2i(6, 1))
		var plan := Timeline.new()
		plan.add(TimelineAction.make_move(enemy.id, Vector2i(4, 1)))
		var events: Array[SimEvent] = []
		Simulator.simulate_player_turn(board, plan, events)
		H.assert_true(
			failures, "passive/zone_control/entry_damage",
			_events_have_unit_damage(events, enemy.id),
		)

	if _passive_should_run(only_id, &"high_ground"):
		var board := H.make_plain_board(Vector2i(8, 4))
		board.set_tile_terrain(Vector2i(1, 2), DataLibrary.get_terrain(&"castle"))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"high_ground")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(4, 2))
		var action := TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id)
		H.assert_true(
			failures, "passive/high_ground/elevation_range",
			AbilitySystem.can_use(board, action),
		)
		board.set_tile_terrain(Vector2i(1, 2), DataLibrary.get_terrain(&"plain"))
		archer._recalculate_stats(board)
		H.assert_true(
			failures, "passive/high_ground/no_bonus_on_flat",
			not AbilitySystem.can_use(board, action),
		)

	if _passive_should_run(only_id, &"patient_hunter"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var patient := H.place_archer(
			board, 1, Vector2i(1, 1),
			{"active_abilities": [basic], "active_passives": [H.factory_passive(&"patient_hunter")]},
		)
		var patient_target := H.place_dummy(board, 2, Vector2i(3, 1))
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(patient.id, basic, patient_target.position, patient_target.id),
			events,
		)
		H.assert_true(
			failures, "passive/patient_hunter/vantage_anchor",
			patient.has_status(GameEnums.StatusType.STURDY)
			and patient.has_status(GameEnums.StatusType.STEALTH),
		)

	if _passive_should_run(only_id, &"true_sight"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"true_sight")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(3, 2))
		enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STEALTH, 2))
		enemy._recalculate_stats(board)
		var hp_before := enemy.health.current_hp
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/true_sight/ignore_stealth",
			enemy.health.current_hp < hp_before,
		)

	if _passive_should_run(only_id, &"piercing_momentum"):
		var board := H.make_plain_board(Vector2i(10, 4))
		var skill := H.factory_ability(&"archer_power_shot")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [skill],
				"active_passives": [H.factory_passive(&"piercing_momentum")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(5, 2))
		var hp_before := enemy.health.current_hp
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, skill, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/piercing_momentum/long_shot_pierce",
			enemy.health.current_hp < hp_before,
		)

	if _passive_should_run(only_id, &"camouflage"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"camouflage")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(3, 2))
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/camouflage/zero_move_stealth",
			archer.has_status(GameEnums.StatusType.STEALTH),
		)

	if _passive_should_run(only_id, &"area_denial"):
		var board := H.make_plain_board(Vector2i(10, 8))
		var trap := H.factory_ability(&"archer_bear_trap")
		var archer := H.place_archer(
			board, 1, Vector2i(2, 3),
			{
				"active_abilities": [trap],
				"active_passives": [H.factory_passive(&"area_denial")],
			},
		)
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board, TimelineAction.make_ability(archer.id, trap, Vector2i(4, 3), -1), events,
		)
		var payload: Dictionary = board.terrain_payloads.get(Vector2i(4, 3), {})
		H.assert_true(
			failures, "passive/area_denial/created_area_weapon_damage",
			bool(payload.get("created_area_weapon_damage", false)),
		)

	if _passive_should_run(only_id, &"caltrop_expert"):
		var board := H.make_plain_board(Vector2i(10, 8))
		var trap := H.factory_ability(&"archer_caltrop_trap")
		var passive := H.factory_passive(&"caltrop_expert")
		var archer := H.place_archer(
			board, 1, Vector2i(2, 3),
			{
				"active_abilities": [trap],
				"active_passives": [passive],
				"upgraded_passives": [passive.id],
			},
		)
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board, TimelineAction.make_ability(archer.id, trap, Vector2i(4, 3), -1), events,
		)
		var payload: Dictionary = board.terrain_payloads.get(Vector2i(4, 3), {})
		H.assert_true(
			failures, "passive/caltrop_expert/trap_damage_bonus",
			int(payload.get("trap_damage_bonus", 0)) > 0,
		)

	if _passive_should_run(only_id, &"sticky_mud"):
		var board := H.make_plain_board(Vector2i(10, 8))
		var volley := H.factory_ability(&"archer_volley")
		var passive := H.factory_passive(&"sticky_mud")
		var archer := H.place_archer(
			board, 1, Vector2i(2, 3),
			{
				"active_abilities": [volley],
				"active_passives": [passive],
				"upgraded_abilities": [volley.id],
			},
		)
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board, TimelineAction.make_ability(archer.id, volley, Vector2i(4, 3), -1), events,
		)
		var payload: Dictionary = board.terrain_payloads.get(Vector2i(4, 3), {})
		H.assert_true(
			failures, "passive/sticky_mud/created_difficult_terrain_extra_mp",
			int(payload.get("created_difficult_terrain_extra_mp", 0)) > 0,
		)

	if _passive_should_run(only_id, &"fletching_hoarder"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"fletching_hoarder")],
			},
		)
		var corpse := H.place_dummy(board, 99, Vector2i(2, 2))
		corpse.health.current_hp = 0
		GridSystem.set_occupant(board, corpse.position, -1)
		var events: Array[SimEvent] = []
		MovementSystem.execute_move(
			board, TimelineAction.make_move(archer.id, Vector2i(2, 2)), events,
		)
		H.assert_true(
			failures, "passive/fletching_hoarder/corpse_move_empowered",
			archer.passive_flags.get("corpse_move_empowered", false),
		)
		var enemy := _place_enemy(board, 2, Vector2i(3, 2))
		var hp_before := enemy.health.current_hp
		var attack_events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			attack_events,
		)
		H.assert_true(
			failures, "passive/fletching_hoarder/corpse_attack_bonus",
			enemy.health.current_hp < hp_before,
		)

	if _passive_should_run(only_id, &"prey_sighted"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"prey_sighted")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(3, 2))
		enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 2))
		enemy._recalculate_stats(board)
		var hp_before := enemy.health.current_hp
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/prey_sighted/movement_penalty_attack_bonus",
			enemy.health.current_hp < hp_before,
		)
		var board_plain := H.make_plain_board(Vector2i(8, 4))
		var plain_archer := H.place_archer(
			board_plain, 10, Vector2i(1, 2),
			{"active_abilities": [basic], "active_passives": []},
		)
		var plain_enemy := H.place_dummy(board_plain, 11, Vector2i(3, 2))
		plain_enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 2))
		plain_enemy._recalculate_stats(board_plain)
		var plain_hp := plain_enemy.health.current_hp
		var plain_events: Array[SimEvent] = []
		AbilitySystem.execute(
			board_plain,
			TimelineAction.make_ability(plain_archer.id, basic, plain_enemy.position, plain_enemy.id),
			plain_events,
		)
		var prey_loss := hp_before - enemy.health.current_hp
		var plain_loss := plain_hp - plain_enemy.health.current_hp
		var expected_ignore := floori(plain_enemy.current_defense * 0.25)
		H.assert_true(
			failures,
			"passive/prey_sighted/def_ignore_pct",
			prey_loss - plain_loss >= expected_ignore,
			"Prey Sighted must ignore at least 25%% DEF (%d)" % expected_ignore,
		)

	if _passive_should_run(only_id, &"barrage"):
		var board := H.make_plain_board(Vector2i(10, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"barrage")],
			},
		)
		var primary := _place_enemy(board, 2, Vector2i(3, 2))
		var secondary := _place_enemy(board, 3, Vector2i(4, 2))
		primary.current_defense = 0
		primary._recalculate_stats(board)
		var lethal := CombatSystem.calculate_scaled_damage(
			archer, 1, GameEnums.StatType.PHYSICAL, board,
		)
		primary.health.current_hp = maxi(1, lethal)
		var secondary_hp := secondary.health.current_hp
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, primary.position, primary.id),
			events,
		)
		H.assert_true(
			failures, "passive/barrage/exact_lethal_followup_damage",
			not primary.is_alive() and secondary.health.current_hp < secondary_hp,
		)

	if _passive_should_run(only_id, &"target_painter"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"target_painter")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(3, 2))
		enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 2, 1))
		enemy._recalculate_stats(board)
		var hp_before := enemy.health.current_hp
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/target_painter/debuffed_attack_bonus",
			enemy.health.current_hp < hp_before,
		)

	if _passive_should_run(only_id, &"rapid_fire"):
		var board := H.make_plain_board(Vector2i(8, 4))
		var basic := DataLibrary._make_class_basic_attack(&"archer")
		var archer := H.place_archer(
			board, 1, Vector2i(1, 2),
			{
				"active_abilities": [basic],
				"active_passives": [H.factory_passive(&"rapid_fire")],
			},
		)
		var enemy := H.place_dummy(board, 2, Vector2i(3, 2))
		archer.movement.points_left = 0
		var mp_before := archer.movement.points_left
		var events: Array[SimEvent] = []
		AbilitySystem.execute(
			board,
			TimelineAction.make_ability(archer.id, basic, enemy.position, enemy.id),
			events,
		)
		H.assert_true(
			failures, "passive/rapid_fire/after_attack_move",
			archer.movement.points_left > mp_before,
		)


static func _events_have_unit_damage(events: Array[SimEvent], unit_id: int) -> bool:
	for event: SimEvent in events:
		if (
			event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("unit", -1)) == unit_id
			and int(event.data.get("amount", 0)) > 0
		):
			return true
	return false
