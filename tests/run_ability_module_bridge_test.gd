extends Node

## Headless smoke: modular finalize preserves Knight/Bruiser effect fingerprints.
## Extends Node so project autoloads (EventBus) are registered before DataLibrary compiles.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	DataLibrary.reset_cache()
	_check_bruiser(failures)
	_check_knight(failures)
	_check_violent_collision_modules(failures)
	_check_native_module_runtime(failures)
	_check_active_upgrade_and_module_order(failures)
	if failures.is_empty():
		print("ABILITY_MODULE_BRIDGE_TEST: PASS")
		get_tree().quit(0)
	else:
		print("ABILITY_MODULE_BRIDGE_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
		get_tree().quit(1)


func _check_bruiser(failures: Array[String]) -> void:
	var bruiser: UnitData = DataLibrary.get_unit(&"bruiser")
	if bruiser == null:
		failures.append("bruiser missing from DataLibrary")
		return
	for ab: AbilityData in bruiser.abilities:
		if ab == null:
			continue
		if ab.modules.is_empty() and not ab.effects.is_empty():
			failures.append("%s has effects but empty modules" % String(ab.id))
		if ab.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			if ab.primary_resource != GameEnums.CostResource.MP:
				failures.append("%s PRE_MOVE primary_resource not MP" % String(ab.id))
			if not ab.has_tag(AbilityModuleBridge.TAG_POSITIONING):
				failures.append("%s PRE_MOVE missing positioning tag" % String(ab.id))
		elif ab.kind == GameEnums.AbilityKind.CLASS_SKILL:
			if ab.primary_resource != GameEnums.CostResource.AP:
				failures.append("%s ACTION primary_resource not AP" % String(ab.id))


func _check_knight(failures: Array[String]) -> void:
	var knight: UnitData = DataLibrary.get_unit(&"knight")
	if knight == null:
		failures.append("knight missing from DataLibrary")
		return
	var swap: AbilityData = null
	for ab: AbilityData in knight.abilities:
		if ab != null and ab.id == &"knight_swap":
			swap = ab
			break
	if swap == null:
		failures.append("knight_swap missing")
		return
	if swap.planner_group != GameEnums.PlannerGroup.PRE_MOVE:
		failures.append("knight_swap planner_group not PRE_MOVE")
	if swap.effects.is_empty() or swap.effects[0].type != GameEnums.EffectType.SWAP:
		failures.append("knight_swap lost SWAP effect after finalize")


func _check_violent_collision_modules(failures: Array[String]) -> void:
	var bruiser: UnitData = DataLibrary.get_unit(&"bruiser")
	if bruiser == null:
		return
	var vc: AbilityData = null
	for ab: AbilityData in bruiser.abilities:
		if ab != null and ab.id == &"bruiser_violent_collision":
			vc = ab
			break
	if vc == null:
		failures.append("bruiser_violent_collision missing")
		return
	if vc.modules.size() < 2:
		failures.append("violent_collision should have DASH + gated MOVE modules")
		return
	if vc.modules[0].primary_type != GameEnums.EffectType.DASH:
		failures.append("violent_collision module[0] should be DASH")
	if vc.modules[1].primary_type != GameEnums.EffectType.MOVE:
		failures.append("violent_collision module[1] should be MOVE")
	if vc.modules[1].gate != GameEnums.ModuleGate.IF_COLLIDED:
		failures.append("violent_collision module[1] gate not IF_COLLIDED")
	if vc.effects.is_empty() or not vc.effects[0].modifiers.has("violent_collision_recast"):
		failures.append("violent_collision legacy effects lost violent_collision_recast")
	if vc.effects.size() != 1:
		failures.append(
			"violent_collision legacy effects should stay 1 DASH (got %d)" % vc.effects.size()
		)
	if not vc.effects[0].modifiers.has("bulldoze"):
		failures.append("violent_collision lost bulldoze modifier")
	## Charge Strike: MOVE module + DAMAGE module with PUSH layer (not three peer modules).
	var charge: AbilityData = null
	for ab2: AbilityData in bruiser.abilities:
		if ab2 != null and ab2.id == &"bruiser_charge_strike":
			charge = ab2
			break
	if charge == null:
		failures.append("bruiser_charge_strike missing")
	elif charge.modules.size() < 2:
		failures.append("charge_strike should be MOVE module + strike module")
	elif charge.modules[0].primary_type != GameEnums.EffectType.MOVE \
			or charge.modules[1].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("charge_strike module order should be MOVE then DAMAGE")
	elif charge.modules[1].layers.is_empty():
		failures.append("charge_strike strike module should have PUSH layer")


func _plain_board(size: Vector2i) -> BoardState:
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, terrain)
	return board


func _check_native_module_runtime(failures: Array[String]) -> void:
	var board := _plain_board(Vector2i(8, 4))
	var actor := UnitState.new()
	actor.id = 1
	actor.team = GameEnums.Team.PLAYER
	actor.position = Vector2i(1, 1)
	actor.health = HealthComponent.new(20)
	actor.ability = AbilityComponent.new(1)
	var target := UnitState.new()
	target.id = 2
	target.team = GameEnums.Team.ENEMY
	target.position = Vector2i(3, 1)
	target.health = HealthComponent.new(20)
	board.units = [actor, target]
	GridSystem.set_occupant(board, actor.position, actor.id)
	GridSystem.set_occupant(board, target.position, target.id)

	var ability := AbilityData.new()
	ability.id = &"module_only_damage"
	ability.kind = GameEnums.AbilityKind.CLASS_SKILL
	ability.action_point_cost = 1
	ability.range_tiles = 3
	ability.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	var damage := AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [damage]
	ability.effects = []
	var action := TimelineAction.make_ability(actor.id, ability, target.position, target.id)
	var events: Array[SimEvent] = []
	AbilitySystem.execute(board, action, events)
	if target.health.current_hp != 16:
		failures.append(
			"module-only runtime should apply DAMAGE 4 (HP %d)" % target.health.current_hp
		)
	if not ability.effects.is_empty():
		failures.append("module-only fixture must keep effects[] empty")


func _check_active_upgrade_and_module_order(failures: Array[String]) -> void:
	var ability := AbilityData.new()
	ability.id = &"module_profile_fixture"
	var base_damage := AbilityModule.new()
	base_damage.primary_type = GameEnums.EffectType.DAMAGE
	base_damage.amount = 2
	var base_push := AbilityModule.new()
	base_push.primary_type = GameEnums.EffectType.PUSH
	base_push.amount = 1
	var upgraded_damage := AbilityModule.new()
	upgraded_damage.primary_type = GameEnums.EffectType.DAMAGE
	upgraded_damage.amount = 5
	ability.modules = [base_damage, base_push]
	ability.upgraded_modules = [upgraded_damage]
	var actor := UnitState.new()
	actor.id = 7
	actor.upgraded_abilities = [ability.id]
	var active_effects := AbilitySystem.active_effects_for(actor, ability)
	if active_effects.size() != 1 or active_effects[0].amount != 5:
		failures.append("active upgraded module profile was not selected")
	var ordered_effects := AbilitySystem.active_effects_for(UnitState.new(), ability)
	if ordered_effects.size() != 2 \
			or ordered_effects[0].type != GameEnums.EffectType.DAMAGE \
			or ordered_effects[1].type != GameEnums.EffectType.PUSH:
		failures.append("module runtime did not preserve ordered primary effects")
