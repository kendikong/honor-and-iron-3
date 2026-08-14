class_name BeastRiderFactory
extends RefCounted

## Beast Rider authoring from class_abilities.txt §6.
## The factory owns only data. Shared systems interpret the authored flags.


static func build(basic_lance: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"beast_rider"
	definition.display_name = "Beast Rider"
	definition.base_constitution = 5
	definition.move_points = 5
	definition.action_points = 1
	definition.base_strength = 3
	definition.base_defense = 2
	definition.base_magic = 2
	definition.preferred_stat = GameEnums.StatType.PHYSICAL
	definition.equipped_weapon = basic_lance
	definition.promotion_stat_bonuses = {
		&"griffin_rider": {"strength": 4, "constitution": 2, "movement": 2, "airborne": true},
		&"wyvern_lord": {"strength": 4, "defense": 2, "constitution": 2, "airborne": true},
		&"apex_predator": {"strength": 4, "constitution": 2, "movement": 3},
	}

	definition.innate_passives.append(_passive(
		&"gallop",
		"Gallop",
		"Standard movement points can be split before and after a Skill or basic attack.",
		"Using movement both before and after an Action grants +1 STR to the attack and +1 DEF during post-action movement.",
		{
			"gallop": true,
			"split_movement": true,
			"upgraded_split_attack_strength": 1,
			"upgraded_split_post_defense": 1,
		},
	))

	definition.abilities.append(_reposition())

	# The Griffin Rider.
	definition.passives.append(_passive(
		&"isolation_tactics",
		"Isolation Tactics",
		"Attacks against isolated enemies gain +2 STR.",
		"Also gain ATK +1 per tile moved this turn.",
		{"promotion": &"griffin_rider", "airborne": true,
		"isolation_attack_strength": 2, "upgraded_moved_tile_attack_strength": 1},
	))
	definition.passives.append(_passive(
		&"terminal_velocity",
		"Terminal Velocity",
		"Collision from Drop, PUSH, or PULL deals +WPN unmitigated damage and applies VULNERABLE.",
		"Drop also applies STAGGER.",
		{"promotion": &"griffin_rider", "airborne": true, "collision_weapon_true_damage": true,
		"collision_vulnerable": true, "upgraded_drop_stagger": true},
	))
	definition.passives.append(_passive(
		&"snatch_and_grab",
		"Snatch & Grab",
		"Initiate grappling and dragging skills from RANGE 2.",
		"Range increases to RANGE 3.",
		{"promotion": &"griffin_rider", "airborne": true,
		"grapple_range": 2, "upgraded_grapple_range": 3},
	))
	definition.passives.append(_passive(
		&"safe_landing",
		"Safe Landing",
		"Take 0 hazard damage when landing. Create a 3x3 PUSH 1 shockwave.",
		"Shockwave PUSH increases to 2.",
		{"promotion": &"griffin_rider", "airborne": true, "safe_landing": true,
		"landing_shockwave_size": 1, "landing_shockwave_push": 1,
		"upgraded_landing_shockwave_push": 2},
	))
	definition.passives.append(_passive(
		&"aerial_superiority",
		"Aerial Superiority",
		"Gain +2 DEF against grounded melee attacks.",
		"Become immune to grounded ROOT.",
		{"promotion": &"griffin_rider", "airborne": true,
		"grounded_melee_defense": 2, "upgraded_grounded_root_immunity": true},
	))

	# The Wyvern Lord.
	definition.passives.append(_passive(
		&"mount_resilience",
		"Mount Resilience",
		"Incoming Ranged damage is reduced by Floor(DEF / 2) + 1.",
		"Reduce it by Floor(DEF / 2) + 2 instead.",
		{"promotion": &"wyvern_lord", "airborne": true,
		"ranged_damage_reduction_base": 1,
		"upgraded_ranged_damage_reduction_base": 2},
	))
	definition.passives.append(_passive(
		&"beasts_instinct",
		"Beast's Instinct",
		"An enemy miss or 0 damage grants +1 STR and +1 AP.",
		"Also gain SHIELD 1.",
		{"promotion": &"wyvern_lord", "airborne": true,
		"miss_zero_damage_strength": 1, "miss_zero_damage_ap": 1,
		"upgraded_miss_zero_damage_shield": 1},
	))
	definition.passives.append(_passive(
		&"territorial",
		"Territorial",
		"An enemy entering an adjacent tile suffers ATK 1.",
		"That enemy suffers ATK 2 instead.",
		{"promotion": &"wyvern_lord", "airborne": true, "adjacent_entry_attack": 1,
		"upgraded_adjacent_entry_attack": 2},
	))
	definition.passives.append(_passive(
		&"intimidating_presence",
		"Intimidating Presence",
		"Enemies in RANGE 2 suffer -1 DEF and -1 MOVE permanently.",
		"Range increases to RANGE 3.",
		{"promotion": &"wyvern_lord", "airborne": true, "intimidating_presence_range": 2,
		"intimidating_presence_def": 1, "intimidating_presence_move": 1,
		"upgraded_intimidating_presence_range": 3},
	))
	definition.passives.append(_passive(
		&"dive_bomber",
		"Dive Bomber",
		"Moving 4 or more tiles before attacking grants ATK +2.",
		"Only 3 or more tiles are required.",
		{"promotion": &"wyvern_lord", "airborne": true, "dive_bomber_min_tiles": 4,
		"dive_bomber_attack_strength": 2,
		"upgraded_dive_bomber_min_tiles": 3},
	))

	# The Apex Predator.
	definition.passives.append(_passive(
		&"pack_hunter",
		"Pack Hunter",
		"Attacking an isolated enemy triggers a mount follow-up bite for ATK 1, ignoring 50% DEF.",
		"The follow-up is ATK 2.",
		{"promotion": &"apex_predator", "pack_hunter_bite": 1,
		"pack_hunter_def_ignore_pct": 0.50,
		"upgraded_pack_hunter_bite": 2},
	))
	definition.passives.append(_passive(
		&"blood_scent",
		"Blood Scent",
		"Gain +1 MOVE and PIERCE while moving toward a BLEEDING enemy.",
		"Gain +2 MOVE instead.",
		{"promotion": &"apex_predator", "blood_scent_move": 1,
		"blood_scent_pierce": true, "upgraded_blood_scent_move": 2},
	))
	definition.passives.append(_passive(
		&"vantage_striker",
		"Vantage Striker",
		"Ignore difficult terrain. Gain +1 STR attacking in hazards or at higher elevation.",
		"That STR bonus increases to +2.",
		{"promotion": &"apex_predator", "ignore_difficult_terrain": true,
		"vantage_attack_strength": 1, "upgraded_vantage_attack_strength": 2},
	))
	definition.passives.append(_passive(
		&"predatory_drive",
		"Predatory Drive",
		"Attacks against BLEEDING or isolated enemies apply BLEED X, where X is WPN.",
		"They also apply POISON.",
		{"promotion": &"apex_predator", "predatory_bleed_weapon": true,
		"upgraded_predatory_poison": true},
	))
	definition.passives.append(_passive(
		&"furious_charge",
		"Furious Charge",
		"Moving straight 3 or more tiles applies PUSH 1 to the next attack.",
		"The PUSH increases to 2.",
		{"promotion": &"apex_predator", "furious_charge_min_tiles": 3,
		"furious_charge_push": 1, "upgraded_furious_charge_push": 2},
	))

	definition.abilities.append(_pounce())
	definition.abilities.append(_feral_drag())
	definition.abilities.append(_maul())
	definition.abilities.append(_bestial_roar())
	definition.abilities.append(_raking_claws())
	definition.abilities.append(_rest_and_recover())
	definition.abilities.append(_intimidate())
	definition.abilities.append(_fetch())
	definition.abilities.append(_savage_bite())
	definition.abilities.append(_run_down())
	definition.abilities.append(_thrash())
	definition.abilities.append(_defensive_posture())
	definition.abilities.append(_airlift())
	definition.abilities.append(_tail_swipe())
	definition.abilities.append(_meteor_drop())

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


static func _reposition() -> AbilityData:
	var base := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 2, 1, 1,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.SLIDE_TARGET_OPPOSITE,
	)
	base.legacy_modifiers["reposition_opposite_side"] = true
	base.legacy_modifiers["reposition_movement_cost"] = 2
	var upgraded := _clone([base])
	upgraded[0].max_range = 2
	upgraded[0].legacy_modifiers["reposition_range"] = 2
	return _movement(
		&"beast_reposition", "Reposition", 2, base, upgraded,
		"Move an adjacent unit to the empty tile directly on your opposite side.",
		"Range increased to 2 tiles.",
	)


static func _pounce() -> AbilityData:
	var move := _module(
		GameEnums.EffectType.MOVE, 3, 1, 3,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	move.execution_phase = GameEnums.ModulePhase.ON_PRE
	move.legacy_modifiers["pounce_land_adjacent"] = true
	move.legacy_modifiers["move_to_target_adjacent"] = true
	var attack := _module(
		GameEnums.EffectType.DAMAGE, 3, 1, 1,
		GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.PHYSICAL,
	)
	attack.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	attack.aim_module_index = 0
	var modules: Array[AbilityModule] = [move, attack]
	var upgraded := _clone(modules)
	upgraded[1].legacy_modifiers["landing_push"] = 1
	return _ability(
		&"beast_pounce", "Pounce", modules, upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Landing applies PUSH 1.",
	)


static func _feral_drag() -> AbilityData:
	var drag := _module(
		GameEnums.EffectType.PULL, 0, 1, 1,
		GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	drag.legacy_modifiers = {
		"feral_drag": true,
		"target_constitution_at_most_strength": true,
		"drag_remaining_movement": true,
	}
	var upgraded := _clone([drag])
	upgraded[0].legacy_modifiers["redirect_incoming_damage"] = true
	return _ability(
		&"beast_feral_drag", "Feral Drag", [drag], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Drag a target whose CON is no greater than your STR for remaining MOV; incoming damage is redirected to it.",
	)


static func _maul() -> AbilityData:
	var hit := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1,
		GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.PHYSICAL,
	)
	hit.legacy_modifiers = {
		"maul_dragged_enemy": true, "drop_adjacent": true,
		"does_not_consume_action_slot": true, "limit_once_per_turn": true,
	}
	var upgraded := _clone([hit])
	upgraded[0].legacy_modifiers["drop_trap_damage_multiplier"] = 2.0
	var ability := _ability(
		&"beast_maul", "Maul", [hit], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Drop the dragged enemy adjacent; dropping it on a trap doubles trap damage.",
	)
	ability.action_point_cost = 0
	return ability


static func _bestial_roar() -> AbilityData:
	var push := _module(
		GameEnums.EffectType.PUSH, 2, 0, 3,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.CONE, 3,
	)
	var fear := DataLibrary._status_effect(GameEnums.StatusType.FEAR, 1)
	fear.modifiers["status_requires_debuff"] = true
	push.layers = [_layer(fear)]
	var upgraded := _clone([push])
	var defense := DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_DEF, -1, 1)
	defense.modifiers["cone_all_targets"] = true
	upgraded[0].layers.append(_layer(defense))
	return _ability(
		&"beast_bestial_roar", "Bestial Roar", [push], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Apply DEF -1 in the cone.",
	)


static func _raking_claws() -> AbilityData:
	var claws := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.ARC, 1, GameEnums.StatType.PHYSICAL,
	)
	var bleed := DataLibrary._status_effect(GameEnums.StatusType.BLEED, 1)
	bleed.modifiers["bleed_weapon"] = true
	claws.layers = [_layer(bleed)]
	var upgraded := _clone([claws])
	upgraded[0].legacy_modifiers["pull_before_attack"] = 1
	return _ability(
		&"beast_raking_claws", "Raking Claws", [claws], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"PULL 1 before attacking.",
	)


static func _rest_and_recover() -> AbilityData:
	var heal := _module(
		GameEnums.EffectType.HEAL, 1, 0, 0,
		GameEnums.TargetingFlags.SELF, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.NONE,
	)
	heal.legacy_modifiers["cost_all_movement"] = true
	var defense := DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 5)
	heal.layers = [_layer(defense)]
	var upgraded := _clone([heal])
	upgraded[0].layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.CLEANSE, 0)))
	var ability := _ability(
		&"beast_rest_recover", "Rest & Recover", [heal], upgraded,
		GameEnums.TargetingFlags.SELF, [AbilityModuleBridge.TAG_HEAL],
		"CLEANSE all debuffs.",
	)
	ability.primary_value = 1
	ability.action_point_cost = 1
	return ability


static func _intimidate() -> AbilityData:
	var stagger := _module(
		GameEnums.EffectType.ADD_STATUS, 1, 0, 0,
		GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.TILE
			| GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	stagger.status_type = GameEnums.StatusType.STAGGER
	stagger.status_duration = 1
	stagger.legacy_modifiers["lower_hp_only"] = true
	var upgraded := _clone([stagger])
	upgraded[0].legacy_modifiers["purge_buffs"] = true
	return _ability(
		&"beast_intimidate", "Intimidate", [stagger], upgraded,
		GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.TILE
			| GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_POSITIONING],
		"PURGE buffs from affected enemies.",
	)


static func _fetch() -> AbilityData:
	var fetch := _module(
		GameEnums.EffectType.PULL, 1, 1, 4,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ALLY
			| GameEnums.TargetingFlags.ENEMY,
	)
	fetch.legacy_modifiers = {"fetch_item_or_corpse": true}
	var upgraded := _clone([fetch])
	upgraded[0].legacy_modifiers["pull_light_ally"] = 2
	return _ability(
		&"beast_fetch", "Fetch", [fetch], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ALLY
			| GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Pull light allies 2 tiles.",
	)


static func _savage_bite() -> AbilityData:
	var bite := _module(
		GameEnums.EffectType.DAMAGE, 4, 1, 1,
		GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.PHYSICAL,
	)
	bite.legacy_modifiers = {"requires_bleed_or_poison": true}
	var upgraded := _clone([bite])
	upgraded[0].legacy_modifiers["on_kill_shield"] = 2
	return _ability(
		&"beast_savage_bite", "Savage Bite", [bite], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"On Kill, gain SHIELD 2.",
	)


static func _run_down() -> AbilityData:
	var dash := _module(
		GameEnums.EffectType.DASH, 3, 1, 3,
		GameEnums.TargetingFlags.DASH_LINE | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	dash.legacy_modifiers["run_down_pass_adjacent_push"] = 1
	dash.legacy_modifiers["trample_atk"] = 2
	var upgraded := _clone([dash])
	upgraded[0].legacy_modifiers["run_down_push_bleed_weapon"] = true
	return _ability(
		&"beast_run_down", "Run Down", [dash], upgraded,
		GameEnums.TargetingFlags.DASH_LINE | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Pushing applies BLEED X, where X is WPN.",
	)


static func _thrash() -> AbilityData:
	var thrash := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 1,
		GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.PHYSICAL,
	)
	thrash.legacy_modifiers["hit_count"] = 3
	thrash.legacy_modifiers["repeat_hits"] = 3
	var upgraded := _clone([thrash])
	var bleed := DataLibrary._status_effect(GameEnums.StatusType.BLEED, 1)
	bleed.modifiers["bleed_weapon"] = true
	upgraded[0].layers = [_layer(bleed)]
	return _ability(
		&"beast_thrash", "Thrash", [thrash], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Each hit applies BLEED X, where X is WPN.",
	)


static func _defensive_posture() -> AbilityData:
	var posture := _module(
		GameEnums.EffectType.ADD_STATUS_SELF, 1, 0, 0,
		GameEnums.TargetingFlags.SELF,
	)
	posture.status_type = GameEnums.StatusType.INTERCEPT
	posture.status_duration = 1
	var defense := DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 2)
	posture.layers = [_layer(defense)]
	var upgraded := _clone([posture])
	upgraded[0].legacy_modifiers["intercept_push_attacker"] = 2
	return _ability(
		&"beast_defensive_posture", "Defensive Posture", [posture], upgraded,
		GameEnums.TargetingFlags.SELF, [AbilityModuleBridge.TAG_POSITIONING],
		"If hit, PUSH 2 the attacker.",
	)


static func _airlift() -> AbilityData:
	var lift := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 1, 1, 1,
		GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	lift.legacy_modifiers = {
		"airlift_pickup_step": 1, "airlift_drop_step": 3, "airlift_keep_caster": true,
	}
	var upgraded := _clone([lift])
	upgraded[0].legacy_modifiers["airlift_ally_attack_strength"] = 1
	return _ability(
		&"beast_airlift", "Airlift", [lift], upgraded,
		GameEnums.TargetingFlags.ALLY, [AbilityModuleBridge.TAG_POSITIONING],
		"Lift an adjacent ally at Step 1 and drop it in an empty tile at Step 3; it gains ATK +1.",
	)


static func _tail_swipe() -> AbilityData:
	var swipe := _module(
		GameEnums.EffectType.PUSH, 2, 0, 0,
		GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.TILE
			| GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_SQUARE, 1,
	)
	var damage := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)
	swipe.layers = [_layer(damage)]
	var upgraded := _clone([swipe])
	upgraded[0].legacy_modifiers["wall_collision_stagger"] = true
	upgraded[0].legacy_modifiers["object_collision_stagger"] = true
	return _ability(
		&"beast_tail_swipe", "Tail Swipe", [swipe], upgraded,
		GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.TILE
			| GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_POSITIONING],
		"Wall collision applies STAGGER.",
	)


static func _meteor_drop() -> AbilityData:
	var jump := _module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 2,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	jump.execution_phase = GameEnums.ModulePhase.ON_PRE
	jump.legacy_modifiers["meteor_drop"] = true
	var strike := _module(
		GameEnums.EffectType.DAMAGE, 2, 0, 0,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.AOE_DIAMOND, 1, GameEnums.StatType.PHYSICAL,
	)
	strike.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	strike.aim_module_index = 0
	var modules: Array[AbilityModule] = [jump, strike]
	var upgraded := _clone(modules)
	upgraded[1].legacy_modifiers["landing_vulnerable"] = true
	return _ability(
		&"beast_meteor_drop", "Meteor Drop", modules, upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Targets hit suffer VULNERABLE.",
	)


static func _movement(
	id: StringName,
	name: String,
	mp_cost: int,
	module: AbilityModule,
	upgraded: Array[AbilityModule],
	description: String,
	upgraded_description: String,
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id, name, [module], upgraded, mp_cost,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_MOVEMENT, AbilityModuleBridge.TAG_POSITIONING],
		upgraded_description, module.targeting_flags,
	)
	ability.upgrade_description = upgraded_description
	ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	ability.action_point_cost = 0
	ability.movement_point_cost = mp_cost
	ability.primary_value = mp_cost
	ability.presentation_anim = GameEnums.PresentationAnim.WALK
	return ability
