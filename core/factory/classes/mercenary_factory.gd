class_name MercenaryFactory
extends RefCounted

## Builds the Bible's complete Mercenary promotion pool.
## Mercenary uses ordered modules for distinct actions/aims and layers for
## additional effects on the same module targets.


static func build(basic_sword: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"mercenary"
	definition.display_name = "Mercenary"
	definition.base_constitution = 5
	definition.move_points = 4
	definition.action_points = 1
	definition.base_strength = 4
	definition.base_defense = 3
	definition.base_magic = 2
	definition.equipped_weapon = basic_sword
	definition.promotion_stat_bonuses = {
		&"swordmaster": {"strength": 4, "defense": 2, "constitution": 2, "movement": 0},
		&"blade_dancer": {"strength": 4, "constitution": 2, "movement": 2},
		&"headhunter": {"strength": 6, "defense": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"predatory_momentum",
		"Predatory Momentum",
		"Basic attacks against targets below 50% HP grant a free 1-tile move. Dealing damage grants +1 STR and +1 MOV next turn.",
		"Threshold increases to below 75% HP. The following-turn bonus is +2 STR and +2 MOV.",
		{
			"predatory_momentum": true,
			"predatory_threshold": 0.50,
			"upgraded_predatory_threshold": 0.75,
			"predatory_free_move": 1,
			"predatory_following_strength": 1,
			"predatory_following_move": 1,
			"upgraded_predatory_following_strength": 2,
			"upgraded_predatory_following_move": 2,
		},
	))

	var pullback_module := _module(
		GameEnums.EffectType.MOVE,
		1,
		1,
		1,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
		GameEnums.MotionMode.BACKWARDS,
	)
	pullback_module.legacy_modifiers["pullback"] = true
	var pullback_upgraded := _clone_modules([pullback_module])
	pullback_upgraded[0].legacy_modifiers["pullback_ally_def"] = 2
	pullback_upgraded[0].legacy_modifiers["movement_mp_override"] = 1
	var pullback := _movement(
		&"mercenary_pullback",
		"Pullback",
		2,
		pullback_module,
		"Cost becomes 1 MOV. The pulled ally gains +2 DEF for the rest of the turn.",
		pullback_upgraded,
	)
	definition.abilities.append(pullback)

	# Swordmaster passives.
	definition.passives.append(_passive(
		&"calculated_strike", "Calculated Strike",
		"Using active movement before attacking grants +1 STR and +1 DEF until round end.",
		"Also gain +1 AP on target kill.",
		{"promotion": &"swordmaster", "movement_before_attack_strength": 1,
		"movement_before_attack_defense": 1, "upgraded_movement_before_attack_kill_ap": 1},
	))
	definition.passives.append(_passive(
		&"weapon_master", "Weapon Master",
		"If STR exceeds enemy DEF, attacks ignore 50% of remaining DEF, rounded down.",
		"Attacks ignore 100% of remaining DEF instead.",
		{"promotion": &"swordmaster", "strength_over_def_ignore_pct": 0.50,
		"upgraded_strength_over_def_ignore_pct": 1.0},
	))
	definition.passives.append(_passive(
		&"dual_wield_momentum", "Dual Wield Momentum",
		"After spending AP on an active skill, immediately execute a 0-AP ATK 1 basic attack against the same target (does not consume the Action slot).",
		"The bonus basic attack ignores 50% DEF.",
		{"promotion": &"swordmaster", "active_skill_bonus_basic_attack": 1,
		"upgraded_bonus_basic_ignore_def_pct": 0.50},
	))
	definition.passives.append(_passive(
		&"precision_edge", "Precision Edge",
		"Attacks against full-HP targets gain ATK +2 and apply BLEED equal to WPN.",
		"Gain ATK +3 instead.",
		{"promotion": &"swordmaster", "full_hp_attack_bonus": 2,
		"full_hp_attack_bleed_weapon": true, "upgraded_full_hp_attack_bonus": 3},
	))
	definition.passives.append(_passive(
		&"duelists_focus", "Duelist's Focus",
		"Attacks against enemies that have not acted deal +2 damage and apply BLIND.",
		"Those targets also suffer WEAKEN.",
		{"promotion": &"swordmaster", "unacted_attack_bonus": 2,
		"unacted_attack_blind": true, "upgraded_unacted_attack_weaken": true},
	))

	# Blade Dancer passives.
	definition.passives.append(_passive(
		&"tactical_versatility", "Tactical Versatility",
		"Casting an active skill grants the next basic attack +2 damage and an immediate free MOVE 1.",
		"The basic attack also ignores 50% DEF.",
		{"promotion": &"blade_dancer", "active_next_basic_bonus": 2,
		"active_free_move": 1, "upgraded_active_next_basic_ignore_def_pct": 0.50},
	))
	definition.passives.append(_passive(
		&"swift_feet", "Swift Feet",
		"Gain +1 MOV per adjacent enemy and ignore Zones of Control.",
		"Also ignore difficult-terrain penalties.",
		{"promotion": &"blade_dancer", "adjacent_enemy_move": 1,
		"ignore_zoc": true, "upgraded_ignore_difficult_terrain": true},
	))
	definition.passives.append(_passive(
		&"hit_and_run", "Hit and Run",
		"After dealing damage, may immediately MOVE 1.",
		"May MOVE 2 instead.",
		{"promotion": &"blade_dancer", "after_damage_move": 1,
		"upgraded_after_damage_move": 2},
	))
	definition.passives.append(_passive(
		&"evasive", "Evasive",
		"If you move 3+ tiles this turn, gain +1 DEF and ROOT immunity.",
		"Also gain immunity to PULL and slow.",
		{"promotion": &"blade_dancer", "moved_tiles_evasive_threshold": 3,
		"moved_tiles_evasive_defense": 1, "moved_tiles_root_immunity": true,
		"upgraded_moved_pull_immunity": true, "upgraded_moved_slow_immunity": true},
	))
	definition.passives.append(_passive(
		&"flanking_maneuver", "Flanking Maneuver",
		"Gain +1 STR and PIERCE if no allies are adjacent when attacking.",
		"Gain +2 STR instead.",
		{"promotion": &"blade_dancer", "isolated_attack_strength": 1,
		"isolated_attack_pierce": true, "upgraded_isolated_attack_strength": 2},
	))

	# Headhunter passives.
	definition.passives.append(_passive(
		&"dirty_fighting", "Dirty Fighting",
		"Attacks deal +2 damage against STAGGERED, ROOTED, or POISONED targets.",
		"Deal +3 damage instead.",
		{"promotion": &"headhunter", "controlled_target_attack_bonus": 2,
		"upgraded_controlled_target_attack_bonus": 3},
	))
	definition.passives.append(_passive(
		&"executioner", "Executioner",
		"Attacks against targets below 50% HP gain ATK +2 and ignore DEF.",
		"Threshold increases to below 75% HP.",
		{"promotion": &"headhunter", "executioner_threshold": 0.50,
		"executioner_attack_bonus": 2, "executioner_ignore_def": true,
		"upgraded_executioner_threshold": 0.75},
	))
	definition.passives.append(_passive(
		&"blood_scent", "Blood Scent",
		"Gain +1 MOV if your destination is closer to an enemy below 50% HP.",
		"Gain +2 MOV instead.",
		{"promotion": &"headhunter", "blood_scent_threshold": 0.50,
		"blood_scent_move": 1, "upgraded_blood_scent_move": 2},
	))
	definition.passives.append(_passive(
		&"ruthless", "Ruthless",
		"On kill, the next attack gains ATK +2 and refunds 1 AP.",
		"Next attack gains ATK +3 instead.",
		{"promotion": &"headhunter", "kill_next_attack_bonus": 2,
		"kill_refund_ap": 1, "upgraded_kill_next_attack_bonus": 3},
	))
	definition.passives.append(_passive(
		&"coup_de_grace", "Coup de Grace",
		"On basic-attack kill, HEAL 1 and gain +1 MOV.",
		"Also apply FEAR to the nearest enemy in RANGE 2.",
		{"promotion": &"headhunter", "basic_kill_heal": 1,
		"basic_kill_move": 1, "upgraded_basic_kill_fear_range": 2},
	))

	definition.abilities.append(_swift_strike())
	definition.abilities.append(_defense_strike())
	definition.abilities.append(_blade_storm())
	definition.abilities.append(_caltrop_toss())
	definition.abilities.append(_feint())
	definition.abilities.append(_riposte_strike())
	definition.abilities.append(_sever())
	definition.abilities.append(_second_wind())
	definition.abilities.append(_tactical_retreat())
	definition.abilities.append(_executioners_blade())
	definition.abilities.append(_precision_strike())
	definition.abilities.append(_flank_and_run())
	definition.abilities.append(_hamstring())
	definition.abilities.append(_acrobatic_vault())
	definition.abilities.append(_duelists_challenge())

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
		result.append(module.duplicate(true) as AbilityModule)
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
	var ability := DataLibrary._make_modular_ability(
		id,
		name,
		modules,
		upgraded_modules,
		cost,
		GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP,
		tags,
		upgrade_description,
		targeting_flags,
	)
	return ability


static func _movement(
	id: StringName,
	name: String,
	mp_cost: int,
	module: AbilityModule,
	upgrade_description: String,
	upgraded_modules: Array[AbilityModule],
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id,
		name,
		[module],
		upgraded_modules,
		mp_cost,
		GameEnums.PlannerGroup.PRE_MOVE,
		GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_POSITIONING, AbilityModuleBridge.TAG_MOVEMENT],
		upgrade_description,
		module.targeting_flags,
	)
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.movement_point_cost = mp_cost
	ability.action_point_cost = 0
	return ability


static func _attack(
	id: StringName,
	name: String,
	damage: int,
	max_range: int,
	upgrade_description: String,
	modifiers: Dictionary = {},
	upgrade_modifiers: Dictionary = {},
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE,
		damage,
		1,
		max_range,
		GameEnums.TargetingFlags.ENEMY,
	)
	module.legacy_modifiers = modifiers.duplicate(true)
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers = modifiers.duplicate(true)
	for key: Variant in upgrade_modifiers:
		upgraded[0].legacy_modifiers[key] = upgrade_modifiers[key]
	return _ability(
		id,
		name,
		1,
		[module],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		upgrade_description,
		upgraded,
	)


static func _swift_strike() -> AbilityData:
	var move := _module(
		GameEnums.EffectType.MOVE_TOWARD,
		2,
		1,
		2,
		GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	move.execution_phase = GameEnums.ModulePhase.ON_PRE
	move.legacy_modifiers["swift_strike"] = true
	var strike := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	strike.scaling_stat = GameEnums.StatType.PHYSICAL
	move.layers.append(_layer(strike))
	var modules: Array[AbilityModule] = [move]
	var upgraded := _clone_modules(modules)
	upgraded[0].legacy_modifiers["target_damaged_ap"] = 1
	return _ability(
		&"mercenary_swift_strike",
		"Swift Strike",
		1,
		modules,
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Gain 1 AP if the target was already damaged.",
		upgraded,
	)


static func _defense_strike() -> AbilityData:
	var strike := _module(GameEnums.EffectType.DAMAGE, 1, 1, 1, GameEnums.TargetingFlags.ENEMY)
	var guard := DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 2)
	strike.layers.append(_layer(guard))
	var modules: Array[AbilityModule] = [strike]
	var upgraded := _clone_modules(modules)
	upgraded[0].legacy_modifiers["remove_push_mitigation"] = true
	upgraded[0].legacy_modifiers["prevent_target_shield"] = true
	return _ability(
		&"mercenary_defense_strike",
		"Defense Strike",
		1,
		modules,
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Target loses Push Mitigation and cannot gain SHIELD.",
		upgraded,
	)


static func _blade_storm() -> AbilityData:
	var module := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY)
	module.legacy_modifiers["bonus_if_target_adjacent_to_ally"] = 2
	var upgraded := _clone_modules([module])
	var bleed := DataLibrary._status_effect(GameEnums.StatusType.BLEED, 1)
	bleed.modifiers["bleed_weapon"] = true
	upgraded[0].layers.append(_layer(bleed))
	return _ability(
		&"mercenary_blade_storm",
		"Blade Storm",
		1,
		[module],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"Apply BLEED equal to WPN.",
		upgraded,
	)


static func _caltrop_toss() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE,
		1,
		1,
		2,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
	)
	var hazard := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 1)
	hazard.modifiers["terrain_id"] = &"caltrop_trap"
	hazard.modifiers["hazard_duration"] = 3
	hazard.modifiers["skip_terrain_entry_status"] = true
	hazard.modifiers["skip_terrain_entry_bleed"] = true
	hazard.modifiers["hazard_damage_bonus"] = 1
	module.layers.append(_layer(hazard))
	var upgraded := _clone_modules([module])
	upgraded[0].layers[0].effect.modifiers["trap_damage_bonus"] = 2
	return _ability(
		&"mercenary_caltrop_toss",
		"Caltrop Toss",
		1,
		[module],
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"CALTROPS gain ATK +2.",
		upgraded,
	)


static func _feint() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS_SELF,
		1,
		0,
		0,
		GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
	)
	module.status_type = GameEnums.StatusType.PIERCE
	module.status_duration = 1
	module.legacy_modifiers["next_attack_strength"] = 1
	module.legacy_modifiers["next_attack_pierce"] = true
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["target_def_pct_debuff"] = 0.25
	upgraded[0].legacy_modifiers["target_def_pct_duration"] = 2
	return _ability(
		&"mercenary_feint",
		"Feint",
		1,
		[module],
		GameEnums.TargetingFlags.SELF,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Next attack gains PIERCE and +1 STR; target loses 25% DEF for 2 turns.",
		upgraded,
	)


static func _riposte_strike() -> AbilityData:
	var module := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY)
	module.legacy_modifiers["if_target_attacked_caster_last_turn_bonus"] = 2
	module.legacy_modifiers["if_target_attacked_caster_last_turn_stagger"] = true
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["target_def_debuff"] = 2
	return _ability(
		&"mercenary_riposte_strike",
		"Riposte Strike",
		1,
		[module],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"Targets that attacked you last turn also suffer DEF -2.",
		upgraded,
	)


static func _sever() -> AbilityData:
	var strike := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY)
	strike.legacy_modifiers["on_kill_all_allies_heal"] = 1
	var upgraded := _clone_modules([strike])
	upgraded[0].legacy_modifiers["on_kill_all_allies_shield"] = 1
	return _ability(
		&"mercenary_sever",
		"Sever",
		1,
		[strike],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_HEAL],
		"On Kill, all allies HEAL 1 and gain SHIELD 1.",
		upgraded,
	)


static func _second_wind() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.HEAL,
		1,
		0,
		0,
		GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
	)
	var grant := DataLibrary._effect(GameEnums.EffectType.ADD_STATUS_SELF, 1)
	grant.modifiers["grant_ap"] = 1
	module.layers.append(_layer(grant))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["next_skill_zero_ap"] = true
	return _ability(
		&"mercenary_second_wind",
		"Second Wind",
		1,
		[module],
		GameEnums.TargetingFlags.SELF,
		[AbilityModuleBridge.TAG_HEAL, AbilityModuleBridge.TAG_POSITIONING],
		"Your next skill costs 0 AP.",
		upgraded,
	)


static func _tactical_retreat() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.MOVE,
		3,
		1,
		3,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	module.legacy_modifiers["smoke_on_start"] = true
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["ghost_move"] = 1
	return _ability(
		&"mercenary_tactical_retreat",
		"Tactical Retreat",
		1,
		[module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		"Gain GHOST during MOVE.",
		upgraded,
	)


static func _executioners_blade() -> AbilityData:
	var ability := _attack(
		&"mercenary_executioners_blade",
		"Executioner's Blade",
		5,
		1,
		"Threshold becomes below 75% HP; on kill, gain 1 AP.",
		{},
		{"kill_grant_ap": 1},
	)
	ability.modules[0].set_condition_hp_below_pct(50)
	ability.upgraded_modules[0].set_condition_hp_below_pct(75)
	return ability


static func _precision_strike() -> AbilityData:
	return _attack(
		&"mercenary_precision_strike",
		"Precision Strike",
		4,
		1,
		"If target has not acted, ignore 100% DEF.",
		{"unacted_target_ignore_def_pct": 0.50},
		{"unacted_target_ignore_def_pct": 1.0},
	)


static func _flank_and_run() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.MOVE,
		2,
		1,
		2,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	module.legacy_modifiers["flank_run_adjacent_enemy_bonus"] = 2
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["ghost_move"] = 1
	return _ability(
		&"mercenary_flank_and_run",
		"Flank & Run",
		1,
		[module],
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Gain GHOST during MOVE.",
		upgraded,
	)


static func _hamstring() -> AbilityData:
	var module := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY)
	var slow := DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 0)
	slow.modifiers["set_max_move"] = 1
	module.layers.append(_layer(slow))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["bleed_bonus_damage"] = 2
	return _ability(
		&"mercenary_hamstring",
		"Hamstring",
		1,
		[module],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"Deal ATK +2 if the target has BLEED.",
		upgraded,
	)


static func _acrobatic_vault() -> AbilityData:
	var vault := _module(
		GameEnums.EffectType.JUMP_TO_BEHIND,
		0,
		1,
		2,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.StatType.NONE,
	)
	var strike := _module(
		GameEnums.EffectType.DAMAGE,
		1,
		1,
		2,
		GameEnums.TargetingFlags.ENEMY,
	)
	var modules: Array[AbilityModule] = [vault, strike]
	var upgraded := _clone_modules(modules)
	upgraded[1].legacy_modifiers["pierce"] = true
	return _ability(
		&"mercenary_acrobatic_vault",
		"Acrobatic Vault",
		1,
		modules,
		GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Jump over the target to the opposite empty tile; attack gains PIERCE.",
		upgraded,
	)


static func _duelists_challenge() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS,
		1,
		1,
		3,
		GameEnums.TargetingFlags.ENEMY,
	)
	module.status_type = GameEnums.StatusType.TAUNT
	module.status_duration = 1
	module.legacy_modifiers["duelist_mark_target"] = true
	var mark := DataLibrary._status_effect(GameEnums.StatusType.MARK, 1)
	module.layers.append(_layer(mark))
	var upgraded := _clone_modules([module])
	upgraded[0].legacy_modifiers["marked_target_defense"] = 2
	return _ability(
		&"mercenary_duelists_challenge",
		"Duelist's Challenge",
		1,
		[module],
		GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Gain +2 DEF against the marked target.",
		upgraded,
	)
