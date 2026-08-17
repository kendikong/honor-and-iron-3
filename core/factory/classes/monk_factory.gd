class_name MonkFactory
extends RefCounted

## Builds the complete Monk promotion pool from class_abilities.txt.
## Monk mechanics are authored as reusable module/passive data and resolved by
## AbilitySystem, CombatSystem, MovementSystem, and Simulator.


static func build(basic_fist: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"monk"
	definition.display_name = "Monk"
	definition.base_constitution = 5
	definition.move_points = 4
	definition.action_points = GameEnums.MAX_AP
	definition.base_strength = 3
	definition.base_defense = 2
	definition.base_magic = 4
	definition.preferred_stat = GameEnums.StatType.MAGICAL
	definition.equipped_weapon = basic_fist
	definition.promotion_stat_bonuses = {
		&"avatar": {"magic": 6, "constitution": 2, "movement": 0},
		&"mystic": {"strength": 4, "magic": 4, "movement": 0},
		&"windwalker": {"strength": 4, "defense": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"way_of_the_weaver",
		"Way of the Weaver",
		"Physical damage empowers the next magic skill with MAG ATK +2 and PIERCE; magical damage empowers the next physical skill with ATK +2 and PUSH 1.",
		"Triggering a weave also grants SHIELD 1.",
		{"way_of_the_weaver": true, "weave_bonus": 2, "weave_push": 1,
		"weave_shield": 1, "promotion": &"core"},
	))

	definition.abilities.append(_leap())

	# Avatar passives.
	definition.passives.append(_passive(
		&"elemental_attunement", "Elemental Attunement",
		"While standing on an elemental surface, attacks gain PIERCE.",
		"Apply BURN X or BLEED X, where X is MAG.",
		{"promotion": &"avatar", "elemental_attunement": true,
		"attunement_pierce": true, "attunement_burn_mag": true},
	))
	definition.passives.append(_passive(
		&"chakra_burn", "Chakra Burn",
		"Hitting an enemy on a hazard applies BURN X, where X is MAG.",
		"Also apply BLIND.",
		{"promotion": &"avatar", "chakra_burn": true, "chakra_burn_mag": true,
		"upgraded_chakra_burn_blind": true},
	))
	definition.passives.append(_passive(
		&"elemental_harmony", "Elemental Harmony",
		"Gain ATK +1 per adjacent elemental tile.",
		"Gain ATK +2 per adjacent elemental tile.",
		{"promotion": &"avatar", "adjacent_elemental_attack": 1,
		"upgraded_adjacent_elemental_attack": 2},
	))
	definition.passives.append(_passive(
		&"catalyst", "Catalyst",
		"Gain +1 MAG and +1 DEF while on an elemental surface.",
		"Also gain +1 MOV.",
		{"promotion": &"avatar", "surface_magic": 1, "surface_defense": 1,
		"upgraded_surface_movement": 1},
	))
	definition.passives.append(_passive(
		&"elemental_shield", "Elemental Shield",
		"Creating terrain grants +1 DEF for the turn.",
		"Gain +2 DEF instead.",
		{"promotion": &"avatar", "terrain_created_defense": 1,
		"upgraded_terrain_created_defense": 2},
	))

	# Mystic passives.
	definition.passives.append(_passive(
		&"weavers_resonance", "Weaver's Resonance",
		"Consuming a Weave stack triggers a 1-tile elemental shockwave and grants SHIELD 1.",
		"Shockwave also applies WEAKEN.",
		{"promotion": &"mystic", "weaver_resonance": true,
		"weaver_resonance_damage": 1, "weaver_resonance_shield": 1,
		"upgraded_weaver_resonance_weaken": true},
	))
	definition.passives.append(_passive(
		&"mind_over_matter", "Mind over Matter",
		"Physical attacks scale from the higher of STR or MAG.",
		"Gain +1 DEF if STR equals MAG.",
		{"promotion": &"mystic", "physical_scale_higher_stat": true,
		"upgraded_equal_stat_defense": 1},
	))
	definition.passives.append(_passive(
		&"inner_peace", "Inner Peace",
		"Spending 0 MOV grants PIERCE on attacks this turn.",
		"Attacks also gain ATK +2.",
		{"promotion": &"mystic", "zero_move_attack_pierce": true,
		"upgraded_zero_move_attack_strength": 2},
	))
	definition.passives.append(_passive(
		&"zen_defense", "Zen Defense",
		"Gain +1 MAG per empty adjacent tile. If all four are empty, gain SHIELD 1.",
		"Gain SHIELD 2 instead.",
		{"promotion": &"mystic", "empty_adjacent_magic": 1,
		"zen_defense_empty_shield": 1, "upgraded_zen_defense_empty_shield": 2},
	))
	definition.passives.append(_passive(
		&"perfect_form", "Perfect Form",
		"Taking 0 damage last turn grants +1 STR and +1 MOV.",
		"Gain +2 STR and +2 MOV instead.",
		{"promotion": &"mystic", "perfect_form_strength": 1,
		"perfect_form_movement": 1, "upgraded_perfect_form_strength": 2,
		"upgraded_perfect_form_movement": 2},
	))

	# Windwalker passives.
	definition.passives.append(_passive(
		&"vaulting_strike", "Vaulting Strike",
		"Vaulting over an enemy grants ATK +2 against that enemy this turn.",
		"Gain ATK +3 instead.",
		{"promotion": &"windwalker", "vaulted_attack_bonus": 2,
		"upgraded_vaulted_attack_bonus": 3},
	))
	definition.passives.append(_passive(
		&"flowing_ki", "Flowing Ki",
		"Moving through or jumping over an enemy grants +1 MAG this turn.",
		"Also gain +1 STR.",
		{"promotion": &"windwalker", "flowing_ki": true, "flowing_ki_magic": 1,
		"upgraded_flowing_ki_strength": 1},
	))
	definition.passives.append(_passive(
		&"evasive_acrobat", "Evasive Acrobat",
		"Gain GHOST. Moving through enemy tiles applies CONFUSION.",
		"Also applies BLIND.",
		{"promotion": &"windwalker", "evasive_acrobat": true,
		"evasive_acrobat_confusion": true, "upgraded_evasive_acrobat_blind": true},
	))
	definition.passives.append(_passive(
		&"momentum_transfer", "Ki Momentum",
		"Gain +1 STR for every 2 tiles moved before attacking.",
		"Gain +1 STR per tile moved.",
		{"promotion": &"windwalker", "moved_tiles_attack_divisor": 2,
		"upgraded_moved_tiles_attack_divisor": 1},
	))
	definition.passives.append(_passive(
		&"light_step", "Light Step",
		"Ignore difficult terrain and traps. Ending on a trap disarms it.",
		"Ending on a trap grants SHIELD 1.",
		{"promotion": &"windwalker", "ignore_difficult_terrain": true,
		"disarm_end_trap": true, "upgraded_light_step_shield": 1},
	))

	definition.abilities.append(_scorching_kick())
	definition.abilities.append(_thunder_palm())
	definition.abilities.append(_yin_yang_flurry())
	definition.abilities.append(_chakra_shift())
	definition.abilities.append(_phase_throw())
	definition.abilities.append(_flying_crane_kick())
	definition.abilities.append(_spirit_palm())
	definition.abilities.append(_soul_punch())
	definition.abilities.append(_hundred_fists())
	definition.abilities.append(_mantra_of_peace())
	definition.abilities.append(_inner_fire())
	definition.abilities.append(_void_step())
	definition.abilities.append(_cyclone_sweep())
	definition.abilities.append(_updraft())
	definition.abilities.append(_geyser_strike())

	DataLibrary.finalize_unit_abilities(definition)
	return definition


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgrade_description: String,
	modifiers: Dictionary,
) -> PassiveData:
	return DataLibrary._make_passive(id, name, description, upgrade_description, modifiers)


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
	var module := DataLibrary._module(
		primary_type, amount, min_range, max_range, targeting_flags,
		shape, shape_size, scaling_stat,
	)
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
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	targeting_flags: int,
	tags: Array[StringName],
	description: String,
) -> AbilityData:
	var ability := DataLibrary._make_modular_ability(
		id, name, modules, upgraded_modules, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		tags, description, targeting_flags,
	)
	ability.presentation_key = id
	return ability


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
	ability.movement_point_cost = mp_cost
	ability.primary_value = mp_cost
	ability.range_tiles = module.max_range
	ability.sync_legacy_targeting()
	return ability


static func _damage(
	id: StringName,
	name: String,
	damage: int,
	min_range: int,
	max_range: int,
	scaling_stat: GameEnums.StatType,
	description: String,
) -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, damage, min_range, max_range,
		GameEnums.TargetingFlags.ENEMY, GameEnums.TargetShape.SINGLE, 1,
		scaling_stat,
	)
	var upgraded := _clone_modules([module])
	return _ability(
		id, name, [module], upgraded, GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK], description,
	)


static func _leap() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.JUMP_TO_BEHIND, 2, 2, 2,
		GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE, 1,
	)
	var upgraded := _clone_modules([module])
	upgraded[0].max_range = 3
	upgraded[0].leap_absorb_surface = true
	return _movement(
		&"monk_leap", "Leap", 2, module, upgraded,
		"Jump directly over a 1-tile obstacle, gap, trap, or unit to an empty tile behind it. [+] Range 3; landing on an elemental surface empowers the next attack.",
	)


static func _scorching_kick() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	var fire_layer := _layer(DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0))
	fire_layer.terrain_id = &"fire"
	fire_layer.hazard_duration = 1
	fire_layer.elemental_surface = true
	module.layers.append(fire_layer)
	var upgraded := _clone_modules([module])
	upgraded[0].layers[0].burning_splash_magic = 2
	upgraded[0].layers[0].burning_splash_shape = GameEnums.TargetShape.AOE_CROSS
	return _ability(
		&"monk_scorching_kick", "Scorching Kick", [module], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Target tile becomes FIRE. [+] If target is burning, deal MAG ATK 2 splash.",
	)


static func _thunder_palm() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	module.bounce_surface_chain = true
	var upgraded := _clone_modules([module])
	var stagger := DataLibrary._status_effect(GameEnums.StatusType.STAGGER, 1)
	upgraded[0].layers.append(_layer(stagger))
	return _ability(
		&"monk_thunder_palm", "Thunder Palm", [module], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"On WATER/FROZEN, chain 50% damage to all units on that surface. [+] Apply STAGGER.",
	)


static func _yin_yang_flurry() -> AbilityData:
	var physical := _module(
		GameEnums.EffectType.DAMAGE, 1, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	physical.track_first_hit_zero = true
	var magical := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)
	magical.scaling_stat = GameEnums.StatType.MAGICAL
	physical.layers.append(_layer(magical))
	var upgraded := _clone_modules([physical])
	upgraded[0].layers[0].pierce_if_first_zero = true
	return _ability(
		&"monk_yin_yang_flurry", "Yin-Yang Flurry", [physical],
		upgraded, GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"Deal ATK 1, then MAG ATK 1. [+] If the first hit deals 0 damage, the second gains PIERCE.",
	)


static func _chakra_shift() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS_SELF, 2, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	module.chakra_shift = true
	var upgraded := _clone_modules([module])
	upgraded[0].chakra_shift = true
	upgraded[0].chakra_burst_damage = 1
	upgraded[0].chakra_burst_shape = GameEnums.TargetShape.AOE_CROSS
	upgraded[0].chakra_burst_size = 2
	return _ability(
		&"monk_chakra_shift", "Chakra Shift", [module], upgraded,
		GameEnums.TargetingFlags.SELF, [AbilityModuleBridge.TAG_POSITIONING],
		"Swap current STR and MAG for 2 turns. [+] Trigger a MAG ATK 1 AOE 2 burst.",
	)


static func _phase_throw() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.SWAP, 0, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
	)
	var upgraded := _clone_modules([module])
	var root := DataLibrary._status_effect(GameEnums.StatusType.ROOT, 1)
	upgraded[0].layers.append(_layer(root))
	return _ability(
		&"monk_phase_throw", "Phase Throw", [module], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_POSITIONING],
		"Swap position with target enemy. [+] Apply ROOT after swapping.",
	)


static func _flying_crane_kick() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DASH, 3, 1, 3,
		GameEnums.TargetingFlags.DASH_LINE | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	module.stop_adjacent_first_enemy = true
	var strike := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	strike.scaling_stat = GameEnums.StatType.PHYSICAL
	var strike_layer := _layer(strike)
	strike_layer.damage_adjacent_on_landing = true
	strike_layer.require_dash_line_enemy = true
	module.layers.append(strike_layer)
	var upgraded := _clone_modules([module])
	upgraded[0].stop_adjacent_first_enemy = true
	upgraded[0].dash_absorb_element = true
	if not upgraded[0].layers.is_empty():
		upgraded[0].layers[0].dash_absorb_element = true
	return _ability(
		&"monk_flying_crane_kick", "Flying Crane Kick", [module], upgraded,
		GameEnums.TargetingFlags.DASH_LINE | GameEnums.TargetingFlags.TILE,
		[AbilityModuleBridge.TAG_ATTACK, AbilityModuleBridge.TAG_MOVEMENT],
		"Dash 3, stop adjacent to the first enemy in the line, and deal ATK 2. [+] Dashing over a hazard absorbs its element into the attack.",
	)


static func _spirit_palm() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 2, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1)))
	module.layers[0].collision_splash_damage = 2
	var upgraded := _clone_modules([module])
	upgraded[0].layers[0].collision_splash_damage = 2
	upgraded[0].layers[0].collision_splash_weaken = true
	return _ability(
		&"monk_spirit_palm", "Spirit Palm", [module], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"MAG ATK 2 and PUSH 1. Collision triggers ATK 2 physical splash. [+] Splash applies WEAKEN.",
	)


static func _soul_punch() -> AbilityData:
	var ability := _damage(
		&"monk_soul_punch", "Soul Punch", 3, 1, 1, GameEnums.StatType.PHYSICAL,
		"ATK 3 targets MAG instead of DEF. [+] Steal 1 MAG from target for 2 turns.",
	)
	ability.modules[0].target_magic_defense = true
	ability.upgraded_modules[0].target_magic_defense = true
	ability.upgraded_modules[0].steal_target_magic = 1
	return ability


static func _hundred_fists() -> AbilityData:
	var ability := _damage(
		&"monk_hundred_fists", "Hundred Fists", 4, 1, 1, GameEnums.StatType.PHYSICAL,
		"ATK 4; caster loses 2 MOV on the following turn. [+] ATK +1 per target status effect.",
	)
	ability.modules[0].next_turn_move_penalty = 2
	ability.upgraded_modules[0].next_turn_move_penalty = 2
	ability.upgraded_modules[0].bonus_per_target_status = 1
	return ability


static func _mantra_of_peace() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS, 1, 0, 0,
		GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	module.status_type = GameEnums.StatusType.WEAKEN
	module.status_duration = 1
	module.mantra_peace_weaken = true
	var upgraded := _clone_modules([module])
	var heal := DataLibrary._effect(GameEnums.EffectType.HEAL, 1)
	heal.scaling_stat = GameEnums.StatType.MAX_HP
	upgraded[0].layers.append(_layer(heal))
	return _ability(
		&"monk_mantra_of_peace", "Mantra of Peace", [module], upgraded,
		module.targeting_flags, [AbilityModuleBridge.TAG_POSITIONING],
		"Apply WEAKEN in AOE 2. [+] Allies in radius HEAL 1.",
	)


static func _inner_fire() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS_SELF, 1, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	module.inner_fire = true
	var upgraded := _clone_modules([module])
	upgraded[0].inner_fire = true
	upgraded[0].inner_fire_surface = true
	return _ability(
		&"monk_inner_fire", "Inner Fire", [module], upgraded,
		GameEnums.TargetingFlags.SELF, [AbilityModuleBridge.TAG_POSITIONING],
		"Physical attacks deal MAG ATK 1 splash for 2 turns. [+] Splash creates FIRE terrain.",
	)


static func _void_step() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.TELEPORT_ADJACENT_TO, 0, 1, 3,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.TILE, GameEnums.TargetShape.SINGLE, 1,
		GameEnums.StatType.NONE,
	)
	var upgraded := _clone_modules([module])
	upgraded[0].landed_magic_bonus = 2
	return _ability(
		&"monk_void_step", "Void Step", [module], upgraded,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.TILE, [AbilityModuleBridge.TAG_MOVEMENT],
		"Teleport to an empty tile adjacent to an ally. [+] Landing grants +2 MAG for 1 turn.",
	)


static func _cyclone_sweep() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.PUSH, 2, 1, 1,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.ARC, 1,
	)
	var upgraded := _clone_modules([module])
	upgraded[0].enemy_pushed_mov = 1
	return _ability(
		&"monk_cyclone_sweep", "Cyclone Sweep", [module], upgraded,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		[AbilityModuleBridge.TAG_ATTACK],
		"PUSH 2 all targets in ARC. [+] Gain +1 MOV per enemy pushed.",
	)


static func _updraft() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.ADD_STATUS_SELF, 2, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	module.status_type = GameEnums.StatusType.AIRBORNE
	module.status_duration = 2
	var mov := DataLibrary._status_effect(
		GameEnums.StatusType.STAT_BUFF_MOV, 2, 1,
	)
	module.layers.append(_layer(mov))
	var upgraded := _clone_modules([module])
	upgraded[0].blind_on_pass_over = true
	return _ability(
		&"monk_updraft", "Updraft", [module], upgraded,
		GameEnums.TargetingFlags.SELF, [AbilityModuleBridge.TAG_POSITIONING],
		"Gain AIRBORNE and +1 MOV for 2 turns. [+] Passing over an enemy applies BLIND.",
	)


static func _geyser_strike() -> AbilityData:
	var module := _module(
		GameEnums.EffectType.DAMAGE, 2, 1, 2, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL,
	)
	module.layers.append(_layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1)))
	var water_layer := _layer(DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0))
	water_layer.terrain_id = &"water"
	water_layer.hazard_duration = 1
	water_layer.elemental_surface = true
	module.layers.append(water_layer)
	var upgraded := _clone_modules([module])
	upgraded[0].layers[0].push_if_target_on_water = 2
	return _ability(
		&"monk_geyser_strike", "Geyser Strike", [module], upgraded,
		GameEnums.TargetingFlags.ENEMY, [AbilityModuleBridge.TAG_ATTACK],
		"MAG ATK 2, PUSH 1, and create WATER terrain. [+] PUSH 2 if target is on WATER.",
	)
