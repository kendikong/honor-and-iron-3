class_name LancerFactory
extends RefCounted

## Builds the Bible's complete Lancer promotion pool.
## The base class is Lancer; promotion names remain Cavalier, Skystriker, and
## Halberdier in passive/skill descriptions. Skills are authored as modular
## AbilityData and compiled to legacy effects for the shared simulator bridge.


static func build(basic_lance: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"lancer"
	def.display_name = "Lancer"
	def.base_constitution = 5
	def.move_points = 3
	def.action_points = 1
	def.base_strength = 4
	def.base_defense = 3
	def.base_magic = 1
	def.equipped_weapon = basic_lance

	var push := _make_movement(
		&"lancer_push",
		"Push",
		1,
		0,
		_module(GameEnums.EffectType.PUSH, 1, 1, 1, GameEnums.TargetingFlags.ALLY),
	)
	push.modules[0].legacy_modifiers["allow_friendly_target"] = true
	push.upgrade_description = "Limit once per turn. Pushing a unit grants +1 STR for your next attack this turn."
	var push_up := _clone_modules(push.modules)
	push_up[0].legacy_modifiers["limit_once_per_turn"] = true
	push_up[0].legacy_modifiers["buff_on_push"] = 1
	push.upgraded_modules = push_up
	def.abilities.append(push)

	# Cavalier passives.
	def.passives.append(_passive(&"kinetic_charge", "Kinetic Charge",
		"Gain +1 STR for every tile moved in a continuous straight line before attacking this turn.",
		"Gain +1 STR for every tile moved in a continuous straight line before attacking this turn.",
		{"promotion": &"cavalier", "straight_line_str_per_tile": 1}))
	def.passives.append(_passive(&"unstoppable_mass", "Unstoppable Mass",
		"If you move your maximum MOVEMENT before attacking, your attack gains PIERCE and you gain ROOT immunity for 1 turn.",
		"If you move your maximum MOVEMENT before attacking, your attack gains PIERCE and you gain ROOT immunity for 1 turn.",
		{"promotion": &"cavalier", "max_move_attack_pierce": true, "max_move_root_immunity": true}))
	def.passives.append(_passive(&"canto", "Canto",
		"Your standard movement gains CANTO.",
		"Your standard movement gains CANTO.",
		{"promotion": &"cavalier", "standard_move_canto": true}))
	def.passives.append(_passive(&"frontline_defense", "Frontline Defense",
		"Gain +1 DEF and immunity to Ranged attacks if moved 3+ tiles.",
		"Gain +1 DEF and immunity to Ranged attacks if moved 3+ tiles. Also gain SHIELD 1.",
		{"promotion": &"cavalier", "moved_tiles_def_threshold": 3, "moved_tiles_def": 1,
		"moved_tiles_ranged_immunity": true, "upgraded_shield": 1}))
	def.passives.append(_passive(&"flanking_strike", "Flanking Strike",
		"Attacks originating from the side of an enemy ignore 2 DEF.",
		"Attacks originating from the side of an enemy ignore 4 DEF instead.",
		{"promotion": &"cavalier", "side_attack_ignore_def": 2, "upgraded_side_attack_ignore_def": 4}))

	# Skystriker passives.
	def.passives.append(_passive(&"plunging_attack", "Plunging Attack",
		"If you use an AP jump or teleport, your next basic attack this turn gains +3 ATK.",
		"If you use an AP jump or teleport, your next basic attack this turn gains +3 ATK and PIERCE.",
		{"promotion": &"skystriker", "jump_next_basic_bonus": 3, "upgraded_jump_next_basic_pierce": true}))
	def.passives.append(_passive(&"crashing_impact", "Crashing Impact",
		"Landing from a jump applies PUSH 1 to all adjacent enemies.",
		"Landing from a jump applies PUSH 1 to all adjacent enemies; wall collisions apply STAGGER.",
		{"promotion": &"skystriker", "landing_adjacent_push": 1, "upgraded_landing_collision_stagger": true}))
	def.passives.append(_passive(&"pole_plant", "Pole-Plant",
		"Your 0-AP Push can target destructible obstacles and traps. Destroying a trap grants SHIELD 2.",
		"Destroying a trap also deals 2 unmitigated damage to adjacent enemies.",
		{"promotion": &"skystriker", "push_destroy_obstacles": true, "trap_destroy_shield": 2,
		"upgraded_trap_destroy_adjacent_damage": 2}))
	def.passives.append(_passive(&"spear_drop", "Spear Drop",
		"Attacking an enemy you vaulted over ignores 2 DEF and applies BLEED X, where X is WPN.",
		"Attacking an enemy you vaulted over ignores 4 DEF and applies BLEED X, where X is WPN.",
		{"promotion": &"skystriker", "vaulted_target_ignore_def": 2,
		"upgraded_vaulted_target_ignore_def": 4, "vaulted_target_bleed_weapon": true}))
	def.passives.append(_passive(&"springboard", "Springboard",
		"On Kill: you may vault into the defeated enemy's space for 0 AP and gain +1 MOV on landing.",
		"On Kill: you may vault into the defeated enemy's space for 0 AP, gain +1 MOV, and gain 1 AP on landing once per turn.",
		{"promotion": &"skystriker", "kill_vault": true, "kill_vault_mov": 1,
		"upgraded_kill_vault_ap": 1}))

	# Halberdier passives.
	def.passives.append(_passive(&"sweet_spot", "Sweet Spot",
		"Attacks originating from exactly RANGE 2 gain +2 ATK and ignore 2 DEF.",
		"Attacks originating from exactly RANGE 2 gain +2 ATK and ignore 4 DEF.",
		{"promotion": &"halberdier", "range_two_bonus_atk": 2, "range_two_ignore_def": 2,
		"upgraded_range_two_ignore_def": 4}))
	def.passives.append(_passive(&"reach_advantage", "Reach Advantage",
		"When attacking a melee unit from exactly RANGE 2, they cannot trigger standard counter-attacks or Retaliation.",
		"When attacking a melee unit from exactly RANGE 2, they cannot trigger standard counter-attacks or Retaliation and suffer -1 DEF.",
		{"promotion": &"halberdier", "range_two_counter_immunity": true,
		"upgraded_range_two_def_debuff": 1}))
	def.passives.append(_passive(&"disengage", "Disengage",
		"If forced to attack at RANGE 1, PUSH yourself 1 before damage.",
		"If forced to attack at RANGE 1, PUSH yourself 1 before damage, then PUSH the enemy 1.",
		{"promotion": &"halberdier", "range_one_self_push": 1, "upgraded_range_one_enemy_push": 1}))
	def.passives.append(_passive(&"zone_of_control", "Zone of Control",
		"If an enemy ends movement exactly 2 tiles away during the Enemy Turn, make a basic attack once per round.",
		"If an enemy ends movement exactly 2 tiles away during the Enemy Turn, make a basic attack with PIERCE once per round.",
		{"promotion": &"halberdier", "enemy_end_range_two_attack": true,
		"upgraded_zone_attack_pierce": true}))
	def.passives.append(_passive(&"leverage", "Leverage",
		"Using your 0-AP Push grants your next attack PIERCE and +1 MOV.",
		"Using your 0-AP Push grants your next attack PIERCE, +1 MOV, and SHIELD 1.",
		{"promotion": &"halberdier", "push_next_attack_pierce": true, "push_mov": 1,
		"upgraded_push_shield": 1}))

	# Shared / promoted actives.
	def.abilities.append(_charge_skill(
		&"lancer_piercing_charge", "Piercing Charge", 3, 2, 2,
		"Create TRAMPLED terrain behind you (MOVE cost x2). If Push was used earlier this turn, PUSH 3 instead.",
		{"create_trampled_terrain": true},
	))
	def.abilities.append(_attack_with_layer(
		&"lancer_sweeping_halberd", "Sweeping Halberd", 2, GameEnums.TargetShape.ARC,
		2, GameEnums.EffectType.PULL, 1,
		"Sweeping Halberd's PULL collision applies STAGGER. If Push was used earlier this turn, PULL 2 instead.",
		{},
		GameEnums.StatusType.STAT_BUFF_STR,
		{"stagger_on_collision": true, "pull_bonus_if_push_used": 1},
	))
	def.abilities.append(_attack_with_layer(
		&"lancer_vaulting_leap", "Vaulting Leap", 2, GameEnums.TargetShape.SINGLE,
		2, GameEnums.EffectType.ADD_STATUS, 1,
		"Armor explodes: ATK 1 in AOE 1 around the target.",
		{"target_def_set": 0},
		GameEnums.StatusType.STAT_DEBUFF_DEF,
		{"target_def_set": 0, "armor_explosion_atk": 1},
	))
	def.abilities.append(_attack(
		&"lancer_run_down", "Run Down", 2, 3,
		"On Kill: gain MAX MOVEMENT +2.",
		{"bonus_atk_vs_fear_or_lower_movement": 2},
		{"on_kill_max_move": 2},
	))
	def.abilities.append(_self_area_status(
		&"lancer_rallying_cry", "Rallying Cry", 2,
		GameEnums.StatusType.STAT_BUFF_MOV, 1,
		"Allies gain TRAMPLE for 1 turn.",
		{"next_turn_max_move": 1, "upgraded_trample": true},
	))
	def.abilities.append(_flanking_maneuver())
	def.abilities.append(_self_status(
		&"lancer_brace", "Brace", GameEnums.StatusType.BRACED, 2,
		"Your MOVEMENT becomes 0 this turn. The next incoming melee attack is negated; attacker suffers ATK 2.",
		{"brace_attacker_stagger": true}, 2,
	))
	def.abilities.append(_attack_with_layer(
		&"lancer_harpoon_toss", "Harpoon Toss", 4, GameEnums.TargetShape.SINGLE,
		1, GameEnums.EffectType.PULL, 3,
		"If SELF has ROOT or target is heavier, PULL SELF to target.",
		{"pull_self_if_rooted_or_heavier": true},
		GameEnums.StatusType.STAT_BUFF_STR,
		{"pull_self_if_rooted_or_heavier": true},
	))
	def.abilities.append(_glorious_charge())
	def.abilities.append(_pole_vault())
	def.abilities.append(_line_breaker())
	def.abilities.append(_spear_wall())
	def.abilities.append(_meteor_drop())

	_apply_polearm_reach_modifiers(def)
	DataLibrary.finalize_unit_abilities(def)
	return def


static func _apply_polearm_reach_modifiers(definition: UnitData) -> void:
	for ability: AbilityData in definition.abilities:
		if ability == null or not ability.tags.has(AbilityModuleBridge.TAG_ATTACK):
			continue
		_apply_polearm_reach_to_modules(ability.modules)
		_apply_polearm_reach_to_modules(ability.upgraded_modules)


static func _apply_polearm_reach_to_modules(modules: Array[AbilityModule]) -> void:
	for module: AbilityModule in modules:
		if module == null or module.max_range <= 1:
			continue
		if module.primary_type == GameEnums.EffectType.DAMAGE:
			module.legacy_modifiers["range_one_damage_multiplier"] = 0.7
		for layer: AbilityLayer in module.layers:
			if layer != null and layer.effect != null and layer.effect.type == GameEnums.EffectType.DAMAGE:
				layer.effect.modifiers["range_one_damage_multiplier"] = 0.7


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgraded_description: String,
	modifiers: Dictionary = {},
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


static func _status_module(
	primary_type: GameEnums.EffectType,
	status_type: GameEnums.StatusType,
	duration: int,
	amount: int,
	min_range: int,
	max_range: int,
	targeting_flags: int,
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
) -> AbilityModule:
	var module := _module(
		primary_type, amount, min_range, max_range, targeting_flags, shape, shape_size,
		GameEnums.StatType.NONE,
	)
	module.status_type = status_type
	module.status_duration = duration
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


static func _make_movement(
	id: StringName,
	name: String,
	range_tiles: int,
	mp_cost: int,
	module: AbilityModule,
) -> AbilityData:
	var ability := _ability(
		id, name, mp_cost, [module], module.targeting_flags,
		[AbilityModuleBridge.TAG_POSITIONING, AbilityModuleBridge.TAG_MOVEMENT], "", [],
	)
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.planner_group = GameEnums.PlannerGroup.PRE_MOVE
	ability.primary_resource = GameEnums.CostResource.MP
	ability.primary_value = mp_cost
	ability.movement_point_cost = mp_cost
	ability.range_tiles = range_tiles
	ability.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	ability.sync_legacy_targeting()
	return ability


static func _attack(
	id: StringName,
	name: String,
	range_tiles: int,
	damage: int,
	upgrade_description: String,
	modifiers: Dictionary = {},
	upgrade_modifiers: Dictionary = {},
) -> AbilityData:
	var module := _module(GameEnums.EffectType.DAMAGE, damage, 1, range_tiles, GameEnums.TargetingFlags.ENEMY)
	module.legacy_modifiers = modifiers.duplicate(true)
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = modifiers.duplicate(true)
	for key: Variant in upgrade_modifiers:
		upgraded[0].legacy_modifiers[key] = upgrade_modifiers[key]
	upgraded[0].legacy_modifiers["upgraded_profile"] = true
	return _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], upgrade_description, upgraded,
	)


static func _attack_with_layer(
	id: StringName,
	name: String,
	range_tiles: int,
	shape: GameEnums.TargetShape,
	damage: int,
	layer_type: GameEnums.EffectType,
	layer_amount: int,
	upgrade_description: String,
	modifiers: Dictionary = {},
	status_type: GameEnums.StatusType = GameEnums.StatusType.STAT_BUFF_STR,
	upgrade_modifiers: Dictionary = {},
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, damage, 1, range_tiles,
		GameEnums.TargetingFlags.ENEMY, shape, 1,
	)
	module.legacy_modifiers = modifiers.duplicate(true)
	var layer_effect := DataLibrary._effect(layer_type, layer_amount)
	layer_effect.status_type = status_type
	layer_effect.status_duration = 1
	layer_effect.modifiers = modifiers.duplicate(true)
	module.layers.append(_layer(layer_effect))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = modifiers.duplicate(true)
	for key: Variant in upgrade_modifiers:
		upgraded[0].legacy_modifiers[key] = upgrade_modifiers[key]
	upgraded[0].layers[0].effect.modifiers = modifiers.duplicate(true)
	for key: Variant in upgrade_modifiers:
		upgraded[0].layers[0].effect.modifiers[key] = upgrade_modifiers[key]
	upgraded[0].layers[0].effect.modifiers["upgraded_profile"] = true
	return _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], upgrade_description, upgraded,
	)


static func _charge_skill(
	id: StringName,
	name: String,
	dash_range: int,
	damage: int,
	push_amount: int,
	upgrade_description: String,
	upgrade_modifiers: Dictionary,
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DASH, dash_range, 1, dash_range,
		GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.PHYSICAL, GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE, damage)))
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, push_amount)))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = upgrade_modifiers.duplicate(true)
	for layer: AbilityLayer in upgraded[0].layers:
		if layer != null and layer.effect != null and layer.effect.type == GameEnums.EffectType.PUSH:
			layer.effect.modifiers["push_bonus_if_push_used"] = 1
	return _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		upgrade_description, upgraded,
	)


static func _self_status(
	id: StringName,
	name: String,
	status_type: GameEnums.StatusType,
	duration: int,
	description: String,
	upgrade_modifiers: Dictionary,
	status_amount: int = 0,
) -> AbilityData:
	var module := _status_module(
		GameEnums.EffectType.ADD_STATUS_SELF, status_type, duration, status_amount, 0, 0,
		GameEnums.TargetingFlags.SELF,
	)
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = upgrade_modifiers.duplicate(true)
	return _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.SELF,
		[AbilityModuleBridge.TAG_POSITIONING], description, upgraded,
	)


static func _self_area_status(
	id: StringName,
	name: String,
	radius: int,
	status_type: GameEnums.StatusType,
	amount: int,
	description: String,
	upgrade_modifiers: Dictionary,
) -> AbilityData:
	var module := _status_module(
		GameEnums.EffectType.ADD_STATUS, status_type, 1, amount, 0, 0,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, radius,
	)
	module.legacy_modifiers["next_turn"] = true
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = upgrade_modifiers.duplicate(true)
	var ability := _ability(
		id, name, 1, [module], GameEnums.TargetingFlags.ALLY,
		[AbilityModuleBridge.TAG_POSITIONING], description, upgraded,
	)
	ability.targeting_flags |= GameEnums.TargetingFlags.SELF
	ability.sync_legacy_targeting()
	return ability


static func _flanking_maneuver() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.MOVE, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	module.legacy_modifiers["l_shape_move"] = true
	module.targeting_flags = GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY
	var strike := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	strike.modifiers["damage_multiplier"] = 2
	strike.modifiers["side_attack_only"] = true
	strike.modifiers["target_after_move_adjacent"] = true
	module.layers.append(_layer(strike))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["l_shape_move"] = true
	upgraded[0].legacy_modifiers["ghost_move"] = 1
	return _ability(
		&"lancer_flanking_maneuver", "Flanking Maneuver", 1, [module],
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Gain GHOST during MOVE.", upgraded,
	)


static func _glorious_charge() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DASH, 4, 1, 4,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
		GameEnums.MotionMode.TO_TARGET_UNIT,
	)
	module.legacy_modifiers["paired_ally_charge"] = true
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["paired_ally_charge"] = true
	upgraded[0].legacy_modifiers["on_kill_both_ap"] = 1
	var ability := _ability(
		&"lancer_glorious_charge", "Glorious Charge", 1, [module],
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"On Kill: both the Lancer and the allied charger gain +1 AP.", upgraded,
	)
	ability.targeting_flags = (
		GameEnums.TargetingFlags.ALLY
		| GameEnums.TargetingFlags.ENEMY
		| GameEnums.TargetingFlags.TILE
	)
	ability.sync_legacy_targeting()
	return ability


static func _pole_vault() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 3, 1, 3, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.VAULT_OVER,
	)
	module.legacy_modifiers["vault_over"] = true
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["vault_over"] = true
	upgraded[0].legacy_modifiers["landing_adjacent_push_if_push_used"] = 1
	upgraded[0].legacy_modifiers["landing_adjacent_push_stagger"] = true
	return _ability(
		&"lancer_pole_vault", "Pole Vault", 1, [module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		"If Push was used earlier this turn, landing applies PUSH 1 to adjacent enemies; collisions STAGGER.",
		upgraded,
	)


static func _line_breaker() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DASH, 4, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.LINE, 4, GameEnums.StatType.PHYSICAL,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	module.legacy_modifiers["line_breaker"] = true
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["line_breaker"] = true
	upgraded[0].legacy_modifiers["bonus_per_enemy_passed"] = 1
	return _ability(
		&"lancer_line_breaker", "Line Breaker", 1, [module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"ATK +1 for each enemy passed through this turn.", upgraded,
	)


static func _spear_wall() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.CREATE_HAZARD, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.ARC, 2, GameEnums.StatType.PHYSICAL,
	)
	module.legacy_modifiers["terrain_id"] = &"spear_wall"
	module.legacy_modifiers["hazard_status"] = GameEnums.StatusType.ROOT
	module.legacy_modifiers["hazard_duration"] = 1
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["hazard_status"] = GameEnums.StatusType.ROOT
	upgraded[0].legacy_modifiers["hazard_duration"] = 2
	return _ability(
		&"lancer_spear_wall", "Spear Wall", 1, [module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Hazard line lasts for 2 turns instead of 1.", upgraded,
	)


static func _meteor_drop() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_CROSS, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)))
	var upgraded := _clone_modules([module])
	var vulnerable := DataLibrary._status_effect(GameEnums.StatusType.VULNERABLE, 1)
	upgraded[0].layers.append(_layer(vulnerable, GameEnums.LayerCondition.ON_LAND))
	return _ability(
		&"lancer_meteor_drop", "Meteor Drop", 1, [module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Targets hit suffer VULNERABLE.", upgraded,
	)
