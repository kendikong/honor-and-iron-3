class_name ArcherQaHarnessPassives
extends RefCounted

const H := preload("res://tests/archer_qa_harness.gd")


static func run_lightfoot(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"lightfoot")
	H.assert_true(failures, "lightfoot/modifiers", not passive.modifiers.is_empty())
	var definition := H.archer_unit_data()
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


static func run_overwatch(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"overwatch")
	H.assert_true(failures, "overwatch/mod", passive != null)
	H.assert_true(
		failures, "overwatch/zone_entry",
		passive != null and passive.modifiers.has("planning_unused_ap_reaction"),
	)


static func run_high_ground(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"high_ground")
	H.assert_true(failures, "high_ground/mod", passive != null)
	H.assert_true(
		failures, "high_ground/elevation_bonus",
		passive != null and passive.modifiers.has("elevation_range"),
	)


static func run_patient_hunter(failures: Array[String]) -> void:
	var board := H.make_plain_board(Vector2i(8, 4))
	var basic := DataLibrary._make_class_basic_attack(&"archer")
	var patient := H.place_archer(
		board, 1, Vector2i(1, 1),
		{"active_abilities": [basic], "active_passives": [H.factory_passive(&"patient_hunter")]},
	)
	var patient_target := H.place_dummy(board, 2, Vector2i(3, 1))
	var patient_events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(patient.id, basic, patient_target.position, patient_target.id),
		patient_events,
	)
	H.assert_true(
		failures, "patient_hunter/vantage_anchor",
		patient.has_status(GameEnums.StatusType.STURDY)
		and patient.has_status(GameEnums.StatusType.STEALTH),
	)


static func run_true_sight(failures: Array[String]) -> void:
	H.assert_true(
		failures, "true_sight/ignore_stealth",
		bool(H.factory_passive(&"true_sight").modifiers.get("ignore_stealth", false)),
	)


static func run_piercing_momentum(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"piercing_momentum")
	H.assert_true(failures, "piercing_momentum/mod", passive != null)
	H.assert_true(
		failures, "piercing_momentum/pierce_bonus",
		passive != null and passive.modifiers.has("long_shot_pierce_distance"),
	)


static func run_camouflage(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"camouflage")
	H.assert_true(failures, "camouflage/mod", passive != null)
	H.assert_true(
		failures, "camouflage/stealth_on_stand",
		passive != null and passive.modifiers.has("zero_move_stealth_range"),
	)


static func run_area_denial(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"area_denial")
	H.assert_true(failures, "area_denial/mod", passive != null)
	H.assert_true(
		failures, "area_denial/trap_bonus",
		passive != null and passive.modifiers.has("created_area_weapon_damage"),
	)


static func run_caltrop_expert(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"caltrop_expert")
	H.assert_true(failures, "caltrop_expert/mod", passive != null)
	H.assert_true(
		failures, "caltrop_expert/caltrop_bonus",
		passive != null and passive.modifiers.has("caltrop_damage_bonus"),
	)


static func run_zone_control(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"zone_control")
	H.assert_true(
		failures, "zone_control/mod",
		passive != null and passive.modifiers.has("zone_entry_range"),
	)


static func run_sticky_mud(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"sticky_mud")
	H.assert_true(failures, "sticky_mud/mod", passive != null)
	H.assert_true(
		failures, "sticky_mud/slow_bonus",
		passive != null and passive.modifiers.has("created_difficult_terrain_extra_mp"),
	)


static func run_fletching_hoarder(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"fletching_hoarder")
	H.assert_true(failures, "fletching_hoarder/mod", passive != null)
	H.assert_true(
		failures, "fletching_hoarder/ammo_bonus",
		passive != null and passive.modifiers.has("corpse_move_attack_bonus"),
	)


static func run_prey_sighted(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"prey_sighted")
	H.assert_true(failures, "prey_sighted/mod", passive != null)
	H.assert_true(
		failures, "prey_sighted/mark_bonus",
		passive != null and passive.modifiers.has("movement_penalty_attack_bonus"),
	)


static func run_barrage(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"barrage")
	H.assert_true(failures, "barrage/mod", passive != null)
	H.assert_true(
		failures, "barrage/extra_shot",
		passive != null and passive.modifiers.has("exact_lethal_followup_damage"),
	)


static func run_target_painter(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"target_painter")
	H.assert_true(failures, "target_painter/mod", passive != null)
	H.assert_true(
		failures, "target_painter/mark_on_hit",
		passive != null and passive.modifiers.has("debuffed_attack_bonus"),
	)


static func run_rapid_fire(failures: Array[String]) -> void:
	var passive := H.factory_passive(&"rapid_fire")
	H.assert_true(failures, "rapid_fire/mod", passive != null)
	H.assert_true(
		failures, "rapid_fire/cooldown_reduction",
		passive != null and passive.modifiers.has("after_attack_move"),
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
