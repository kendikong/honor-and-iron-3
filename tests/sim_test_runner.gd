class_name SimTestRunner
extends RefCounted

## Purpose: The actual Milestone 1 checks for the pure simulation, in one place so
## both the command-line runner and the in-editor runner share identical logic
## (no duplicated tests).
## Responsibilities: Build tiny in-code scenarios, run the Simulator, assert
##   outcomes, and print a readable battle log demo.
## Dependencies: the whole core/ simulation stack + data/ definitions.
## Lifecycle: created by a runner, used once via run_all(), then discarded.

## Runs every check. Returns the number of failures (0 == all passed).
func run_all() -> int:
	var failures := 0
	failures += _check("preview matches execution", _test_preview_matches_execution())
	failures += _check("input board is never mutated", _test_input_not_mutated())
	failures += _check("push into wall deals collision damage", _test_push_into_wall())
	failures += _check("battle reaches a conclusion", _test_battle_completes())
	failures += _check("bomber self-destructs and damages adjacent", _test_bomber_explodes())
	failures += _check("summoner spawns minion and respects cap", _test_summoner_spawns())
	failures += _check("teleporter warps behind farthest player", _test_teleporter_warps())
	failures += _check("engineer grenade damages target and adjacent without self-damage", _test_engineer_grenade())
	failures += _check("movement skill spends MP not AP", _test_movement_skill_spends_mp())
	failures += _check("movement skill resolves in pre-move bucket", _test_movement_skill_pre_move_bucket())
	failures += _check("run clears next turn and can be used again", _test_run_available_next_turn())
	failures += _check("run leaves action slot for 0 AP basic attack", _test_run_leaves_action_slot())

	print_demo_battle()

	if failures == 0:
		print("\n[PASS] All Milestone 1 simulation tests passed.")
	else:
		printerr("[FAIL] %d Milestone 1 test(s) failed." % failures)
	return failures

# --- Readable demo so you can SEE the engine work ------------------------------

## Simulates one full turn and prints the ordered event log in plain English,
## using a tidy scenario that shows a move -> slash -> knockback-into-wall chain.
func print_demo_battle() -> void:
	print("\n--- DEMO: one simulated turn (plain-English event log) ---")
	# 6x3 board with a wall at (4,1). Knight at (1,1), training dummy at (3,1).
	var board := _empty_board(Vector2i(6, 3), [Vector2i(4, 1)])
	var knight_def := _make_unit_data(&"knight", 12, 3, 1, null)
	var dummy_def := _make_unit_data(&"dummy", 6, 0, 0, null)
	_place(board, 1, knight_def, GameEnums.Team.PLAYER, Vector2i(1, 1))
	_place(board, 2, dummy_def, GameEnums.Team.ENEMY, Vector2i(3, 1))
	print("Start: Knight at (1,1), Dummy (6 hp) at (3,1), Wall at (4,1).")

	var plan := Timeline.new()
	var slash := _make_attack(&"slash", 4, 1, 1)  # 4 damage, then push 1 tile
	plan.add(TimelineAction.make_move(1, Vector2i(2, 1)))
	plan.add(TimelineAction.make_ability(1, slash, Vector2i(3, 1), 2))
	print("Player plan: step to (2,1), then slash the dummy east.")

	var result := Simulator.simulate(board, plan)
	print("What happens, in order:")
	for event in result.events:
		print("  - %s" % _humanize(event))
	var dummy_after := result.final_state.get_unit_by_id(2)
	print("Result: Dummy at %s with %d hp (4 from slash, +1 from hitting the wall)." % [
		dummy_after.position, dummy_after.health.current_hp,
	])
	print("--- end demo ---")

func _humanize(event: SimEvent) -> String:
	var d := event.data
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			return "unit %s walks from %s to %s (%s steps)" % [d.get("actor"), d.get("from"), d.get("to"), d.get("steps")]
		GameEnums.SimEventType.UNIT_PUSHED:
			return "unit %s is pushed from %s to %s" % [d.get("unit"), d.get("from"), d.get("to")]
		GameEnums.SimEventType.COLLISION:
			return "unit %s collides with %s at %s" % [d.get("unit"), d.get("against"), d.get("coord")]
		GameEnums.SimEventType.UNIT_DAMAGED:
			return "unit %s takes %s damage (hp now %s)" % [d.get("unit"), d.get("amount"), d.get("hp")]
		GameEnums.SimEventType.UNIT_DIED:
			return "unit %s dies" % d.get("unit")
		GameEnums.SimEventType.ACTION_FAILED:
			return "action by %s failed (%s)" % [d.get("actor"), d.get("reason")]
		GameEnums.SimEventType.TURN_ENDED:
			return "turn %s ends" % d.get("turn")
		_:
			return event.describe()

# --- Content builders (in code, so no .tres authoring is needed yet) -----------

func _make_terrain(p_id: StringName, blocks: bool) -> TerrainData:
	var t := TerrainData.new()
	t.id = p_id
	t.display_name = String(p_id)
	t.blocks_movement = blocks
	t.stops_displacement = blocks
	return t

func _make_attack(p_id: StringName, dmg: int, push: int, p_range: int) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = p_id
	ability.display_name = String(p_id)
	ability.action_point_cost = 1
	ability.range_tiles = p_range
	var effects: Array[EffectData] = []
	if dmg > 0:
		var d := EffectData.new()
		d.type = GameEnums.EffectType.DAMAGE
		d.amount = dmg
		effects.append(d)
	if push > 0:
		var p := EffectData.new()
		p.type = GameEnums.EffectType.PUSH
		p.amount = push
		effects.append(p)
	ability.effects = effects
	return ability

func _make_unit_data(p_id: StringName, hp: int, move: int, ap: int, behavior: BehaviorData) -> UnitData:
	var u := UnitData.new()
	u.id = p_id
	u.display_name = String(p_id)
	u.max_hp = hp
	u.move_points = move
	u.action_points = ap
	u.behavior = behavior
	u.base_strength = 0
	u.base_magic = 0
	u.base_defense = 0
	return u

func _empty_board(size: Vector2i, walls: Array[Vector2i]) -> BoardState:
	var plain := _make_terrain(&"plain", false)
	var wall := _make_terrain(&"wall", true)
	var board := BoardState.new()
	board.grid_size = size
	for y in range(size.y):
		for x in range(size.x):
			var coord := Vector2i(x, y)
			var terrain := wall if walls.has(coord) else plain
			board.tiles[coord] = TileState.create(coord, terrain)
	return board

func _place(board: BoardState, unit_id: int, def: UnitData, team: GameEnums.Team, coord: Vector2i) -> UnitState:
	var unit := UnitState.create(unit_id, def, team, coord)
	board.units.append(unit)
	GridSystem.set_occupant(board, coord, unit_id)
	return unit

# --- Scenario used by the equality tests ---------------------------------------

func _build_skirmish() -> BoardState:
	var board := _empty_board(Vector2i(8, 8), [])
	var player_def := _make_unit_data(&"knight", 12, 3, 1, null)
	var enemy_behavior := BehaviorData.new()
	enemy_behavior.strategy = &"melee_chase"
	enemy_behavior.attack = _make_attack(&"claw", 3, 0, 1)
	var enemy_def := _make_unit_data(&"goblin", 6, 3, 1, enemy_behavior)

	_place(board, 1, player_def, GameEnums.Team.PLAYER, Vector2i(1, 1))
	_place(board, 2, enemy_def, GameEnums.Team.ENEMY, Vector2i(6, 6))

	# Lock enemy intents, exactly as a planning phase would.
	board.intents = EnemyPlanner.plan(board)
	return board

func _build_skirmish_plan(_board: BoardState) -> Timeline:
	var plan := Timeline.new()
	var attack := _make_attack(&"slash", 4, 1, 1)
	plan.add(TimelineAction.make_move(1, Vector2i(3, 3)))
	plan.add(TimelineAction.make_ability(1, attack, Vector2i(3, 4)))
	return plan

# --- Tests ---------------------------------------------------------------------

func _test_preview_matches_execution() -> bool:
	var board := _build_skirmish()
	var plan := _build_skirmish_plan(board)
	# "Preview" and "execute" are the same call; run twice and compare outputs.
	var r1 := Simulator.simulate(board, plan)
	var r2 := Simulator.simulate(board, plan)
	var ok := true
	if _hash_board(r1.final_state) != _hash_board(r2.final_state):
		ok = false
		printerr("  board mismatch:\n  A=%s\n  B=%s" % [_hash_board(r1.final_state), _hash_board(r2.final_state)])
	if _hash_events(r1.events) != _hash_events(r2.events):
		ok = false
		printerr("  event mismatch:\n  A=\n%s\n  B=\n%s" % [_hash_events(r1.events), _hash_events(r2.events)])
	return ok

func _test_input_not_mutated() -> bool:
	var board := _build_skirmish()
	var plan := _build_skirmish_plan(board)
	var before := _hash_board(board)
	Simulator.simulate(board, plan)
	var after := _hash_board(board)
	if before != after:
		printerr("  input changed:\n  before=%s\n  after =%s" % [before, after])
		return false
	return true

func _test_push_into_wall() -> bool:
	# Player at (0,1), enemy at (1,1), wall at (2,1). PUSH 3 into the wall
	# (0 tiles moved, excess 3) deals scaled collision damage; enemy does not move.
	var board := _empty_board(Vector2i(5, 3), [Vector2i(2, 1)])
	var player_def := _make_unit_data(&"knight", 12, 3, 1, null)
	var enemy_def := _make_unit_data(&"dummy", 6, 0, 0, null)  # no behavior -> no intent
	var player := _place(board, 1, player_def, GameEnums.Team.PLAYER, Vector2i(0, 1))
	var enemy := _place(board, 2, enemy_def, GameEnums.Team.ENEMY, Vector2i(1, 1))
	var expected_dmg := CombatSystem.collision_scaled_raw(
		player, CombatSystem.collision_base(3), board,
	)

	var plan := Timeline.new()
	var shove := _make_attack(&"shove", 0, 3, 1)
	plan.add(TimelineAction.make_ability(1, shove, Vector2i(1, 1), 2))

	var result := Simulator.simulate(board, plan)
	var enemy_after := result.final_state.get_unit_by_id(2)
	var ok := true
	if enemy_after.position != Vector2i(1, 1):
		ok = false
		printerr("  enemy moved unexpectedly to %s" % enemy_after.position)
	if enemy_after.health.current_hp != enemy.health.max_hp - expected_dmg:
		ok = false
		printerr("  expected hp %d, got %d (collision dmg %d)" % [
			enemy.health.max_hp - expected_dmg, enemy_after.health.current_hp, expected_dmg,
		])
	return ok

func _test_battle_completes() -> bool:
	var board := _build_skirmish()
	var strong := _make_attack(&"smite", 6, 0, 2)
	var max_turns := 30
	var turn := 0
	while board.has_living_team(GameEnums.Team.PLAYER) and board.has_living_team(GameEnums.Team.ENEMY):
		turn += 1
		if turn > max_turns:
			printerr("  battle did not conclude within %d turns" % max_turns)
			return false
		# Re-plan enemy intents from the live board each turn.
		board.intents = EnemyPlanner.plan(board)
		var plan := Timeline.new()
		var player := board.get_unit_by_id(1)
		var enemy := board.get_unit_by_id(2)
		if player != null and enemy != null and player.is_alive() and enemy.is_alive():
			plan.add(TimelineAction.make_ability(1, strong, enemy.position, enemy.id))
		# Adopt the simulated future as the new real board (this is "execute").
		board = Simulator.simulate(board, plan).final_state
	return not board.has_living_team(GameEnums.Team.ENEMY)

# --- Helpers -------------------------------------------------------------------

func _check(label: String, passed: bool) -> int:
	if passed:
		print("[ok] %s" % label)
		return 0
	printerr("[X] %s" % label)
	return 1

func _hash_board(b: BoardState) -> String:
	var ids: Array[int] = []
	for u in b.units:
		ids.append(u.id)
	ids.sort()
	var parts: Array[String] = ["turn=%d" % b.turn_index]
	for id in ids:
		var u := b.get_unit_by_id(id)
		parts.append("u%d[pos=%s,hp=%d,team=%d,mp=%d,ap=%d]" % [
			u.id, u.position, u.health.current_hp, u.team,
			u.movement.points_left, u.ability.points_left,
		])
	return ";".join(parts)

func _hash_events(events: Array[SimEvent]) -> String:
	var lines: Array[String] = []
	for e in events:
		lines.append(e.describe())
	return "\n".join(lines)

func _test_bomber_explodes() -> bool:
	var board := _empty_board(Vector2i(5, 5), [])
	
	var player_def := _make_unit_data(&"player", 10, 3, 1, null)
	var ally_def := _make_unit_data(&"ally", 10, 3, 1, null)
	
	var bomb_ability := AbilityData.new()
	bomb_ability.id = &"detonate"
	bomb_ability.display_name = "Detonate"
	bomb_ability.action_point_cost = 1
	bomb_ability.range_tiles = 0
	var bomb_effect := EffectData.new()
	bomb_effect.type = GameEnums.EffectType.EXPLODE
	bomb_effect.amount = 4
	bomb_ability.effects = [bomb_effect]
	
	var bomber_behavior := BehaviorData.new()
	bomber_behavior.strategy = &"bomber"
	bomber_behavior.attack = bomb_ability
	var bomber_def := _make_unit_data(&"bomber", 4, 4, 1, bomber_behavior)
	
	# Place units: Player at (2,2), Bomber at (2,3), Ally (enemy to player) at (1,3)
	_place(board, 1, player_def, GameEnums.Team.PLAYER, Vector2i(2, 2))
	var bomber := _place(board, 2, bomber_def, GameEnums.Team.ENEMY, Vector2i(2, 3))
	var ally := _place(board, 3, ally_def, GameEnums.Team.ENEMY, Vector2i(1, 3))
	
	board.intents = EnemyPlanner.plan(board)
	
	var plan := Timeline.new()
	var result := Simulator.simulate(board, plan)
	
	var p_after := result.final_state.get_unit_by_id(1)
	var b_after := result.final_state.get_unit_by_id(2)
	var a_after := result.final_state.get_unit_by_id(3)
	
	var ok := true
	if b_after != null and b_after.is_alive():
		ok = false
		printerr("  bomber did not die from self-destruct")
	if p_after == null or p_after.health.current_hp != 6: # 10 - 4
		ok = false
		printerr("  player did not take correct explode damage")
	if a_after == null or a_after.health.current_hp != 6: # 10 - 4
		ok = false
		printerr("  ally did not take correct explode damage")
	return ok

func _test_summoner_spawns() -> bool:
	var board := _empty_board(Vector2i(8, 8), [])
	
	var player_def := _make_unit_data(&"player", 10, 3, 1, null)
	var hatchling_def := _make_unit_data(&"hatchling", 3, 3, 1, null)
	
	var spawn_ability := AbilityData.new()
	spawn_ability.id = &"spawn"
	spawn_ability.display_name = "Spawn"
	spawn_ability.action_point_cost = 1
	spawn_ability.range_tiles = 1
	var spawn_effect := EffectData.new()
	spawn_effect.type = GameEnums.EffectType.SPAWN
	spawn_effect.amount = 0
	spawn_ability.effects = [spawn_effect]
	
	var summoner_behavior := BehaviorData.new()
	summoner_behavior.strategy = &"summoner"
	summoner_behavior.attack = spawn_ability
	summoner_behavior.spawn_unit = hatchling_def
	summoner_behavior.max_spawns = 2
	var summoner_def := _make_unit_data(&"summoner", 8, 2, 1, summoner_behavior)
	
	_place(board, 1, player_def, GameEnums.Team.PLAYER, Vector2i(0, 0))
	_place(board, 2, summoner_def, GameEnums.Team.ENEMY, Vector2i(4, 4))
	
	# Turn 1: should spawn a hatchling
	board.intents = EnemyPlanner.plan(board)
	var plan1 := Timeline.new()
	var r1 := Simulator.simulate(board, plan1)
	
	var ok := true
	if r1.final_state.units.size() != 3: # Player, Summoner, and 1 hatchling
		ok = false
		printerr("  summoner failed to spawn minion")
		
	# Turn 2: should spawn second hatchling
	var b2 := r1.final_state
	b2.intents = EnemyPlanner.plan(b2)
	var plan2 := Timeline.new()
	var r2 := Simulator.simulate(b2, plan2)
	
	if r2.final_state.units.size() != 4: # Player, Summoner, 2 hatchlings
		ok = false
		printerr("  summoner failed to spawn second minion")
		
	# Turn 3: should NOT spawn third hatchling because max_spawns = 2
	var b3 := r2.final_state
	b3.intents = EnemyPlanner.plan(b3)
	var plan3 := Timeline.new()
	var r3 := Simulator.simulate(b3, plan3)
	
	if r3.final_state.units.size() != 4: # Still 4
		ok = false
		printerr("  summoner spawned minion exceeding max_spawns limit")
		
	return ok

func _test_teleporter_warps() -> bool:
	var board := _empty_board(Vector2i(8, 8), [])
	
	var player_def := _make_unit_data(&"player", 10, 3, 1, null)
	
	var attack_ability := AbilityData.new()
	attack_ability.id = &"strike"
	attack_ability.display_name = "Strike"
	attack_ability.action_point_cost = 1
	attack_ability.range_tiles = 1
	var attack_effect := EffectData.new()
	attack_effect.type = GameEnums.EffectType.DAMAGE
	attack_effect.amount = 3
	attack_ability.effects = [attack_effect]
	
	var tele_behavior := BehaviorData.new()
	tele_behavior.strategy = &"teleporter"
	tele_behavior.attack = attack_ability
	var teleporter_def := _make_unit_data(&"teleporter", 6, 4, 1, tele_behavior)
	teleporter_def.movement_type = GameEnums.MovementType.TELEPORT
	
	# Place player at (2,2) facing EAST
	var p := _place(board, 1, player_def, GameEnums.Team.PLAYER, Vector2i(2, 2))
	p.facing = GameEnums.Facing.EAST
	
	# Place teleporter far away at (6,6)
	_place(board, 2, teleporter_def, GameEnums.Team.ENEMY, Vector2i(6, 6))
	
	board.intents = EnemyPlanner.plan(board)
	
	var plan := Timeline.new()
	var result := Simulator.simulate(board, plan)
	
	var p_after := result.final_state.get_unit_by_id(1)
	var t_after := result.final_state.get_unit_by_id(2)
	
	var ok := true
	if t_after == null or t_after.position != Vector2i(1, 2): # behind player facing EAST is (1,2)
		ok = false
		printerr("  teleporter did not warp to correct backstab tile (1,2), got %s" % (t_after.position if t_after != null else "null"))
	if p_after == null or p_after.health.current_hp != 5: # 10 - (3 base + 2 backstab bonus) = 5
		ok = false
		printerr("  teleporter did not attack target player correctly (hp: %s)" % (p_after.health.current_hp if p_after != null else "null"))
	return ok

func _test_engineer_grenade() -> bool:
	var board := _empty_board(Vector2i(8, 8), [])
	
	var eng_def := _make_unit_data(&"engineer", 12, 3, 1, null)
	var target_def := _make_unit_data(&"target", 10, 3, 1, null)
	var adjacent_def := _make_unit_data(&"adjacent", 10, 3, 1, null)
	
	# Place Engineer at (2, 2)
	var engineer := _place(board, 1, eng_def, GameEnums.Team.PLAYER, Vector2i(2, 2))
	# Place Target at (2, 5) (3 tiles away - range 3)
	var target := _place(board, 2, target_def, GameEnums.Team.ENEMY, Vector2i(2, 5))
	# Place Adjacent unit at (3, 5)
	var adjacent := _place(board, 3, adjacent_def, GameEnums.Team.ENEMY, Vector2i(3, 5))
	
	var grenade_ability := AbilityData.new()
	grenade_ability.id = &"eng_grenade"
	grenade_ability.display_name = "Grenade"
	grenade_ability.action_point_cost = 1
	grenade_ability.range_tiles = 3
	var grenade_effect := EffectData.new()
	grenade_effect.type = GameEnums.EffectType.RANGED_EXPLODE
	grenade_effect.amount = 2
	grenade_ability.effects = [grenade_effect]
	
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, grenade_ability, Vector2i(2, 5), 2))
	
	var result := Simulator.simulate(board, plan)
	
	var eng_after := result.final_state.get_unit_by_id(1)
	var target_after := result.final_state.get_unit_by_id(2)
	var adj_after := result.final_state.get_unit_by_id(3)
	
	var ok := true
	if eng_after == null or not eng_after.is_alive() or eng_after.health.current_hp != 12:
		ok = false
		printerr("  engineer was damaged or died from throwing grenade")
	if target_after == null or target_after.health.current_hp != 8:
		ok = false
		printerr("  target did not take correct grenade damage, hp: %s" % (target_after.health.current_hp if target_after != null else "null"))
	if adj_after == null or adj_after.health.current_hp != 8:
		ok = false
		printerr("  adjacent unit did not take correct grenade damage, hp: %s" % (adj_after.health.current_hp if adj_after != null else "null"))
	return ok


func _test_movement_skill_spends_mp() -> bool:
	var board := _empty_board(Vector2i(6, 6), [])
	var swap := AbilityData.new()
	swap.id = &"test_swap"
	swap.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	swap.is_movement_skill = true
	swap.movement_point_cost = 2
	swap.range_tiles = 1
	swap.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	var swap_fx := EffectData.new()
	swap_fx.type = GameEnums.EffectType.SWAP
	swap.effects = [swap_fx]
	var actor_def := _make_unit_data(&"actor", 10, 4, 1, null)
	var ally_def := _make_unit_data(&"ally", 10, 3, 1, null)
	var actor := _place(board, 1, actor_def, GameEnums.Team.PLAYER, Vector2i(2, 2))
	var ally := _place(board, 2, ally_def, GameEnums.Team.PLAYER, Vector2i(2, 3))
	actor.movement.points_left = 4
	actor.ability.points_left = 1
	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, swap, ally.position, 2, GameEnums.MoveTiming.PRE_ACTION))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)
	var ok := actor.movement.points_left == 2 and actor.ability.points_left == 1
	if not ok:
		printerr("  expected MP 2 and AP 1 after swap, got MP %d AP %d" % [
			actor.movement.points_left, actor.ability.points_left,
		])
	return ok


func _test_movement_skill_pre_move_bucket() -> bool:
	var swap := AbilityData.new()
	swap.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	swap.is_movement_skill = true
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(1, Vector2i(3, 2)))
	plan.add(TimelineAction.make_ability(1, swap, Vector2i(2, 2), 2, GameEnums.MoveTiming.PRE_ACTION))
	var steps: Array[TimelineAction] = UnitPlanOrder.ordered_steps_for_unit(plan, 1)
	if steps.size() != 2:
		printerr("  expected 2 pre-move steps, got %d" % steps.size())
		return false
	if not steps[1].ability.is_movement_kind():
		printerr("  movement skill must sort into pre-move column order")
		return false
	return true


func _test_run_available_next_turn() -> bool:
	var board := _empty_board(Vector2i(12, 3), [])
	var runner_def := _make_unit_data(&"runner", 10, 4, 1, null)
	_place(board, 1, runner_def, GameEnums.Team.PLAYER, Vector2i(0, 1))
	board.intents = []

	var plan_turn1 := Timeline.new()
	plan_turn1.add(TimelineAction.make_run_move(1, Vector2i(5, 1)))
	var after_turn1 := Simulator.simulate(board, plan_turn1)
	var runner_turn1 := after_turn1.final_state.get_unit_by_id(1)
	if runner_turn1 == null:
		printerr("  runner missing after turn 1")
		return false
	if runner_turn1.position != Vector2i(5, 1):
		printerr("  turn 1 run move failed, at %s" % runner_turn1.position)
		return false
	if runner_turn1.has_status(GameEnums.StatusType.RUNNING):
		printerr("  RUNNING must not be stored as a status")
		return false
	if runner_turn1.has_run_boost():
		printerr("  run boost must clear at turn boundary")
		return false
	if runner_turn1.ability.points_left != 1:
		printerr("  AP should refill for turn 2, got %d" % runner_turn1.ability.points_left)
		return false

	var plan_turn2 := Timeline.new()
	plan_turn2.add(TimelineAction.make_run_move(1, Vector2i(10, 1)))
	var after_turn2 := Simulator.simulate(after_turn1.final_state, plan_turn2)
	var runner_turn2 := after_turn2.final_state.get_unit_by_id(1)
	if runner_turn2 == null:
		printerr("  runner missing after turn 2")
		return false
	if runner_turn2.position != Vector2i(10, 1):
		printerr("  turn 2 run move failed, at %s" % runner_turn2.position)
		return false
	if runner_turn2.has_status(GameEnums.StatusType.RUNNING):
		printerr("  RUNNING must not persist after second turn")
		return false
	if runner_turn2.ability.points_left != 0:
		printerr("  second run should spend AP, left %d" % runner_turn2.ability.points_left)
		return false
	return true


func _test_run_leaves_action_slot() -> bool:
	var board := _empty_board(Vector2i(8, 3), [])
	var runner_def := _make_unit_data(&"runner", 10, 4, 1, null)
	var runner := _place(board, 1, runner_def, GameEnums.Team.PLAYER, Vector2i(0, 1))
	var basic := AbilityData.new()
	basic.id = &"basic_attack"
	basic.kind = GameEnums.AbilityKind.CLASS_SKILL
	basic.action_point_cost = 0
	basic.range_tiles = 1
	var dmg := EffectData.new()
	dmg.type = GameEnums.EffectType.DAMAGE
	dmg.amount = 1
	basic.effects = [dmg]

	var plan := Timeline.new()
	plan.add(TimelineAction.make_run_move(1, Vector2i(2, 1)))
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, plan, events)

	if runner.turn_action_used:
		printerr("  run must not consume the action slot")
		return false
	if runner.ability.points_left != 0:
		printerr("  run should spend 1 AP, left %d" % runner.ability.points_left)
		return false
	if not runner.can_use_action_slot():
		printerr("  action slot must stay open after run for 0 AP basic attack")
		return false
	if runner.turn_action_used:
		printerr("  run must not set turn_action_used")
		return false
	if not AbilitySystem.can_plan(runner, basic):
		printerr("  0 AP basic attack must be planable after run")
		return false
	return true

