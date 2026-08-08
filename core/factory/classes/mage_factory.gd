class_name MageFactory
extends RefCounted

## Builds the complete Mage moveset from class_abilities.txt.
## All Mage behavior is authored as data and consumed by shared simulation systems.


static func build(basic_staff: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"mage"
	definition.display_name = "Mage"
	definition.base_constitution = 3
	definition.move_points = 3
	definition.action_points = 1
	definition.base_strength = 1
	definition.base_defense = 1
	definition.base_magic = 5
	definition.preferred_stat = GameEnums.StatType.MAGICAL
	definition.equipped_weapon = basic_staff
	definition.promotion_stat_bonuses = {
		&"geomancer": {"magic": 4, "constitution": 4, "movement": 0},
		&"archmage": {"magic": 8, "movement": 0},
		&"graviturge": {"magic": 4, "defense": 2, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"arcane_overchannel",
		"Arcane Overchannel",
		"Spells grant Arcane Overchannel stacks, up to 3; each stack grants +1 MAG ATK.",
		"At 3 stacks, refund 1 AP once per turn and gain SHIELD 2.",
		{"arcane_overchannel": true, "arcane_overchannel_max": 3,
		"arcane_overchannel_magic": 1, "arcane_overchannel_refund_ap": 1,
		"arcane_overchannel_shield": 2, "promotion": &"core"},
	))

	var blink := DataLibrary._make_movement_ability(
		&"mage_blink",
		"Blink",
		2,
		[DataLibrary._effect(GameEnums.EffectType.TELEPORT_CASTER, 0)],
		3,
		GameEnums.StatType.NONE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.TargetingMode.TILE,
	)
	blink.upgraded_range_tiles = 3
	blink.effects[0].modifiers["blink"] = true
	var blink_upgrade := DataLibrary._duplicate_effects(blink.effects)
	blink_upgrade[0].modifiers["leave_elemental_surface"] = true
	blink.upgraded_effects = blink_upgrade
	blink.upgrade_description = "Range becomes 3; leave an elemental surface on departure."
	definition.abilities.append(blink)

	# Geomancer passives.
	definition.passives.append(_passive(&"elementalist", "Elementalist",
		"Fire leaves FIRE; Ice leaves FROZEN; Lightning hits all on WATER/FROZEN.",
		"Enemies on new terrain take WPN unmitigated damage.",
		{"promotion": &"geomancer", "elementalist": true,
		"elementalist_terrain_damage_weapon": true}))
	definition.passives.append(_passive(&"feedback", "Feedback",
		"Creating terrain grants +1 MAG and SHIELD 1 for 1 turn.",
		"Gain SHIELD 2 instead.",
		{"promotion": &"geomancer", "feedback_magic": 1, "feedback_shield": 1,
		"upgraded_feedback_shield": 2}))
	definition.passives.append(_passive(&"elemental_master", "Elemental Master",
		"Gain +1 MAG per elemental tile on the map.",
		"Gain +1 DEF if 3 or more elemental tiles exist.",
		{"promotion": &"geomancer", "elemental_master_magic": 1,
		"upgraded_elemental_master_def_threshold": 3,
		"upgraded_elemental_master_def": 1}))
	definition.passives.append(_passive(&"lasting_terrain", "Lasting Terrain",
		"Surfaces last 1 extra turn and deal +1 hazard damage.",
		"Deal +2 hazard damage instead.",
		{"promotion": &"geomancer", "lasting_terrain_duration": 1,
		"lasting_terrain_damage": 1, "upgraded_lasting_terrain_damage": 2}))
	definition.passives.append(_passive(&"surface_syphoner", "Surface Syphoner",
		"Ending your turn on a created surface HEALs 1 and CLEANSEs you.",
		"HEAL 1 and gain SHIELD 1 instead of CLEANSE.",
		{"promotion": &"geomancer", "surface_syphoner": true,
		"surface_syphoner_heal": 1, "surface_syphoner_shield": 1}))

	# Archmage passives.
	definition.passives.append(_passive(&"mana_leak", "Mana Leak",
		"When damaged, deal MAG ATK 1 to adjacent tiles.",
		"Deal MAG ATK 2 instead.",
		{"promotion": &"archmage", "mana_leak": 1,
		"upgraded_mana_leak": 2}))
	definition.passives.append(_passive(&"arcane_overdrive", "Arcane Overdrive",
		"Gain +3 MAG; every spell consumes 5% current HP. Physical damage bypasses 50% SHIELD.",
		"Gain +4 MAG; spell HP cost remains 5%.",
		{"promotion": &"archmage", "arcane_overdrive_magic": 3,
		"upgraded_arcane_overdrive_magic": 4,
		"arcane_overdrive_hp_pct": 0.05, "arcane_overdrive_shield_bypass": 0.5}))
	definition.passives.append(_passive(&"mana_well", "Mana Well",
		"Ending on an elemental surface makes your next spell cost 0 AP.",
		"Also gain +1 MAG next turn.",
		{"promotion": &"archmage", "mana_well": true,
		"mana_well_magic": 1}))
	definition.passives.append(_passive(&"mana_siphon", "Mana Siphon",
		"Spell kills refund 1 AP once per turn; if capped, heal MAG and gain Overchannel.",
		"Also HEAL 1 on kill.",
		{"promotion": &"archmage", "mana_siphon": true,
		"mana_siphon_heal": 1}))
	definition.passives.append(_passive(&"overload", "Overload",
		"Gain +2 MAG and take 1 damage per turn, never below 1 HP.",
		"Gain +3 MAG instead.",
		{"promotion": &"archmage", "overload_magic": 2,
		"upgraded_overload_magic": 3, "overload_tick_damage": 1}))

	# Graviturge passives.
	definition.passives.append(_passive(&"wild_magic", "Wild Magic",
		"Targeting an enemy on a hazard casts the spell twice; the second cast costs 0 AP.",
		"Second cast gains +1 MAG.",
		{"promotion": &"graviturge", "wild_magic": true,
		"upgraded_wild_magic_magic": 1}))
	definition.passives.append(_passive(&"arcane_tether", "Arcane Tether",
		"An enemy moving adjacent suffers MAG ATK 1 and ROOT.",
		"MAG ATK increases to 2.",
		{"promotion": &"graviturge", "arcane_tether": 1,
		"upgraded_arcane_tether": 2}))
	definition.passives.append(_passive(&"arcane_mastery", "Arcane Mastery",
		"AOE spells gain +1 radius.",
		"AOE spells gain PIERCE.",
		{"promotion": &"graviturge", "arcane_mastery_radius": 1,
		"arcane_mastery_pierce": true}))
	definition.passives.append(_passive(&"arcane_attunement", "Arcane Attunement",
		"Casting a spell on an ally grants +1 DEF and +1 STR for 1 turn.",
		"The ally also gains +1 MOV.",
		{"promotion": &"graviturge", "arcane_attunement": true,
		"arcane_attunement_def": 1, "arcane_attunement_str": 1,
		"upgraded_arcane_attunement_mov": 1}))
	definition.passives.append(_passive(&"gravity_anchor", "Gravity Anchor",
		"Enemies suffering ROOT take +1 damage from spells.",
		"They take +2 damage instead.",
		{"promotion": &"graviturge", "gravity_anchor": 1,
		"upgraded_gravity_anchor": 2}))

	definition.abilities.append(_fireball())
	definition.abilities.append(_ice_shard())
	definition.abilities.append(_chain_lightning())
	definition.abilities.append(_arcane_push())
	definition.abilities.append(_teleport())
	definition.abilities.append(_meteor())
	definition.abilities.append(_black_hole())
	definition.abilities.append(_time_warp())
	definition.abilities.append(_mana_shield())
	definition.abilities.append(_disintegrate())
	definition.abilities.append(_gravity_well())
	definition.abilities.append(_elemental_surge())
	definition.abilities.append(_earth_spike())
	definition.abilities.append(_density_shift())
	definition.abilities.append(_arcane_barrage())

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


static func _spell(
	id: StringName,
	name: String,
	range_tiles: int,
	effects: Array[EffectData],
	targeting_flags: int,
	shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE,
	shape_size: int = 1,
) -> AbilityData:
	var ability := DataLibrary._make_ability(
		id, name, range_tiles, effects, 1, GameEnums.StatType.MAGICAL, shape, shape_size,
	)
	ability.targeting_flags = targeting_flags
	ability.sync_legacy_targeting()
	ability.tags = [AbilityModuleBridge.TAG_SPELL]
	ability.presentation_anim = GameEnums.PresentationAnim.SPELL
	return ability


static func _upgrade(
	ability: AbilityData,
	effects: Array[EffectData],
	description: String,
) -> AbilityData:
	ability.upgraded_effects = effects
	ability.upgrade_description = description
	return ability


static func _terrain(id: StringName, duration: int = 1) -> EffectData:
	var effect := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
	effect.modifiers["terrain_id"] = id
	effect.modifiers["hazard_duration"] = duration
	effect.modifiers["elemental_surface"] = true
	return effect


static func _spawn_effect(spawn_id: StringName) -> EffectData:
	var effect := DataLibrary._effect(GameEnums.EffectType.SPAWN, 0)
	effect.spawn_unit_id = spawn_id
	return effect


static func _fireball() -> AbilityData:
	var fire_effect := _terrain(&"fire")
	var fire_effects: Array[EffectData] = [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 3),
		fire_effect,
	]
	var ability := _spell(
		&"mage_fireball", "Fireball", 4,
		fire_effects,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_SQUARE,
		1,
	)
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["reaction_frozen_to_steam"] = true
	upgraded[1].modifiers["reaction_frozen_to_steam"] = true
	upgraded[1].modifiers["terrain_id"] = &"steam"
	upgraded[1].modifiers["reaction_terrain"] = &"frozen"
	upgraded[0].modifiers["reaction_terrain"] = &"frozen"
	upgraded[0].modifiers["reaction_damage"] = 2
	ability.upgraded_target_shape = GameEnums.TargetShape.AOE_SQUARE
	ability.upgraded_target_shape_size = 3
	return _upgrade(ability, upgraded, "On FROZEN, create STEAM (AOE 3x3) with MAG ATK 2 splash.")


static func _ice_shard() -> AbilityData:
	var ability := _spell(
		&"mage_ice_shard", "Ice Shard", 4,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 1),
		_terrain(&"frozen")],
		GameEnums.TargetingFlags.ENEMY,
	)
	ability.effects[1].modifiers["set_max_move"] = 1
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["reaction_fire_to_steam"] = true
	upgraded[2].modifiers["reaction_fire_to_steam"] = true
	upgraded[2].modifiers["terrain_id"] = &"steam"
	upgraded[2].modifiers["reaction_terrain"] = &"fire"
	upgraded[0].modifiers["reaction_terrain"] = &"fire"
	upgraded[0].modifiers["reaction_damage"] = 2
	ability.upgraded_target_shape = GameEnums.TargetShape.AOE_SQUARE
	ability.upgraded_target_shape_size = 3
	return _upgrade(ability, upgraded, "On FIRE, create STEAM (AOE 3x3) with MAG ATK 2 splash.")


static func _chain_lightning() -> AbilityData:
	var ability := _spell(
		&"mage_chain_lightning", "Chain Lightning", 4,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)],
		GameEnums.TargetingFlags.ENEMY,
	)
	ability.effects[0].modifiers["bounce_count"] = 2
	ability.effects[0].modifiers["bounce_range"] = 2
	ability.effects[0].modifiers["surface_chain"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["strike_all_surface"] = true
	return _upgrade(ability, upgraded, "On WATER/FROZEN, strike all units on that surface.")


static func _arcane_push() -> AbilityData:
	var ability := _spell(
		&"mage_arcane_push", "Arcane Push", 3,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 3)],
		GameEnums.TargetingFlags.ENEMY,
	)
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded.append(_terrain(&"arcane_trail"))
	upgraded[2].modifiers["arcane_trail"] = true
	return _upgrade(ability, upgraded, "Leaves an Arcane Trail dealing MAG ATK 1 to crossing units.")


static func _teleport() -> AbilityData:
	var ability := _spell(
		&"mage_teleport", "Teleport", 4,
		[DataLibrary._effect(GameEnums.EffectType.TELEPORT_CASTER, 0)],
		GameEnums.TargetingFlags.TILE,
	)
	ability.effects[0].modifiers["teleport_visible"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded.append(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 1))
	return _upgrade(ability, upgraded, "Gain SHIELD 1 upon landing.")


static func _meteor() -> AbilityData:
	var ability := _spell(
		&"mage_meteor", "Meteor", 5,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 5)],
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND,
		2,
	)
	ability.effects[0].modifiers["delayed_next_turn"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["delayed_next_turn"] = true
	upgraded[0].modifiers["create_crater"] = true
	return _upgrade(ability, upgraded, "Impact creates CRATER terrain applying BURN.")


static func _black_hole() -> AbilityData:
	var ability := _spell(
		&"mage_black_hole", "Black Hole", 4,
		[DataLibrary._effect(GameEnums.EffectType.PULL, 2)],
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND,
		2,
	)
	ability.effects[0].modifiers["pull_to_center"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["pull_to_center"] = true
	upgraded[0].modifiers["pull_surfaces"] = true
	return _upgrade(ability, upgraded, "Pull hazards and surfaces to the center.")


static func _time_warp() -> AbilityData:
	var ability := _spell(
		&"mage_time_warp", "Time Warp", 3,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE_SELF, 4),
		DataLibrary._effect(GameEnums.EffectType.ADD_STATUS, 1)],
		GameEnums.TargetingFlags.ALLY,
	)
	ability.effects[1].modifiers["utility_only"] = true
	ability.effects[1].modifiers["grant_ap"] = 1
	ability.effects[1].modifiers["cooldown_reduction"] = 1
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[1].modifiers["cooldown_reduction"] = 1
	return _upgrade(ability, upgraded, "Target ally cooldowns -1.")


static func _mana_shield() -> AbilityData:
	var ability := _spell(
		&"mage_mana_shield", "Mana Shield", 0,
		[DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 0)],
		GameEnums.TargetingFlags.SELF,
	)
	ability.effects[0].scaling_stat = GameEnums.StatType.MAGICAL
	ability.effects[0].modifiers["mana_shield"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["mana_shield"] = true
	upgraded[0].modifiers["mana_shield_casting"] = true
	return _upgrade(ability, upgraded, "May cast spells by paying 1 SHIELD per spell.")


static func _disintegrate() -> AbilityData:
	var ability := _spell(
		&"mage_disintegrate", "Disintegrate", 3,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 6)],
		GameEnums.TargetingFlags.ENEMY,
	)
	ability.effects[0].modifiers["destroy_corpse_on_kill"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["destroy_corpse_on_kill"] = true
	upgraded[0].modifiers["kill_grant_ap"] = 1
	return _upgrade(ability, upgraded, "On Kill, gain 1 AP.")


static func _gravity_well() -> AbilityData:
	var ability := _spell(
		&"mage_gravity_well", "Gravity Well", 4,
		[DataLibrary._status_effect(GameEnums.StatusType.ROOT, 1)],
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.AOE_DIAMOND,
		2,
	)
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded.append(DataLibrary._status_effect(GameEnums.StatusType.BLIND, 1))
	return _upgrade(ability, upgraded, "Also applies BLIND.")


static func _elemental_surge() -> AbilityData:
	var ability := _spell(
		&"mage_elemental_surge", "Elemental Surge", 0,
		[DataLibrary._effect(GameEnums.EffectType.ADD_STATUS_SELF, 1)],
		GameEnums.TargetingFlags.SELF,
	)
	ability.effects[0].modifiers["utility_only"] = true
	ability.effects[0].modifiers["elemental_surge"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["elemental_surge"] = true
	upgraded[0].modifiers["elemental_surge_ap"] = 1
	return _upgrade(ability, upgraded, "Also grants +1 AP.")


static func _earth_spike() -> AbilityData:
	var ability := _spell(
		&"mage_earth_spike", "Earth Spike", 4,
		[_spawn_effect(&"obsidian_wall")],
		GameEnums.TargetingFlags.TILE,
	)
	ability.effects[0].modifiers["construct_hp_pct"] = 0.50
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["construct_hp_pct"] = 0.50
	upgraded[0].modifiers["creation_adjacent_damage"] = 1
	return _upgrade(ability, upgraded, "The obstacle deals MAG ATK 1 to adjacent units on creation.")


static func _density_shift() -> AbilityData:
	var ability := _spell(
		&"mage_density_shift", "Density Shift", 3,
		[DataLibrary._status_effect(GameEnums.StatusType.STURDY, 2)],
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
	)
	ability.effects[0].modifiers["density_shift"] = true
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["density_shift"] = true
	upgraded[0].modifiers["apply_weaken_enemy"] = true
	return _upgrade(ability, upgraded, "Enemies also gain WEAKEN.")


static func _arcane_barrage() -> AbilityData:
	var ability := _spell(
		&"mage_arcane_barrage", "Arcane Barrage", 4,
		[DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)],
		GameEnums.TargetingFlags.ENEMY,
	)
	ability.effects[0].modifiers["repeat_hits"] = 3
	var upgraded := DataLibrary._duplicate_effects(ability.effects)
	upgraded[0].modifiers["repeat_hits"] = 3
	upgraded[0].modifiers["ignore_target_magic_pct"] = 0.25
	return _upgrade(ability, upgraded, "Each hit ignores 25% of target MAG.")
