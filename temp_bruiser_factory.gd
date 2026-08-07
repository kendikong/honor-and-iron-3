class_name BruiserFactory
extends RefCounted

static func build(basic_axe: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"bruiser"
	def.display_name = "Bruiser"
	def.base_constitution = 7
	def.move_points = 3
	def.action_points = 1
	def.base_strength = 4
	def.base_defense = 2
	def.base_magic = 1
	def.equipped_weapon = basic_axe
	
	# Movement Skill (Push Through)
	var push_through_mod := DataLibrary._module(GameEnums.EffectType.MOVE_INTO_AND_PUSH, 1)
	var push_through := DataLibrary._make_movement_ability(
		&"bruiser_push_through",
		"Push Through",
		1,
		[push_through_mod],
		2,
		GameEnums.StatType.NONE,
		GameEnums.TargetShape.SINGLE,
		1,
		GameEnums.TargetingMode.ENEMY_UNIT,
	)
	push_through.upgrade_description = "Cost reduced to 1 MOV. Pushing unit grants +1 STR for next attack."
	push_through.upgraded_movement_point_cost = 1
	push_through.upgraded_modules = DataLibrary._duplicate_modules(push_through.modules)
	push_through.upgraded_modules[0].legacy_modifiers["buff_on_push"] = 1
	def.abilities.append(push_through)
	
	# Passives
	def.passives.append(DataLibrary._make_passive(&"cellular_regeneration", "Cellular Regeneration", "HEAL 1 if adjacent to 1+ enemies at turn start.", "[+] Also gain +1 STR if adjacent to 2+ enemies."))
	def.passives.append(DataLibrary._make_passive(&"blood_for_blood", "Blood for Blood", "If damaged last turn, attacks apply BLEED X (X = WPN).", "[+] Attacks also gain ATK +1."))
	def.passives.append(DataLibrary._make_passive(&"adrenaline_junkie", "Adrenaline Junkie", "Gain MOVE +1 and STR +1 per 10% missing HP.", "[+] Also gain +1 DEF for every 20% missing HP."))
	def.passives.append(DataLibrary._make_passive(&"enraged", "Enraged", "Gain +1 STR per unique debuff/hazard.", "[+] Also gain +1 MOV per debuff/hazard."))
	def.passives.append(DataLibrary._make_passive(&"last_stand", "Last Stand", "When HP < 25%, gain +2 STR and +2 DEF.", "[+] Gain +3 STR and +3 DEF instead."))
	
	def.passives.append(DataLibrary._make_passive(&"colossal_mass", "Colossal Mass", "Gain +1 STR for every 15 Max HP.", "[+] Gain +1 STR for every 10 Max HP instead."))
	def.passives.append(DataLibrary._make_passive(&"overwhelming_bulk", "Overwhelming Bulk", "If Current HP > target Max HP, attacks gain PIERCE.", "[+] Attacks also apply PUSH 1."))
	def.passives.append(DataLibrary._make_passive(&"thrill_of_pain", "Thrill of Pain", "Damage taken adds ATK +2 and PUSH 1 to NEXT attack.", "[+] Next attack gains ATK +3 instead."))
	def.passives.append(DataLibrary._make_passive(&"momentum_of_titan", "Momentum of the Titan", "PUSH collision adds damage = 10% Max HP.", "[+] Damage increases to 20% Max HP."))
	def.passives.append(DataLibrary._make_passive(&"scar_tissue", "Scar Tissue", "Reduce physical damage by 1 per 20 Max HP or missing HP.", "[+] Reduce damage by additional 1."))
	
	def.passives.append(DataLibrary._make_passive(&"momentum_transfer", "Momentum Transfer", "Applying PUSH collision HEALS 1.", "[+] HEAL 1 and gain +1 STR."))
	def.passives.append(DataLibrary._make_passive(&"crowd_breaker", "Crowd Breaker", "+1 STR per adjacent enemy. Splash damage ATK 1.", "[+] Splash damage ATK 2."))
	def.passives.append(DataLibrary._make_passive(&"juggernaut", "Juggernaut", "Moving over traps destroys them for 0 damage.", "[+] Destroying trap grants SHIELD 1."))
	def.passives.append(DataLibrary._make_passive(&"battering_ram", "Battering Ram", "PUSH pushes 1 additional tile.", "[+] Pushed enemies hitting walls suffer STAGGER."))
	def.passives.append(DataLibrary._make_passive(&"unstoppable_force", "Unstoppable Force", "Immune to STAGGER/ROOT. Resisting grants SHIELD 1.", "[+] Resisting grants SHIELD 2."))
	
	# Actives
	var charge_move = DataLibrary._module(GameEnums.EffectType.MOVE, 2)
	charge_move.execution_phase = GameEnums.ModulePhase.ON_PRE
	var charge_atk = DataLibrary._module(GameEnums.EffectType.DAMAGE, 3)
	charge_atk.execution_phase = GameEnums.ModulePhase.ON_ACTION
	var charge_push = DataLibrary._module(GameEnums.EffectType.PUSH, 1)
	charge_push.execution_phase = GameEnums.ModulePhase.ON_ACTION
	charge_push.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	charge_push.aim_module_index = 1
	var charge_strike = DataLibrary._make_ability(&"bruiser_charge_strike", "Charge Strike", 1, [
		charge_move,
		charge_atk,
		charge_push
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.SINGLE, 1)
	charge_strike.upgrade_description = "Gain GHOST during MOVE. Gain ATK +2 if passing through terrain."
	charge_strike.upgraded_modules = DataLibrary._duplicate_modules(charge_strike.modules)
	charge_strike.upgraded_modules[0].legacy_modifiers["ghost_move"] = 1
	charge_strike.upgraded_modules[1].legacy_modifiers["bonus_dmg_from_terrain"] = 2
	def.abilities.append(charge_strike)

	var cb_push = DataLibrary._module(GameEnums.EffectType.PUSH, 1)
	cb_push.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	cb_push.aim_module_index = 0
	var concussion_blow = DataLibrary._make_ability(&"bruiser_concussion_blow", "Concussion Blow", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 2),
		cb_push
	], 1, GameEnums.StatType.PHYSICAL)
	concussion_blow.modules[1].legacy_modifiers["object_collision_stagger"] = 1
	concussion_blow.upgrade_description = "Enemy collision applies STAGGER to both units."
	concussion_blow.upgraded_modules = DataLibrary._duplicate_modules(concussion_blow.modules)
	concussion_blow.upgraded_modules[1].legacy_modifiers["enemy_collision_stagger_both"] = 1
	def.abilities.append(concussion_blow)

	var cleave = DataLibrary._make_ability(&"bruiser_cleave", "Cleave", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 2)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.ARC, 1)
	cleave.upgrade_description = "Apply BLEED X (where X = your WPN) to all targets."
	cleave.upgraded_modules = DataLibrary._duplicate_modules(cleave.modules)
	var bleed_eff = DataLibrary._status_module(GameEnums.StatusType.BLEED, 2)
	bleed_eff.legacy_modifiers["weapon_scaled"] = 1
	cleave.upgraded_modules.append(bleed_eff)
	def.abilities.append(cleave)

	var suplex_throw = DataLibrary._module(GameEnums.EffectType.THROW_BEHIND, 0)
	suplex_throw.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	suplex_throw.aim_module_index = 0
	var suplex = DataLibrary._make_ability(&"bruiser_suplex", "Suplex", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 4),
		suplex_throw
	], 1, GameEnums.StatType.PHYSICAL)
	suplex.upgrade_description = "Gain ATK +1 for every 10 Current HP you possess."
	suplex.upgraded_modules = DataLibrary._duplicate_modules(suplex.modules)
	suplex.upgraded_modules[0].legacy_modifiers["bonus_dmg_per_10_hp"] = 1
	def.abilities.append(suplex)

	var adrenaline_surge = DataLibrary._make_ability(&"bruiser_adrenaline_surge", "Adrenaline Surge", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE_SELF, 5),
		DataLibrary._status_module_self(GameEnums.StatusType.STAT_BUFF_STR, 1, 1),
		DataLibrary._status_module_self(GameEnums.StatusType.STAT_BUFF_MOV, 1, 1)
	], 1)
	adrenaline_surge.upgrade_description = "On Kill: HEAL 1 and gain SHIELD 2."
	adrenaline_surge.targeting_mode = GameEnums.TargetingMode.SELF
	adrenaline_surge.targeting_flags = GameEnums.TargetingFlags.SELF
	adrenaline_surge.modules[0].legacy_modifiers["zero_ap_adjacent_enemies"] = 2
	adrenaline_surge.upgraded_modules = DataLibrary._duplicate_modules(adrenaline_surge.modules)
	adrenaline_surge.upgraded_modules[1].legacy_modifiers["on_kill_heal_shield"] = 1
	def.abilities.append(adrenaline_surge)

	var es_dest = DataLibrary._module(GameEnums.EffectType.DESTROY_OBSTACLE, 0)
	es_dest.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	es_dest.aim_module_index = 0
	var earthshatter = DataLibrary._make_ability(&"bruiser_earthshatter", "Earthshatter", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 2),
		es_dest
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.ARC, 1)
	earthshatter.upgrade_description = "Gain ATK +1 per destroyed object."
	earthshatter.upgraded_modules = DataLibrary._duplicate_modules(earthshatter.modules)
	earthshatter.upgraded_modules[1].legacy_modifiers["buff_per_destroyed_object"] = 1
	def.abilities.append(earthshatter)

	var ms_swap = DataLibrary._module(GameEnums.EffectType.SWAP, 0)
	ms_swap.execution_phase = GameEnums.ModulePhase.ON_PRE
	var meat_shield = DataLibrary._make_ability(&"bruiser_meat_shield", "Meat Shield", 1, [
		ms_swap,
		DataLibrary._status_module_self(GameEnums.StatusType.INTERCEPT, 1)
	], 1)
	meat_shield.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	meat_shield.targeting_flags = GameEnums.TargetingFlags.ALLY
	meat_shield.upgrade_description = "RANGE 3. Gain STR +2 per interception."
	meat_shield.upgraded_range_tiles = 3
	meat_shield.upgraded_modules = DataLibrary._duplicate_modules(meat_shield.modules)
	meat_shield.upgraded_modules[1].legacy_modifiers["intercept_grant_str"] = 2
	def.abilities.append(meat_shield)

	var frenzy_dmg = DataLibrary._module(GameEnums.EffectType.DAMAGE, 1)
	frenzy_dmg.hit_count = 3
	var frenzy = DataLibrary._make_ability(&"bruiser_frenzy", "Frenzy", 1, [
		frenzy_dmg
	], 1, GameEnums.StatType.PHYSICAL)
	frenzy.upgrade_description = "On Kill: Gain 1 AP."
	frenzy.upgraded_modules = DataLibrary._duplicate_modules(frenzy.modules)
	for eff in frenzy.upgraded_modules:
		eff.legacy_modifiers["frenzy_on_kill_ap"] = 1
	def.abilities.append(frenzy)

	var roar_debuff = DataLibrary._status_module(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 2)
	roar_debuff.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	roar_debuff.aim_module_index = 0
	var guttural_roar = DataLibrary._make_ability(&"bruiser_guttural_roar", "Guttural Roar", 0, [
		DataLibrary._module(GameEnums.EffectType.PUSH, 1),
		roar_debuff
	], 1, GameEnums.StatType.NONE, GameEnums.TargetShape.AOE_SQUARE, 2)
	guttural_roar.upgrade_description = "PUSH 1 all items/coins/scrap. Item collision: ATK 1."
	guttural_roar.upgraded_modules = DataLibrary._duplicate_modules(guttural_roar.modules)
	guttural_roar.upgraded_modules[0].legacy_modifiers["push_board_items"] = 1
	guttural_roar.upgraded_modules[0].legacy_modifiers["item_collision_damage"] = 1
	def.abilities.append(guttural_roar)

	var hb_dmg_self = DataLibrary._module(GameEnums.EffectType.DAMAGE_SELF, 1)
	hb_dmg_self.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	hb_dmg_self.aim_module_index = 0
	var hb_stagger = DataLibrary._status_module(GameEnums.StatusType.STAGGER, 1)
	hb_stagger.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	hb_stagger.aim_module_index = 0
	var hb_stagger_self = DataLibrary._status_module_self(GameEnums.StatusType.STAGGER, 1)
	hb_stagger_self.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	hb_stagger_self.aim_module_index = 0
	var headbutt = DataLibrary._make_ability(&"bruiser_headbutt", "Headbutt", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 3),
		hb_dmg_self,
		hb_stagger,
		hb_stagger_self
	], 1, GameEnums.StatType.PHYSICAL)
	headbutt.upgrade_description = "Deal bonus damage equal to 10% of your Max HP."
	headbutt.upgraded_modules = DataLibrary._duplicate_modules(headbutt.modules)
	headbutt.upgraded_modules[0].legacy_modifiers["bonus_dmg_pct_max_hp"] = 0.1
	def.abilities.append(headbutt)

	var blood_boil = DataLibrary._make_ability(&"bruiser_blood_boil", "Blood Boil", 1, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE_SELF, 5),
		DataLibrary._status_module_self(GameEnums.StatusType.STAT_BUFF_STR, 1)
	], 1)
	blood_boil.modules[1].amount = 3
	blood_boil.targeting_mode = GameEnums.TargetingMode.SELF
	blood_boil.targeting_flags = GameEnums.TargetingFlags.SELF
	blood_boil.upgrade_description = "Spend 10 HP to gain STR +5 instead."
	blood_boil.upgraded_modules = DataLibrary._duplicate_modules(blood_boil.modules)
	blood_boil.upgraded_modules[0].amount = 10
	blood_boil.upgraded_modules[1].amount = 5
	def.abilities.append(blood_boil)

	var violent_collision = DataLibrary._make_ability(&"bruiser_violent_collision", "Violent Collision", 1, [
		DataLibrary._module(GameEnums.EffectType.DASH, 3)
	], 1, GameEnums.StatType.NONE)
	violent_collision.modules[0].legacy_modifiers["bulldoze"] = 1
	violent_collision.modules[0].legacy_modifiers["push"] = 1
	violent_collision.targeting_mode = GameEnums.TargetingMode.DASH_LINE
	violent_collision.targeting_flags = GameEnums.TargetingFlags.DASH_LINE
	violent_collision.upgrade_description = "Collisions apply STAGGER (1 turn)."
	violent_collision.upgraded_modules = DataLibrary._duplicate_modules(violent_collision.modules)
	violent_collision.upgraded_modules[0].legacy_modifiers["stagger_on_collision"] = 1
	## Authored gate (ability-data.md §2.7) — not anonymous modifiers.
	AbilityModuleBridge.ensure_if_collided_followup_move(violent_collision)
	def.abilities.append(violent_collision)

	var crimson_whirlwind = DataLibrary._make_ability(&"bruiser_crimson_whirlwind", "Crimson Whirlwind", 0, [
		DataLibrary._module(GameEnums.EffectType.DAMAGE, 1)
	], 1, GameEnums.StatType.PHYSICAL, GameEnums.TargetShape.AOE_SQUARE, 1)
	crimson_whirlwind.upgrade_description = "HEAL 1 for every target successfully hit."
	crimson_whirlwind.upgraded_modules = DataLibrary._duplicate_modules(crimson_whirlwind.modules)
	crimson_whirlwind.upgraded_modules[0].legacy_modifiers["heal_per_target_hit"] = 1
	def.abilities.append(crimson_whirlwind)

	var bf_teleport = DataLibrary._module(GameEnums.EffectType.TELEPORT_CASTER, 0)
	bf_teleport.execution_phase = GameEnums.ModulePhase.ON_PRE
	var bf_dmg = DataLibrary._module(GameEnums.EffectType.DAMAGE, 2)
	bf_dmg.execution_phase = GameEnums.ModulePhase.ON_ACTION
	bf_dmg.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	bf_dmg.aim_module_index = 0
	var belly_flop = DataLibrary._make_ability(&"bruiser_belly_flop", "Belly Flop", 2, [
		bf_teleport,
		bf_dmg
	], 2, GameEnums.StatType.PHYSICAL)
	belly_flop.modules[1].legacy_modifiers["damage_adjacent_on_landing"] = 1
	belly_flop.upgrade_description = "Landing applies PUSH 1 to all adjacent enemies."
	belly_flop.targeting_mode = GameEnums.TargetingMode.TILE
	belly_flop.targeting_flags = GameEnums.TargetingFlags.TILE
	belly_flop.upgraded_modules = DataLibrary._duplicate_modules(belly_flop.modules)
	var bf_push = DataLibrary._module(GameEnums.EffectType.PUSH, 1)
	bf_push.execution_phase = GameEnums.ModulePhase.ON_ACTION
	bf_push.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	bf_push.aim_module_index = 0
	bf_push.legacy_modifiers["belly_flop_push"] = 1
	belly_flop.upgraded_modules.append(bf_push)
	def.abilities.append(belly_flop)

	var bd_dash = DataLibrary._module(GameEnums.EffectType.DASH, 3)
	bd_dash.execution_phase = GameEnums.ModulePhase.ON_PRE
	var bd_dest = DataLibrary._module(GameEnums.EffectType.DESTROY_OBSTACLE, 0)
	bd_dest.execution_phase = GameEnums.ModulePhase.ON_ACTION
	bd_dest.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	bd_dest.aim_module_index = 0
	var breaching_dash = DataLibrary._make_ability(&"bruiser_breaching_dash", "Breaching Dash", 1, [
		bd_dash,
		bd_dest
	], 1, GameEnums.StatType.PHYSICAL)
	breaching_dash.upgrade_description = "Your next attack this turn gains PIERCE."
	breaching_dash.targeting_mode = GameEnums.TargetingMode.DASH_LINE
	breaching_dash.targeting_flags = GameEnums.TargetingFlags.DASH_LINE
	breaching_dash.upgraded_modules = DataLibrary._duplicate_modules(breaching_dash.modules)
	breaching_dash.upgraded_modules[0].legacy_modifiers["next_attack_pierce"] = 1
	def.abilities.append(breaching_dash)

	## AD-4 modules-first: author flat effects; call AbilityModuleBridge.ensure_* for
	## explicit gates (e.g. violent_collision IF_COLLIDED) before append;
	## finalize_unit_abilities infers modules + compiles legacy effects[].
	DataLibrary.finalize_unit_abilities(def)
	return def


