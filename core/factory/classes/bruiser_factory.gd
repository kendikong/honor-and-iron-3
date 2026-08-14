class_name BruiserFactory
extends RefCounted

static func build(basic_axe: WeaponData) -> UnitData:
	var def := UnitData.new()
	def.id = &"bruiser"
	def.display_name = "Bruiser"
	def.base_constitution = 7
	def.move_points = 4
	def.action_points = 1
	def.base_strength = 4
	def.base_defense = 2
	def.base_magic = 1
	def.equipped_weapon = basic_axe
	def.promotion_stat_bonuses = {
		&"bloodrager": {"strength": 4, "constitution": 4, "movement": 0},
		&"behemoth": {"constitution": 6, "defense": 2, "movement": 0},
		&"siegebreaker": {"strength": 4, "constitution": 2, "movement": 2},
	}
	
	# Movement Skill (Push Through)
	var push_module := DataLibrary._module(
		GameEnums.EffectType.MOVE_INTO_AND_PUSH, 1, 1, 1, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.INTO_OCCUPIED_PUSH,
	)
	var push_upgraded := DataLibrary._duplicate_modules([push_module])
	push_upgraded[0].legacy_modifiers["buff_on_push"] = 1
	var push_through := DataLibrary._make_modular_ability(
		&"bruiser_push_through", "Push Through", [push_module], push_upgraded,
		2, GameEnums.PlannerGroup.PRE_MOVE, GameEnums.CostResource.MP,
		[AbilityModuleBridge.TAG_POSITIONING],
		"Cost reduced to 1 MOV. Pushing a unit grants +1 STR for your next attack this turn.",
		GameEnums.TargetingFlags.ALLY, GameEnums.CostResource.NONE, 0,
		GameEnums.CostModifier.NONE, 0, 1,
	)
	def.abilities.append(push_through)
	
	# Passives
	def.innate_passives.append(DataLibrary._make_passive(&"cellular_regeneration", "Sanguine Regeneration", "At the start of every turn, restore 5% of Max HP.", "[+] Restore 10%; at full HP convert the excess into SHIELD.", {
		"sanguine_regeneration": true,
	}))
	def.passives.append(DataLibrary._make_passive(&"reactive_adrenaline", "Reactive Adrenaline", "Starting adjacent to enemies converts Sanguine Regeneration into SHIELD and grants +1 STR per adjacent enemy, up to +3.", "[+] Also gain +1 DEF per adjacent enemy.", {
		"reactive_adrenaline": true,
		"adjacent_enemy_str_cap": 3,
		"upgraded_adjacent_enemy_def": 1,
	}))
	def.passives.append(DataLibrary._make_passive(&"blood_for_blood", "Blood for Blood", "If damaged last turn, attacks apply BLEED X (X = WPN).", "[+] Attacks also gain ATK +1."))
	def.passives.append(DataLibrary._make_passive(&"adrenaline_junkie", "Adrenaline Junkie", "Gain +1 MOV and +1 STR per 25% missing HP (max +3).", "[+] Also gain +1 DEF per 25% missing HP (max +3)."))
	def.passives.append(DataLibrary._make_passive(&"enraged", "Enraged", "Gain +1 STR per unique debuff/hazard.", "[+] Also gain +1 MOV per debuff/hazard."))
	def.passives.append(DataLibrary._make_passive(&"last_stand", "Last Stand", "When HP < 25%, gain +2 STR and +2 DEF.", "[+] Gain +3 STR and +3 DEF instead."))
	
	def.passives.append(DataLibrary._make_passive(&"colossal_mass", "Colossal Mass", "Gain +1 STR for every 15 Max HP.", "[+] Gain +1 STR for every 10 Max HP instead."))
	def.passives.append(DataLibrary._make_passive(&"overwhelming_bulk", "Overwhelming Bulk", "If Current HP > target Max HP, physical attacks gain PIERCE.", "[+] Attacks also apply PUSH 1.", {
		"overwhelming_bulk": true,
	}))
	def.passives.append(DataLibrary._make_passive(&"thrill_of_pain", "Thrill of Pain", "Damage taken adds ATK +2 and PUSH 1 to NEXT attack.", "[+] Next attack gains ATK +3 instead."))
	def.passives.append(DataLibrary._make_passive(&"momentum_of_titan", "Momentum of the Titan", "PUSH collision adds damage = 10% Max HP.", "[+] Damage increases to 20% Max HP."))
	def.passives.append(DataLibrary._make_passive(&"scar_tissue", "Scar Tissue", "Reduce physical damage by 1 per 20 Max HP or missing HP, capped at Floor(Max HP/10).", "[+] Count every 15 Max HP or 15 missing HP instead of 20."))
	
	def.passives.append(DataLibrary._make_passive(&"momentum_transfer", "Momentum Transfer", "Applying PUSH collision HEALS 1.", "[+] HEAL 1 and gain +1 STR."))
	def.passives.append(DataLibrary._make_passive(&"crowd_breaker", "Crowd Breaker", "+1 STR per adjacent enemy. Splash damage ATK 1.", "[+] Splash damage ATK 2."))
	def.passives.append(DataLibrary._make_passive(&"juggernaut", "Juggernaut", "Moving over traps destroys them for 0 damage.", "[+] Destroying trap grants SHIELD 1."))
	def.passives.append(DataLibrary._make_passive(&"battering_ram", "Battering Ram", "PUSH pushes 1 additional tile.", "[+] Pushed enemies hitting walls suffer STAGGER."))
	def.passives.append(DataLibrary._make_passive(&"unstoppable_force", "Unstoppable Force", "Immune to STAGGER/ROOT. Resisting grants SHIELD 1.", "[+] Resisting grants SHIELD 2."))
	
	# Actives
	var charge_move := DataLibrary._module(
		GameEnums.EffectType.MOVE, 2, 1, 2,
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	var charge_attack := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	charge_attack.execution_phase = GameEnums.ModulePhase.ON_ACTION
	charge_attack.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	charge_attack.aim_module_index = 0
	charge_attack.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1))]
	var charge_upgraded := DataLibrary._duplicate_modules([charge_move, charge_attack])
	charge_upgraded[0].keywords = [DataLibrary._keyword(GameEnums.AbilityKeywordId.GHOST)]
	charge_upgraded[1].legacy_modifiers["bonus_dmg_from_terrain"] = 2
	charge_upgraded[1].layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1))]
	var charge_strike := DataLibrary._make_modular_ability(
		&"bruiser_charge_strike", "Charge Strike", [charge_move, charge_attack],
		charge_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [],
		"Gain GHOST during MOVE. Gain ATK +2 if passing through terrain.",
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
	)
	charge_strike.range_tiles = 1
	def.abilities.append(charge_strike)

	var concussion_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	var concussion_push := DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	concussion_push.modifiers["object_collision_stagger"] = 1
	concussion_module.layers = [DataLibrary._layer(concussion_push)]
	var concussion_upgraded := DataLibrary._duplicate_modules([concussion_module])
	var upgraded_concussion_push := DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	upgraded_concussion_push.modifiers["enemy_collision_stagger_both"] = 1
	concussion_upgraded[0].layers = [DataLibrary._layer(upgraded_concussion_push)]
	var concussion_blow := DataLibrary._make_modular_ability(
		&"bruiser_concussion_blow", "Concussion Blow", [concussion_module],
		concussion_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Enemy collision applies STAGGER to both units.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(concussion_blow)

	var cleave_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.ARC, 1, GameEnums.StatType.PHYSICAL,
	)
	var cleave_upgraded := DataLibrary._duplicate_modules([cleave_module])
	var bleed_eff := DataLibrary._status_effect(GameEnums.StatusType.BLEED, 2)
	bleed_eff.modifiers["weapon_scaled"] = 1
	cleave_upgraded[0].layers = [DataLibrary._layer(bleed_eff)]
	var cleave := DataLibrary._make_modular_ability(
		&"bruiser_cleave", "Cleave", [cleave_module], cleave_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		[], "Apply BLEED X (where X = your WPN) to all targets.",
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
	)
	def.abilities.append(cleave)

	var suplex_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 4, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	suplex_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.THROW_BEHIND, 0))]
	var suplex_upgraded := DataLibrary._duplicate_modules([suplex_module])
	suplex_upgraded[0].legacy_modifiers["bonus_dmg_per_10_hp"] = 1
	var suplex := DataLibrary._make_modular_ability(
		&"bruiser_suplex", "Suplex", [suplex_module], suplex_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		[], "Gain ATK +1 for every 10 Current HP you possess.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(suplex)

	var adrenaline_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 1, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	adrenaline_module.status_type = GameEnums.StatusType.STAT_BUFF_STR
	adrenaline_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.STAT_BUFF_MOV, 1, 1)),
	]
	var adrenaline_upgraded := DataLibrary._duplicate_modules([adrenaline_module])
	adrenaline_upgraded[0].legacy_modifiers["on_kill_heal_shield"] = 1
	var adrenaline_surge := DataLibrary._make_modular_ability(
		&"bruiser_adrenaline_surge", "Adrenaline Surge", [adrenaline_module],
		adrenaline_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "On Kill: HEAL 1 and gain SHIELD 2.",
		GameEnums.TargetingFlags.SELF, GameEnums.CostResource.HP, 5,
		GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N, 2,
	)
	def.abilities.append(adrenaline_surge)

	var earthshatter_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 1, 1,
		GameEnums.TargetingFlags.ENEMY | GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.ARC, 1, GameEnums.StatType.PHYSICAL,
	)
	earthshatter_module.layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.DESTROY_OBSTACLE, 0)),
	]
	var earthshatter_upgraded := DataLibrary._duplicate_modules([earthshatter_module])
	earthshatter_upgraded[0].layers[0].effect.modifiers["buff_per_destroyed_object"] = 1
	var earthshatter := DataLibrary._make_modular_ability(
		&"bruiser_earthshatter", "Earthshatter", [earthshatter_module],
		earthshatter_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Gain ATK +1 per destroyed object.",
		GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(earthshatter)

	var meat_module := DataLibrary._module(
		GameEnums.EffectType.SWAP, 0, 1, 1, GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_TARGET_UNIT,
	)
	meat_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.INTERCEPT, 1)),
	]
	var meat_upgraded := DataLibrary._duplicate_modules([meat_module])
	meat_upgraded[0].max_range = 3
	meat_upgraded[0].layers[0].effect.modifiers["intercept_grant_str"] = 2
	var meat_shield := DataLibrary._make_modular_ability(
		&"bruiser_meat_shield", "Meat Shield", [meat_module], meat_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP,
		[], "RANGE 3. Gain STR +2 per interception.", GameEnums.TargetingFlags.ALLY,
	)
	def.abilities.append(meat_shield)

	var frenzy_modules: Array[AbilityModule] = []
	for _i: int in range(3):
		var hit := DataLibrary._module(
			GameEnums.EffectType.DAMAGE, 1, 1, 1, GameEnums.TargetingFlags.ENEMY,
			GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
		)
		if not frenzy_modules.is_empty():
			hit.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
			hit.aim_module_index = 0
		frenzy_modules.append(hit)
	var frenzy_upgraded := DataLibrary._duplicate_modules(frenzy_modules)
	for hit: AbilityModule in frenzy_upgraded:
		hit.legacy_modifiers["frenzy_on_kill_ap"] = 1
	var frenzy := DataLibrary._make_modular_ability(
		&"bruiser_frenzy", "Frenzy", frenzy_modules, frenzy_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"On Kill: Gain 1 AP.", GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(frenzy)

	var roar_module := DataLibrary._module(
		GameEnums.EffectType.PUSH, 1, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_CROSS, 2,
	)
	roar_module.layers = [
		DataLibrary._layer(DataLibrary._status_effect(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 2)),
	]
	var roar_upgraded := DataLibrary._duplicate_modules([roar_module])
	roar_upgraded[0].legacy_modifiers["push_board_items"] = 1
	roar_upgraded[0].legacy_modifiers["item_collision_damage"] = 1
	var guttural_roar := DataLibrary._make_modular_ability(
		&"bruiser_guttural_roar", "Guttural Roar", [roar_module], roar_upgraded,
		1, GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"PUSH 1 all items/coins/scrap. Item collision: ATK 1.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(guttural_roar)

	var headbutt_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 3, 1, 1, GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	headbutt_module.layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.DAMAGE_SELF, 1)),
		DataLibrary._layer(DataLibrary._status_effect(GameEnums.StatusType.STAGGER, 1)),
		DataLibrary._layer(DataLibrary._status_effect_self(GameEnums.StatusType.STAGGER, 1)),
	]
	var headbutt_upgraded := DataLibrary._duplicate_modules([headbutt_module])
	headbutt_upgraded[0].legacy_modifiers["bonus_dmg_pct_max_hp"] = 0.1
	var headbutt := DataLibrary._make_modular_ability(
		&"bruiser_headbutt", "Headbutt", [headbutt_module], headbutt_upgraded,
		1, GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"Deal bonus damage equal to 10% of your Max HP.", GameEnums.TargetingFlags.ENEMY,
	)
	def.abilities.append(headbutt)

	var blood_module := DataLibrary._module(
		GameEnums.EffectType.ADD_STATUS_SELF, 3, 0, 0, GameEnums.TargetingFlags.SELF,
	)
	blood_module.status_type = GameEnums.StatusType.STAT_BUFF_STR
	var blood_upgraded := DataLibrary._duplicate_modules([blood_module])
	blood_upgraded[0].amount = 5
	var blood_boil := DataLibrary._make_modular_ability(
		&"bruiser_blood_boil", "Blood Boil", [blood_module], blood_upgraded,
		1, GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"Spend 10 HP to gain STR +5 instead.", GameEnums.TargetingFlags.SELF,
		GameEnums.CostResource.HP, 5, GameEnums.CostModifier.NONE, 0, -1, 10,
	)
	def.abilities.append(blood_boil)

	var collision_dash := DataLibrary._module(
		GameEnums.EffectType.DASH, 3, 1, 3, GameEnums.TargetingFlags.DASH_LINE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.INTO_OCCUPIED_PUSH,
	)
	collision_dash.keywords = [
		DataLibrary._keyword(GameEnums.AbilityKeywordId.BULLDOZE, 1, 1, false),
	]
	collision_dash.legacy_modifiers["violent_collision_recast"] = 1
	var collision_recast := DataLibrary._module(
		GameEnums.EffectType.MOVE, 3, 1, 3, GameEnums.TargetingFlags.DASH_LINE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	collision_recast.gate = GameEnums.ModuleGate.IF_COLLIDED
	var collision_upgraded := DataLibrary._duplicate_modules([collision_dash, collision_recast])
	var collision_stagger := DataLibrary._effect(GameEnums.EffectType.PUSH, 0)
	collision_stagger.modifiers["stagger_on_collision"] = 1
	collision_upgraded[0].layers = [
		DataLibrary._layer(collision_stagger, GameEnums.LayerCondition.ON_COLLISION),
	]
	var violent_collision := DataLibrary._make_modular_ability(
		&"bruiser_violent_collision", "Violent Collision",
		[collision_dash, collision_recast], collision_upgraded, 1,
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.AP, [],
		"Collisions apply STAGGER (1 turn).", GameEnums.TargetingFlags.DASH_LINE,
	)
	def.abilities.append(violent_collision)

	var whirlwind_module := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 1, 0, 0, GameEnums.TargetingFlags.SELF,
		GameEnums.TargetShape.AOE_SQUARE, 1, GameEnums.StatType.PHYSICAL,
	)
	var whirlwind_upgraded := DataLibrary._duplicate_modules([whirlwind_module])
	whirlwind_upgraded[0].legacy_modifiers["heal_per_target_hit"] = 1
	var crimson_whirlwind := DataLibrary._make_modular_ability(
		&"bruiser_crimson_whirlwind", "Crimson Whirlwind", [whirlwind_module],
		whirlwind_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "HEAL 1 for every target successfully hit.",
		GameEnums.TargetingFlags.SELF,
	)
	def.abilities.append(crimson_whirlwind)

	var belly_teleport := DataLibrary._module(
		GameEnums.EffectType.TELEPORT_CASTER, 0, 1, 2, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.NONE,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	var belly_damage := DataLibrary._module(
		GameEnums.EffectType.DAMAGE, 2, 0, 0, GameEnums.TargetingFlags.TILE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
	)
	belly_damage.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	belly_damage.aim_module_index = 0
	belly_damage.legacy_modifiers["damage_adjacent_on_landing"] = 1
	var belly_upgraded := DataLibrary._duplicate_modules([belly_teleport, belly_damage])
	var belly_push := DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	belly_push.modifiers["belly_flop_push"] = 1
	belly_upgraded[1].layers = [DataLibrary._layer(belly_push)]
	var belly_flop := DataLibrary._make_modular_ability(
		&"bruiser_belly_flop", "Belly Flop", [belly_teleport, belly_damage],
		belly_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Landing applies PUSH 1 to all adjacent enemies.",
		GameEnums.TargetingFlags.TILE,
	)
	belly_flop.range_tiles = 2
	def.abilities.append(belly_flop)

	var breach_module := DataLibrary._module(
		GameEnums.EffectType.DASH, 3, 1, 3, GameEnums.TargetingFlags.DASH_LINE,
		GameEnums.TargetShape.SINGLE, 1, GameEnums.StatType.PHYSICAL,
		GameEnums.MotionMode.TO_EMPTY_TILE,
	)
	breach_module.layers = [DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.DESTROY_OBSTACLE, 0))]
	var breach_upgraded := DataLibrary._duplicate_modules([breach_module])
	breach_upgraded[0].keywords = [DataLibrary._keyword(GameEnums.AbilityKeywordId.PIERCE)]
	breach_upgraded[0].legacy_modifiers["next_attack_pierce"] = 1
	var breaching_dash := DataLibrary._make_modular_ability(
		&"bruiser_breaching_dash", "Breaching Dash", [breach_module],
		breach_upgraded, 1, GameEnums.PlannerGroup.ACTION,
		GameEnums.CostResource.AP, [], "Your next attack this turn gains PIERCE.",
		GameEnums.TargetingFlags.DASH_LINE,
	)
	def.abilities.append(breaching_dash)

	DataLibrary.finalize_unit_abilities(def)
	return def
