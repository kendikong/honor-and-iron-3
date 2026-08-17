class_name ArcherFactory
extends RefCounted

## Builds the Bible's complete Archer promotion pool.
## Archer mechanics are authored as modular AbilityData and interpreted by the
## shared ability, combat, movement, and terrain systems.


static func build(basic_bow: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"archer"
	def.display_name = "Archer"
	def.base_constitution = 3
	def.move_points = 4
	def.action_points = GameEnums.MAX_AP
	def.base_strength = 4
	def.base_defense = 1
	def.base_magic = 1
	def.equipped_weapon = basic_bow
	def.promotion_stat_bonuses = {
		&"sniper": {"strength": 6, "movement": 2},
		&"trapper": {"strength": 4, "defense": 4, "movement": 0},
		&"nomad": {"strength": 2, "constitution": 2, "movement": 3},
	}

	var sidestep_module := DataLibrary._module(
		GameEnums.EffectType.MOVE, 1, 1, 1, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	sidestep_module.preserve_facing = true
	sidestep_module.ignore_zoc = true
	var sidestep_upgraded := DataLibrary._duplicate_modules([sidestep_module])
	sidestep_upgraded[0].next_ranged_attack_strength = 1
	var sidestep := DataLibrary._make_modular_ability(
		&"archer_sidestep", "Sidestep", [sidestep_module],
		sidestep_upgraded, 1, GameEnums.PlannerGroup.PRE_MOVE,
		GameEnums.CostResource.MP, [AbilityModuleBridge.TAG_POSITIONING],
		"Your next ranged attack gains +1 STR.", GameEnums.TargetingFlags.TILE,
	)
	def.abilities.append(sidestep)

	# Innate trait.
	def.innate_passives.append(_passive(
		&"lightfoot",
		"Steady Aim",
		"Spend MOV equal to Max MOV while standing still to gain +1 RANGE and +1 STR for attacks this turn.",
		"Gain +2 RANGE, +2 STR, and PIERCE instead.",
		{"steady_aim": true, "steady_aim_range": 1, "steady_aim_strength": 1,
		"upgraded_steady_aim_range": 2, "upgraded_steady_aim_strength": 2,
		"upgraded_steady_aim_pierce": true},
	))

	# Sniper passives.
	def.passives.append(_passive(
		&"overwatch",
		"Overwatch",
		"If you do not spend your Action this turn, pre-plot a cone reaction. First enemy entering that cone in LOS suffers a WPN basic attack.",
		"That reaction also applies ROOT.",
		{"planning_unused_ap_reaction": 1, "overwatch_basic_attack": true,
		"overwatch_cone_size": 4, "upgraded_overwatch_root": true},
	))
	def.passives.append(_passive(
		&"high_ground",
		"High Ground",
		"Attacking from elevation grants +1 RANGE and ignores 50% of target DEF.",
		"Attacking from elevation grants +1 RANGE and ignores 50% of target DEF.",
		{"elevation_range": 1, "elevation_def_multiplier": 0.5},
	))
	def.passives.append(_passive(
		&"patient_hunter",
		"Vantage Anchor",
		"Triggering Steady Aim grants STURDY and STEALTH against enemies further than 3 tiles away until your next turn.",
		"While Anchored, also gain +1 STR.",
		{"vantage_anchor": true, "vantage_anchor_sturdy": true,
		"vantage_anchor_stealth_range": 3, "upgraded_vantage_anchor_strength": 1},
	))
	def.passives.append(_passive(
		&"true_sight",
		"True Sight",
		"Attacks ignore cover bonuses and STEALTH.",
		"Attacks ignore cover bonuses and STEALTH.",
		{"ignore_cover": true, "ignore_stealth": true},
	))
	def.passives.append(_passive(
		&"piercing_momentum",
		"Piercing Momentum",
		"Attacks traveling 4 or more tiles before hitting gain PIERCE.",
		"Attacks traveling 4 or more tiles before hitting gain PIERCE.",
		{"long_shot_pierce_distance": 4},
	))

	# Trapper passives.
	def.passives.append(_passive(
		&"camouflage",
		"Camouflage",
		"If you spend 0 MOV, gain STEALTH for attacks beyond RANGE 3 until next turn.",
		"Next attack out of STEALTH gains +2 STR.",
		{"zero_move_stealth_range": 3, "upgraded_stealth_attack_bonus": 2},
	))
	def.passives.append(_passive(
		&"area_denial",
		"Area Denial",
		"Traps, Hazard Lines, and Difficult Terrain you create apply ROOT and WPN unmitigated damage.",
		"Those created traps also apply POISON.",
		{"created_area_root": true, "created_area_weapon_damage": true,
		"created_area_poison": true},
	))
	def.passives.append(_passive(
		&"caltrop_expert",
		"Caltrop Expert",
		"Placing Caltrops costs 0 AP.",
		"Caltrops gain ATK +2.",
		{"caltrop_zero_ap": true, "caltrop_damage_bonus": 2},
	))
	def.passives.append(_passive(
		&"zone_control",
		"Zone Control",
		"Enemies entering RANGE 3 suffer 1 unmitigated damage and PUSH 1 backward.",
		"Enemies suffer 2 unmitigated damage instead.",
		{"zone_entry_range": 3, "zone_entry_damage": 1, "upgraded_zone_entry_damage": 2,
		"zone_entry_push": 1},
	))
	def.passives.append(_passive(
		&"sticky_mud",
		"Sticky Mud",
		"Difficult terrain you create costs +1 MOVE and removes FEAR.",
		"Difficult terrain you create also applies ROOT.",
		{"created_difficult_terrain_extra_mp": 1, "created_difficult_terrain_remove_fear": true,
		"created_difficult_terrain_root": true},
	))

	# Nomad passives.
	def.passives.append(_passive(
		&"fletching_hoarder",
		"Fletching Hoarder",
		"Moving over an enemy corpse empowers the next attack by +2 STR.",
		"Empowers the next attack by +3 STR instead.",
		{"corpse_move_attack_bonus": 2, "upgraded_corpse_move_attack_bonus": 3},
	))
	def.passives.append(_passive(
		&"prey_sighted",
		"Prey Sighted",
		"Attacks against movement-penalized enemies gain +2 STR and ignore 25% DEF.",
		"Ignore 50% DEF instead.",
		{"movement_penalty_attack_bonus": 2, "movement_penalty_ignore_def_pct": 0.25,
		"upgraded_movement_penalty_ignore_def_pct": 0.5},
	))
	def.passives.append(_passive(
		&"barrage",
		"Barrage",
		"Exact lethal damage immediately deals ATK 1 to the next nearest enemy.",
		"Deal ATK 2 instead.",
		{"exact_lethal_followup_damage": 1, "upgraded_exact_lethal_followup_damage": 2},
	))
	def.passives.append(_passive(
		&"target_painter",
		"Target Painter",
		"Attacks against debuffed enemies gain +2 STR.",
		"Those attacks also gain PIERCE.",
		{"debuffed_attack_bonus": 2, "upgraded_debuffed_attack_pierce": true},
	))
	def.passives.append(_passive(
		&"rapid_fire",
		"Rapid Fire",
		"After attacking, gain +1 MOVE.",
		"Gain +2 MOVE instead.",
		{"after_attack_move": 1, "upgraded_after_attack_move": 2},
	))

	# Active skills.
	def.abilities.append(_power_shot())
	def.abilities.append(_volley())
	def.abilities.append(_pinning_arrow())
	def.abilities.append(_piercing_shot())
	def.abilities.append(_toxic_spore_arrow())
	def.abilities.append(_grapple_arrow())
	def.abilities.append(_explosive_arrow())
	def.abilities.append(_hunters_mark())
	def.abilities.append(_repelling_shot())
	def.abilities.append(_bear_trap())
	def.abilities.append(_suppressing_fire())
	def.abilities.append(_caltrop_trap())
	def.abilities.append(_parting_shot())
	def.abilities.append(_scouts_eye())

	DataLibrary.finalize_unit_abilities(def)
	return def


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgraded_description: String,
	modifiers: Dictionary,
) -> PassiveData:
	return DataLibrary._make_passive(id, name, description, upgraded_description, modifiers)


static func _module(
	primary_type: GameEnums.EffectType,
	amount: int,
	min_range: int,
	max_range: int,
	targeting_flags: int,
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
	scaling_stat: GameEnums.StatType = GameEnums.StatType.PHYSICAL,
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
	return module


static func _layer(
	effect: EffectData,
	condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION,
) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.effect = effect
	layer.condition = condition
	return layer


static func _clone_modules(source: Array[AbilityModule]) -> Array[AbilityModule]:
	var result: Array[AbilityModule] = []
	for module: AbilityModule in source:
		result.append(module.duplicate(true))
	return result


static func _ability(
	id: StringName,
	name: String,
	cost: int,
	modules: Array[AbilityModule],
	targeting_flags: int,
	tags: Array[StringName],
	upgrade_description: String,
	upgraded_modules: Array[AbilityModule],
) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = id
	ability.display_name = name
	ability.kind = GameEnums.AbilityKind.CLASS_SKILL
	ability.planner_group = GameEnums.PlannerGroup.ACTION
	ability.primary_resource = GameEnums.CostResource.AP
	ability.primary_value = cost
	ability.action_point_cost = cost
	ability.targeting_flags = targeting_flags
	ability.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	ability.tags = tags
	ability.upgrade_description = upgrade_description
	ability.modules = modules
	ability.upgraded_modules = upgraded_modules
	ability.presentation_key = id
	ability.sync_legacy_targeting()
	return ability


static func _attack(
	id: StringName,
	name: String,
	damage: int,
	max_range: int,
	upgrade_description: String,
	modifiers: Dictionary = {},
	upgrade_modifiers: Dictionary = {},
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
	targeting_flags: int = GameEnums.TargetingFlags.ENEMY,
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, damage, 1, max_range, targeting_flags,
		shape, shape_size,
	)
	for key: Variant in modifiers:
		module.ingest_runtime_key(String(key), modifiers[key])
	var upgraded := _clone_modules([module])
	for key: Variant in modifiers:
		upgraded[0].ingest_runtime_key(String(key), modifiers[key])
	for key: Variant in upgrade_modifiers:
		upgraded[0].ingest_runtime_key(String(key), upgrade_modifiers[key])
	return _ability(
		id, name, 1, [module], targeting_flags, [AbilityModuleBridge.TAG_ATTACK],
		upgrade_description, upgraded,
	)


static func _attack_with_status(
	id: StringName,
	name: String,
	damage: int,
	max_range: int,
	status_type: GameEnums.StatusType,
	status_duration: int,
	upgrade_description: String,
	modifiers: Dictionary = {},
	upgrade_modifiers: Dictionary = {},
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, damage, 1, max_range,
		GameEnums.TargetingFlags.ENEMY,
	)
	for key: Variant in modifiers:
		module.ingest_runtime_key(String(key), modifiers[key])
	var status := DataLibrary._status_effect(status_type, status_duration)
	module.layers.append(_layer(status))
	var upgraded := _clone_modules([module])
	for key: Variant in upgrade_modifiers:
		var key_text := String(key)
		if key_text == "rooted_push_bleed_weapon":
			upgraded[0].layers[0].ingest_runtime_key(key_text, upgrade_modifiers[key])
		else:
			upgraded[0].ingest_runtime_key(key_text, upgrade_modifiers[key])
	return _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], upgrade_description, upgraded,
	)


static func _power_shot() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 3, 1, 5, GameEnums.TargetingFlags.ENEMY,
	)
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1)))
	var upgraded := _clone_modules([module])
	upgraded[0].layers[0].push_collision_pierce = true
	upgraded[0].layers[0].push_collision_damage = 2
	return _ability(
		&"archer_power_shot", "Power Shot", 1, [module],
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Enemy collision applies PIERCE and ATK 2 to the second enemy.", upgraded,
	)


static func _volley() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_SQUARE, 1,
	)
	var upgraded := _clone_modules([module])
	var terrain := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 1)
	var terrain_layer := _layer(terrain)
	terrain_layer.difficult_terrain_created = true
	upgraded[0].terrain_id = &"trampled"
	upgraded[0].hazard_duration = 1
	upgraded[0].layers.append(terrain_layer)
	return _ability(
		&"archer_volley", "Volley", 1, [module], GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK], "Area becomes difficult terrain (MOVE cost x2).",
		upgraded,
	)


static func _pinning_arrow() -> AbilityData:
	var ability := _attack_with_status(
		&"archer_pinning_arrow", "Pinning Arrow", 1, 4,
		GameEnums.StatusType.ROOT, 1,
		"ROOT breaks on damage. If target is PUSHED while Rooted, apply BLEED WPN.",
	)
	ability.modules[0].root_break_on_damage = true
	ability.upgraded_modules[0].layers[0].rooted_push_bleed_weapon = true
	return ability


static func _piercing_shot() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.LINE, 4,
	)
	module.skewer = 4
	module.layers.append(_layer(DataLibrary._status_effect_self(GameEnums.StatusType.PIERCE, 1)))
	var upgraded := _clone_modules([module])
	upgraded[0].bounce_walls_45 = true
	return _ability(
		&"archer_piercing_shot", "Piercing Shot", 1, [module],
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], "Arrow bounces off walls at a 45-degree angle.",
		upgraded,
	)


static func _toxic_spore_arrow() -> AbilityData:
	var ability := _attack_with_status(
		&"archer_toxic_spore_arrow", "Toxic Spore Arrow", 1, 5,
		GameEnums.StatusType.POISON, 2,
		"Apply POISON. Upgraded: spread POISON to adjacent enemies on hit.",
	)
	ability.upgraded_modules[0].spread_status_adjacent = true
	return ability


static func _grapple_arrow() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.PULL, 1, 1, 4,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
	)
	module.grapple_wall_pull_self = true
	var upgraded := _clone_modules([module])
	upgraded[0].grapple_pass_through_damage = 2
	return _ability(
		&"archer_grapple_arrow", "Grapple Arrow", 1, [module],
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		"Shoot a wall/obstacle to PULL SELF adjacent. Upgraded: pass through enemy for ATK 2.",
		upgraded,
	)


static func _explosive_arrow() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 4,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_CROSS, 1,
	)
	module.destroy_terrain = true
	var upgraded := _clone_modules([module])
	upgraded[0].ignite_flammable_terrain = true
	return _ability(
		&"archer_explosive_arrow", "Explosive Arrow", 1, [module],
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], "Destroy terrain; upgraded ignites flammable terrain/oil.",
		upgraded,
	)


static func _hunters_mark() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 5,
		GameEnums.TargetingFlags.ENEMY,
	)
	module.status_type = GameEnums.StatusType.MARK
	module.status_duration = 2
	module.allies_range_bonus = 1
	module.allies_pierce = true
	var upgraded := _clone_modules([module])
	upgraded[0].prevent_stealth_teleport = true
	return _ability(
		&"archer_hunters_mark", "Hunter's Mark", 1, [module],
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Allies gain RANGE +1 and PIERCE against the target. Upgraded target cannot gain STEALTH or Teleport.",
		upgraded,
	)


static func _repelling_shot() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 2,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
	)
	module.allow_friendly_target = true
	var push := DataLibrary._effect(GameEnums.EffectType.PUSH, 3)
	var push_layer := _layer(push)
	module.layers.append(push_layer)
	var upgraded := _clone_modules([module])
	upgraded[0].ally_damage_zero = true
	return _ability(
		&"archer_repelling_shot", "Repelling Shot", 1, [module],
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"On an ally, deal ATK 0 and PUSH 3.", upgraded,
	)


static func _bear_trap() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.CREATE_HAZARD, 3, 1, 3,
		GameEnums.TargetingFlags.TILE,
	)
	module.terrain_id = &"bear_trap"
	module.hazard_duration = 3
	module.trap_damage = 3
	module.terrain_hazard_status = GameEnums.StatusType.ROOT
	var upgraded := _clone_modules([module])
	upgraded[0].trap_vulnerable = true
	return _ability(
		&"archer_bear_trap", "Bear Trap", 1, [module], GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Place a trap that deals ATK 3 and ROOT. Upgraded: trapped enemies suffer VULNERABLE.",
		upgraded,
	)


static func _suppressing_fire() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 1, 4,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.ARC, 1,
	)
	module.terrain_id = &"suppressing_fire"
	module.hazard_duration = 1
	module.crossing_weapon_damage = true
	module.crossing_mov_penalty = 1
	var upgraded := _clone_modules([module])
	upgraded[0].crossing_blind = true
	return _ability(
		&"archer_suppressing_fire", "Suppressing Fire", 1, [module],
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"Create a one-turn hazard line; crossing enemies suffer WPN unmitigated damage and -1 MOV. Upgraded also BLINDs.",
		upgraded,
	)


static func _caltrop_trap() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.CREATE_HAZARD, 1, 1, 3,
		GameEnums.TargetingFlags.TILE,
	)
	module.terrain_id = &"caltrop_trap"
	module.hazard_duration = 3
	module.terrain_hazard_status = GameEnums.StatusType.ROOT
	module.trap_bleed_weapon = true
	var upgraded := _clone_modules([module])
	upgraded[0].trap_def_debuff = 2
	return _ability(
		&"archer_caltrop_trap", "Caltrop Trap", 1, [module],
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"Place a trap that applies ROOT and BLEED WPN. Upgraded trap also applies -2 DEF.",
		upgraded,
	)


static func _parting_shot() -> AbilityData:
	var strike := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 3,
		GameEnums.TargetingFlags.ENEMY,
	)
	strike.execution_phase = GameEnums.ModulePhase.ON_ACTION
	var move := DataLibrary._module(
		GameEnums.EffectType.MOVE, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	move.aim_binding = GameEnums.AimBinding.NEW_AIM
	move.execution_phase = GameEnums.ModulePhase.ON_POST
	var modules: Array[AbilityModule] = [strike, move]
	var upgraded := _clone_modules(modules)
	upgraded[1].keywords = [DataLibrary._keyword(GameEnums.AbilityKeywordId.GHOST)]
	return _ability(
		&"archer_parting_shot", "Parting Shot", 1, modules,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"After attacking, immediately MOVE 2 tiles. Upgraded movement gains GHOST.",
		upgraded,
	)


static func _scouts_eye() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.PURGE, 0, 1, 5,
		GameEnums.TargetingFlags.ENEMY,
	)
	module.strip_stealth = true
	var upgraded := _clone_modules([module])
	var vulnerable := DataLibrary._status_effect(GameEnums.StatusType.VULNERABLE, 1)
	upgraded[0].layers.append(_layer(vulnerable))
	return _ability(
		&"archer_scouts_eye", "Scout's Eye", 1, [module],
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Strip STEALTH and PURGE buffs. Upgraded target suffers VULNERABLE.",
		upgraded,
	)
