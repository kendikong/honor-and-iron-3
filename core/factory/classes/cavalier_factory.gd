class_name CavalierFactory
extends RefCounted

static func build(basic_lance: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"cavalier"
	def.display_name = "Cavalier"
	def.base_constitution = 5
	def.move_points = 4
	def.action_points = 1
	def.base_strength = 4
	def.base_defense = 3
	def.base_magic = 1
	def.equipped_weapon = basic_lance
	
	# Movement Skill (Push)
	var push := DataLibrary._make_movement_ability(&"cavalier_push", "Push", 0, [
		DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	], 0, GameEnums.StatType.NONE, GameEnums.TargetShape.SINGLE, 1)
	push.upgrade_description = "Limit once per turn. Pushing unit grants +1 STR for next attack."
	push.upgraded_effects = DataLibrary._duplicate_effects(push.effects)
	def.abilities.append(push)
	
	# Passives
	def.passives.append(DataLibrary._make_passive(&"kinetic_charge", "Kinetic Charge", "Gain +1 STR per tile moved in continuous straight line before attacking.", ""))
	def.passives.append(DataLibrary._make_passive(&"unstoppable_mass", "Unstoppable Mass", "If you move max MOVEMENT before attacking, attack gains PIERCE and ROOT immunity.", ""))
	def.passives.append(DataLibrary._make_passive(&"canto", "Canto", "Standard movement gains CANTO.", ""))
	def.passives.append(DataLibrary._make_passive(&"frontline_defense", "Frontline Defense", "Gain +1 DEF and Ranged immunity if moved 3+ tiles.", "[+] Also gain SHIELD 1."))
	def.passives.append(DataLibrary._make_passive(&"flanking_strike", "Flanking Strike", "Side attacks ignore 2 DEF.", "[+] Ignores 4 DEF instead."))
	
	def.passives.append(DataLibrary._make_passive(&"plunging_attack", "Plunging Attack", "Using an AP jump/teleport before your action adds +3 ATK to that action.", "[+] Attack gains PIERCE."))
	def.passives.append(DataLibrary._make_passive(&"crashing_impact", "Crashing Impact", "Landing creates shockwave (PUSH 1 adjacent).", "[+] Pushed enemies hitting obstacles suffer STAGGER."))
	def.passives.append(DataLibrary._make_passive(&"pole_plant", "Pole-Plant", "0-AP Push works on traps. Destroying trap = SHIELD 2.", "[+] Destroying trap deals 2 unmitigated damage to adjacent."))
	def.passives.append(DataLibrary._make_passive(&"spear_drop", "Spear Drop", "Attacking an enemy you vaulted over ignores 2 DEF and applies BLEED X.", "[+] Ignores 4 DEF."))
	def.passives.append(DataLibrary._make_passive(&"springboard", "Springboard", "On Kill: Free vault to defeated enemy space for 0 AP, gain +1 MOV on landing.", "[+] Gain 1 AP on landing (Once per turn)."))
	
	def.passives.append(DataLibrary._make_passive(&"sweet_spot", "Sweet Spot", "Attacks from exactly RANGE 2 gain +2 ATK and ignore 2 DEF.", "[+] Ignore 4 DEF instead."))
	def.passives.append(DataLibrary._make_passive(&"reach_advantage", "Reach Advantage", "Attacking melee unit from exactly RANGE 2 prevents counter-attacks.", "[+] Target suffers -1 DEF."))
	def.passives.append(DataLibrary._make_passive(&"disengage", "Disengage", "Attacking at RANGE 1 applies PUSH 1 to yourself before damage.", "[+] Also applies PUSH 1 to enemy."))
	def.passives.append(DataLibrary._make_passive(&"zone_of_control", "Zone of Control", "Enemy ending turn exactly 2 tiles away suffers basic attack (Once per round).", "[+] Attack gains PIERCE."))
	def.passives.append(DataLibrary._make_passive(&"leverage", "Leverage", "Using 0-AP Push grants next attack PIERCE and +1 MOV.", "[+] Also gain SHIELD 1."))
	
	# Actives
	var piercing_charge = DataLibrary._make_ability(&"cavalier_piercing_charge", "Piercing Charge", 3, [
		DataLibrary._effect(GameEnums.EffectType.DASH, 3),
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 2)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.SINGLE, 2)
	piercing_charge.upgrade_description = "Create TRAMPLED terrain behind you (MOVE cost x2)."
	piercing_charge.upgraded_effects = DataLibrary._duplicate_effects(piercing_charge.effects)
	def.abilities.append(piercing_charge)

	var sweeping_halberd = DataLibrary._make_ability(&"cavalier_sweeping_halberd", "Sweeping Halberd", 2, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._effect(GameEnums.EffectType.PULL, 1)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.ARC, 2)
	sweeping_halberd.upgrade_description = "Enemy collision on PULL applies STAGGER."
	sweeping_halberd.upgraded_effects = DataLibrary._duplicate_effects(sweeping_halberd.effects)
	def.abilities.append(sweeping_halberd)

	var vaulting_leap = DataLibrary._make_ability(&"cavalier_vaulting_leap", "Vaulting Leap", 2, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_DEF, 1) # Sets DEF=0 logically
	], 1, GameEnums.StatType.PHYSICAL)
	vaulting_leap.upgrade_description = "Armor explodes: ATK 1 (AOE 1 around target)."
	vaulting_leap.upgraded_effects = DataLibrary._duplicate_effects(vaulting_leap.effects)
	def.abilities.append(vaulting_leap)

	var run_down = DataLibrary._make_ability(&"cavalier_run_down", "Run Down", 2, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 3)
	], 1, GameEnums.StatType.PHYSICAL)
	run_down.upgrade_description = "On Kill: Gain MAX MOVEMENT +2."
	run_down.upgraded_effects = DataLibrary._duplicate_effects(run_down.effects)
	def.abilities.append(run_down)

	var rallying_cry = DataLibrary._make_ability(&"cavalier_rallying_cry", "Rallying Cry", 0, [
		DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_MOV, 1)
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.AOE_SQUARE, 2)
	rallying_cry.upgrade_description = "Allies gain TRAMPLE (1 turn)."
	rallying_cry.upgraded_effects = DataLibrary._duplicate_effects(rallying_cry.effects)
	def.abilities.append(rallying_cry)

	var flanking_maneuver = DataLibrary._make_ability(&"cavalier_flanking_maneuver", "Flanking Maneuver", 2, [ # L-Shape MOVE
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	flanking_maneuver.upgrade_description = "Gain GHOST during MOVE."
	flanking_maneuver.upgraded_effects = DataLibrary._duplicate_effects(flanking_maneuver.effects)
	def.abilities.append(flanking_maneuver)

	var brace = DataLibrary._make_ability(&"cavalier_brace", "Brace", 0, [
		DataLibrary._status_effect_self(GameEnums.StatusType.STURDY, 1) # Negate next melee
	], 1)
	brace.upgrade_description = "Attacker suffers STAGGER."
	brace.upgraded_effects = DataLibrary._duplicate_effects(brace.effects)
	def.abilities.append(brace)

	var harpoon_toss = DataLibrary._make_ability(&"cavalier_harpoon_toss", "Harpoon Toss", 4, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PULL, 3)
	], 1, GameEnums.StatType.PHYSICAL)
	harpoon_toss.upgrade_description = "If SELF ROOT or target heavier, PULL SELF to target."
	harpoon_toss.upgraded_effects = DataLibrary._duplicate_effects(harpoon_toss.effects)
	def.abilities.append(harpoon_toss)

	var glorious_charge = DataLibrary._make_ability(&"cavalier_glorious_charge", "Glorious Charge", 4, [
		DataLibrary._effect(GameEnums.EffectType.DASH, 4),
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	], 1, GameEnums.StatType.PHYSICAL)
	glorious_charge.upgrade_description = "On Kill: Both gain +1 AP."
	glorious_charge.upgraded_effects = DataLibrary._duplicate_effects(glorious_charge.effects)
	def.abilities.append(glorious_charge)

	var pole_vault = DataLibrary._make_ability(&"cavalier_pole_vault", "Pole Vault", 3, [
		DataLibrary._effect(GameEnums.EffectType.TELEPORT_CASTER, 3)
	], 1, GameEnums.StatType.NONE)
	pole_vault.upgrade_description = "Landing applies PUSH 1 to adjacent enemies."
	pole_vault.upgraded_effects = DataLibrary._duplicate_effects(pole_vault.effects)
	def.abilities.append(pole_vault)

	var line_breaker = DataLibrary._make_ability(&"cavalier_line_breaker", "Line Breaker", 4, [
		DataLibrary._effect(GameEnums.EffectType.DASH, 4),
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.LINE, 4)
	line_breaker.upgrade_description = "ATK +1 for each enemy passed through this turn."
	line_breaker.upgraded_effects = DataLibrary._duplicate_effects(line_breaker.effects)
	def.abilities.append(line_breaker)

	var spear_wall = DataLibrary._make_ability(&"cavalier_spear_wall", "Spear Wall", 2, [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2),
		DataLibrary._status_effect(GameEnums.StatusType.ROOT, 1)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.ARC, 2)
	spear_wall.upgrade_description = "Hazard lasts 2 turns."
	spear_wall.upgraded_effects = DataLibrary._duplicate_effects(spear_wall.effects)
	def.abilities.append(spear_wall)

	var meteor_drop = DataLibrary._make_ability(&"cavalier_meteor_drop", "Meteor Drop", 2, [
		DataLibrary._effect(GameEnums.EffectType.TELEPORT_CASTER, 2),
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.AOE_SQUARE, 1)
	meteor_drop.upgrade_description = "Targets hit suffer VULNERABLE."
	meteor_drop.upgraded_effects = DataLibrary._duplicate_effects(meteor_drop.effects)
	def.abilities.append(meteor_drop)

	DataLibrary.finalize_unit_abilities(def)
	return def
