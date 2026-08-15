class_name DataLibrary
extends RefCounted

const LancerFactoryScript := preload("res://core/factory/classes/lancer_factory.gd")
const ArcherFactoryScript := preload("res://core/factory/classes/archer_factory.gd")
const ClericFactoryScript := preload("res://core/factory/classes/cleric_factory.gd")
const MageFactoryScript := preload("res://core/factory/classes/mage_factory.gd")
const MercenaryFactoryScript := preload("res://core/factory/classes/mercenary_factory.gd")
const MonkFactoryScript := preload("res://core/factory/classes/monk_factory.gd")
const ShamanFactoryScript := preload("res://core/factory/classes/shaman_factory.gd")
const RogueFactoryScript := preload("res://core/factory/classes/rogue_factory.gd")
const BeastRiderFactoryScript := preload("res://core/factory/classes/beast_rider_factory.gd")
const EngineerFactoryScript := preload("res://core/factory/classes/engineer_factory.gd")

## Purpose: A hardcoded central registry of all Units, Terrain, Abilities, and Maps.
## This simulates loading .tres files from disk until the actual asset pipeline
## and resource authoring is set up in the editor.

static var _player_units: Array[UnitData] = []
static var _enemy_units: Array[UnitData] = []
static var _all_units_dict: Dictionary = {}
static var _maps: Array[MapData] = []
static var _universal_run: AbilityData
static var _universal_wait: AbilityData


## Clears cached registry so the next access re-runs factory init (editor reset).
static func reset_cache() -> void:
	_player_units.clear()
	_enemy_units.clear()
	_all_units_dict.clear()
	_maps.clear()
	_cached_terrains.clear()
	_universal_run = null
	_universal_wait = null


static func get_all_player_units() -> Array[UnitData]:
	_ensure_init()
	return _player_units

static func get_all_enemy_units() -> Array[UnitData]:
	_ensure_init()
	return _enemy_units

static func get_all_maps() -> Array[MapData]:
	_ensure_init()
	return _maps
	
static func get_unit(id: StringName) -> UnitData:
	_ensure_init()
	return _all_units_dict.get(id)


static func get_training_dummy() -> UnitData:
	_ensure_init()
	return _all_units_dict.get(&"training_dummy")


static func get_player_class_ids() -> Array[StringName]:
	_ensure_init()
	var ids: Array[StringName] = []
	for unit: UnitData in _player_units:
		ids.append(unit.id)
	return ids


static func build_player_active_abilities(def: UnitData, level: int) -> Array[AbilityData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(def.id) if def != null else "")
	if level >= 99:
		return build_player_active_abilities_seeded(def, -1, rng)
	if level == 1:
		return build_player_active_abilities_seeded(def, 1, rng)
	return build_player_active_abilities_seeded(def, -1, rng)


static func build_player_active_abilities_seeded(
	def: UnitData,
	class_skill_count: int,
	rng: RandomNumberGenerator,
) -> Array[AbilityData]:
	if def == null:
		return []
	if def.is_construct:
		return def.abilities.duplicate()
	var out: Array[AbilityData] = []
	var basic_attack: AbilityData = null
	var reposition_skills: Array[AbilityData] = []
	var class_abilities: Array[AbilityData] = []
	for ab: AbilityData in def.abilities:
		if is_basic_ability(ab.id):
			basic_attack = ab
		elif ab.is_pre_move_planner():
			reposition_skills.append(ab)
		else:
			class_abilities.append(ab)
	if basic_attack == null:
		basic_attack = _make_class_basic_attack(def.id)
	out.append(get_universal_run())
	out.append_array(reposition_skills)
	out.append(basic_attack)
	var pick_count: int = class_skill_count
	if pick_count < 0 or pick_count >= class_abilities.size():
		out.append_array(class_abilities)
	elif pick_count == 0:
		pass
	else:
		var pool: Array[AbilityData] = class_abilities.duplicate()
		for _i: int in range(mini(pick_count, pool.size())):
			var idx: int = rng.randi() % pool.size()
			out.append(pool[idx])
			pool.remove_at(idx)
	return out


static func build_training_abilities(def: UnitData) -> Array[AbilityData]:
	return build_player_active_abilities(def, 99)


static func _ensure_init() -> void:
	if not _player_units.is_empty():
		return

	_universal_run = _make_ability(
		&"universal_run",
		"Run",
		0,
		[],
		1,
	)
	_universal_run.kind = GameEnums.AbilityKind.UNIVERSAL_RUN
	_universal_run.targeting_mode = GameEnums.TargetingMode.SELF
	_universal_run.targeting_flags = GameEnums.TargetingFlags.SELF
	_universal_run.sync_legacy_targeting()
	_universal_run.presentation_anim = GameEnums.PresentationAnim.WALK
	_universal_run.finalize_modular()
	_universal_wait = _make_ability(&"universal_wait", "Wait", 0, [], 0)
	_universal_wait.kind = GameEnums.AbilityKind.UNIVERSAL_WAIT
	_universal_wait.targeting_mode = GameEnums.TargetingMode.SELF
	_universal_wait.targeting_flags = GameEnums.TargetingFlags.SELF
	_universal_wait.sync_legacy_targeting()
	_universal_wait.finalize_modular()

	var _trade := _make_ability(&"swap", "Swap", 1, [_effect(GameEnums.EffectType.SWAP, 0)], 0)
	_trade.finalize_modular()
	
	var c_turret = _make_construct(&"construct_turret", "Construct Turret", 50.0)
	var c_tesla = _make_construct(&"tesla_barricade", "Tesla Barricade", 150.0)
	var c_mine = _make_construct(&"magnetic_mine", "Magnetic Mine", 25.0)
	var c_voodoo = _make_construct(&"voodoo_totem", "Voodoo Totem", 50.0)
	var c_bone = _make_construct(&"bone_barricade", "Bone Barricade", 50.0)
	var c_obsidian = _make_construct(&"obsidian_wall", "Obsidian Wall", 50.0)
	var c_hammer = _make_construct(&"divine_hammer", "Divine Hammer", 10.0)
	var c_ghost = _make_construct(&"ghost_ally", "Ghost Ally", 0.0)
	
	var basic_axe = _make_weapon(&"iron_axe", "Iron Axe")
	var basic_sword = _make_weapon(&"iron_sword", "Iron Sword")
	var basic_lance = _make_weapon(&"iron_lance", "Iron Lance")
	var basic_bow = _make_weapon(&"iron_bow", "Iron Bow")
	var basic_staff = _make_weapon(&"wooden_staff", "Wooden Staff")
	var basic_fist = _make_weapon(&"wrap", "Hand Wraps")
	var basic_gun = _make_weapon(&"flintlock", "Flintlock")

	# 1. KNIGHT (AXE)
	var knight := KnightFactory.build(basic_axe)

	# 2. BRUISER (AXE)
	var fighter := BruiserFactory.build(basic_axe)

	# 4. LANCER (LANCE)
	var lancer: UnitData = LancerFactoryScript.build(basic_lance)

	# 5. ARCHER (BOW)
	var archer: UnitData = ArcherFactoryScript.build(basic_bow)

	# 6. MAGE (MAGIC)
	var mage: UnitData = MageFactoryScript.build(basic_staff)

	# 7. CLERIC (STAFF)
	var cleric: UnitData = ClericFactoryScript.build(basic_staff)

	# 8. MERCENARY (SWORD)
	var mercenary: UnitData = MercenaryFactoryScript.build(basic_sword)

	# 9. MONK (FIST)
	var monk: UnitData = MonkFactoryScript.build(basic_fist)

	# 10. ENGINEER (GUN/EXPLOSIVES)
	var engineer: UnitData = EngineerFactoryScript.build(basic_gun)

	# 11. SHAMAN (STAFF)
	var shaman: UnitData = ShamanFactoryScript.build(basic_staff)

	# 12. ROGUE (SWORD)
	var rogue: UnitData = RogueFactoryScript.build(basic_sword)

	# 13. BEAST RIDER (LANCE)
	var beast_rider: UnitData = BeastRiderFactoryScript.build(basic_lance)

	_player_units = [
		knight, fighter, mercenary, rogue, monk, beast_rider,
		mage, archer, cleric, shaman, lancer, engineer,
	]
	for u in _player_units:
		_ensure_player_basic_attack(u)
		finalize_unit_abilities(u)

	var charger := _make_unit_data(&"charger", "Charger", 3, 4, 1, [],
		_behavior(&"charger", _make_ability(&"gore", "Gore", 1, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 4, 0, 1)
	var artillery := _make_unit_data(&"artillery", "Artillery", 2, 2, 1, [],
		_behavior(&"artillery", _make_ability(&"bolt", "Bolt", 3, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 5, 0, 0)
	var shover := _make_unit_data(&"shover", "Shover", 3, 3, 1, [],
		_behavior(&"shover", _make_ability(&"bash", "Bash", 1, [_effect(GameEnums.EffectType.PUSH, 2)], 1)), GameEnums.MovementType.WALK, 3, 0, 2)
	
	var trapper := _make_unit_data(&"trapper", "Trapper", 2, 3, 1, [],
		_behavior(&"artillery", _make_ability(&"hook", "Hook", 3, [_effect(GameEnums.EffectType.PULL, 2)], 1)), GameEnums.MovementType.WALK, 3, 0, 1)
	var brute := _make_unit_data(&"brute", "Brute", 4, 2, 1, [],
		_behavior(&"melee_chase", _make_ability(&"slam", "Slam", 1, [_effect(GameEnums.EffectType.DAMAGE, 2), _effect(GameEnums.EffectType.PUSH, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 5, 0, 3)
	var priest := _make_unit_data(&"priest", "Priest", 2, 3, 1, [],
		_behavior(&"healer", _make_ability(&"mend", "Mend", 2, [_effect(GameEnums.EffectType.HEAL, 3)], 1, GameEnums.StatType.MAGICAL)), GameEnums.MovementType.WALK, 0, 3, 1)

	var hatchling := _make_unit_data(&"hatchling", "Hatchling", 1, 3, 1, [],
		_behavior(&"melee_chase", _make_ability(&"bite", "Bite", 1, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 2, 0, 0)
	var protector := _make_unit_data(&"protector", "Protector", 4, 3, 1, [],
		_behavior(&"protector", _make_ability(&"shield_ally", "Shield Ally", 1, [_effect(GameEnums.EffectType.ARMOR_UP, 1)], 1)), GameEnums.MovementType.WALK, 2, 0, 3)
	var commander := _make_unit_data(&"commander", "Commander", 3, 3, 1, [],
		_behavior(&"commander", _make_ability(&"command_buff", "Command Buff", 3, [_effect(GameEnums.EffectType.ARMOR_UP, 1)], 1)), GameEnums.MovementType.WALK, 0, 3, 2)
	var bomber := _make_unit_data(&"bomber", "Bomber", 2, 4, 1, [],
		_behavior(&"bomber", _make_ability(&"detonate", "Detonate", 0, [_effect(GameEnums.EffectType.EXPLODE, 5)], 1)), GameEnums.MovementType.WALK, 0, 0, 0)
	var teleporter := _make_unit_data(&"teleporter", "Teleporter", 2, 4, 1, [],
		_behavior(&"teleporter", _make_ability(&"warp_strike", "Warp Strike", 1, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)),
		GameEnums.MovementType.TELEPORT, 4, 0, 1)
	var summoner := _make_unit_data(&"summoner", "Summoner", 2, 2, 1, [],
		_behavior(&"summoner", _make_ability(&"spawn_hatchling", "Spawn Hatchling", 1, [_effect(GameEnums.EffectType.SPAWN, 0)], 1), hatchling, 3), GameEnums.MovementType.WALK, 0, 4, 1)
	var sentinel := _make_unit_data(&"sentinel", "Sentinel", 4, 0, 1, [],
		_behavior(&"sentinel", _make_ability(&"turret_shot", "Turret Shot", 2, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 5, 0, 2)
	var flanker := _make_unit_data(&"flanker", "Flanker", 2, 4, 1, [],
		_behavior(&"flanker", _make_ability(&"backstab", "Backstab", 1, [_effect(GameEnums.EffectType.DAMAGE, 1)], 1, GameEnums.StatType.PHYSICAL)), GameEnums.MovementType.WALK, 4, 0, 1)

	priest.preferred_stat = GameEnums.StatType.MAGICAL
	protector.preferred_stat = GameEnums.StatType.DEFENSE

	_enemy_units = [charger, artillery, shover, trapper, brute, priest, hatchling, protector, commander, bomber, teleporter, summoner, sentinel, flanker]
	for u in _enemy_units:
		if u.equipped_weapon == null:
			u.equipped_weapon = basic_sword
		# All enemies except hatchlings get a basic attack for when they are staggered
		if u.id != &"hatchling":
			_ensure_player_basic_attack(u)
		finalize_unit_abilities(u)
		_finalize_behavior_abilities(u)

	for u in _player_units:
		_all_units_dict[u.id] = u
	for u in _enemy_units:
		_all_units_dict[u.id] = u

	var cleric_holy_hammer := _make_unit_data(
		&"cleric_holy_hammer",
		"Holy Hammer",
		1,
		0,
		1,
		[],
		null,
		GameEnums.MovementType.WALK,
		0,
		0,
		0,
		basic_sword,
		[],
	)
	cleric_holy_hammer.is_construct = true
	cleric_holy_hammer.construct_scaling_percent = 25.0
	_all_units_dict[cleric_holy_hammer.id] = cleric_holy_hammer

	for u in _player_units:
		finalize_unit_abilities(u)
	for u in _enemy_units:
		finalize_unit_abilities(u)
		_finalize_behavior_abilities(u)

	var training_dummy := _make_unit_data(
		&"training_dummy",
		"Training Dummy",
		20,
		0,
		0,
		[],
		null,
		GameEnums.MovementType.WALK,
		0,
		0,
		2,
	)
	training_dummy.preferred_stat = GameEnums.StatType.MAX_HP
	_all_units_dict[&"training_dummy"] = training_dummy

	# Setup Maps
	_maps.append(_build_proving_grounds(charger, artillery))
	_maps.append(_build_the_crossing(trapper, shover, artillery))
	_maps.append(_build_siege_approach(brute, priest, artillery))
	_maps.append(_build_the_hive(summoner, protector, flanker))
	_maps.append(_build_powder_keg(bomber, commander, sentinel))

static func _build_proving_grounds(e_ch: UnitData, e_ar: UnitData) -> MapData:
	var enc := EncounterData.new()
	enc.display_name = "Proving Grounds"
	enc.map_description = "A standard arena with a central pit. Good for learning the basics."
	enc.grid_size = Vector2i(17, 11)
	enc.default_terrain = _plain()
	
	var pit_x := 9
	for pit_y in range(3, 8):
		enc.tile_terrains[Vector2i(pit_x, pit_y)] = _hazard(&"pit", "Pit", 6, true)
	enc.tile_terrains[Vector2i(pit_x, 2)] = _wall()
	enc.tile_terrains[Vector2i(pit_x, 8)] = _wall()
	for spike_x in range(3, 7):
		enc.tile_terrains[Vector2i(spike_x, 9)] = _hazard(&"spikes", "Spikes", 2, false)
	enc.tile_terrains[Vector2i(5, 4)] = _wall()
	enc.tile_terrains[Vector2i(5, 6)] = _wall()
	enc.tile_terrains[Vector2i(12, 4)] = _wall()
	enc.tile_terrains[Vector2i(12, 6)] = _wall()
	enc.tile_terrains[Vector2i(3, 3)] = _tall_grass()
	enc.tile_terrains[Vector2i(3, 4)] = _tall_grass()
	enc.tile_terrains[Vector2i(13, 3)] = _castle()

	var pu := _player_units.duplicate()
	pu.shuffle()
	enc.player_spawns = [
		_spawn(pu[0], Vector2i(1, 2)), _spawn(pu[1], Vector2i(1, 4)), 
		_spawn(pu[2], Vector2i(1, 6)), _spawn(pu[3], Vector2i(1, 8))
	]
	enc.enemy_spawns = [
		_spawn(e_ch, Vector2i(15, 2)), _spawn(e_ch, Vector2i(15, 8)), _spawn(e_ch, Vector2i(14, 3)),
		_spawn(e_ch, Vector2i(14, 7)), _spawn(e_ar, Vector2i(15, 5)), _spawn(e_ar, Vector2i(16, 5))
	]
	
	var map := MapData.new()
	map.display_name = enc.display_name
	map.map_description = enc.map_description
	map.encounter = enc
	map.card_color = Color(0.2, 0.4, 0.2)
	return map

static func _build_the_crossing(e_tr: UnitData, e_sh: UnitData, e_ar: UnitData) -> MapData:
	var enc := EncounterData.new()
	enc.display_name = "The Crossing"
	enc.map_description = "A tight chokepoint river map favoring displacement."
	enc.grid_size = Vector2i(13, 9)
	enc.default_terrain = _plain()
	
	var water = _hazard(&"water", "Shallows", 0, false)
	water.fortitude = -1 # vulnerable in water
	for y in range(9):
		for x in range(5, 8):
			if (y == 3 or y == 4 or y == 5) and (x == 6 or x == 7):
				enc.tile_terrains[Vector2i(x, y)] = _plain() # Bridge 1
			elif (y == 0 or y == 1 or y == 8) and x == 6:
				enc.tile_terrains[Vector2i(x, y)] = _wall()
			else:
				enc.tile_terrains[Vector2i(x, y)] = water

	var pu := _player_units.duplicate()
	pu.shuffle()
	enc.player_spawns = [
		_spawn(pu[0], Vector2i(1, 3)), _spawn(pu[1], Vector2i(1, 5)), _spawn(pu[2], Vector2i(2, 4)), _spawn(pu[3], Vector2i(0, 4))
	]
	enc.enemy_spawns = [
		_spawn(e_sh, Vector2i(8, 3)), _spawn(e_sh, Vector2i(8, 5)), _spawn(e_sh, Vector2i(9, 4)), 
		_spawn(e_ar, Vector2i(10, 4)), _spawn(e_tr, Vector2i(10, 7)), _spawn(e_tr, Vector2i(10, 1))
	]
	
	var map := MapData.new()
	map.display_name = enc.display_name
	map.map_description = enc.map_description
	map.encounter = enc
	map.card_color = Color(0.2, 0.3, 0.6)
	return map

static func _build_siege_approach(e_br: UnitData, e_pr: UnitData, e_ar: UnitData) -> MapData:
	var enc := EncounterData.new()
	enc.display_name = "Siege Approach"
	enc.map_description = "A wide open field leading to a fortified position."
	enc.grid_size = Vector2i(20, 13)
	enc.default_terrain = _plain()
	
	for y in range(2, 7):
		enc.tile_terrains[Vector2i(14, y)] = _wall()
	for x in range(14, 20):
		enc.tile_terrains[Vector2i(x, 2)] = _wall()
		if x > 15:
			enc.tile_terrains[Vector2i(x, 4)] = _castle()
			enc.tile_terrains[Vector2i(x, 5)] = _castle()

	var pu := _player_units.duplicate()
	pu.shuffle()
	enc.player_spawns = [
		_spawn(pu[0], Vector2i(2, 4)), _spawn(pu[1], Vector2i(1, 5)), _spawn(pu[2], Vector2i(2, 6)), _spawn(pu[3], Vector2i(3, 5))
	]
	enc.enemy_spawns = [
		_spawn(e_br, Vector2i(12, 4)), _spawn(e_br, Vector2i(12, 6)), _spawn(e_br, Vector2i(13, 5)),
		_spawn(e_pr, Vector2i(15, 5)),
		_spawn(e_ar, Vector2i(17, 3)), _spawn(e_ar, Vector2i(17, 7))
	]
	
	var map := MapData.new()
	map.display_name = enc.display_name
	map.map_description = enc.map_description
	map.encounter = enc
	map.card_color = Color(0.5, 0.2, 0.2)
	return map

# --- Builders ---

static func _spawn(u: UnitData, c: Vector2i) -> UnitPlacement:
	var p = UnitPlacement.new()
	p.unit = u
	p.coord = c
	return p

static func _behavior(strategy: StringName, attack: AbilityData, spawn_unit: UnitData = null, max_spawns: int = 0) -> BehaviorData:
	var b := BehaviorData.new()
	b.strategy = strategy
	b.attack = attack
	b.spawn_unit = spawn_unit
	b.max_spawns = max_spawns
	return b

static func _effect(type: GameEnums.EffectType, amount: int) -> EffectData:
	var e := EffectData.new()
	e.type = type
	e.amount = amount
	return e

static func _spawn_effect(spawn_id: StringName) -> EffectData:
	var e := EffectData.new()
	e.type = GameEnums.EffectType.SPAWN
	e.spawn_unit_id = spawn_id
	return e

static func _status_effect(type: GameEnums.StatusType, duration: int, value: int = 0) -> EffectData:
	var e := EffectData.new()
	e.type = GameEnums.EffectType.ADD_STATUS
	e.status_type = type
	e.status_duration = duration
	e.amount = value
	return e

static func _status_effect_self(type: GameEnums.StatusType, duration: int, value: int = 0) -> EffectData:
	var e := EffectData.new()
	e.type = GameEnums.EffectType.ADD_STATUS_SELF
	e.status_type = type
	e.status_duration = duration
	e.amount = value
	return e


static func make_status(type: GameEnums.StatusType, duration: int, value: int = 0) -> StatusData:
	return StatusData.new(type, duration, value)


static func _module(
	primary_type: GameEnums.EffectType,
	amount: int,
	min_range: int,
	max_range: int,
	targeting_flags: int,
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
	scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE,
	motion_mode: GameEnums.MotionMode = GameEnums.MotionMode.NONE,
) -> AbilityModule:
	var module := AbilityModule.new()
	module.primary_type = primary_type
	module.amount = amount
	module.min_range = min_range
	module.max_range = max_range
	module.targeting_flags = targeting_flags
	module.target_shape = shape
	module.target_shape_size = shape_size
	module.scaling_stat = scaling_stat
	module.motion_mode = motion_mode
	return module


static func _layer(
	effect: EffectData,
	condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION,
) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.effect = effect
	layer.condition = condition
	return layer


static func _keyword(
	keyword_id: GameEnums.AbilityKeywordId,
	amount: int = 0,
	push_amount: int = 0,
	emit_as_effect: bool = false,
) -> AbilityKeyword:
	var keyword := AbilityKeyword.new()
	keyword.keyword_id = keyword_id
	keyword.amount = amount
	keyword.push_amount = push_amount
	keyword.emit_as_effect = emit_as_effect
	return keyword


static func _duplicate_modules(source: Array[AbilityModule]) -> Array[AbilityModule]:
	var result: Array[AbilityModule] = []
	for module: AbilityModule in source:
		result.append(module.duplicate(true) as AbilityModule)
	return result


static func _flags_to_targeting_mode(flags: int) -> GameEnums.TargetingMode:
	if (flags & GameEnums.TargetingFlags.DASH_LINE) != 0:
		return GameEnums.TargetingMode.DASH_LINE
	if (flags & GameEnums.TargetingFlags.TILE) != 0:
		return GameEnums.TargetingMode.TILE
	if (flags & GameEnums.TargetingFlags.SELF) != 0 and (
		flags & (GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.ALLY)
	) == 0:
		return GameEnums.TargetingMode.SELF
	if (flags & GameEnums.TargetingFlags.ALLY) != 0:
		return GameEnums.TargetingMode.ALLY_UNIT
	if (flags & GameEnums.TargetingFlags.ENEMY) != 0:
		return GameEnums.TargetingMode.ENEMY_UNIT
	return GameEnums.TargetingMode.TILE


static func _make_modular_ability(
	p_id: StringName,
	p_name: String,
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	primary_value: int = 1,
	planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION,
	primary_resource: GameEnums.CostResource = GameEnums.CostResource.AP,
	tags: Array[StringName] = [],
	upgrade_description: String = "",
	targeting_flags: int = GameEnums.TargetingFlags.ENEMY,
	secondary_resource: GameEnums.CostResource = GameEnums.CostResource.NONE,
	secondary_value: int = 0,
	cost_modifier: GameEnums.CostModifier = GameEnums.CostModifier.NONE,
	cost_modifier_n: int = 0,
	upgraded_primary_value: int = -1,
	upgraded_secondary_value: int = -1,
) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = p_id
	ability.display_name = p_name
	ability.kind = (
		GameEnums.AbilityKind.MOVEMENT_SKILL
		if planner_group == GameEnums.PlannerGroup.PRE_MOVE
		else GameEnums.AbilityKind.CLASS_SKILL
	)
	ability.planner_group = planner_group
	ability.primary_resource = primary_resource
	ability.primary_value = primary_value
	ability.upgraded_primary_value = upgraded_primary_value
	ability.secondary_resource = secondary_resource
	ability.secondary_value = secondary_value
	ability.upgraded_secondary_value = upgraded_secondary_value
	ability.cost_modifier = cost_modifier
	ability.cost_modifier_n = cost_modifier_n
	ability.action_point_cost = primary_value if primary_resource == GameEnums.CostResource.AP else 0
	ability.movement_point_cost = primary_value if primary_resource == GameEnums.CostResource.MP else 0
	ability.is_movement_skill = planner_group == GameEnums.PlannerGroup.PRE_MOVE
	ability.modules = modules
	ability.upgraded_modules = upgraded_modules
	ability.tags = tags
	ability.upgrade_description = upgrade_description
	ability.targeting_flags = targeting_flags
	ability.targeting_mode = _flags_to_targeting_mode(targeting_flags)
	var first_motion_range: int = -1
	var authored_new_aim: bool = false
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.aim_binding != GameEnums.AimBinding.NEW_AIM:
			continue
		if AbilityModuleBridge.is_motion_type(module.primary_type):
			if first_motion_range < 0:
				first_motion_range = module.max_range
			if not authored_new_aim:
				ability.range_tiles = module.max_range
				authored_new_aim = true
			continue
		if not authored_new_aim:
			ability.range_tiles = module.max_range
			authored_new_aim = true
		ability.target_shape = module.target_shape
		ability.target_shape_size = module.target_shape_size
		break
	if not authored_new_aim and first_motion_range >= 0:
		ability.range_tiles = first_motion_range
	if ability.target_shape != GameEnums.TargetShape.SINGLE and (
		(targeting_flags & GameEnums.TargetingFlags.ENEMY) != 0
		or (targeting_flags & GameEnums.TargetingFlags.ALLY) != 0
	):
		ability.targeting_flags |= GameEnums.TargetingFlags.TILE
	ability.presentation_key = p_id
	ability.presentation_anim = (
		GameEnums.PresentationAnim.WALK
		if planner_group == GameEnums.PlannerGroup.PRE_MOVE
		else GameEnums.PresentationAnim.AUTO
	)
	ability.effects = AbilityModuleBridge.compile_modules_to_effects(ability.modules)
	ability.sync_legacy_targeting()
	for module: AbilityModule in modules:
		if module != null and module.scaling_stat != GameEnums.StatType.NONE:
			ability.scaling_stat = module.scaling_stat
			break
	return ability


static func _make_ability(p_id: StringName, p_name: String, p_range: int, effects: Array[EffectData], ap_cost: int = 1, stat: GameEnums.StatType = GameEnums.StatType.NONE, shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE, shape_size: int = 1) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = p_id
	ability.display_name = p_name
	ability.kind = GameEnums.AbilityKind.CLASS_SKILL
	ability.planner_group = GameEnums.PlannerGroup.ACTION
	ability.primary_resource = GameEnums.CostResource.AP
	ability.primary_value = ap_cost
	ability.action_point_cost = ap_cost
	ability.range_tiles = p_range
	ability.presentation_key = p_id
	ability.effects = effects
	ability.scaling_stat = stat
	ability.target_shape = shape
	ability.target_shape_size = shape_size
	_configure_ability_targeting(ability)
	if is_basic_ability(p_id):
		ability.action_point_cost = 0
		ability.primary_value = 0
	## finalize_modular() runs after factory post-mutations (see finalize_unit_abilities).
	return ability


static func _configure_ability_targeting(ability: AbilityData) -> void:
	if ability == null or ability.is_movement_kind():
		return
	if ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		ability.targeting_mode = GameEnums.TargetingMode.SELF
		ability.targeting_flags = GameEnums.TargetingFlags.SELF
		ability.sync_legacy_targeting()
		return
	var effects: Array[EffectData] = ability.effects
	if effects.is_empty():
		return
	var only_self_buffs := true
	var has_offense := false
	var has_heal := false
	for eff: EffectData in effects:
		match eff.type:
			GameEnums.EffectType.ADD_STATUS_SELF, GameEnums.EffectType.DAMAGE_SELF:
				continue
			GameEnums.EffectType.HEAL, GameEnums.EffectType.CLEANSE, GameEnums.EffectType.ARMOR_UP:
				has_heal = true
				only_self_buffs = false
			GameEnums.EffectType.ADD_STATUS:
				if GameEnums.is_debuff(eff.status_type):
					has_offense = true
					only_self_buffs = false
				else:
					only_self_buffs = false
			GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL, \
			GameEnums.EffectType.PURGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE, \
			GameEnums.EffectType.DASH, GameEnums.EffectType.DESTROY_OBSTACLE:
				has_offense = true
				only_self_buffs = false
			GameEnums.EffectType.SWAP:
				only_self_buffs = false
			_:
				only_self_buffs = false
	if only_self_buffs and ability.range_tiles == 0:
		ability.targeting_mode = GameEnums.TargetingMode.SELF
	elif ability.range_tiles == 0 and ability.target_shape != GameEnums.TargetShape.SINGLE:
		ability.targeting_mode = GameEnums.TargetingMode.SELF
	elif has_heal and not has_offense:
		ability.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	elif has_offense:
		ability.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	elif not has_offense:
		ability.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	ability.targeting_flags = AbilityData._targeting_mode_to_flags(ability.targeting_mode)
	_sync_shaped_tile_targeting_flags(ability)
	ability.sync_legacy_targeting()


## Ranged blast/arc/line (AOE, ARC, SKEWER) skills use the TILE awaiting-input pipeline.
static func _sync_shaped_tile_targeting_flags(ability: AbilityData) -> void:
	if ability == null or ability.is_movement_kind():
		return
	if ability.has_targeting(GameEnums.TargetingFlags.TILE):
		return
	if ability.has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		return
	var shaped_base := (
		ability.range_tiles > 0
		and ability.target_shape != GameEnums.TargetShape.SINGLE
	)
	var upg_range := ability.range_tiles
	if ability.upgraded_range_tiles >= 0:
		upg_range = ability.upgraded_range_tiles
	var shaped_upg := (
		upg_range > 0
		and ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE
	)
	if not shaped_base and not shaped_upg:
		return
	if ability.has_targeting(GameEnums.TargetingFlags.ENEMY):
		ability.targeting_flags |= GameEnums.TargetingFlags.TILE
	elif ability.has_targeting(GameEnums.TargetingFlags.ALLY):
		ability.targeting_flags |= GameEnums.TargetingFlags.TILE


static func _make_movement_ability(
	p_id: StringName,
	p_name: String,
	p_range: int,
	effects: Array[EffectData],
	mp_cost: int = 1,
	stat: GameEnums.StatType = GameEnums.StatType.NONE,
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
	targeting: GameEnums.TargetingMode = GameEnums.TargetingMode.ALLY_UNIT,
) -> AbilityData:
	var ability := _make_ability(p_id, p_name, p_range, effects, 0, stat, shape, shape_size)
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.planner_group = GameEnums.PlannerGroup.PRE_MOVE
	ability.primary_resource = GameEnums.CostResource.MP
	ability.primary_value = mp_cost
	ability.movement_point_cost = mp_cost
	ability.targeting_mode = targeting
	ability.is_movement_skill = true
	ability.presentation_anim = GameEnums.PresentationAnim.WALK
	ability.targeting_flags = AbilityData._targeting_mode_to_flags(ability.targeting_mode)
	ability.sync_legacy_targeting()
	ability.tags = [AbilityModuleBridge.TAG_POSITIONING]
	## finalize_modular() runs after factory post-mutations (see finalize_unit_abilities).
	return ability


## Call after factory finishes mutating abilities (modifiers, upgrades, targeting).
static func finalize_unit_abilities(unit: UnitData) -> void:
	if unit == null:
		return
	for ability: AbilityData in unit.abilities:
		if ability != null:
			ability.finalize_modular()
			_sync_shaped_tile_targeting_flags(ability)
			ability.sync_legacy_targeting()


static func _finalize_behavior_abilities(unit: UnitData) -> void:
	if unit == null or unit.behavior == null:
		return
	var behavior_ability: AbilityData = unit.behavior.attack
	if behavior_ability != null:
		behavior_ability.finalize_modular()


static func is_basic_ability(ability_id: StringName) -> bool:
	return ability_id == &"basic_attack" or String(ability_id).ends_with("_basic")


static func is_universal_run(ability_id: StringName) -> bool:
	return ability_id == &"universal_run"


static func is_universal_wait(ability_id: StringName) -> bool:
	return ability_id == &"universal_wait"


static func is_movement_ability(ability_id: StringName) -> bool:
	return is_universal_run(ability_id)


static func get_universal_run() -> AbilityData:
	_ensure_init()
	return _universal_run


static func get_universal_wait() -> AbilityData:
	_ensure_init()
	return _universal_wait


static func _make_class_basic_attack(class_id: StringName) -> AbilityData:
	var id: StringName = &"basic_attack"
	var display_name: String = "Basic Attack"
	var rng: int = 1
	var effects: Array[EffectData] = [_effect(GameEnums.EffectType.DAMAGE, 1)]
	var stat: GameEnums.StatType = GameEnums.StatType.PHYSICAL
	match class_id:
		&"knight":
			id = &"knight_basic"
			display_name = "Shield Strike"
		&"bruiser":
			id = &"bruiser_basic"
			display_name = "Wild Swing"
		&"lancer":
			id = &"lancer_basic"
			display_name = "Lance Thrust"
			rng = 2
		&"archer":
			id = &"archer_basic"
			display_name = "Snap Shot"
			rng = 2
		&"mage":
			id = &"mage_basic"
			display_name = "Arcane Flick"
			rng = 2
			stat = GameEnums.StatType.MAGICAL
		&"cleric":
			id = &"cleric_basic"
			display_name = "Mending Touch"
			effects = [_effect(GameEnums.EffectType.HEAL, 1)]
			stat = GameEnums.StatType.MAGICAL
		&"mercenary":
			id = &"mercenary_basic"
			display_name = "Quick Cut"
		&"monk":
			id = &"monk_basic"
			display_name = "Finger Jab"
		&"engineer":
			id = &"engineer_basic"
			display_name = "Pistol Tap"
			rng = 2
		&"shaman":
			id = &"shaman_basic"
			display_name = "Spirit Nudge"
			rng = 2
			stat = GameEnums.StatType.MAGICAL
		&"rogue":
			id = &"rogue_basic"
			display_name = "Quick Strike"
		&"beast_rider":
			id = &"beast_rider_basic"
			display_name = "Lance Jab"
			rng = 1
	if class_id == &"lancer":
		effects[0].modifiers["range_one_damage_multiplier"] = 0.7
	var targeting_flags: int = (
		GameEnums.TargetingFlags.ALLY
		if effects[0].type == GameEnums.EffectType.HEAL
		else GameEnums.TargetingFlags.ENEMY
	)
	var module := _module(
		effects[0].type,
		effects[0].amount,
		1 if rng > 0 else 0,
		rng,
		targeting_flags,
		GameEnums.TargetShape.SINGLE,
		1,
		stat,
	)
	module.legacy_modifiers = effects[0].modifiers.duplicate(true)
	var ab: AbilityData = _make_modular_ability(
		id,
		display_name,
		[module],
		_duplicate_modules([module]),
		0,
		GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP,
		[AbilityModuleBridge.TAG_ATTACK],
		"",
		targeting_flags,
	)
	return ab

static func _ensure_player_basic_attack(unit: UnitData) -> void:
	if unit == null or unit.is_construct:
		return
	for i in range(unit.abilities.size() - 1, -1, -1):
		if is_basic_ability(unit.abilities[i].id):
			unit.abilities.remove_at(i)
	unit.abilities.insert(0, _make_class_basic_attack(unit.id))

static func _make_unit_data(p_id: StringName, p_name: String, con: int, p_move: int, p_act: int, abs: Array[AbilityData], behav: BehaviorData = null, m_type = GameEnums.MovementType.WALK, base_str: int = 1, base_mag: int = 1, base_def: int = 1, wpn = null, passives: Array[PassiveData] = []) -> UnitData:
	var u := UnitData.new()
	u.id = p_id
	u.display_name = p_name
	u.base_constitution = con
	u.move_points = p_move
	u.action_points = p_act
	u.abilities = abs
	u.behavior = behav
	u.movement_type = m_type
	u.base_strength = base_str
	u.base_magic = base_mag
	u.base_defense = base_def
	u.equipped_weapon = wpn
	u.passives = passives
	_all_units_dict[p_id] = u
	return u
	
static func _make_construct(p_id: StringName, p_name: String, scaling_pct: float) -> UnitData:
	var u := UnitData.new()
	u.id = p_id
	u.display_name = p_name
	u.base_constitution = 1
	u.move_points = 0
	u.action_points = 1
	u.abilities = []
	u.behavior = null
	u.movement_type = GameEnums.MovementType.WALK
	u.base_strength = 0
	u.base_magic = 0
	u.base_defense = 0
	u.is_construct = true
	u.construct_scaling_percent = scaling_pct
	_all_units_dict[p_id] = u
	return u

static func _duplicate_effects(effects: Array[EffectData]) -> Array[EffectData]:
	var result: Array[EffectData] = []
	for e in effects:
		var dup = e.duplicate(true)
		result.append(dup)
	return result

static func _make_weapon(id: StringName, name: String, might: int = 4) -> WeaponData:
	var w = WeaponData.new()
	w.id = id
	w.display_name = name
	w.might = might
	return w
	
static func _make_passive(id: StringName, name: String, desc: String, upgrade_desc: String = "", modifiers: Dictionary = {}) -> PassiveData:
	var p = PassiveData.new()
	p.id = id
	p.display_name = name
	p.description = desc
	p.upgraded_description = upgrade_desc
	p.modifiers = modifiers
	return p

static func _plain() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"plain"
	t.display_name = "Plain"
	return t

static func _wall() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"wall"
	t.display_name = "Wall"
	t.blocks_movement = true
	t.stops_displacement = true
	return t

static func _tall_grass() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"tall_grass"
	t.display_name = "Tall Grass"
	t.fortitude = 1
	return t

static func _castle() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"castle"
	t.display_name = "Castle"
	t.fortitude = 2
	t.elevated = true
	return t

static func _hazard(p_id: StringName, p_name: String, damage: int, is_pit: bool) -> TerrainData:
	var t := TerrainData.new()
	t.id = p_id
	t.display_name = p_name
	t.hazard_damage = damage
	t.blocks_movement = is_pit
	t.stops_displacement = false
	t.is_trap = p_id == &"trap"
	return t

static func _fire() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"fire"
	t.display_name = "Fire"
	t.hazard_damage = 2
	return t

static func _poison() -> TerrainData:
	var t := _hazard(&"poison", "Poison", 1, false)
	t.entry_status = GameEnums.StatusType.POISON
	t.entry_status_duration = 1
	return t

static func _water() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"water"
	t.display_name = "Water"
	# Extinguishes burn, adds vulnerability to lightning, etc (handled via system)
	return t

static func _oil() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"oil"
	t.display_name = "Oil"
	# Increases movement cost, ignites into fire
	return t

static func _steam() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"steam"
	t.display_name = "Steam"
	# Blocks line of sight / grants evasion
	return t

static func _frozen() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"frozen"
	t.display_name = "Frozen"
	# Ice physics (slide) or root
	return t
	
static func _cracked() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"cracked"
	t.display_name = "Cracked Earth"
	t.mp_cost_per_tile = 2
	# Becomes pit if hit again
	return t


static func _arcane_trail() -> TerrainData:
	return _hazard(&"arcane_trail", "Arcane Trail", 0, false)


static func _crater() -> TerrainData:
	return _hazard(&"crater", "Crater", 1, false)


static func _trampled() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"trampled"
	t.display_name = "Trampled Ground"
	t.mp_cost_per_tile = 2
	return t

static func _bear_trap() -> TerrainData:
	var t := _hazard(&"bear_trap", "Bear Trap", 3, false)
	t.is_trap = true
	t.entry_status = GameEnums.StatusType.ROOT
	t.entry_status_duration = 1
	return t

static func _caltrop_trap() -> TerrainData:
	var t := _hazard(&"caltrop_trap", "Caltrop Trap", 0, false)
	t.is_trap = true
	t.entry_status = GameEnums.StatusType.ROOT
	t.entry_status_duration = 1
	t.entry_bleed_amount = 1
	return t

static func _suppressing_fire() -> TerrainData:
	var t := _hazard(&"suppressing_fire", "Suppressing Fire", 0, false)
	t.entry_status_duration = 1
	t.entry_move_penalty = 1
	return t

static func _spear_wall() -> TerrainData:
	var t := _hazard(&"spear_wall", "Spear Wall", 2, false)
	t.entry_status = GameEnums.StatusType.ROOT
	t.entry_status_duration = 1
	return t

static func _barbed_wire() -> TerrainData:
	var t := _hazard(&"barbed_wire", "Barbed Wire", 0, false)
	t.is_trap = true
	t.entry_status = GameEnums.StatusType.ROOT
	t.entry_status_duration = 1
	t.entry_bleed_amount = 1
	return t

static func _sanctuary() -> TerrainData:
	var t := _hazard(&"sanctuary", "Sanctuary", 0, false)
	t.display_name = "Sanctuary"
	return t

static func _holy_ground() -> TerrainData:
	var t := _hazard(&"holy_ground", "Holy Ground", 0, false)
	t.display_name = "Holy Ground"
	return t

static func _smoke() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"smoke"
	t.display_name = "Smoke"
	# Blocks line of sight
	return t

static var _cached_terrains: Dictionary = {}

static func get_terrain(id: StringName) -> TerrainData:
	if _cached_terrains.is_empty():
		_cached_terrains[&"plain"] = _plain()
		_cached_terrains[&"wall"] = _wall()
		_cached_terrains[&"tall_grass"] = _tall_grass()
		_cached_terrains[&"castle"] = _castle()
		_cached_terrains[&"fire"] = _fire()
		_cached_terrains[&"poison"] = _poison()
		_cached_terrains[&"water"] = _water()
		_cached_terrains[&"oil"] = _oil()
		_cached_terrains[&"steam"] = _steam()
		_cached_terrains[&"frozen"] = _frozen()
		_cached_terrains[&"cracked"] = _cracked()
		_cached_terrains[&"arcane_trail"] = _arcane_trail()
		_cached_terrains[&"crater"] = _crater()
		_cached_terrains[&"trampled"] = _trampled()
		_cached_terrains[&"bear_trap"] = _bear_trap()
		_cached_terrains[&"caltrop_trap"] = _caltrop_trap()
		_cached_terrains[&"suppressing_fire"] = _suppressing_fire()
		_cached_terrains[&"spear_wall"] = _spear_wall()
		_cached_terrains[&"barbed_wire"] = _barbed_wire()
		_cached_terrains[&"sanctuary"] = _sanctuary()
		_cached_terrains[&"holy_ground"] = _holy_ground()
		_cached_terrains[&"smoke"] = _smoke()
		_cached_terrains[&"pit"] = _hazard(&"pit", "Pit", 6, true)
		_cached_terrains[&"spikes"] = _hazard(&"spikes", "Spikes", 2, false)
	return _cached_terrains.get(id)

static func get_all_terrains() -> Array[TerrainData]:
	if _cached_terrains.is_empty():
		get_terrain(&"plain") # Force initialization
		
	var arr: Array[TerrainData] = []
	for k in _cached_terrains.keys():
		arr.append(_cached_terrains[k])
	return arr

static func _build_the_hive(e_sum: UnitData, e_pr: UnitData, e_fl: UnitData) -> MapData:
	var enc := EncounterData.new()
	enc.display_name = "The Hive"
	enc.map_description = "Open terrain infested with summoners. Kill them before the hatchlings overwhelm you!"
	enc.grid_size = Vector2i(15, 10)
	enc.default_terrain = _plain()
	
	enc.tile_terrains[Vector2i(3, 3)] = _tall_grass()
	enc.tile_terrains[Vector2i(3, 6)] = _tall_grass()
	enc.tile_terrains[Vector2i(11, 3)] = _tall_grass()
	enc.tile_terrains[Vector2i(11, 6)] = _tall_grass()
	enc.tile_terrains[Vector2i(7, 4)] = _castle()
	enc.tile_terrains[Vector2i(7, 5)] = _castle()
	
	var pu := _player_units.duplicate()
	pu.shuffle()
	enc.player_spawns = [
		_spawn(pu[0], Vector2i(1, 2)), _spawn(pu[1], Vector2i(1, 4)),
		_spawn(pu[2], Vector2i(1, 6)), _spawn(pu[3], Vector2i(1, 8))
	]
	enc.enemy_spawns = [
		_spawn(e_sum, Vector2i(13, 5)),
		_spawn(e_pr, Vector2i(11, 5)),
		_spawn(e_fl, Vector2i(9, 2)),
		_spawn(e_fl, Vector2i(9, 7)),
		_spawn(e_fl, Vector2i(10, 3)),
		_spawn(e_fl, Vector2i(10, 6))
	]
	
	var map := MapData.new()
	map.display_name = enc.display_name
	map.map_description = enc.map_description
	map.encounter = enc
	map.card_color = Color(0.4, 0.1, 0.4)
	return map

static func _build_powder_keg(e_bo: UnitData, e_cmd: UnitData, e_se: UnitData) -> MapData:
	var enc := EncounterData.new()
	enc.display_name = "Powder Keg"
	enc.map_description = "Tight corridors packed with explosive bombers and zone-denying sentinels."
	enc.grid_size = Vector2i(16, 9)
	enc.default_terrain = _plain()
	
	for x in [4, 8, 12]:
		for y in range(0, 9):
			if y != 2 and y != 6:
				enc.tile_terrains[Vector2i(x, y)] = _wall()
				
	enc.tile_terrains[Vector2i(4, 2)] = _hazard(&"spikes", "Spikes", 2, false)
	enc.tile_terrains[Vector2i(8, 6)] = _hazard(&"spikes", "Spikes", 2, false)
	enc.tile_terrains[Vector2i(12, 2)] = _hazard(&"spikes", "Spikes", 2, false)
	
	var pu := _player_units.duplicate()
	pu.shuffle()
	enc.player_spawns = [
		_spawn(pu[0], Vector2i(1, 2)), _spawn(pu[1], Vector2i(1, 4)),
		_spawn(pu[2], Vector2i(2, 3)), _spawn(pu[3], Vector2i(1, 6))
	]
	enc.enemy_spawns = [
		_spawn(e_se, Vector2i(6, 2)),
		_spawn(e_se, Vector2i(10, 6)),
		_spawn(e_bo, Vector2i(6, 6)),
		_spawn(e_bo, Vector2i(10, 2)),
		_spawn(e_bo, Vector2i(14, 4)),
		_spawn(e_cmd, Vector2i(14, 5))
	]
	
	var map := MapData.new()
	map.display_name = enc.display_name
	map.map_description = enc.map_description
	map.encounter = enc
	map.card_color = Color(0.6, 0.3, 0.1)
	return map
