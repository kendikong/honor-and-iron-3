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
	
	# Movement Skill (Swap) — Master Bible; always granted, not part of roll pool.
	var swap := DataLibrary._make_movement_ability(&"knight_swap", "Swap", 1, [
		DataLibrary._effect(GameEnums.EffectType.SWAP, 0)
	], 1)
	swap.upgrade_description = "Gain +2 DEF and SHIELD 2 for the rest of the turn."
	var swap_upgraded = swap.effects.duplicate()
	var def_buff = DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	def_buff.amount = 2
	swap_upgraded.append(def_buff)
	swap_upgraded.append(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2))
	swap.upgraded_effects = swap_upgraded
	def.abilities.append(swap)
	
	# Passives
	def.passives.append(DataLibrary._make_passive(&"collision_retaliator", "Collision Retaliator", "Enemy collision suffers ATK 2. Knight takes 0 collision damage.", "[+] PUSH 1."))
	def.passives.append(DataLibrary._make_passive(&"thorny_carapace", "Thorny Carapace", "Melee hit reflects 50% damage (rounded down) & PUSH 1.", "[+] Reflects 100% damage instead."))
	def.passives.append(DataLibrary._make_passive(&"trample_move", "Trample Move", "Normal movement gains TRAMPLE.", "[+] Enemies trampled suffer -1 DEF."))
	def.passives.append(DataLibrary._make_passive(&"stand_ground", "Stand Ground", "Immune to PUSH/PULL. Enemy attempts trigger COUNTER ATTACK 1.", "[+] COUNTER ATTACK 2 instead."))
	def.passives.append(DataLibrary._make_passive(&"spiked_barricade", "Spiked Barricade", "PUSH into walls/obstacles applies STUN.", "[+] Target also suffers -1 DEF."))
	
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
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	shield_bash.upgrade_description = "Apply STUN if collides with wall/enemy."
	shield_bash.upgraded_effects = DataLibrary._duplicate_effects(shield_bash.effects)
	shield_bash.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.PUSH_STUN_ON_COLLISION, 1))
	def.abilities.append(shield_bash)

	var phalanx_stance = DataLibrary._make_ability(&"knight_phalanx_stance", "Phalanx Stance", 0, [
		DataLibrary._status_effect_self(GameEnums.StatusType.STURDY, 1),
		DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	], 1)
	phalanx_stance.effects[1].amount = 5
	phalanx_stance.can_target_self = true
	phalanx_stance.targeting_mode = GameEnums.TargetingMode.SELF
	phalanx_stance.upgrade_description = "Infinite RANGE for Retaliation Protocol."
	phalanx_stance.upgraded_effects = DataLibrary._duplicate_effects(phalanx_stance.effects)
	phalanx_stance.upgraded_effects.append(
		DataLibrary._status_effect_self(GameEnums.StatusType.RETALIATION_INFINITE_RANGE, 1)
	)
	def.abilities.append(phalanx_stance)

	var taunting_strike = DataLibrary._make_ability(&"knight_taunting_strike", "Taunting Strike", 2, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PULL, 1),
		DataLibrary._status_effect(GameEnums.StatusType.TAUNT, 1)
	], 1, GameEnums.StatType.PHYSICAL)
	taunting_strike.upgrade_description = "RANGE 3 | AOE 3x3 | PULL 2 all."
	taunting_strike.upgraded_range_tiles = 3
	taunting_strike.upgraded_target_shape = GameEnums.TargetShape.AOE_SQUARE
	taunting_strike.upgraded_target_shape_size = 1
	taunting_strike.upgraded_effects = DataLibrary._duplicate_effects(taunting_strike.effects)
	taunting_strike.upgraded_effects[1].amount = 2
	def.abilities.append(taunting_strike)

	var seismic_stomp = DataLibrary._make_ability(&"knight_seismic_stomp", "Seismic Stomp", 0, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._effect(GameEnums.EffectType.PURGE, 0)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.AOE_SQUARE, 1)
	seismic_stomp.upgrade_description = "Create CRACKED terrain."
	seismic_stomp.upgraded_effects = DataLibrary._duplicate_effects(seismic_stomp.effects)
	seismic_stomp.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.CHANGE_TERRAIN, 0))
	def.abilities.append(seismic_stomp)

	var fortify = DataLibrary._make_ability(&"knight_fortify", "Fortify", 3, [
		DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_DEF, 1)
	], 1)
	fortify.effects[0].scaling_stat = GameEnums.StatType.DEFENSE
	fortify.upgrade_description = "Ally gains THORNS 50%."
	fortify.upgraded_effects = DataLibrary._duplicate_effects(fortify.effects)
	var thorns = DataLibrary._status_effect(GameEnums.StatusType.THORNS, 1)
	thorns.amount = 50
	fortify.upgraded_effects.append(thorns)
	def.abilities.append(fortify)

	var bowling_charge = DataLibrary._make_ability(&"knight_bowling_charge", "Bowling Charge", 3, [
		DataLibrary._effect(GameEnums.EffectType.DASH, 3),
		DataLibrary._effect(GameEnums.EffectType.BULLDOZE, 1),
	], 1)
	bowling_charge.effects[0].scaling_stat = GameEnums.StatType.PHYSICAL
	bowling_charge.upgrade_description = "Pushed target chain-pushes enemies behind them."
	bowling_charge.upgraded_effects = DataLibrary._duplicate_effects(bowling_charge.effects)
	bowling_charge.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.PUSH_CHAIN_COLLISION, 1))
	def.abilities.append(bowling_charge)

	var iron_grip = DataLibrary._make_ability(&"knight_iron_grip", "Iron Grip", 1, [
		DataLibrary._status_effect(GameEnums.StatusType.ROOT, 1),
		DataLibrary._status_effect(GameEnums.StatusType.IRON_GRIP_DEBUFF, 1)
	], 1)
	iron_grip.upgrade_description = "Refund 1 AP if already ROOT/STUN."
	iron_grip.upgraded_effects = DataLibrary._duplicate_effects(iron_grip.effects)
	iron_grip.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.REFUND_AP_ON_CC, 0))
	def.abilities.append(iron_grip)

	var redirect_strike = DataLibrary._make_ability(&"knight_redirect_strike", "Redirect Strike", 0, [
		DataLibrary._status_effect_self(GameEnums.StatusType.INTERCEPT, 1)
	], 1)
	redirect_strike.upgrade_description = "Gain DEF +2 per redirected hit."
	redirect_strike.upgraded_effects = DataLibrary._duplicate_effects(redirect_strike.effects)
	redirect_strike.upgraded_effects[0].amount = 1
	redirect_strike.can_target_self = true
	redirect_strike.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(redirect_strike)
	
	var indomitable_will = DataLibrary._make_ability(&"knight_indomitable_will", "Indomitable Will", 0, [
		DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 0),
		DataLibrary._status_effect_self(GameEnums.StatusType.INDOMITABLE_WILL, 2)
	], 1)
	indomitable_will.effects[0].scaling_stat = GameEnums.StatType.MISSING_HP
	indomitable_will.upgrade_description = "When expires, gain +2 STR."
	indomitable_will.upgraded_effects = [
		DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 0),
		DataLibrary._status_effect_self(GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED, 2)
	]
	indomitable_will.upgraded_effects[0].scaling_stat = GameEnums.StatType.MISSING_HP
	indomitable_will.can_target_self = true
	indomitable_will.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(indomitable_will)

	var retaliation_protocol = DataLibrary._make_ability(&"knight_retaliation_protocol", "Retaliation Protocol", 0, [
		DataLibrary._status_effect_self(GameEnums.StatusType.RETALIATION_PROTOCOL, 1)
	], 1)
	retaliation_protocol.upgrade_description = "Counter-attacks apply PUSH 1."
	retaliation_protocol.upgraded_effects = DataLibrary._duplicate_effects(retaliation_protocol.effects)
	retaliation_protocol.upgraded_effects[0].amount = 1
	retaliation_protocol.can_target_self = true
	retaliation_protocol.targeting_mode = GameEnums.TargetingMode.SELF
	def.abilities.append(retaliation_protocol)

	var shield_slam = DataLibrary._make_ability(&"knight_shield_slam", "Shield Slam", 1, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	shield_slam.effects[0].bonus_if_adjacent_at_cast = 2
	shield_slam.upgrade_description = "Target DEF -1 before damage."
	shield_slam.upgraded_effects = DataLibrary._duplicate_effects(shield_slam.effects)
	shield_slam.upgraded_effects[0].def_debuff_before_damage = 1
	def.abilities.append(shield_slam)

	var defensive_formation = DataLibrary._make_ability(&"knight_defensive_formation", "Defensive Formation", 0, [
		DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_DEF, 1),
		DataLibrary._status_effect(GameEnums.StatusType.STURDY, 1)
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.AOE_DIAMOND, 3)
	defensive_formation.effects[0].amount = 2
	defensive_formation.upgrade_description = "Allies gain SHIELD 2."
	defensive_formation.upgraded_effects = DataLibrary._duplicate_effects(defensive_formation.effects)
	defensive_formation.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2))
	def.abilities.append(defensive_formation)

	var chain_hook = DataLibrary._make_ability(&"knight_chain_hook", "Chain Hook", 3, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PULL, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	chain_hook.upgrade_description = "Target suffers VULNERABLE if pulled adjacent."
	chain_hook.upgraded_effects = DataLibrary._duplicate_effects(chain_hook.effects)
	chain_hook.upgraded_effects.append(DataLibrary._effect(GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, 1))
	def.abilities.append(chain_hook)
	
	var trampling_advance = DataLibrary._make_ability(&"knight_trampling_advance", "Trampling Advance", 2, [
		DataLibrary._effect(GameEnums.EffectType.MOVE, 2),
		DataLibrary._effect(GameEnums.EffectType.TRAMPLE, 2),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.SINGLE, 1)
	trampling_advance.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	trampling_advance.movement_point_cost = 2
	trampling_advance.targeting_flags = GameEnums.TargetingFlags.TILE
	trampling_advance.presentation_anim = GameEnums.PresentationAnim.RUN
	trampling_advance.upgrade_description = ""
	trampling_advance.upgraded_effects = DataLibrary._duplicate_effects(trampling_advance.effects)
	def.abilities.append(trampling_advance)

	return def
