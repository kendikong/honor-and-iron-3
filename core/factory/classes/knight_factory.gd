class_name KnightFactory
extends RefCounted

static func build(basic_axe: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"knight"
	def.display_name = "Knight"
	def.base_constitution = 6
	def.move_points = 3
	def.action_points = 1
	def.base_strength = 4
	def.base_defense = 5
	def.base_magic = 2
	def.preferred_stat = GameEnums.StatType.DEFENSE
	def.equipped_weapon = basic_axe
	
	# Movement Skill (Swap) â€” Master Bible; always granted, not part of roll pool.
	var swap := DataLibrary._make_movement_ability(&"knight_swap", "Swap", 1, [
		DataLibrary._module(GameEnums.EffectType.SWAP, 0)
	], 1)
	swap.upgrade_description = "Gain +2 DEF and SHIELD 2 for the rest of the turn."
	var swap_upgraded = swap.modules.duplicate()
	var def_buff = DataLibrary._status_module_self(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	def_buff.amount = 2
	swap_upgraded.append(def_buff)
	swap_upgraded.append(DataLibrary._module(GameEnums.EffectType.ARMOR_UP, 2))
	swap.upgraded_modules = swap_upgraded
	def.abilities.append(swap)
	
	# Passives
	def.passives.append(DataLibrary._make_passive(&"collision_retaliator", "Collision Retaliator", "Enemy collision suffers ATK 2. Knight takes 0 collision damage.", "[+] PUSH 1."))
	def.passives.append(DataLibrary._make_passive(&"thorny_carapace", "Thorny Carapace", "Melee hit reflects 50% damage (rounded down) & PUSH 1.", "[+] Reflects 100% damage instead."))
	
	def.passives.append(DataLibrary._make_passive(&"concussive_shatter", "Concussive Shatter", "Enemy collision suffers extra damage equal to 50% of your DEF, and target loses -1 DEF.", "[+] Target also suffers VULNERABLE.", {
		"collision_add_def_pct": 0.5,
		"collision_apply_target_status": GameEnums.StatusType.STAT_DEBUFF_DEF,
		"collision_apply_target_status_upgraded": GameEnums.StatusType.VULNERABLE
	}))
	
	def.passives.append(DataLibrary._make_passive(&"kinetic_momentum", "Kinetic Momentum", "Causing an enemy to suffer collision damage grants SHIELD equal to your STR + DEF for 1 turn.", "[+] Also refunds 1 MOV point on your first collision each turn.", {
		"collision_grant_shield_str_def": true,
		"collision_refund_mov_if_upgraded": true
	}))
	
	def.passives.append(DataLibrary._make_passive(&"stand_ground", "Stand Ground", "Immune to PUSH/PULL. Enemy attempts trigger COUNTER ATTACK 1.", "[+] COUNTER ATTACK 2 instead."))
	
	def.passives.append(DataLibrary._make_passive(&"indestructible_bastion", "Indestructible Bastion", "Lethal damage -> 1 HP + SHIELD = DEF (Once).", "[+] Gain +2 STR for combat."))
	def.passives.append(DataLibrary._make_passive(&"shield_mastery", "Shield Mastery", "Damage from front -> gain SHIELD 2.", "[+] Gain SHIELD 3."))
	def.passives.append(DataLibrary._make_passive(&"kinetic_armor", "Kinetic Armor", "Incoming damage reduced by flat 1 if SHIELD active.", "[+] Reduced by 2."))
	def.passives.append(DataLibrary._make_passive(&"kinetic_converter", "Kinetic Converter", "When hit, gain STR +1 and MOVE +1 for next turn.", "[+] Gain STR +2."))
	def.passives.append(DataLibrary._make_passive(&"kinetic_redirection", "Kinetic Redirection", "Mitigating damage adds +1 STR to next attack (Stacks to +3).", "[+] Next attack gains PIERCE."))
	
	def.passives.append(DataLibrary._make_passive(&"bulwark", "Bulwark", "Gain +1 DEF per adjacent unit.", "[+] Also +1 STR per adjacent enemy."))
	def.passives.append(DataLibrary._make_passive(&"living_barricade", "Living Barricade", "Allies behind are immune to ranged attacks.", "[+] Allies behind gain +1 DEF."))
	def.passives.append(DataLibrary._make_passive(&"shield_wall", "Shield Wall", "Adjacent allies gain +1 DEF and PULL immunity.", "[+] Range of aura = 2 tiles."))
	def.passives.append(DataLibrary._make_passive(&"rallying_presence", "Rallying Presence", "Allies starting turn adjacent gain +1 MOV.", "[+] +2 MOV."))
	def.passives.append(DataLibrary._make_passive(&"intercept_tactics", "Intercept Tactics", "Using a redirect skill grants +2 DEF.", "[+] +3 DEF."))
	
	# Actives
	var shield_bash = DataLibrary._make_ability(&"knight_shield_bash", "Shield Bash", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._module(GameEnums.EffectType.PUSH, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	shield_bash.upgrade_description = "Apply STAGGER if collides with wall/enemy."
	shield_bash.upgraded_modules = DataLibrary._duplicate_modules(shield_bash.modules)
	shield_bash.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, 1))
	def.abilities.append(shield_bash)

	var phalanx_stance = DataLibrary._make_ability(&"knight_phalanx_stance", "Phalanx Stance", 0, [
		DataLibrary._status_module_self(GameEnums.StatusType.STURDY, 1),
		DataLibrary._status_module_self(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	], 1)
	phalanx_stance.modules[1].amount = 5
	phalanx_stance.can_target_self = true
	phalanx_stance.targeting_mode = GameEnums.TargetingMode.SELF
	phalanx_stance.upgrade_description = "Infinite RANGE for Retaliation Protocol."
	phalanx_stance.upgraded_modules = DataLibrary._duplicate_modules(phalanx_stance.modules)
	phalanx_stance.upgraded_modules.append(
		DataLibrary._status_module_self(GameEnums.StatusType.RETALIATION_INFINITE_RANGE, 1)
	)
	def.abilities.append(phalanx_stance)

	var taunting_strike = DataLibrary._make_ability(&"knight_taunting_strike", "Taunting Strike", 2, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._module(GameEnums.EffectType.PULL, 1),
		DataLibrary._status_module(GameEnums.StatusType.TAUNT, 1)
	], 1, GameEnums.StatType.PHYSICAL)
	taunting_strike.upgrade_description = "RANGE 3 | AOE 3x3 | PULL 2 all."
	taunting_strike.upgraded_range_tiles = 3
	taunting_strike.upgraded_target_shape = GameEnums.TargetShape.AOE_SQUARE
	taunting_strike.upgraded_target_shape_size = 1
	taunting_strike.upgraded_modules = DataLibrary._duplicate_modules(taunting_strike.modules)
	taunting_strike.upgraded_modules[1].amount = 2
	def.abilities.append(taunting_strike)

	var seismic_stomp = DataLibrary._make_ability(&"knight_seismic_stomp", "Seismic Stomp", 0, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._module(GameEnums.EffectType.PURGE, 0)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.AOE_SQUARE, 1)
	seismic_stomp.upgrade_description = "Create CRACKED terrain."
	seismic_stomp.upgraded_modules = DataLibrary._duplicate_modules(seismic_stomp.modules)
	seismic_stomp.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.CHANGE_TERRAIN, 0))
	def.abilities.append(seismic_stomp)

	var fortify = DataLibrary._make_ability(&"knight_fortify", "Fortify", 3, [
		DataLibrary._status_module(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	], 1)
	fortify.modules[0].scaling_stat = GameEnums.StatType.DEFENSE
	fortify.upgrade_description = "Ally gains THORNS 50%."
	fortify.upgraded_modules = DataLibrary._duplicate_modules(fortify.modules)
	var thorns = DataLibrary._status_module(GameEnums.StatusType.THORNS, 1)
	thorns.amount = 50
	fortify.upgraded_modules.append(thorns)
	def.abilities.append(fortify)

	var bowling_charge = DataLibrary._make_ability(&"knight_bowling_charge", "Bowling Charge", 3, [
		DataLibrary._module(GameEnums.EffectType.DASH, 3),
		DataLibrary._module(GameEnums.EffectType.BULLDOZE, 1),
	], 1)
	bowling_charge.modules[0].scaling_stat = GameEnums.StatType.PHYSICAL
	bowling_charge.targeting_mode = GameEnums.TargetingMode.DASH_LINE
	bowling_charge.targeting_flags = GameEnums.TargetingFlags.TILE
	bowling_charge.sync_legacy_targeting()
	bowling_charge.upgrade_description = ""
	bowling_charge.upgraded_modules = DataLibrary._duplicate_modules(bowling_charge.modules)
	bowling_charge.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.PUSH_CHAIN_COLLISION, 1))
	def.abilities.append(bowling_charge)

	var iron_grip = DataLibrary._make_ability(&"knight_iron_grip", "Iron Grip", 1, [
		DataLibrary._status_module(GameEnums.StatusType.ROOT, 1),
		DataLibrary._status_module(GameEnums.StatusType.IRON_GRIP_DEBUFF, 1)
	], 1)
	iron_grip.upgrade_description = "Refund 1 AP if already ROOT/STAGGER."
	iron_grip.upgraded_modules = DataLibrary._duplicate_modules(iron_grip.modules)
	iron_grip.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.REFUND_AP_ON_CC, 0))
	def.abilities.append(iron_grip)

	var redirect_strike = DataLibrary._make_ability(&"knight_redirect_strike", "Redirect Strike", 2, [
		DataLibrary._status_module_self(GameEnums.StatusType.INTERCEPT, 1)
	], 1)
	redirect_strike.upgrade_description = "Gain DEF +2 per redirected hit."
	redirect_strike.upgraded_modules = DataLibrary._duplicate_modules(redirect_strike.modules)
	redirect_strike.upgraded_modules[0].amount = 1
	redirect_strike.can_target_self = true
	redirect_strike.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(redirect_strike)
	
	var indomitable_will = DataLibrary._make_ability(&"knight_indomitable_will", "Indomitable Will", 0, [
		DataLibrary._module(GameEnums.EffectType.ARMOR_UP, 0),
		DataLibrary._status_module_self(GameEnums.StatusType.INDOMITABLE_WILL, 2)
	], 1)
	indomitable_will.modules[0].scaling_stat = GameEnums.StatType.MISSING_HP
	indomitable_will.upgrade_description = "When expires, gain +2 STR."
	var indo_up: Array[AbilityModule] = [
		DataLibrary._module(GameEnums.EffectType.ARMOR_UP, 0),
		DataLibrary._status_module_self(GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED, 2)
	]
	indomitable_will.upgraded_modules = indo_up
	indomitable_will.upgraded_modules[0].scaling_stat = GameEnums.StatType.MISSING_HP
	indomitable_will.can_target_self = true
	indomitable_will.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(indomitable_will)

	var retaliation_protocol = DataLibrary._make_ability(&"knight_retaliation_protocol", "Retaliation Protocol", 0, [
		DataLibrary._status_module_self(GameEnums.StatusType.RETALIATION_PROTOCOL, 1)
	], 1)
	retaliation_protocol.upgrade_description = "Counter-attacks apply PUSH 1."
	retaliation_protocol.upgraded_modules = DataLibrary._duplicate_modules(retaliation_protocol.modules)
	retaliation_protocol.upgraded_modules[0].amount = 1
	retaliation_protocol.can_target_self = true
	retaliation_protocol.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(retaliation_protocol)

	var shield_slam = DataLibrary._make_ability(&"knight_shield_slam", "Shield Slam", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._module(GameEnums.EffectType.PUSH, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	shield_slam.modules[0].legacy_modifiers["bonus_if_adjacent_at_cast"] = 2
	shield_slam.upgrade_description = "Target DEF -1 before damage."
	shield_slam.upgraded_modules = DataLibrary._duplicate_modules(shield_slam.modules)
	shield_slam.upgraded_modules[0].legacy_modifiers["def_debuff_before_damage"] = 1
	def.abilities.append(shield_slam)

	var defensive_formation = DataLibrary._make_ability(&"knight_defensive_formation", "Defensive Formation", 0, [
		DataLibrary._status_module(GameEnums.StatusType.STAT_BUFF_DEF, 1),
		DataLibrary._status_module(GameEnums.StatusType.STURDY, 1)
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.AOE_DIAMOND, 3)
	defensive_formation.modules[0].amount = 2
	defensive_formation.modules[0].legacy_modifiers["exclude_caster"] = true
	defensive_formation.modules[1].legacy_modifiers["exclude_caster"] = true
	defensive_formation.upgrade_description = "Allies gain SHIELD 2."
	defensive_formation.upgraded_modules = DataLibrary._duplicate_modules(defensive_formation.modules)
	defensive_formation.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.ARMOR_UP, 2))
	defensive_formation.upgraded_modules[2].legacy_modifiers["exclude_caster"] = true
	def.abilities.append(defensive_formation)

	var chain_hook = DataLibrary._make_ability(&"knight_chain_hook", "Chain Hook", 3, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._module(GameEnums.EffectType.PULL, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	chain_hook.upgrade_description = "Target suffers VULNERABLE if pulled adjacent."
	chain_hook.upgraded_modules = DataLibrary._duplicate_modules(chain_hook.modules)
	chain_hook.upgraded_modules.append(DataLibrary._module(GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, 1))
	def.abilities.append(chain_hook)
	
	var trampling_advance = DataLibrary._make_ability(&"knight_trampling_advance", "Trampling Advance", 2, [
		DataLibrary._module(GameEnums.EffectType.MOVE, 2),
		DataLibrary._module(GameEnums.EffectType.TRAMPLE, 2),
		DataLibrary._module(GameEnums.EffectType.PUSH, 1)
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.SINGLE, 1)
	trampling_advance.targeting_flags = GameEnums.TargetingFlags.TILE
	trampling_advance.targeting_mode = GameEnums.TargetingMode.TILE
	trampling_advance.movement_point_cost = 2
	trampling_advance.presentation_anim = GameEnums.PresentationAnim.RUN
	trampling_advance.sync_legacy_targeting()
	trampling_advance.upgrade_description = ""
	var trample_upgraded: Array[AbilityModule] = [
		DataLibrary._module(GameEnums.EffectType.TRAMPLE, 2),
		DataLibrary._module(GameEnums.EffectType.PUSH, 1),
	]
	trampling_advance.upgraded_modules = trample_upgraded
	def.abilities.append(trampling_advance)

	## AD-4 modules-first: author flat effects; call AbilityModuleBridge.ensure_* for
	## explicit gates before append; finalize_unit_abilities infers modules + compiles
	## legacy effects[] for AbilitySystem readers (ability-data.md Â§14 item 10).
	DataLibrary.finalize_unit_abilities(def)
	return def
