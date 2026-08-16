class_name KnightFactory
extends RefCounted

static func build(basic_axe: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"knight"
	def.display_name = "Knight"
	def.base_constitution = 6
	def.move_points = 3
	def.action_points = GameEnums.MAX_AP
	def.base_strength = 4
	def.base_defense = 5
	def.base_magic = 2
	def.preferred_stat = GameEnums.StatType.DEFENSE
	def.equipped_weapon = basic_axe
	def.promotion_stat_bonuses = {
		&"sentinel": {"defense": 4, "constitution": 4, "movement": 0},
		&"juggernaut": {"strength": 4, "defense": 4, "movement": 0},
		&"cataphract": {"constitution": 2, "defense": 2, "movement": 2},
	}
	
	# Movement Skill (Swap) â€” Master Bible; always granted, not part of roll pool.
	var swap_module := DataLibrary._module(
		GameEnums.EffectType.SWAP, 0, 1, 1, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	var swap_upgraded := DataLibrary._duplicate_modules([swap_module])
	swap_upgraded[0].layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 2)),
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2)),
	]
	var swap := DataLibrary._make_modular_ability(
		&"knight_swap", "Swap", [swap_module], swap_upgraded, 1,
		GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_POSITIONING], "Gain +2 DEF and SHIELD 2 for the rest of the turn.",
		GameEnums.TargetingFlags.ALLY,
	)
	def.abilities.append(swap)
	
	# Passives
	def.innate_passives.append(DataLibrary._make_passive(&"collision_retaliator", "Bastion Front", "Take 0 collision damage. Physical damage from the frontal arc within 3 tiles gains +2 DEF mitigation.", "[+] Frontal mitigation increases to +4 DEF and collision grants SHIELD 2.", {
		"collision_retaliator": true,
		"bastion_front": true,
		"bastion_front_def": 2,
		"upgraded_bastion_front_def": 4,
	}))
	def.passives.append(DataLibrary._make_passive(&"kinetic_dissipation", "Kinetic Dissipation", "When pushed or knocked into an obstacle or unit, gain SHIELD equal to DEF and trigger a 1-tile shockwave dealing physical damage equal to DEF.", "[+] The enemy is also PUSHED 1 tile.", {
		"collision_grant_shield_def": true,
		"collision_shockwave_damage_def": true,
		"collision_shockwave_radius": 1,
	}))
	def.passives.append(DataLibrary._make_passive(&"thorny_carapace", "Thorny Carapace", "Melee hit reflects 50% damage (rounded down) & PUSH 1.", "[+] Reflects 100% damage instead."))
	
	def.passives.append(DataLibrary._make_passive(&"concussive_shatter", "Concussive Shatter", "Enemy collision suffers extra damage equal to 50% of your DEF, and target loses DEF equal to your WPN.", "[+] Target also suffers VULNERABLE.", {
		"collision_add_def_pct": 0.5,
		"collision_apply_target_status": GameEnums.StatusType.STAT_DEBUFF_DEF,
		"collision_def_loss_wpn": true,
		"collision_apply_target_status_upgraded": GameEnums.StatusType.VULNERABLE
	}))
	
	def.passives.append(DataLibrary._make_passive(&"kinetic_momentum", "Kinetic Momentum", "Causing an enemy to suffer collision damage grants SHIELD equal to your STR + DEF for 1 turn.", "[+] Also refunds 1 MOV point on your first collision each turn.", {
		"collision_grant_shield_str_def": true,
		"collision_refund_mov_if_upgraded": true
	}))
	
	def.passives.append(DataLibrary._make_passive(&"stand_ground", "Stand Ground", "Immune to PUSH/PULL. Enemy attempts trigger COUNTER ATTACK 1.", "[+] COUNTER ATTACK 2 instead."))
	
	def.passives.append(DataLibrary._make_passive(&"indestructible_bastion", "Indestructible Bastion", "Lethal damage -> 1 HP + SHIELD = DEF (Once).", "[+] Gain +2 STR for combat."))
	def.passives.append(DataLibrary._make_passive(&"shield_mastery", "Phalanx Deflection", "When mitigating frontal damage with DEF or SHIELD, store 50% of mitigated damage as Kinetic Energy, capped at 2 * DEF.", "[+] Cap increases to 3 * DEF.", {
		"phalanx_deflection": true,
		"kinetic_energy_mitigation_pct": 0.5,
		"kinetic_energy_cap_def_multiplier": 2,
		"upgraded_kinetic_energy_cap_def_multiplier": 3,
	}))
	def.passives.append(DataLibrary._make_passive(&"kinetic_armor", "Kinetic Armor", "Incoming damage reduced by Floor(DEF / 2) if SHIELD is active.", "[+] Floor((DEF + 2) / 2)."))
	def.passives.append(DataLibrary._make_passive(&"kinetic_converter", "Kinetic Converter", "When hit, gain STR +1 and MOVE +1 for next turn.", "[+] Gain STR +2."))
	def.passives.append(DataLibrary._make_passive(&"kinetic_redirection", "Kinetic Redirection", "Mitigating damage adds +1 STR to next attack (Stacks to +3).", "[+] Next attack gains PIERCE."))
	
	def.passives.append(DataLibrary._make_passive(&"bulwark", "Bulwark", "Gain +1 DEF per adjacent unit.", "[+] Also +1 STR per adjacent enemy."))
	def.passives.append(DataLibrary._make_passive(&"living_barricade", "Living Barricade", "Allies behind are immune to ranged attacks.", "[+] Allies behind gain +1 DEF."))
	def.passives.append(DataLibrary._make_passive(&"shield_wall", "Shield Wall", "Adjacent allies gain +1 DEF and PULL immunity.", "[+] Range of aura = 2 tiles."))
	def.passives.append(DataLibrary._make_passive(&"rallying_presence", "Rallying Presence", "Allies starting turn adjacent gain +1 MOV.", "[+] +2 MOV."))
	def.passives.append(DataLibrary._make_passive(&"intercept_tactics", "Intercept Tactics", "Using a redirect skill grants +2 DEF.", "[+] +3 DEF."))
	
	# Actives
	var shield_bash_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	shield_bash_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 2))]
	var shield_bash_upgraded := DataLibrary._duplicate_modules([shield_bash_module])
	shield_bash_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, 1))
	)
	var shield_bash := DataLibrary._make_modular_ability(
		&"knight_shield_bash", "Shield Bash", [shield_bash_module],
		shield_bash_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Apply STAGGER if collides with wall/enemy.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(shield_bash)

	var phalanx_stance_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 0, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	phalanx_stance_module.status_type = GameEnums.StatusType.STURDY
	phalanx_stance_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1, 5)),
	]
	var phalanx_stance_upgraded := DataLibrary._duplicate_modules([phalanx_stance_module])
	phalanx_stance_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.RETALIATION_INFINITE_RANGE, 1))
	)
	var phalanx_stance := DataLibrary._make_modular_ability(
		&"knight_phalanx_stance", "Phalanx Stance", [phalanx_stance_module],
		phalanx_stance_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Infinite RANGE for Retaliation Protocol.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(phalanx_stance)

	var taunting_strike_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	taunting_strike_module.layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PULL, 1)),
		DataLibrary._layer(DataLibrary._status_effect(GameEnums.StatusType.TAUNT, 1)),
	]
	var taunting_strike_upgraded := DataLibrary._duplicate_modules([taunting_strike_module])
	taunting_strike_upgraded[0].max_range = 3
	taunting_strike_upgraded[0].target_shape = GameEnums.TargetShape.AOE_SQUARE
	taunting_strike_upgraded[0].target_shape_size = 1
	taunting_strike_upgraded[0].layers[0].effect.amount = 2
	var taunting_strike := DataLibrary._make_modular_ability(
		&"knight_taunting_strike", "Taunting Strike", [taunting_strike_module],
		taunting_strike_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "RANGE 3 | AOE 3x3 | PULL 2 all.",
		GameEnums.TargetingFlags.TILE,
	)
	def.abilities.append(taunting_strike)

	var seismic_stomp_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 1, GameEnums.StatType.PHYSICAL,
	)
	seismic_stomp_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PURGE, 0))]
	var seismic_stomp_upgraded := DataLibrary._duplicate_modules([seismic_stomp_module])
	seismic_stomp_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.CHANGE_TERRAIN, 0))
	)
	var seismic_stomp := DataLibrary._make_modular_ability(
		&"knight_seismic_stomp", "Seismic Stomp", [seismic_stomp_module],
		seismic_stomp_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Create CRACKED terrain.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(seismic_stomp)

	var fortify_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 0, 1, 3, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.DEFENSE,
	)
	fortify_module.status_type = GameEnums.StatusType.STAT_BUFF_DEF
	var fortify_upgraded := DataLibrary._duplicate_modules([fortify_module])
	var thorns := DataLibrary._status_effect(GameEnums.StatusType.THORNS, 1, 50)
	fortify_upgraded[0].layers = [DataLibrary._layer(thorns)]
	var fortify := DataLibrary._make_modular_ability(
		&"knight_fortify", "Fortify", [fortify_module], fortify_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"Ally gains THORNS 50%.", GameEnums.TargetingFlags.ALLY,
	)
	def.abilities.append(fortify)

	var bowling_flags: int = GameEnums.TargetingFlags.DASH_LINE
	var bowling_module := DataLibrary._module(
		GameEnums.EffectType.DASH, 3, 1, 3, bowling_flags,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
		GameEnums.MotionMode.NONE,
	)
	bowling_module.keywords = [
		DataLibrary._keyword(GameEnums.AbilityKeywordId.BULLDOZE, 1, 0, true),
	]
	var bowling_upgraded := DataLibrary._duplicate_modules([bowling_module])
	bowling_upgraded[0].layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH_CHAIN_COLLISION, 1)),
	]
	var bowling_charge := DataLibrary._make_modular_ability(
		&"knight_bowling_charge", "Bowling Charge", [bowling_module],
		bowling_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "", bowling_flags,
	)
	def.abilities.append(bowling_charge)

	var iron_grip_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 1, 1, 1, GameEnums.TargetingFlags.ENEMY,
	)
	iron_grip_module.status_type = GameEnums.StatusType.ROOT
	iron_grip_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect(GameEnums.StatusType.IRON_GRIP_DEBUFF, 1)),
	]
	var iron_grip_upgraded := DataLibrary._duplicate_modules([iron_grip_module])
	iron_grip_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.REFUND_AP_ON_CC, 0))
	)
	var iron_grip := DataLibrary._make_modular_ability(
		&"knight_iron_grip", "Iron Grip", [iron_grip_module], iron_grip_upgraded,
		1, GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"Refund 1 AP if already ROOT/STAGGER.", GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(iron_grip)

	var redirect_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 0, 1, 2, GameEnums.TargetingFlags.ALLY,
	)
	redirect_module.status_type = GameEnums.StatusType.INTERCEPT
	var redirect_upgraded := DataLibrary._duplicate_modules([redirect_module])
	redirect_upgraded[0].amount = 1
	var redirect_strike := DataLibrary._make_modular_ability(
		&"knight_redirect_strike", "Redirect Strike", [redirect_module],
		redirect_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Gain DEF +2 per redirected hit.",
		GameEnums.TargetingFlags.ALLY,
	)
	redirect_strike.range_tiles = 2
	def.abilities.append(redirect_strike)
	
	var indomitable_module := DataLibrary._module(
		GameEnums.EffectType.ARMOR_UP, 0, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.MISSING_HP,
	)
	indomitable_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.INDOMITABLE_WILL, 2)),
	]
	var indomitable_upgraded := DataLibrary._duplicate_modules([indomitable_module])
	indomitable_upgraded[0].layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED, 2)),
	]
	var indomitable_will := DataLibrary._make_modular_ability(
		&"knight_indomitable_will", "Indomitable Will", [indomitable_module],
		indomitable_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "When expires, gain +2 STR.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(indomitable_will)

	var retaliation_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 0, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	retaliation_module.status_type = GameEnums.StatusType.RETALIATION_PROTOCOL
	var retaliation_upgraded := DataLibrary._duplicate_modules([retaliation_module])
	retaliation_upgraded[0].amount = 1
	var retaliation_protocol := DataLibrary._make_modular_ability(
		&"knight_retaliation_protocol", "Retaliation Protocol", [retaliation_module],
		retaliation_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Counter-attacks apply PUSH 1.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(retaliation_protocol)

	var shield_slam_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	shield_slam_module.bonus_if_adjacent_at_cast = 2
	shield_slam_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 2))]
	var shield_slam_upgraded := DataLibrary._duplicate_modules([shield_slam_module])
	shield_slam_upgraded[0].def_debuff_before_damage = 1
	var shield_slam := DataLibrary._make_modular_ability(
		&"knight_shield_slam", "Shield Slam", [shield_slam_module],
		shield_slam_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Target DEF -1 before damage.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(shield_slam)

	var 	defensive_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS, 2, 0, 0,
		GameEnums.TargetingFlags.ALLY | GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_DIAMOND, 3,
	)
	defensive_module.status_type = GameEnums.StatusType.STAT_BUFF_DEF
	DataLibrary._add_extra(defensive_module, "exclude_caster", true)
	defensive_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect(GameEnums.StatusType.STURDY, 1)),
	]
	defensive_module.layers[0].effect.modifiers["exclude_caster"] = true
	var defensive_upgraded := DataLibrary._duplicate_modules([defensive_module])
	defensive_upgraded[0].layers.append(DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2)))
	defensive_upgraded[0].layers[1].effect.modifiers["exclude_caster"] = true
	var defensive_formation := DataLibrary._make_modular_ability(
		&"knight_defensive_formation", "Defensive Formation", [defensive_module],
		defensive_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Allies gain SHIELD 2.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(defensive_formation)

	var chain_hook_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 1, 3, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	chain_hook_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PULL, 2))]
	var chain_hook_upgraded := DataLibrary._duplicate_modules([chain_hook_module])
	chain_hook_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, 1))
	)
	var chain_hook := DataLibrary._make_modular_ability(
		&"knight_chain_hook", "Chain Hook", [chain_hook_module],
		chain_hook_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Target suffers VULNERABLE if pulled adjacent.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(chain_hook)
	
	var trample_module := DataLibrary._module(
		GameEnums.EffectType.MOVE, 2, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.NONE,
	)
	trample_module.keywords = [
		DataLibrary._keyword(GameEnums.AbilityKeywordId.TRAMPLE, 2, 0, true),
	]
	trample_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1))]
	var trample_upgraded := DataLibrary._duplicate_modules([trample_module])
	trample_upgraded[0].layers.append(
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 1), GameEnums.LayerCondition.PER_TILE_MOVED)
	)
	var trampling_advance := DataLibrary._make_modular_ability(
		&"knight_trampling_advance", "Trampling Advance", [trample_module],
		trample_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "", GameEnums.TargetingFlags.TILE,
	)
	def.abilities.append(trampling_advance)

	DataLibrary.finalize_unit_abilities(def)
	return def
