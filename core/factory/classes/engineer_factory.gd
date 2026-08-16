class_name EngineerFactory
extends RefCounted

## Engineer authoring from class_abilities.txt §12.
## Runtime behavior is owned by AbilitySystem, CombatSystem, MovementSystem,
## Simulator, and EngineerSystems; this factory only describes the Bible data.


static func build(basic_gun: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"engineer"
	definition.display_name = "Engineer"
	definition.base_constitution = 4
	definition.move_points = 4
	definition.action_points = GameEnums.MAX_AP
	definition.base_strength = 3
	definition.base_defense = 3
	definition.base_magic = 1
	definition.preferred_stat = GameEnums.StatType.PHYSICAL
	definition.equipped_weapon = basic_gun
	definition.promotion_stat_bonuses = {
		&"siegecrafter": {"defense": 4, "constitution": 4},
		&"demolitionist": {"strength": 4, "constitution": 4},
		&"mechanist": {"constitution": 4, "defense": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"blueprint_tread",
		"Blueprint Tread",
		"Friendly Constructs and Turrets are passable tiles. Ending adjacent repairs 1 HP.",
		"Passing through a friendly Construct grants the Engineer and Construct SHIELD 1.",
		{
			"construct_passable": true,
			"construct_repair_adjacent": 1,
			"upgraded_construct_pass_through_shield": 1,
		},
	))

	definition.abilities.append(_recall())
	definition.abilities.append(_dismantle())
	definition.abilities.append(_sludge_bomb())
	definition.abilities.append(_construct_turret())
	definition.abilities.append(_frag_bomb())
	definition.abilities.append(_magnetic_mine())
	definition.abilities.append(_tesla_barricade())
	definition.abilities.append(_flak_cannon())
	definition.abilities.append(_wrench_smack())
	definition.abilities.append(_emp_grenade())
	definition.abilities.append(_rocket_launcher())
	definition.abilities.append(_scrap_shield())
	definition.abilities.append(_manual_detonation())
	definition.abilities.append(_overdrive_injection())
	definition.abilities.append(_barbed_wire())

	# Siegecrafter.
	definition.passives.append(_passive(
		&"turret_syndrome", "Turret Syndrome",
		"End turn without moving: spawn a mini-turret adjacent.",
		"Mini-turret gains +50% Max HP.",
		{"promotion": &"siegecrafter", "stationary_mini_turret": true,
		"mini_turret_hp_pct": 25, "upgraded_mini_turret_hp_bonus_pct": 50},
	))
	definition.passives.append(_passive(
		&"automation", "Automation",
		"Turrets gain ATK +1 and RANGE +1.",
		"Turrets gain ATK +2 instead.",
		{"promotion": &"siegecrafter", "turret_attack_bonus": 1,
		"turret_range_bonus": 1, "upgraded_turret_attack_bonus": 2},
	))
	definition.passives.append(_passive(
		&"master_builder", "Master Builder",
		"+1 active construct limit.",
		"+2 active construct limit.",
		{"promotion": &"siegecrafter", "active_construct_limit": 1,
		"upgraded_active_construct_limit": 2},
	))
	definition.passives.append(_passive(
		&"reinforced_constructs", "Reinforced Constructs",
		"Constructs gain +25% Max HP and inherit 50% of your DEF.",
		"Constructs gain +50% Max HP and inherit 100% of your DEF.",
		{"promotion": &"siegecrafter", "construct_hp_bonus_pct": 25,
		"construct_def_inherit_pct": 50, "upgraded_construct_hp_bonus_pct": 50,
		"upgraded_construct_def_inherit_pct": 100},
	))
	definition.passives.append(_passive(
		&"shield_generator", "Shield Generator",
		"Allies adjacent to turrets gain +1 DEF.",
		"Allies adjacent to turrets are immune to PULL.",
		{"promotion": &"siegecrafter", "turret_adjacent_defense": 1,
		"upgraded_turret_adjacent_pull_immunity": true},
	))

	# Demolitionist.
	definition.passives.append(_passive(
		&"blast_shielding", "Blast Shielding",
		"Immune to own explosion damage.",
		"Explosion hitting 3+ enemies grants +1 AP once per turn.",
		{"promotion": &"demolitionist", "own_explosion_immunity": true,
		"explosion_three_enemy_ap": 1},
	))
	definition.passives.append(_passive(
		&"explosive_expert", "Explosive Expert",
		"Explosives deal +1 damage to mechanicals and ignore DEF.",
		"Explosions gain ATK +2.",
		{"promotion": &"demolitionist", "explosive_mechanical_bonus": 1,
		"explosive_ignore_def": true, "upgraded_explosion_attack_bonus": 2},
	))
	definition.passives.append(_passive(
		&"chain_reaction", "Chain Reaction",
		"Construct detonation triggers Manual Detonation on friendly explosives in RANGE 2.",
		"Range becomes RANGE 3.",
		{"promotion": &"demolitionist", "chain_reaction_range": 2,
		"upgraded_chain_reaction_range": 3},
	))
	definition.passives.append(_passive(
		&"shrapnel", "Shrapnel",
		"Device detonations apply BLEED X (X = WPN) and PUSH 1.",
		"Also applies BLIND.",
		{"promotion": &"demolitionist", "detonation_bleed_weapon": true,
		"detonation_push": 1, "upgraded_detonation_blind": true},
	))
	definition.passives.append(_passive(
		&"expanded_blast", "Expanded Blast",
		"Explosion AOE increases by +1 tile.",
		"Explosions destroy traps and cover.",
		{"promotion": &"demolitionist", "explosion_aoe_bonus": 1,
		"upgraded_explosion_destroy_traps": true},
	))

	# Mechanist.
	definition.passives.append(_passive(
		&"scrap_mechanic", "Scrap Mechanic",
		"Enemy dying in RANGE 3 drops Scrap.",
		"Drops 2 Scrap.",
		{"promotion": &"mechanist", "enemy_death_scrap_range": 3,
		"upgraded_enemy_death_scrap": 2},
	))
	definition.passives.append(_passive(
		&"recycling_protocol", "Recycling Protocol",
		"Friendly Construct destroyed: gain 2 Scrap and +1 AP once per turn.",
		"Gain 3 Scrap instead.",
		{"promotion": &"mechanist", "construct_destroyed_scrap": 2,
		"construct_destroyed_ap": 1, "upgraded_construct_destroyed_scrap": 3},
	))
	definition.passives.append(_passive(
		&"overclock", "Overclock",
		"Constructs act twice per turn and take 1 damage per turn.",
		"Constructs suffer 0 damage per turn.",
		{"promotion": &"mechanist", "construct_overclock": true,
		"overclock_turn_damage": 1, "upgraded_overclock_turn_damage": 0},
	))
	definition.passives.append(_passive(
		&"overclocked_maintenance", "Overclocked Maintenance",
		"If you spend 1+ MOV and end adjacent to a friendly construct: HEAL 1, CLEANSE, both gain SHIELD 1.",
		"Repair HEAL 2.",
		{"promotion": &"mechanist", "maintenance_repair": 1,
		"maintenance_shield": 1,
		"upgraded_maintenance_repair": 2},
	))
	definition.passives.append(_passive(
		&"field_technician", "Field Technician",
		"Blueprint Tread repair RANGE 2. After any repair, +1 STR on your next attack.",
		"Next attack bonus becomes +2 STR.",
		{"promotion": &"mechanist", "repair_range": 2,
		"repair_next_attack_strength": 1,
		"upgraded_repair_next_attack_strength": 2},
	))

	DataLibrary.finalize_unit_abilities(definition)
	return definition


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
	scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE,
) -> AbilityModule:
	return DataLibrary._module(
		primary_type, amount, min_range, max_range, targeting_flags,
		shape, shape_size, scaling_stat,
	)


static func _layer(effect: EffectData) -> AbilityLayer:
	return DataLibrary._layer(effect)


static func _clone(modules: Array[AbilityModule]) -> Array[AbilityModule]:
	return DataLibrary._duplicate_modules(modules)


static func _ability(
	id: StringName,
	name: String,
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	targeting_flags: int,
	tags: Array[StringName],
	upgrade_description: String,
) -> AbilityData:
	return DataLibrary._make_modular_ability(
		id, name, modules, upgraded_modules, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, tags,
		upgrade_description, targeting_flags,
	)


static func _movement(
	id: StringName,
	name: String,
	module: AbilityModule,
	upgraded: Array[AbilityModule],
	description: String,
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id, name, [module], upgraded, 3,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		description, module.targeting_flags,
	)
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.action_point_cost = 0
	ability.movement_point_cost = 3
	ability.primary_value = 3
	return ability


static func _recall() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.TELEPORT_ADJACENT_TO, 0, 1, 99,
		GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE,
	)
	base.set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ADJACENT_CONSTRUCT)
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["arrival_overclock"] = true
	return _movement(
		&"engineer_recall", "Recall", base, upgraded,
		"Teleport to an empty tile adjacent to an active Construct.",
	)


static func _dismantle() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	base.legacy_modifiers["target_def_pct_loss"] = 0.25
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["on_hit_scrap"] = 1
	return _ability(&"engineer_dismantle", "Dismantle", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"On Hit: Generate 1 Scrap.")


static func _sludge_bomb() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_SQUARE, 1, GameEnums.StatType.PHYSICAL,
	)
	var oil := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
	oil.modifiers = {"terrain_id": &"oil", "hazard_duration": 3, "oil_field": true}
	base.layers = [_layer(oil)]
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["ignite_oil_area"] = true
	return _ability(&"engineer_sludge_bomb", "Sludge Bomb", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Fire ignites the entire OIL area.")


static func _construct_turret() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SPAWN, 0, 1, 2, GameEnums.TargetingFlags.TILE,
	)
	base.spawn_unit_id = &"construct_turret"
	base.legacy_modifiers = {"construct_spawn": true, "turret_attack": 1}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["on_death_adjacent_damage"] = 2
	return _ability(&"engineer_construct_turret", "Construct Turret", [base], upgraded,
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"On death: deal ATK 2 to adjacent enemies.")


static func _frag_bomb() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 3,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_SQUARE, 1, GameEnums.StatType.PHYSICAL,
	)
	base.legacy_modifiers["ignite_oil"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["construct_destruction_refund_ap"] = 1
	return _ability(&"engineer_frag_bomb", "Frag Bomb", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Refund 1 AP on Construct destruction.")


static func _magnetic_mine() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SPAWN, 0, 1, 3, GameEnums.TargetingFlags.TILE,
	)
	base.spawn_unit_id = &"magnetic_mine"
	base.legacy_modifiers = {
		"construct_spawn": true, "mine_pull": 2, "mine_damage": 2,
		"mine_explode": true,
	}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["absorbs_items_scrap"] = true
	return _ability(&"engineer_magnetic_mine", "Magnetic Mine", [base], upgraded,
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"Absorbs items and Scrap.")


static func _tesla_barricade() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SPAWN, 0, 1, 1, GameEnums.TargetingFlags.TILE,
	)
	base.spawn_unit_id = &"tesla_barricade"
	base.legacy_modifiers = {"construct_spawn": true, "tesla_wall": true}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["manual_detonation_stagger"] = true
	return _ability(&"engineer_tesla_barricade", "Tesla Barricade", [base], upgraded,
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"Manual Detonation applies STAGGER.")


static func _flak_cannon() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.ARC, 3, GameEnums.StatType.PHYSICAL,
	)
	base.layers = [_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1))]
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["scrap_attack_bonus"] = 2
	upgraded[0].legacy_modifiers["scrap_bleed_weapon"] = true
	return _ability(&"engineer_flak_cannon", "Flak Cannon", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Consume 1 Scrap: ATK +2 and BLEED X.")


static func _wrench_smack() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	base.legacy_modifiers["wrench_smack"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["wrench_strength_bonus"] = 1
	return _ability(&"engineer_wrench_smack", "Wrench Smack", [base], upgraded,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_HEAL],
		"Construct target: HEAL 2, remove debuffs, and grant OVERCLOCK. +1 STR.")


static func _emp_grenade() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.PURGE, 0, 1, 4,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	base.layers = [_layer(DataLibrary._status_effect(GameEnums.StatusType.SILENCE, 1))]
	base.legacy_modifiers = {"emp_grenade": true, "mechanical_boss_damage_wpn": 3}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["emp_friendly_construct_heal"] = 2
	upgraded[0].legacy_modifiers["emp_friendly_construct_overclock"] = true
	return _ability(&"engineer_emp_grenade", "EMP Grenade", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Friendly Constructs HEAL 2 and gain OVERCLOCK.")


static func _rocket_launcher() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 4, 0, 99,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_SQUARE, 1, GameEnums.StatType.PHYSICAL,
	)
	base.legacy_modifiers = {"rocket_launcher": true, "destroy_terrain": true,
		"exhaust_next_turn": true, "delayed_next_turn": true}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["sacrifice_construct_instant"] = true
	var sacrifice := _module(
		GameEnums.EffectType.DAMAGE, 0, 0, 99, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	sacrifice.aim_binding = GameEnums.AimBinding.NEW_AIM
	sacrifice.legacy_modifiers["sacrifice_construct_instant"] = true
	upgraded.append(sacrifice)
	return _ability(&"engineer_rocket_launcher", "Rocket Launcher", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Sacrifice a Construct to fire instantly.")


static func _scrap_shield() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.ARMOR_UP, 0, 1, 2, GameEnums.TargetingFlags.ALLY,
	)
	base.legacy_modifiers = {"scrap_shield": true, "scrap_multiplier": 2}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["shield_depletion_explode"] = true
	return _ability(&"engineer_scrap_shield", "Scrap Shield", [base], upgraded,
		GameEnums.TargetingFlags.ALLY, [AbilityModuleBridge.TAG_POSITIONING],
		"Shield depletion explodes for WPN damage and PUSH 1.")


static func _manual_detonation() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.RANGED_EXPLODE, 2, 1, 3, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	base.legacy_modifiers = {"manual_detonation": true}
	base.set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT)
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["refund_scrap"] = 1
	var ability := _ability(&"engineer_manual_detonation", "Manual Detonation",
		[base], upgraded, GameEnums.TargetingFlags.ALLY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Refund 1 Scrap.")
	ability.action_point_cost = 0
	ability.primary_value = 0
	return ability


static func _overdrive_injection() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.ADD_STATUS, 2, 1, 1, GameEnums.TargetingFlags.ALLY,
	)
	base.status_type = GameEnums.StatusType.STAT_BUFF_STR
	base.status_duration = 1
	base.legacy_modifiers = {"overdrive_injection": true,
		"construct_unmitigated_damage": 2}
	base.set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT)
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["refund_scrap_on_construct_death"] = 1
	return _ability(&"engineer_overdrive_injection", "Overdrive Injection",
		[base], upgraded, GameEnums.TargetingFlags.ALLY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Refund 1 Scrap when the Construct dies.")


static func _barbed_wire() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.CREATE_HAZARD, 0, 1, 3, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.ARC, 3,
	)
	base.legacy_modifiers = {
		"terrain_id": &"barbed_wire", "hazard_duration": 2,
		"barbed_wire": true, "bleed_weapon": true, "entry_root": true,
	}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["adjacent_defense_bonus"] = 1
	return _ability(&"engineer_barbed_wire", "Barbed Wire", [base], upgraded,
		GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_POSITIONING],
		"Wall grants +1 DEF adjacent.")
