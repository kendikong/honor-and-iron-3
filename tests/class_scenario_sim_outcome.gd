class_name ClassScenarioSimOutcome
extends RefCounted

## Shared post-sim outcome asserts for thin harness delegates (CLASS_QA_BIBLE.md §3 Layer B).


static func assert_from_events(
	failures: Array[String],
	prefix: String,
	ability: AbilityData,
	events: Array[SimEvent],
	board_before: BoardState,
	board_after: BoardState,
	target_unit_id: int,
) -> void:
	if ability == null:
		return
	if _ability_has_effect(ability, GameEnums.EffectType.DAMAGE, false):
		_assert_damage(failures, prefix, events, board_before, board_after, target_unit_id)
	if _ability_has_effect(ability, GameEnums.EffectType.HEAL, false):
		_assert_heal(failures, prefix, events, board_after, target_unit_id)
	if _ability_has_effect(ability, GameEnums.EffectType.ADD_STATUS, false):
		_assert_status(failures, prefix, board_after, target_unit_id)
	if _ability_has_effect(ability, GameEnums.EffectType.MOVE, false) \
			or _ability_has_effect(ability, GameEnums.EffectType.DASH, false) \
			or _ability_has_effect(ability, GameEnums.EffectType.TELEPORT_CASTER, false):
		_assert_move(failures, prefix, board_before, board_after, 1)
	if _ability_has_effect(ability, GameEnums.EffectType.CHANGE_TERRAIN, false) \
			or _ability_has_effect(ability, GameEnums.EffectType.CREATE_HAZARD, false):
		_assert_terrain(failures, prefix, events)


static func _ability_has_effect(
	ability: AbilityData,
	effect_type: GameEnums.EffectType,
	upgraded: bool,
) -> bool:
	var effects: Array = ability.upgraded_effects if upgraded else ability.effects
	for effect: EffectData in effects:
		if effect != null and effect.type == effect_type:
			return true
	return false


static func _assert_damage(
	failures: Array[String],
	prefix: String,
	events: Array[SimEvent],
	board_before: BoardState,
	board_after: BoardState,
	target_unit_id: int,
) -> void:
	var damaged := false
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
			damaged = true
			break
	if not damaged and target_unit_id > 0:
		var before: UnitState = board_before.get_unit_by_id(target_unit_id)
		var after: UnitState = board_after.get_unit_by_id(target_unit_id)
		if before != null and after != null:
			damaged = after.health.current_hp < before.health.current_hp
	_assert(failures, "%s/outcome/damage" % prefix, damaged)


static func _assert_heal(
	failures: Array[String],
	prefix: String,
	events: Array[SimEvent],
	board_after: BoardState,
	target_unit_id: int,
) -> void:
	var healed := false
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.UNIT_HEALED:
			healed = true
			break
	if not healed and target_unit_id > 0:
		var unit: UnitState = board_after.get_unit_by_id(target_unit_id)
		if unit != null:
			healed = unit.health.current_hp > 0
	_assert(failures, "%s/outcome/heal" % prefix, healed)


static func _assert_status(
	failures: Array[String],
	prefix: String,
	board_after: BoardState,
	target_unit_id: int,
) -> void:
	if target_unit_id <= 0:
		return
	var unit: UnitState = board_after.get_unit_by_id(target_unit_id)
	_assert(
		failures, "%s/outcome/status" % prefix,
		unit != null and not unit.status_effects.is_empty(),
	)


static func _assert_move(
	failures: Array[String],
	prefix: String,
	board_before: BoardState,
	board_after: BoardState,
	actor_id: int,
) -> void:
	var before: UnitState = board_before.get_unit_by_id(actor_id)
	var after: UnitState = board_after.get_unit_by_id(actor_id)
	_assert(
		failures, "%s/outcome/move" % prefix,
		before != null and after != null and before.position != after.position,
	)


static func _assert_terrain(
	failures: Array[String],
	prefix: String,
	events: Array[SimEvent],
) -> void:
	for event: SimEvent in events:
		if event.type == GameEnums.SimEventType.TERRAIN_CHANGED:
			return
	_assert(failures, "%s/outcome/terrain" % prefix, false)


static func _assert(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
