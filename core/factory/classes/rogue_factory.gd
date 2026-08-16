class_name RogueFactory
extends RefCounted

## Complete Rogue authoring from class_abilities.txt §4.
## The factory owns only authored data. AbilitySystem, MovementSystem,
## CombatSystem, and Simulator remain the runtime owners.


static func build(basic_sword: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"rogue"
	definition.display_name = "Rogue"
	definition.base_constitution = 4
	definition.move_points = 5
	definition.action_points = GameEnums.MAX_AP
	definition.base_strength = 4
	definition.base_defense = 2
	definition.base_magic = 1
	definition.preferred_stat = GameEnums.StatType.PHYSICAL
	definition.equipped_weapon = basic_sword
	definition.promotion_stat_bonuses = {
		&"assassin": {"strength": 4, "constitution": 2, "movement": 2},
		&"ninja": {"strength": 2, "movement": 3},
		&"saboteur": {"strength": 4, "constitution": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"pass",
		"Pass",
		"Standard movement has GHOST and passes through enemies, traps, and ZOC.",
		"Moving directly through an enemy makes the next attack against them ignore DEF.",
		{
			"pass": true,
			"ghost_move": true,
			"pass_through_enemy": true,
			"upgraded_pass_setup_pierce": true,
		},
	))

	definition.abilities.append(_slip_past())

	# Assassin passives.
	definition.passives.append(_passive(
		&"backstab",
		"Backstab",
		"Attacks originating directly behind an enemy ignore DEF.",
		"Also apply BLEED equal to WPN.",
		{"promotion": &"assassin", "backstab_ignore_def": true,
		"upgraded_backstab_bleed_weapon": true},
	))
	definition.passives.append(_passive(
		&"blink_mastery",
		"Blink Mastery",
		"After Teleport, the next attack gains ATK +3.",
		"The next attack gains ATK +4 instead.",
		{"promotion": &"assassin", "after_teleport_attack_bonus": 3,
		"upgraded_after_teleport_attack_bonus": 4},
	))
	definition.passives.append(_passive(
		&"lethal_position",
		"Lethal Position",
		"Gain +1 STR and +1 RANGE per tile moved from the start tile.",
		"Also gain +1 DEF per tile moved.",
		{"promotion": &"assassin", "moved_tiles_attack_strength": 1,
		"moved_tiles_attack_range": 1, "upgraded_moved_tiles_defense": 1},
	))
	definition.passives.append(_passive(
		&"shadow_strike",
		"Shadow Strike",
		"Teleporting adjacent to an enemy applies MARK and ROOT.",
		"Also apply SILENCE.",
		{"promotion": &"assassin", "teleport_adjacent_mark_root": true,
		"upgraded_teleport_adjacent_silence": true},
	))
	definition.passives.append(_passive(
		&"killing_intent",
		"Killing Intent",
		"Ending the turn adjacent to a target below 50% HP grants 1 AP next turn.",
		"Threshold becomes below 75% HP.",
		{"promotion": &"assassin", "end_adjacent_low_hp_ap": 1,
		"killing_intent_threshold": 0.50,
		"upgraded_killing_intent_threshold": 0.75},
	))

	# Ninja passives.
	definition.passives.append(_passive(
		&"shadow_clone",
		"Shadow Clone",
		"On Kill, leave a Decoy on the tile applying TAUNT for 1 turn.",
		"The Decoy explodes on death for ATK 2 AOE.",
		{"promotion": &"ninja", "on_kill_decoy_taunt": 1,
		"upgraded_decoy_explode_atk": 2},
	))
	definition.passives.append(_passive(
		&"phase_shift",
		"Phase Shift",
		"Teleporting grants STEALTH until the next attack.",
		"The first attack out of STEALTH ignores DEF.",
		{"promotion": &"ninja", "teleport_stealth": true,
		"upgraded_stealth_attack_ignore_def": true},
	))
	definition.passives.append(_passive(
		&"blink_strike",
		"Blink Strike",
		"Basic attacks can target RANGE 2 and teleport to the target.",
		"Range increases to RANGE 3.",
		{"promotion": &"ninja", "basic_attack_range": 2,
		"upgraded_basic_attack_range": 3},
	))
	definition.passives.append(_passive(
		&"shadow_meld",
		"Shadow Meld",
		"While in SMOKE, skills gain MAG ATK +2 and cost 0 AP once per turn.",
		"Skills gain MAG ATK +3.",
		{"promotion": &"ninja", "smoke_spell_magic": 2,
		"smoke_spell_free_ap": true, "smoke_spell_once_per_turn": true,
		"upgraded_smoke_spell_magic": 3},
	))
	definition.passives.append(_passive(
		&"shadow_slip",
		"Shadow Slip",
		"Moving directly through an enemy applies BLIND and MARK. Attacking a MARKED target that turn refunds 1 MOV and deals bonus physical damage equal to WPN.",
		"Also apply POISON.",
		{"promotion": &"ninja", "cross_enemy_blind_mark": true,
		"marked_attack_refund_move": 1, "marked_attack_weapon_bonus": true,
		"upgraded_cross_enemy_poison": true},
	))

	# Saboteur passives.
	definition.passives.append(_passive(
		&"miasma_spreader",
		"Miasma Spreader",
		"Attacking a debuffed unit spreads its debuffs to adjacent enemies.",
		"Spread to RANGE 2.",
		{"promotion": &"saboteur", "spread_debuffs_on_attack": true,
		"miasma_spreader_range": 1, "upgraded_miasma_spreader_range": 2},
	))
	definition.passives.append(_passive(
		&"panic_cascade",
		"Panic Cascade",
		"Applying any debuff causes extra damage equal to WPN per active unique debuff this turn.",
		"If the target has CONFUSION, extra damage is 2×WPN per unique debuff.",
		{"promotion": &"saboteur", "panic_on_debuff": true,
		"upgraded_confused_wpn_mult": 2},
	))
	definition.passives.append(_passive(
		&"debuff_overload",
		"Debuff Overload",
		"Enemies take +1 unmitigated damage per unique debuff at turn start.",
		"Bonus becomes +2 per unique debuff.",
		{"promotion": &"saboteur", "turn_start_damage_per_debuff": 1,
		"upgraded_turn_start_damage_per_debuff": 2},
	))
	definition.passives.append(_passive(
		&"mind_static",
		"Mind Static",
		"Enemies in RANGE 2 suffer -25% DEF and cannot gain SHIELD.",
		"Range becomes 3 and DEF reduction becomes -50%.",
		{"promotion": &"saboteur", "mind_static_range": 2,
		"mind_static_def_pct": 0.25, "mind_static_no_shield": true,
		"upgraded_mind_static_range": 3, "upgraded_mind_static_def_pct": 0.50},
	))
	definition.passives.append(_passive(
		&"board_scrambler",
		"Board Scrambler",
		"After dealing damage, swap the target with the highest-HP enemy in RANGE 3.",
		"The target also suffers ROOT.",
		{"promotion": &"saboteur", "damage_swap_highest_hp_range": 3,
		"upgraded_damage_swap_root": true},
	))

	definition.abilities.append(_shadow_step())
	definition.abilities.append(_kidney_strike())
	definition.abilities.append(_smoke_bomb())
	definition.abilities.append(_evasive_strike())
	definition.abilities.append(_grappling_hook())
	definition.abilities.append(_switcheroo())
	definition.abilities.append(_blindside())
	definition.abilities.append(_throat_slit())
	definition.abilities.append(_amnesia_dust())
	definition.abilities.append(_death_mark())
	definition.abilities.append(_lethal_flourish())
	definition.abilities.append(_shadow_swap())
	definition.abilities.append(_kidnap())
	definition.abilities.append(_shuriken_volley())
	definition.abilities.append(_poison_flask())

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
	motion_mode: GameEnums.MotionMode = GameEnums.MotionMode.NONE,
) -> AbilityModule:
	return DataLibrary._module(
		primary_type, amount, min_range, max_range, targeting_flags,
		shape, shape_size, scaling_stat, motion_mode,
	)


static func _layer(
	effect: EffectData,
	condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION,
) -> AbilityLayer:
	return DataLibrary._layer(effect, condition)


static func _clone(source: Array[AbilityModule]) -> Array[AbilityModule]:
	return DataLibrary._duplicate_modules(source)


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
	mp_cost: int,
	module: AbilityModule,
	upgraded: Array[AbilityModule],
	description: String,
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id, name, [module], upgraded, mp_cost,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		description, module.targeting_flags,
	)
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.action_point_cost = 0
	ability.movement_point_cost = mp_cost
	ability.primary_value = mp_cost
	return ability


static func _slip_past() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 1,
		GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	base.legacy_modifiers["slip_past"] = true
	base.legacy_modifiers["land_opposite_target"] = true
	base.legacy_modifiers["move_through_adjacent_unit"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["ally_def_buff"] = 1
	return _movement(
		&"rogue_slip_past", "Slip Past", 1, base, upgraded,
		"Move through an adjacent ally to the empty tile directly behind them; upgraded: that ally gains +1 DEF for 1 turn.",
	)


static func _shadow_step() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.TELEPORT_ADJACENT_TO, 0, 1, 4,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	base.legacy_modifiers["shadow_step"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["behind_target_strength"] = 1
	return _ability(
		&"rogue_shadow_step", "Shadow Step", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		"Teleport behind the target; gain +1 STR this turn.",
	)


static func _kidney_strike() -> AbilityData:
	var base := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	var slow := DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_MOV, 2, 2)
	slow.modifiers["movement_penalty"] = 2
	base.layers.append(_layer(slow))
	var upgraded := _clone([base])
	var root := DataLibrary._status_effect(GameEnums.StatusType.ROOT, 1)
	root.modifiers["from_behind_only"] = true
	upgraded[0].layers.append(_layer(root, GameEnums.LayerCondition.IF_FROM_BEHIND))
	return _ability(
		&"rogue_kidney_strike", "Kidney Strike", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"From behind, apply ROOT.",
	)


static func _smoke_bomb() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.CREATE_HAZARD, 0, 0, 0,
		GameEnums.TargetingFlags.SELF, GameEnums.TargetShape.AOE_SQUARE, 1,
		GameEnums.StatType.NONE,
	)
	base.legacy_modifiers = {
		"terrain_id": &"smoke",
		"hazard_duration": 2,
		"smoke_field": true,
		"smoke_stealth_outside_attackers": true,
	}
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["smoke_ally_heal_per_turn"] = 1
	return _ability(
		&"rogue_smoke_bomb", "Smoke Bomb", [base], upgraded,
		GameEnums.TargetingFlags.SELF,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Allies inside HEAL 1 per turn.",
	)


static func _evasive_strike() -> AbilityData:
	var move := _module(
		GameEnums.EffectType.MOVE, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	move.execution_phase = GameEnums.ModulePhase.ON_PRE
	var strike := _module(GameEnums.EffectType.DAMAGE, 1, 1, 1, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	strike.aim_binding = GameEnums.AimBinding.NEW_AIM
	strike.execution_phase = GameEnums.ModulePhase.ON_ACTION
	var guard := DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 1)
	strike.layers.append(_layer(guard))
	var modules: Array[AbilityModule] = [move, strike]
	var upgraded := _clone(modules)
	upgraded[0].amount = 3
	upgraded[1].amount = 2
	if not upgraded[1].layers.is_empty() and upgraded[1].layers[0].effect != null:
		upgraded[1].layers[0].effect.amount = 2
	return _ability(
		&"rogue_evasive_strike", "Evasive Strike", modules, upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"MOVE 3 | ATK 2 | DEF +2.",
	)


static func _grappling_hook() -> AbilityData:
	var base := _module(GameEnums.EffectType.PULL, 4, 1, 4, GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE)
	base.legacy_modifiers["grapple_bidirectional"] = true
	base.legacy_modifiers["pull_self_or_target"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["trap_collision_damage_multiplier"] = 2
	return _ability(
		&"rogue_grappling_hook", "Grappling Hook", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Target trap collision damage is doubled.",
	)


static func _switcheroo() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SWAP, 0, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_TARGET_UNIT,
	)
	base.legacy_modifiers["switcheroo"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["inherit_incoming_attacks"] = true
	return _ability(
		&"rogue_switcheroo", "Switcheroo", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Target inherits incoming attacks aimed at you.",
	)


static func _blindside() -> AbilityData:
	var base := _module(GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	base.legacy_modifiers["if_target_unacted_stagger"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["if_target_staggered_bonus"] = 2
	return _ability(
		&"rogue_blindside", "Blindside", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"If target is STAGGERED, gain ATK +2.",
	)


static func _throat_slit() -> AbilityData:
	var base := _module(GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	base.layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.SILENCE, 1)))
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["on_kill_spread_silence_adjacent"] = true
	return _ability(
		&"rogue_throat_slit", "Throat Slit", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"On Kill, spread SILENCE to an adjacent enemy.",
	)


static func _amnesia_dust() -> AbilityData:
	var base := _module(GameEnums.EffectType.DAMAGE, 0, 1, 2, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	var confusion := DataLibrary._status_effect(GameEnums.StatusType.CONFUSION, 1)
	confusion.modifiers["next_turn"] = true
	base.layers = [
		_layer(DataLibrary._status_effect(GameEnums.StatusType.BLIND, 1)),
		_layer(confusion),
	]
	base.legacy_modifiers["confusion_next_turn"] = true
	base.set_condition_not_acted()
	var upgraded := _clone([base])
	upgraded[0].layers.append(_layer(DataLibrary._status_effect(GameEnums.StatusType.POISON, 1)))
	return _ability(
		&"rogue_amnesia_dust", "Amnesia Dust", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Also apply POISON.",
	)


static func _death_mark() -> AbilityData:
	var base := _module(GameEnums.EffectType.ADD_STATUS, 1, 1, 5, GameEnums.TargetingFlags.ENEMY)
	base.status_type = GameEnums.StatusType.MARK
	base.status_duration = 2
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["on_kill_refresh_mark_zero_ap"] = true
	return _ability(
		&"rogue_death_mark", "Death Mark", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"On Kill, refresh Death Mark for 0 AP.",
	)


static func _lethal_flourish() -> AbilityData:
	var base := _module(GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	base.legacy_modifiers["bonus_if_target_debuffed"] = 2
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["kill_grant_ap"] = 1
	return _ability(
		&"rogue_lethal_flourish", "Lethal Flourish", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"On Kill, gain 1 AP.",
	)


static func _shadow_swap() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SWAP, 0, 1, 3, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_TARGET_UNIT,
	)
	var upgraded := _clone([base])
	upgraded[0].layers = [
		_layer(DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 1)),
	]
	return _ability(
		&"rogue_shadow_swap", "Shadow Swap", [base], upgraded,
		GameEnums.TargetingFlags.ALLY, [AbilityModuleBridge.TAG_POSITIONING],
		"Gain +1 DEF for 1 turn after the swap.",
	)


static func _kidnap() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.SWAP, 0, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_TARGET_UNIT,
	)
	base.layers = [_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 2))]
	base.legacy_modifiers["kidnap"] = true
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["swap_collision_stagger_both"] = true
	upgraded[0].legacy_modifiers["enemy_collision_stagger_both"] = true
	return _ability(
		&"rogue_kidnap", "Kidnap", [base], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Target collision applies STAGGER to both.",
	)


static func _shuriken_volley() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.CONE, 3, GameEnums.StatType.PHYSICAL,
	)
	var bleed := DataLibrary._status_effect(GameEnums.StatusType.BLEED, 1)
	bleed.modifiers["bleed_weapon"] = true
	base.layers = [_layer(bleed)]
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["pierce_vs_blind"] = true
	return _ability(
		&"rogue_shuriken_volley", "Shuriken Volley", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"Gain PIERCE against BLIND targets.",
	)


static func _poison_flask() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_CROSS, 1, GameEnums.StatType.PHYSICAL,
	)
	var hazard := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 1)
	hazard.modifiers = {
		"terrain_id": &"poison",
		"hazard_duration": 2,
		"poison_hazard": true,
	}
	base.layers = [_layer(hazard)]
	var upgraded := _clone([base])
	upgraded[0].legacy_modifiers["hazard_blind_on_entry"] = true
	for layer: AbilityLayer in upgraded[0].layers:
		if layer != null and layer.effect != null \
				and layer.effect.type == GameEnums.EffectType.CREATE_HAZARD:
			layer.effect.modifiers["hazard_blind_on_entry"] = true
	return _ability(
		&"rogue_poison_flask", "Poison Flask", [base], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Hazard applies BLIND on entry.",
	)
