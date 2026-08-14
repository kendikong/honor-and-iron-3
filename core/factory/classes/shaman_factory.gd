class_name ShamanFactory
extends RefCounted

## Complete Shaman authoring from class_abilities.txt §10.
## All rows are data-first; shared systems consume the authored modules and
## passive modifier contracts.


static func build(basic_staff: WeaponData) -> UnitData:
	var definition := UnitData.new()
	definition.id = &"shaman"
	definition.display_name = "Shaman"
	definition.base_constitution = 3
	definition.move_points = 4
	definition.action_points = 1
	definition.base_strength = 1
	definition.base_defense = 1
	definition.base_magic = 4
	definition.preferred_stat = GameEnums.StatType.MAGICAL
	definition.equipped_weapon = basic_staff
	definition.promotion_stat_bonuses = {
		&"spirit_caller": {"constitution": 4, "defense": 4, "movement": 0},
		&"bloodweaver": {"magic": 4, "constitution": 4, "movement": 0},
		&"soulwalker": {"magic": 6, "movement": 2},
	}

	definition.innate_passives.append(_passive(
		&"hexing_presence",
		"Hexing Presence",
		"Enemies within RANGE 2 suffer -2 STR, -2 MAG, -2 DEF and cannot gain SHIELD.",
		"Range becomes 3 and affected enemies also lose -1 MOV.",
		{"hexing_presence": true, "hexing_presence_range": 2,
		"hexing_presence_str": -2, "hexing_presence_mag": -2,
		"hexing_presence_def": -2, "hexing_presence_no_shield": true,
		"upgraded_hexing_presence_range": 3, "upgraded_hexing_presence_mov": -1},
	))

	var usher_pick := DataLibrary._module(
		GameEnums.EffectType.MOVE, 1, 1, 2, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.ALLY_STEP,
	)
	usher_pick.legacy_modifiers["relocate_subject_only"] = true
	var usher_step := DataLibrary._module(
		GameEnums.EffectType.MOVE, 1, 1, 1, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.ALLY_STEP,
	)
	usher_step.aim_binding = GameEnums.AimBinding.NEW_AIM
	usher_step.legacy_modifiers["relocate_target"] = true
	usher_step.legacy_modifiers["move_active_totem"] = false
	var usher_upgraded := DataLibrary._duplicate_modules([usher_pick, usher_step])
	usher_upgraded[0].max_range = 4
	usher_upgraded[1].max_range = 2
	usher_upgraded[1].legacy_modifiers["relocate_target"] = true
	usher_upgraded[1].legacy_modifiers["move_active_totem"] = true
	definition.abilities.append(DataLibrary._make_modular_ability(
		&"shaman_usher", "Usher", [usher_pick, usher_step], usher_upgraded, 2,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Select an ally within RANGE 4; active Totems may also move 2 tiles.",
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.TILE,
	))

	_add_passives(definition)
	_add_abilities(definition)
	DataLibrary.finalize_unit_abilities(definition)
	return definition


static func _add_passives(definition: UnitData) -> void:
	var p := definition.passives
	p.append(_passive(&"echoing_spirits", "Echoing Spirits",
		"Totems pulse twice per turn; hazard/debuff damage empowers the next attack with +1 MAG.",
		"Totems gain +2 HP.",
		{"promotion": &"spirit_caller", "echoing_spirits": true,
		"totem_pulse_count": 2, "hazard_damage_next_magic": 1,
		"upgraded_totem_hp": 2}))
	p.append(_passive(&"spiritual_offering", "Spiritual Offering",
		"Summoning a Totem or using HP for a skill grants SHIELD 1.",
		"Grant SHIELD 2 instead.",
		{"promotion": &"spirit_caller", "spiritual_offering": true,
		"offering_shield": 1, "upgraded_offering_shield": 2}))
	p.append(_passive(&"spiritual_guardian", "Spiritual Guardian",
		"Totems, Linked Allies, and Ghosts project +1 DEF to adjacent allies.",
		"Aura increases to +2 DEF.",
		{"promotion": &"spirit_caller", "spiritual_guardian": true,
		"guardian_aura_def": 1, "upgraded_guardian_aura_def": 2}))
	p.append(_passive(&"miasma_resonance", "Miasma Resonance",
		"Enemies in Hexing Presence take +1 damage per BURN, BLEED, or POISON tick and lose -1 MOV.",
		"DoT bonus damage increases to +2.",
		{"promotion": &"spirit_caller", "miasma_resonance": true,
		"miasma_dot_bonus": 1, "miasma_mov_penalty": 1,
		"upgraded_miasma_dot_bonus": 2}))
	p.append(_passive(&"voodoo_conduit", "Voodoo Conduit",
		"Totem, Link, and Debuff maximum range and AOE increase by 1 tile.",
		"Increase them by 2 tiles instead.",
		{"promotion": &"spirit_caller", "voodoo_conduit": true,
		"conduit_range_bonus": 1, "upgraded_conduit_range_bonus": 2}))

	p.append(_passive(&"voodoo_doll", "Voodoo Doll",
		"When hit, the closest debuffed enemy suffers WPN unmitigated damage.",
		"Damage becomes WPN * 2.",
		{"promotion": &"bloodweaver", "voodoo_doll": true,
		"voodoo_doll_wpn_multiplier": 1, "upgraded_voodoo_doll_wpn_multiplier": 2}))
	p.append(_passive(&"spirit_link", "Spirit Link",
		"Linked enemies take WPN unmitigated damage when hit.",
		"Damage becomes WPN * 2.",
		{"promotion": &"bloodweaver", "spirit_link": true,
		"spirit_link_wpn_multiplier": 1, "upgraded_spirit_link_wpn_multiplier": 2}))
	p.append(_passive(&"pain_sharing", "Pain Sharing",
		"Linked enemies take +1 damage from all sources.",
		"Bonus damage becomes +2.",
		{"promotion": &"bloodweaver", "pain_sharing": true,
		"linked_damage_bonus": 1, "upgraded_linked_damage_bonus": 2}))
	p.append(_passive(&"sympathetic_magic", "Sympathetic Magic",
		"Linked ally healing also HEALs 1 and grants +1 MAG.",
		"Grant +2 MAG instead.",
		{"promotion": &"bloodweaver", "sympathetic_magic": true,
		"linked_ally_heal": 1, "linked_ally_magic": 1,
		"upgraded_linked_ally_magic": 2}))
	p.append(_passive(&"chain_reaction", "Chain Reaction",
		"Applying PUSH to a linked enemy applies PUSH 1 to all linked enemies.",
		"Apply PUSH 2 instead.",
		{"promotion": &"bloodweaver", "chain_reaction": true,
		"linked_push": 1, "upgraded_linked_push": 2}))

	p.append(_passive(&"soul_collector", "Soul Collector",
		"On Kill, drop a Soul Orb: +1 MAG and +1 Max HP, capped at 3 per combat.",
		"Cap increases to 5 per combat.",
		{"promotion": &"soulwalker", "soul_collector": true,
		"soul_orb_magic": 1, "soul_orb_max_hp": 1, "soul_orb_cap": 3,
		"upgraded_soul_orb_cap": 5}))
	p.append(_passive(&"hexing_touch", "Hexing Touch",
		"Melee attackers suffer permanent STR -1 and DEF -1.",
		"Attackers also lose -1 MOV.",
		{"promotion": &"soulwalker", "hexing_touch": true,
		"hexing_touch_str": -1, "hexing_touch_def": -1,
		"upgraded_hexing_touch_mov": -1}))
	p.append(_passive(&"ritual_sacrifice", "Ritual Sacrifice",
		"Once per turn, cast a skill using 3 HP instead of AP.",
		"Use 1 HP instead.",
		{"promotion": &"soulwalker", "ritual_sacrifice": true,
		"ritual_hp_cost": 3, "upgraded_ritual_hp_cost": 1}))
	p.append(_passive(&"soul_burn", "Soul Burn",
		"Debuffed enemies take +1 damage and lose -1 MOV.",
		"Bonus damage becomes +2.",
		{"promotion": &"soulwalker", "soul_burn": true,
		"soul_burn_damage": 1, "soul_burn_mov": 1,
		"upgraded_soul_burn_damage": 2}))
	p.append(_passive(&"soul_weaver", "Soul Weaver",
		"Healing a unit removes its oldest debuff and applies it to the nearest enemy.",
		"Apply the transferred debuff to the 2 nearest enemies.",
		{"promotion": &"soulwalker", "soul_weaver": true,
		"soul_weaver_transfer_count": 1, "upgraded_soul_weaver_transfer_count": 2}))


static func _add_abilities(definition: UnitData) -> void:
	definition.abilities.append(_curse_of_weakness())
	definition.abilities.append(_healing_totem())
	definition.abilities.append(_flame_totem())
	definition.abilities.append(_bloodlust())
	definition.abilities.append(_hex())
	definition.abilities.append(_voodoo_link())
	definition.abilities.append(_terrify())
	definition.abilities.append(_miasma())
	definition.abilities.append(_bone_spear())
	definition.abilities.append(_ancestral_spirit())
	definition.abilities.append(_totem_guard())
	definition.abilities.append(_sympathetic_bond())
	definition.abilities.append(_earthbind_totem())
	definition.abilities.append(_soul_siphon())
	definition.abilities.append(_pain_spike())


static func _passive(
	id: StringName,
	name: String,
	description: String,
	upgrade_description: String,
	modifiers: Dictionary,
) -> PassiveData:
	return DataLibrary._make_passive(id, name, description, upgrade_description, modifiers)


static func _ability(
	id: StringName,
	name: String,
	modules: Array[AbilityModule],
	upgraded_modules: Array[AbilityModule],
	targeting_flags: int,
	description: String,
) -> AbilityData:
	return DataLibrary._make_modular_ability(
		id, name, modules, upgraded_modules, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		[AbilityModuleBridge.TAG_SPELL], description, targeting_flags,
	)


static func _layer(effect: EffectData, condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.effect = effect
	layer.condition = condition
	return layer


static func _status(
	status: GameEnums.StatusType,
	duration: int,
	value: int = 0,
) -> EffectData:
	return DataLibrary._status_effect(status, duration, value)


static func _curse_of_weakness() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, -2, 1, 4, GameEnums.TargetingFlags.ENEMY)
	base.status_type = GameEnums.StatusType.STAT_BUFF_STR
	base.status_duration = 3
	base.legacy_modifiers = {"curse_of_weakness": true, "stat_str": -2, "stat_def": -2}
	base.layers.append(_layer(_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 3, 2)))
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["push_mitigation_zero"] = true
	return _ability(&"shaman_curse_of_weakness", "Curse of Weakness", [base], up,
		GameEnums.TargetingFlags.ENEMY, "Target STR -2 and DEF -2 for 3 turns; [+] Push Mitigation = 0.")


static func _healing_totem() -> AbilityData:
	var base := _spawn(&"voodoo_totem", 2, {"totem_kind": &"healing", "pulse_aoe": 2, "pulse_heal": 1})
	var up := _spawn(&"voodoo_totem", 2, {"totem_kind": &"healing", "pulse_aoe": 2, "pulse_heal": 1, "pulse_cleanse": true})
	return _ability(&"shaman_healing_totem", "Healing Totem", [base], [up],
		GameEnums.TargetingFlags.TILE, "Summon a Totem with AOE 2 HEAL 1 pulses; [+] pulses CLEANSE.")


static func _flame_totem() -> AbilityData:
	var base := _spawn(&"voodoo_totem", 2, {"totem_kind": &"flame", "pulse_aoe": 2, "pulse_mag_atk": 1})
	var up := _spawn(&"voodoo_totem", 2, {"totem_kind": &"flame", "pulse_aoe": 2, "pulse_mag_atk": 1, "pulse_fire": true})
	return _ability(&"shaman_flame_totem", "Flame Totem", [base], [up],
		GameEnums.TargetingFlags.TILE, "Summon a Totem with AOE 2 MAG ATK 1 pulses; [+] pulses create FIRE.")


static func _bloodlust() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 2, 1, 3, GameEnums.TargetingFlags.ALLY)
	base.status_type = GameEnums.StatusType.STAT_BUFF_STR
	base.status_duration = 1
	base.legacy_modifiers = {"bloodlust": true, "bloodlust_def": -2, "bloodlust_mov": 1, "bloodlust_hp": 2}
	base.layers.append(_layer(_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 2)))
	base.layers.append(_layer(_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, 1)))
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["bloodlust_bleed_on_attack"] = true
	return _ability(&"shaman_bloodlust", "Bloodlust", [base], up, GameEnums.TargetingFlags.ALLY,
		"Ally gains STR +2, DEF -2, MOV +1 and spends 2 HP each turn; [+] attacks apply BLEED.")


static func _hex() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ENEMY)
	base.status_type = GameEnums.StatusType.WEAKEN
	base.status_duration = 1
	base.legacy_modifiers = {"hex": true, "wither": true, "requires_missing_hp": true, "boss_damage_reduction": 0.25}
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["hex_vulnerable"] = true
	return _ability(&"shaman_hex", "Hex", [base], up, GameEnums.TargetingFlags.ENEMY,
		"Apply WITHER for 1 turn to a target below Max HP; Boss damage reduction is 25%; [+] VULNERABLE.")


static func _voodoo_link() -> AbilityData:
	var first := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ENEMY)
	first.legacy_modifiers = {"voodoo_link": true, "link_two_enemies": true, "shared_damage_wpn": 1}
	var second := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 0, 1, 3, GameEnums.TargetingFlags.ENEMY)
	second.aim_binding = GameEnums.AimBinding.NEW_AIM
	second.legacy_modifiers = {"link_partner_pick": true}
	var up := DataLibrary._duplicate_modules([first, second])
	up[0].legacy_modifiers["shared_push"] = true
	return _ability(&"shaman_voodoo_link", "Voodoo Link", [first, second], up, GameEnums.TargetingFlags.ENEMY,
		"Link 2 enemies; shared damage equals WPN; [+] shared PUSH effects.")


static func _terrify() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 1, 1, 2, GameEnums.TargetingFlags.ENEMY)
	base.status_type = GameEnums.StatusType.FEAR
	base.status_duration = 1
	base.legacy_modifiers = {"terrify": true, "requires_debuff": true}
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["boss_fallback_purge_shield"] = true
	up[0].legacy_modifiers["boss_fallback_vulnerable"] = true
	return _ability(&"shaman_terrify", "Terrify", [base], up, GameEnums.TargetingFlags.ENEMY,
		"Apply FEAR to a debuffed target; Boss fallback strips SHIELD and applies VULNERABLE.")


static func _miasma() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL)
	base.layers.append(_layer(_status(GameEnums.StatusType.POISON, 1)))
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["poison_spread_on_push_collision"] = true
	return _ability(&"shaman_miasma", "Miasma", [base], up, GameEnums.TargetingFlags.ENEMY,
		"MAG ATK 1 and POISON; [+] POISON spreads on PUSH collision.")


static func _bone_spear() -> AbilityData:
	var hit := DataLibrary._module(GameEnums.EffectType.DAMAGE, 2, 1, 4, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.LINE, 4, GameEnums.StatType.MAGICAL)
	hit.legacy_modifiers["bone_spear"] = true
	var spawn := DataLibrary._module(GameEnums.EffectType.SPAWN, 0, 1, 4, GameEnums.TargetingFlags.TILE)
	spawn.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	spawn.aim_module_index = 0
	spawn.spawn_unit_id = &"bone_barricade"
	spawn.legacy_modifiers = {"construct_hp_pct": 0.50, "spawn_furthest_empty_on_line": true}
	var up := DataLibrary._duplicate_modules([hit, spawn])
	up[1].legacy_modifiers["lightning_rod"] = true
	return _ability(&"shaman_bone_spear", "Bone Spear", [hit, spawn], up,
		GameEnums.TargetingFlags.TILE, "SKEWER 4 ATK 2; create a BONE BARRICADE on the furthest empty tile.")


static func _ancestral_spirit() -> AbilityData:
	var base := _spawn(&"ghost_ally", 1, {
		"ally_corpse": true, "ghost_duration": 1, "echo_next_cast": true, "ghost_hp_pct": 0.25,
	})
	base.targeting_flags = GameEnums.TargetingFlags.ALLY
	var up := _spawn(&"ghost_ally", 1, {
		"ally_corpse": true, "ghost_duration": 1, "echo_next_cast": true,
		"echo_upgraded": true, "ghost_hp_pct": 0.25,
	})
	up.targeting_flags = GameEnums.TargetingFlags.ALLY
	return _ability(&"shaman_ancestral_spirit", "Ancestral Spirit", [base], [up],
		GameEnums.TargetingFlags.ALLY, "Target an ally corpse in RANGE 1; summon a Ghost Ally at 25% caster HP for 1 turn.")


static func _totem_guard() -> AbilityData:
	var base := _spawn(&"voodoo_totem", 2, {"totem_kind": &"guard", "ranged_reduction": 2})
	var up := _spawn(&"voodoo_totem", 2, {"totem_kind": &"guard", "ranged_reduction": 2, "melee_def": 1})
	return _ability(&"shaman_totem_guard", "Totem Guard", [base], [up], GameEnums.TargetingFlags.TILE,
		"Summon a Totem; adjacent allies reduce ranged damage by 2; [+] gain +1 DEF vs melee.")


static func _sympathetic_bond() -> AbilityData:
	var ally := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 1, 1, 3, GameEnums.TargetingFlags.ALLY)
	ally.legacy_modifiers = {"sympathetic_bond": true, "link_ally_enemy": true, "ally_heal_enemy_wpn": true}
	var enemy := DataLibrary._module(GameEnums.EffectType.ADD_STATUS, 0, 1, 3, GameEnums.TargetingFlags.ENEMY)
	enemy.aim_binding = GameEnums.AimBinding.NEW_AIM
	enemy.legacy_modifiers = {"link_partner_pick": true}
	var up := DataLibrary._duplicate_modules([ally, enemy])
	up[0].legacy_modifiers["enemy_damage_ally_heal"] = 1
	return _ability(&"shaman_sympathetic_bond", "Sympathetic Bond", [ally, enemy], up,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.ENEMY,
		"Link an ally and enemy; ally HEAL causes enemy WPN damage; [+] enemy damage HEALs ally 1.")


static func _earthbind_totem() -> AbilityData:
	var base := _spawn(&"voodoo_totem", 2, {"totem_kind": &"earthbind", "pulse_aoe": 2, "pulse_status": GameEnums.StatusType.ROOT})
	var up := _spawn(&"voodoo_totem", 2, {"totem_kind": &"earthbind", "pulse_aoe": 2, "pulse_status": GameEnums.StatusType.ROOT, "pulse_weaken": true})
	return _ability(&"shaman_earthbind_totem", "Earthbind Totem", [base], [up], GameEnums.TargetingFlags.TILE,
		"Summon a Totem with AOE 2 ROOT pulses; [+] pulses also apply WEAKEN.")


static func _soul_siphon() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MAGICAL)
	base.legacy_modifiers = {"bonus_damage_per_debuff": 1}
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["heal_per_debuff"] = 1
	return _ability(&"shaman_soul_siphon", "Soul Siphon", [base], up, GameEnums.TargetingFlags.ENEMY,
		"MAG ATK 1 plus +1 damage per target debuff; [+] HEAL 1 per debuff.")


static func _pain_spike() -> AbilityData:
	var base := DataLibrary._module(GameEnums.EffectType.DAMAGE, 2, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL)
	base.legacy_modifiers = {"pain_spike": true, "linked_enemy_damage": 1}
	var up := DataLibrary._duplicate_modules([base])
	up[0].legacy_modifiers["linked_enemy_blind"] = true
	return _ability(&"shaman_pain_spike", "Pain Spike", [base], up, GameEnums.TargetingFlags.ENEMY,
		"ATK 2; if the target is Linked, deal ATK 1 to linked enemies; [+] linked enemies suffer BLIND.")


static func _spawn(spawn_id: StringName, range_tiles: int, modifiers: Dictionary) -> AbilityModule:
	var module := DataLibrary._module(
		GameEnums.EffectType.SPAWN, 0, 1, range_tiles, GameEnums.TargetingFlags.TILE,
	)
	module.spawn_unit_id = spawn_id
	module.legacy_modifiers = modifiers
	return module
