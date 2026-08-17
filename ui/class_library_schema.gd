class_name ClassLibrarySchema
extends RefCounted

## Reference data for the Class Library Editor: glossary, enum definitions,
## ability data dumps, and simulation implementation notes.

const KW_COLOR: String = "#FBBF24"
const _ModuleAuthoringRules := preload("res://data/definitions/module_authoring_rules.gd")

static var _ABILITY_CODE_BRANCHES: Dictionary = {
	&"knight_defensive_formation": "Defensive Formation: AOE diamond 3; ADD_STATUS DEF+STURDY on allies via exclude_caster modifier in AbilitySystem.",
	&"knight_shield_bash": "Shield Bash: upgrade adds PUSH 1 on hit (ID branch in ability_system).",
	&"knight_chain_hook": "Chain Hook: upgrade extends PULL range / behavior (ID branch in ability_system).",
	&"knight_bowling_charge": "Bowling Charge upgrade: enemy-enemy chain collision in ability_system (ID branch).",
}


static func manual_keywords() -> Dictionary:
	## Master Bible — Keyword Terminology Glossary (class_abilities.txt §127–217).
	## Player-facing tooltips must match this wording (Keyword Parity Mandate).
	return {
		# Action & utility
		"ATK": "Deal physical damage scaling off the skill's base power, weapon might, and your strength. X = Skill Base Power.",
		"MAG ATK": "Deal magical damage scaling off the skill's base power, weapon might, and your magic. X = Skill Base Power.",
		"AOE ATK": "MAG/physical area attack — damage hits all units in the listed target shape.",
		"HEAL": "Restore health equal to Round Down(X * 10% of the target's Max HP).",
		"MAG HEAL": "Round Down( (X + WPN) * (1 + MAG / 5) * 0.20 + 20% of Target's Max HP ).",
		"SHIELD": "Gain temporary over-HP equal to Round Down(X * 10% of the target's Max HP). Takes priority over normal HP.",
		"CLEANSE": "Instantly remove all negative debuffs and status effects.",
		"PURGE": "Instantly remove all positive buffs and shields.",
		"MOVE": "Move up to X tiles.",
		"PIERCE": "This attack ignores the target's DEF and MAG entirely.",
		"PUSH": "Displace target X tiles away from caster.",
		"PULL": "Displace target X tiles toward caster.",
		"COLLISION": (
			"If pushed into an obstacle or unit, the pushed unit deals collision damage but bounces back "
			+ "to its original tile. Simultaneous collisions: both suffer damage, bounce back, stop one tile early."
		),
		"COUNTER ATTACK": "Counter-attack for listed ATK power (scaled by STR and weapon).",
		"DASH": "Move X tiles in one cardinal direction.",
		"DESTROY OBSTACLE": "Instantly removes a wall, trap, or destructible terrain.",
		"EXPLODE": "Deals damage to all units in adjacent cardinal tiles.",
		"SPAWN": "Summons a unit or construct on the target tile.",
		"SWAP": "Caster and target exchange tile positions.",
		"TELEPORT": "Move instantly, ignoring pathing constraints.",
		"TRAMPLE": (
			"Pass-through movement: deal ATK X to each enemy moved through without displacing them. "
			+ "Caster must end on an open tile."
		),
		"PUSH THROUGH": (
			"Move into an adjacent tile occupied by an ally, pushing them 1 tile forward."
		),
		"THROW BEHIND": "Move target to the empty tile directly behind the caster.",
		"CREATE HAZARD": "Place a hazard or trap on the target tile(s).",
		"BULLDOZE": (
			"Pass-through movement: collision damage with base X and PUSH X on enemies moved through "
			+ "(caster immune to collision). Sideways push while passing; axial PUSH when landing on the victim."
		),
		# Economy
		"AP": "Action Points — spent on class Active Skills and Run.",
		"MOV": "Movement Points — spent on basic walks and class Movement Skills.",
		# Targeting (Manhattan)
		"RANGE": "Maximum target distance in tiles. Line of sight required unless otherwise specified.",
		"RANGE 0": "Anchored to the caster's current tile (Self).",
		"AOE": "Cross-shaped area — expands X tiles from the center.",
		"AOE SQUARE": "Chebyshev square. Shape size is radius: 1 = 3x3, 2 = 5x5.",
		"ARC": "3-tile sweep attack (1x3 or 3x1 perpendicular line).",
		"CONE": "Directional arc expanding outward from the caster for X tiles.",
		"SKEWER": "X tiles in one cardinal direction.",
		"GLOBAL": "Ignores range limits and line of sight.",
		# Stats (skill-line notation)
		"DEF": "Defense — reduces incoming physical damage after SHIELD.",
		"STR": "Strength — scales physical ATK.",
		"MAG": "Magic — scales MAG ATK and mitigates magical damage.",
		"WPN": "Weapon Might — added to ability base power in the damage formula.",
	}


static func manual_keyword_system(kw: String) -> String:
	## Brief sim/code logic for the Class Library glossary "Implementation" column.
	match kw:
		"ATK":
			return (
				"EffectType.DAMAGE → CombatSystem.calculate_scaled_damage(base, scaling_stat) "
				+ "then deal_damage with DEF/MAG mitigation unless PIERCE."
			)
		"MAG ATK":
			return "EffectType.DAMAGE with scaling_stat MAGICAL → MAG scaling path in CombatSystem."
		"AOE ATK":
			return "EffectType.RANGED_EXPLODE or shape-gathered DAMAGE hits each unit in target_shape tiles."
		"HEAL":
			return "EffectType.HEAL → CombatSystem.heal using scaling_stat and EffectData.amount as base power."
		"MAG HEAL":
			return "EffectType.HEAL with MAGICAL scaling_stat; POISON halves final heal amount."
		"SHIELD":
			return "EffectType.ARMOR_UP → CombatSystem.add_armor; blocked when target has VULNERABLE."
		"CLEANSE":
			return "EffectType.CLEANSE strips debuffs (GameEnums.is_debuff) from target.active_statuses."
		"PURGE":
			return "EffectType.PURGE removes buffs and sets target.armor = 0."
		"MOVE":
			return "EffectType.MOVE → MovementSystem.execute_move or execute_skill_walk."
		"PIERCE":
			return "StatusType.PIERCE on attacker: deal_damage zeroes DEF/MAG mitigation and fortitude."
		"PUSH":
			return "EffectType.PUSH → pending_pushes → PhysicsSystem.push; wall/unit block triggers collision damage."
		"PULL":
			return "EffectType.PULL → PhysicsSystem.push toward caster; same collision rules as PUSH."
		"COLLISION":
			return (
				"PhysicsSystem._emit_collision → CombatSystem.deal_collision_damage: "
				+ "base = 1 + floor(excess_push/3) + bonus; scaled by 0.75×(base+WPN)×(1+STR/5)."
			)
		"COUNTER ATTACK":
			return "CombatSystem.counter_attack after qualifying hits; uses calculate_scaled_damage with listed base."
		"DASH":
			return (
				"EffectType.DASH queues PhysicsSystem.dash along straight_line_dir; "
				+ "steps = straight_line_distance to target_coord."
			)
		"DESTROY OBSTACLE":
			return "EffectType.DESTROY_OBSTACLE: deal_damage equal to construct HP if target.definition.is_construct."
		"EXPLODE":
			return "EffectType.EXPLODE damages all units on 4 cardinal neighbors plus caster tile."
		"SPAWN":
			return "EffectType.SPAWN creates unit from EffectData.spawn_unit_id on target tile."
		"SWAP":
			return "EffectType.SWAP → PhysicsSystem.swap: exchanges positions, no collision."
		"TELEPORT":
			return "EffectType.TELEPORT_CASTER moves actor if tile unoccupied and not a wall."
		"TRAMPLE":
			return (
				"EffectType.TRAMPLE: PhysicsSystem.resolve_pass_through_tile on each entered enemy tile "
				+ "(dash or MovementSystem.execute_pass_through_walk). Flat ATK X, tile restore, open end tile."
			)
		"BULLDOZE":
			return (
				"EffectType.BULLDOZE: resolve_pass_through_tile → apply_trample_contact "
				+ "(collision base X + PUSH X). Works on DASH or path walk without DASH."
			)
		"AP":
			return "UnitState.ability.points_left; AbilitySystem._has_resource_for_ability spends on CLASS_SKILL / Run."
		"MOV":
			return "UnitState.movement.points_left; MovementSystem.execute_move deducts per tile; MOVEMENT_SKILL uses MP cost."
		"RANGE":
			return "AbilityData.range_tiles vs GridSystem.manhattan in AbilitySystem.can_use; LOS checks in planning input."
		"RANGE 0":
			return "TargetingFlags.SELF or target_coord == actor.position; no distance required."
		"AOE":
			return "TargetShape.AOE_CROSS + target_shape_size; AbilitySystem gathers cross tiles from center."
		"AOE SQUARE":
			return "TargetShape.AOE_SQUARE; square footprint from target_coord."
		"ARC":
			return "TargetShape.ARC; 3-tile perpendicular sweep from facing."
		"CONE":
			return "TargetShape.CONE; expanding arc tiles from caster toward target."
		"SKEWER":
			return "TargetShape.LINE; straight line of target_shape_size tiles."
		"GLOBAL":
			return "No range cap in can_use when ability marks global targeting (bypasses manhattan check)."
		"DEF":
			return "UnitState.current_defense from base + weapon + stat_def; reduces physical damage in deal_damage."
		"STR":
			return "UnitState.stat_str; scales physical calculate_scaled_damage and collision force."
		"MAG":
			return "UnitState.stat_mag; scales magical damage and magical mitigation."
		"WPN":
			return "equipped_weapon.might added inside calculate_scaled_damage and collision_base formulas."
		_:
			return "No implementation note mapped for this keyword."


static func status_player_tooltip(st: GameEnums.StatusType) -> String:
	## Master Bible status/mechanic definitions for player-facing glossary & hints.
	match st:
		GameEnums.StatusType.STAT_BUFF_STR:
			return "STR +X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.STAT_BUFF_MAG:
			return "MAG +X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.STAT_BUFF_DEF:
			return "DEF +X for the listed duration. X is set by the skill (e.g. DEF +5, or X = your current DEF on Fortify)."
		GameEnums.StatusType.STAT_BUFF_MOV, GameEnums.StatusType.STAT_BUFF_MP:
			return "MOVEMENT +X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.STAT_BUFF_ACC:
			return "ACC +X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return "DEF −X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.STAT_DEBUFF_MOV:
			return "Target MAX MOVEMENT reduced by X for the listed duration."
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return "ACC −X for the listed duration. X is set by the applying skill."
		GameEnums.StatusType.BURN:
			return "Take exactly X unmitigated damage at the start of the turn. Leaves FIRE terrain if moving."
		GameEnums.StatusType.BLEED:
			return "Take exactly X unmitigated damage at the end of the turn. Moving costs +1 MOV per tile."
		GameEnums.StatusType.POISON:
			return (
				"Take unmitigated damage equal to 10% of Max HP (rounded up) at the start of the turn. "
				+ "Healing received is reduced by 50% (rounded down)."
			)
		GameEnums.StatusType.WEAKEN:
			return "Target suffers −2 STR and −2 MAG for the duration."
		GameEnums.StatusType.VULNERABLE:
			return (
				"Target loses all Push Mitigation (pushed maximum distance by collisions) "
				+ "and cannot gain SHIELD."
			)
		GameEnums.StatusType.STAGGER:
			return "Target loses their Phase Action for the current/next round."
		GameEnums.StatusType.STAGGER:
			return "Target's Action Points (AP) are reduced by 1 for their next turn."
		GameEnums.StatusType.ROOT:
			return (
				"Target's MOVEMENT becomes 0. Breaks instantly if the target takes any damage. "
				+ "They can still attack if in range."
			)
		GameEnums.StatusType.SILENCE:
			return "Cannot cast Active Skills. Can only use standard Movement and basic physical attacks."
		GameEnums.StatusType.TAUNT:
			return "Target is forced to target the Taunter with their next offensive action."
		GameEnums.StatusType.BLIND:
			return "Target's maximum RANGE is reduced to 1."
		GameEnums.StatusType.PACIFY:
			return "Cannot use offensive skills or basic attacks for the duration. Breaks instantly on damage."
		GameEnums.StatusType.FEAR:
			return "Target must spend their entire MOVEMENT running directly away from the source on their next turn."
		GameEnums.StatusType.CONFUSION:
			return "Target is forced to target the nearest unit (friend or foe) other than the caster."
		GameEnums.StatusType.PIERCE:
			return "This attack ignores the target's DEF and MAG entirely."
		GameEnums.StatusType.GHOST:
			return "Unit can move through enemy-occupied tiles and traps/hazards without penalty (intangible)."
		GameEnums.StatusType.TRAMPLE:
			return (
				"Unit can move through enemy tiles. Per skill text, passing through an enemy triggers "
				+ "the effect as a hit."
			)
		GameEnums.StatusType.STEALTH:
			return "Unit cannot be targeted by ranged attacks or skills (Range > 1)."
		GameEnums.StatusType.INTERCEPT:
			return "Redirect a percentage of incoming damage from an adjacent ally to this unit."
		GameEnums.StatusType.MARK:
			return "Target takes extra damage from specific sources or grants bonuses to attackers hitting them."
		GameEnums.StatusType.STURDY:
			return "Immune to PUSH and PULL effects."
		GameEnums.StatusType.INVULNERABLE:
			return "Immune to all damage, debuffs, and positional manipulation."
		GameEnums.StatusType.AIRBORNE:
			return "Standard movement ignores all ground hazards, traps, difficult terrain, and Chasms."
		GameEnums.StatusType.CANTO:
			return (
				"After executing a Skill or basic attack, your Max MOV is fully refunded, "
				+ "allowing you to move again this turn."
			)
		GameEnums.StatusType.POLYMORPH:
			return (
				"Target is transformed into a harmless creature (0 Base ATK, 1 MOV) for the duration. "
				+ "Cannot use Active Skills. Bosses are immune."
			)
		GameEnums.StatusType.THORNS:
			return "Reflects X% of damage dealt back to melee attackers (rounded down)."
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "Target DEF halved next turn (rounded up)."
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "Until next turn, when hit in melee, counter-attack for ATK 2. [+] Counter-attacks apply PUSH 1."
		GameEnums.StatusType.RETALIATION_INFINITE_RANGE:
			return "Retaliation Protocol counters ignore range limits this turn (Phalanx [+] upgrade)."
		GameEnums.StatusType.INDOMITABLE_WILL:
			return "Convert missing HP into SHIELD for 2 turns. [+] When SHIELD expires, gain +2 STR."
		GameEnums.StatusType.RUNNING:
			return "Run — costs 1 AP, extends movement for this turn's walk without consuming the Action slot."
		GameEnums.StatusType.ELECTRIFIED:
			return "Incoming damage gains +1 raw before mitigation."
		GameEnums.StatusType.WEAK_TRAP:
			return "Trap marker — triggers when stepped on (skill-defined effect)."
		_:
			return GameEnums.StatusType.keys()[st].capitalize().replace("_", " ")


## Derived click-condition line from one authored module filter.
static func module_target_filter_line(module: AbilityModule) -> String:
	if module == null or module.target_filter == GameEnums.ModuleTargetFilter.NONE:
		return ""
	match module.target_filter:
		GameEnums.ModuleTargetFilter.HP:
			if module.target_filter_hp == GameEnums.ModuleTargetFilterHp.BELOW_CASTER_HP:
				return "TARGET HP MUST BE BELOW CASTER HP"
			return "TARGET HP MUST BE BELOW %d%%" % module.target_filter_hp_pct
		GameEnums.ModuleTargetFilter.STATUS:
			match module.target_filter_status_mode:
				GameEnums.ModuleTargetFilterStatus.ANY_DEBUFF:
					return "TARGET MUST HAVE A DEBUFF"
				GameEnums.ModuleTargetFilterStatus.NOT_ACTED:
					return "TARGET MUST NOT HAVE ACTED"
				_:
					var names: PackedStringArray = PackedStringArray()
					if module.target_filter_status != GameEnums.StatusType.NONE:
						names.append(GameEnums.StatusType.keys()[module.target_filter_status])
					if module.target_filter_status_or != GameEnums.StatusType.NONE:
						names.append(GameEnums.StatusType.keys()[module.target_filter_status_or])
					if names.is_empty():
						return "TARGET MUST HAVE A STATUS"
					return "TARGET MUST HAVE %s" % " OR ".join(names)
		GameEnums.ModuleTargetFilter.STAT:
			return "TARGET CON MUST BE ≤ CASTER STR"
		GameEnums.ModuleTargetFilter.OCCUPANT:
			match module.target_filter_occupant:
				GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT:
					return "TARGET MUST BE AN ALLY CONSTRUCT"
				GameEnums.ModuleTargetFilterOccupant.ADJACENT_CONSTRUCT:
					return "TARGET TILE MUST BE ADJACENT TO AN ALLY CONSTRUCT"
				GameEnums.ModuleTargetFilterOccupant.ITEM_OR_CORPSE:
					return "TARGET MUST BE AN ITEM OR CORPSE"
				GameEnums.ModuleTargetFilterOccupant.ALLY_CORPSE:
					return "TARGET MUST BE AN ALLY CORPSE"
				GameEnums.ModuleTargetFilterOccupant.DRAGGED_ENEMY:
					return "TARGET MUST BE THE DRAGGED ENEMY"
				_:
					return ""
		_:
			return ""


## Derived click-condition line from the first authored module filter.
static func ability_target_filter_line(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	var upgraded: bool = unit != null and unit.is_ability_upgraded(ability.id)
	var modules: Array[AbilityModule] = ability.get_active_modules(upgraded)
	for module: AbilityModule in modules:
		var line: String = module_target_filter_line(module)
		if line != "":
			return line
	return ""


## Master Bible skill lines (class_abilities.txt) — overrides generated effect text when present.
static func bible_ability_effect_line(ability: AbilityData) -> String:
	if ability == null:
		return ""
	match ability.id:
		&"knight_shield_bash":
			return "ATK 1 | PUSH 2"
		&"knight_phalanx_stance":
			return "DEF +5 | STURDY"
		&"knight_taunting_strike":
			return "ATK 1 | PULL 1 | Apply TAUNT"
		&"knight_seismic_stomp":
			return "ATK 2 | PURGE"
		&"knight_fortify":
			return "DEF +X (X = caster DEF)"
		&"knight_bowling_charge":
			return "DASH 3 | BULLDOZE 1"
		&"knight_iron_grip":
			return "Apply ROOT | DEF halved next turn"
		&"knight_redirect_strike":
			return "RANGE 2 | Apply INTERCEPT 50%"
		&"knight_indomitable_will":
			return "SHIELD = missing HP (2 turns)"
		&"knight_retaliation_protocol":
			return "Counter ATK 2 on melee hit"
		&"knight_shield_slam":
			return "ATK 2 | PUSH 2 | If adjacent at cast: ATK +2"
		&"knight_defensive_formation":
			return "DEF +2 | STURDY (immune PUSH/PULL)"
		&"knight_chain_hook":
			return "ATK 1 | PULL 2"
		&"knight_swap":
			return "SWAP"
		&"bruiser_push_through":
			return "PUSH THROUGH"
		_:
			return ""


static func bible_ability_targeting_label(ability: AbilityData) -> String:
	if ability == null:
		return ""
	var authored_flags: int = 0
	for module: AbilityModule in ability.get_active_modules():
		if module == null:
			continue
		authored_flags |= module.targeting_flags
		if module.primary_type == GameEnums.EffectType.DASH:
			return "DASH %d" % module.amount
		if (
			module.aim_binding == GameEnums.AimBinding.NEW_AIM
			and not AbilityModuleBridge.is_motion_type(module.primary_type)
			and module.max_range > 0
		):
			return "RANGE %d" % module.max_range
	if authored_flags & GameEnums.TargetingFlags.SELF:
		var self_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
		for module: AbilityModule in ability.get_active_modules():
			if module != null and module.aim_binding == GameEnums.AimBinding.NEW_AIM:
				self_shape = module.target_shape
				break
		if self_shape != GameEnums.TargetShape.SINGLE:
			return "RANGE 0"
		return "SELF"
	return ""


static func bible_ability_aoe_label(ability: AbilityData) -> String:
	if ability == null or ability.target_shape == GameEnums.TargetShape.SINGLE:
		return ""
	if AbilitySystem.has_pass_through_effects(ability) or AbilitySystem.ability_has_movement_effect(ability):
		return ""
	match ability.id:
		&"knight_seismic_stomp":
			return "AOE 1"
		&"knight_defensive_formation":
			return "AOE 3"
		_:
			pass
	match ability.target_shape:
		GameEnums.TargetShape.AOE_SQUARE:
			var n: int = ability.target_shape_size
			return "AOE %dx%d" % [n * 2 + 1, n * 2 + 1]
		GameEnums.TargetShape.AOE_DIAMOND:
			return "AOE %d" % ability.target_shape_size
		GameEnums.TargetShape.LINE:
			return "SKEWER %d" % ability.target_shape_size
		_:
			return "AOE"


static func enum_definitions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: String in GameEnums.AbilityKind.keys():
		out.append({
			"category": "AbilityKind",
			"name": k,
			"tooltip": _ability_kind_tooltip(k),
			"system": _ability_kind_system(k),
		})
	for k: String in GameEnums.TargetingMode.keys():
		out.append({
			"category": "TargetingMode",
			"name": k,
			"tooltip": _targeting_mode_tooltip(k),
			"system": _targeting_mode_system(k),
		})
	for k: String in GameEnums.TargetShape.keys():
		out.append({
			"category": "TargetShape",
			"name": k,
			"tooltip": _target_shape_tooltip(k),
			"system": _target_shape_system(k),
		})
	for k: String in GameEnums.EffectType.keys():
		out.append({
			"category": "EffectType",
			"name": k,
			"tooltip": _effect_type_tooltip(k),
			"system": _effect_type_system(k),
		})
	for k: String in GameEnums.StatusType.keys():
		if k == "NONE":
			continue
		var st: GameEnums.StatusType = GameEnums.StatusType[k]
		out.append({
			"category": "StatusType",
			"name": k,
			"tooltip": status_player_tooltip(st),
			"system": _status_system(st),
		})
	for k: String in GameEnums.PresentationAnim.keys():
		out.append({
			"category": "PresentationAnim",
			"name": k,
			"tooltip": k.capitalize(),
			"system": "Presentation layer anim hint when presentation_key is empty.",
		})
	for k: String in GameEnums.StatType.keys():
		if k == "NONE":
			continue
		out.append({
			"category": "StatType",
			"name": k,
			"tooltip": k,
			"system": _stat_type_system(k),
		})
	return out


static func passive_preview_bbcode(passive: PassiveData) -> String:
	if passive == null:
		return ""
	var parts: Array[String] = []
	if not passive.description.is_empty():
		parts.append("[b]Base[/b]\n%s" % passive_bbcode(passive.description))
	if not passive.upgraded_description.is_empty():
		parts.append("[b]Upgraded[/b]\n%s" % passive_bbcode(passive.upgraded_description))
	return scale_bbcode("\n\n".join(parts))


static func passive_data_dump(passive: PassiveData) -> String:
	if passive == null:
		return ""
	return "id: %s\ndisplay_name: %s\ndescription: %s\nupgraded_description: %s" % [
		String(passive.id),
		passive.display_name,
		passive.description,
		passive.upgraded_description,
	]


static func passive_implementation_notes(passive: PassiveData) -> String:
	if passive == null:
		return ""
	var parts: Array[String] = []
	parts.append(
		"Passives are data-only: description / upgraded_description drive player tooltips via passive_preview_bbcode()."
	)
	parts.append(
		"Combat systems may branch on passive.id for bespoke behavior; keyword text in descriptions is not auto-executed."
	)
	parts.append("Upgraded text replaces base in UI when the unit has the class promotion upgrade.")
	return "\n".join(parts)


static func scale_bbcode(body: String) -> String:
	if body.is_empty():
		return ""
	var body_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY)
	return "[font_size=%d]%s[/font_size]" % [body_px, body]


static func passive_bbcode(text: String) -> String:
	if text.is_empty():
		return ""
	var keywords: Dictionary = manual_keywords()
	var out: String = text
	var keys: Array = keywords.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for kw: String in keys:
		var rx := RegEx.new()
		if rx.compile("\\b%s\\b" % kw) != OK:
			continue
		out = rx.sub(out, "[hint=\"%s\"][color=%s]%s[/color][/hint]" % [keywords[kw], KW_COLOR, kw], true)
	return out


static func ability_data_dump(ability: AbilityData) -> String:
	if ability == null:
		return ""
	var lines: Array[String] = []
	var tag_names := PackedStringArray()
	for tag: StringName in ability.tags:
		tag_names.append(String(tag))
	lines.append("id: %s" % String(ability.id))
	lines.append("display_name: %s" % ability.display_name)
	lines.append("planner_group: %s" % GameEnums.PlannerGroup.keys()[ability.planner_group])
	if ability.upgraded_planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		lines.append("upgraded_planner_group: PRE_MOVE")
	lines.append("tags: %s" % ", ".join(tag_names))
	lines.append("primary_resource: %s" % GameEnums.CostResource.keys()[ability.primary_resource])
	lines.append("primary_value: %d" % ability.primary_value)
	lines.append("targeting_flags: %s" % targeting_flags_dump(ability))
	lines.append("uses_per_combat: %d" % ability.uses_per_combat)
	if ability.once_per_turn:
		lines.append("once_per_turn: true")
	lines.append("presentation_key: %s" % String(ability.presentation_key))
	lines.append("presentation_anim: %s" % GameEnums.PresentationAnim.keys()[ability.presentation_anim])
	if not ability.upgrade_description.is_empty():
		lines.append("upgrade_description: %s" % ability.upgrade_description)
	lines.append("--- modules (%d) ---" % ability.modules.size())
	lines.append(modules_summary_bbcode(ability))
	if not ability.upgraded_modules.is_empty():
		lines.append("--- upgraded_modules (%d) ---" % ability.upgraded_modules.size())
		for i: int in ability.upgraded_modules.size():
			lines.append(_module_dump_line(i, ability.upgraded_modules[i]))
	return "\n".join(lines)


static func ability_implementation_notes(ability: AbilityData) -> String:
	if ability == null:
		return ""
	var parts: Array[String] = []
	parts.append("Planning: %s" % _planning_note(ability))
	parts.append("Targeting: AbilitySystem.target_passes_mode via targeting_flags bitmask.")
	if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		parts.append("Economy: spends %s (%d); PRE_MOVE timeline bucket; no action slot." % [
			GameEnums.CostResource.keys()[ability.primary_resource],
			ability.primary_value,
		])
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		parts.append("Economy: PRE_MOVE only — spends 1 AP on move (uses_run); does not consume the Action slot.")
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		parts.append("Economy: consumes the Action slot; ends planning for this unit.")
	else:
		parts.append("Economy: spends %s (%d); ACTION timeline bucket; consumes action slot." % [
			GameEnums.CostResource.keys()[ability.primary_resource],
			ability.primary_value,
		])
	for module: AbilityModule in ability.get_active_modules():
		if module != null:
			parts.append(_module_impl_note(module))
	if ability.id in _ABILITY_CODE_BRANCHES:
		parts.append("⚠ CODE BRANCH: %s" % _ABILITY_CODE_BRANCHES[ability.id])
	return "\n".join(parts)


static func in_game_ability_bbcode(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	CombatUiFormatters.configure_body_font(ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	var body_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY)
	var body: String = CombatUiFormatters.ability_effect_bbcode(ability, unit)
	return "[font_size=%d]%s[/font_size]" % [body_px, body]


static func targeting_flags_dump(ability: AbilityData) -> String:
	if ability == null:
		return "none"
	var authored_flags: int = 0
	for module: AbilityModule in ability.get_active_modules():
		if module != null:
			authored_flags |= module.targeting_flags
	var labels: PackedStringArray = []
	if authored_flags & GameEnums.TargetingFlags.SELF:
		labels.append("Self")
	if authored_flags & GameEnums.TargetingFlags.ALLY:
		labels.append("Ally")
	if authored_flags & GameEnums.TargetingFlags.ENEMY:
		labels.append("Enemy")
	if authored_flags & GameEnums.TargetingFlags.TILE:
		labels.append("Tile")
	if authored_flags & GameEnums.TargetingFlags.DASH_LINE:
		labels.append("Dash line")
	if authored_flags & GameEnums.TargetingFlags.EXCLUDE_CASTER:
		labels.append("Exclude caster")
	if labels.is_empty():
		return "none"
	return ", ".join(labels)


static func targeting_flags_hint(ability: AbilityData) -> String:
	var dump := targeting_flags_dump(ability)
	if dump == "none":
		return ""
	return " | %s" % dump


static func duplicate_effect(src: EffectData) -> EffectData:
	var e := EffectData.new()
	e.type = src.type
	e.amount = src.amount
	e.status_type = src.status_type
	e.status_duration = src.status_duration
	e.scaling_stat = src.scaling_stat
	e.bonus_if_adjacent_at_cast = src.bonus_if_adjacent_at_cast
	e.def_debuff_before_damage = src.def_debuff_before_damage
	e.spawn_unit_id = src.spawn_unit_id
	e.modifiers = src.modifiers.duplicate(true)
	return e


static func keyword_to_dict(src: AbilityKeyword) -> Dictionary:
	if src == null:
		return {}
	return {
		"keyword_id": src.keyword_id,
		"amount": src.amount,
		"push_amount": src.push_amount,
		"emit_as_effect": src.emit_as_effect,
	}


static func keyword_from_dict(data: Dictionary) -> AbilityKeyword:
	var keyword := AbilityKeyword.new()
	keyword.keyword_id = int(data.get("keyword_id", keyword.keyword_id))
	keyword.amount = int(data.get("amount", keyword.amount))
	keyword.push_amount = int(data.get("push_amount", keyword.push_amount))
	keyword.emit_as_effect = bool(data.get("emit_as_effect", keyword.emit_as_effect))
	return keyword


static func layer_to_dict(src: AbilityLayer) -> Dictionary:
	if src == null:
		return {}
	return {
		"condition": src.condition,
		"object_collision_stagger": src.object_collision_stagger,
		"enemy_collision_stagger_both": src.enemy_collision_stagger_both,
		"weapon_scaled": src.weapon_scaled,
		"buff_per_destroyed_object": src.buff_per_destroyed_object,
		"stagger_on_collision": src.stagger_on_collision,
		"intercept_grant_str": src.intercept_grant_str,
		"push_collision_pierce": src.push_collision_pierce,
		"push_collision_damage": src.push_collision_damage,
		"difficult_terrain_created": src.difficult_terrain_created,
		"rooted_push_bleed_weapon": src.rooted_push_bleed_weapon,
		"grapple_pass_through_damage": src.grapple_pass_through_damage,
		"ignite_flammable_terrain": src.ignite_flammable_terrain,
		"ally_damage_zero": src.ally_damage_zero,
		"trap_vulnerable": src.trap_vulnerable,
		"crossing_blind": src.crossing_blind,
		"trap_def_debuff": src.trap_def_debuff,
		"range_one_damage_multiplier": src.range_one_damage_multiplier,
		"elemental_surface": src.elemental_surface,
		"reaction_terrain": src.reaction_terrain,
		"reaction_steam_splash": src.reaction_steam_splash,
		"reaction_steam_splash_size": src.reaction_steam_splash_size,
		"reaction_steam_splash_damage": src.reaction_steam_splash_damage,
		"set_max_move": src.set_max_move,
		"arcane_trail": src.arcane_trail,
		"creation_adjacent_damage": src.creation_adjacent_damage,
		"terrain_id": src.terrain_id,
		"hazard_duration": src.hazard_duration,
		"effect": effect_to_dict(src.effect) if src.effect != null else {},
	}


static func layer_from_dict(data: Dictionary) -> AbilityLayer:
	var layer := AbilityLayer.new()
	layer.condition = int(data.get("condition", layer.condition))
	layer.object_collision_stagger = bool(
		data.get("object_collision_stagger", layer.object_collision_stagger)
	)
	layer.enemy_collision_stagger_both = bool(
		data.get("enemy_collision_stagger_both", layer.enemy_collision_stagger_both)
	)
	layer.weapon_scaled = bool(data.get("weapon_scaled", layer.weapon_scaled))
	layer.buff_per_destroyed_object = int(
		data.get("buff_per_destroyed_object", layer.buff_per_destroyed_object)
	)
	layer.stagger_on_collision = bool(data.get("stagger_on_collision", layer.stagger_on_collision))
	layer.intercept_grant_str = int(data.get("intercept_grant_str", layer.intercept_grant_str))
	layer.push_collision_pierce = bool(data.get("push_collision_pierce", layer.push_collision_pierce))
	layer.push_collision_damage = int(data.get("push_collision_damage", layer.push_collision_damage))
	layer.difficult_terrain_created = bool(
		data.get("difficult_terrain_created", layer.difficult_terrain_created)
	)
	layer.rooted_push_bleed_weapon = bool(
		data.get("rooted_push_bleed_weapon", layer.rooted_push_bleed_weapon)
	)
	layer.grapple_pass_through_damage = int(
		data.get("grapple_pass_through_damage", layer.grapple_pass_through_damage)
	)
	layer.ignite_flammable_terrain = bool(
		data.get("ignite_flammable_terrain", layer.ignite_flammable_terrain)
	)
	layer.ally_damage_zero = bool(data.get("ally_damage_zero", layer.ally_damage_zero))
	layer.trap_vulnerable = bool(data.get("trap_vulnerable", layer.trap_vulnerable))
	layer.crossing_blind = bool(data.get("crossing_blind", layer.crossing_blind))
	layer.trap_def_debuff = int(data.get("trap_def_debuff", layer.trap_def_debuff))
	layer.range_one_damage_multiplier = float(
		data.get("range_one_damage_multiplier", layer.range_one_damage_multiplier)
	)
	layer.elemental_surface = bool(data.get("elemental_surface", layer.elemental_surface))
	layer.reaction_terrain = StringName(str(data.get("reaction_terrain", String(layer.reaction_terrain))))
	layer.reaction_steam_splash = bool(data.get("reaction_steam_splash", layer.reaction_steam_splash))
	layer.reaction_steam_splash_size = int(
		data.get("reaction_steam_splash_size", layer.reaction_steam_splash_size)
	)
	layer.reaction_steam_splash_damage = int(
		data.get("reaction_steam_splash_damage", layer.reaction_steam_splash_damage)
	)
	layer.set_max_move = int(data.get("set_max_move", layer.set_max_move))
	layer.arcane_trail = bool(data.get("arcane_trail", layer.arcane_trail))
	layer.creation_adjacent_damage = int(
		data.get("creation_adjacent_damage", layer.creation_adjacent_damage)
	)
	layer.terrain_id = StringName(str(data.get("terrain_id", String(layer.terrain_id))))
	layer.hazard_duration = int(data.get("hazard_duration", layer.hazard_duration))
	var effect_data: Variant = data.get("effect", {})
	if effect_data is Dictionary and not (effect_data as Dictionary).is_empty():
		layer.effect = EffectData.new()
		apply_effect_dict(layer.effect, effect_data as Dictionary)
	return layer


static func extras_to_array(src: AbilityModule) -> Array:
	var extras: Array = []
	if src == null:
		return extras
	for extra: AbilityExtraRule in src.extras:
		if extra == null:
			continue
		extras.append({
			"id": extra.id,
			"value": extra.value,
			"override_key": extra.override_key,
		})
	return extras


static func extra_from_dict(data: Dictionary) -> AbilityExtraRule:
	var extra := AbilityExtraRule.new()
	extra.id = int(data.get("id", extra.id)) as AbilityExtraRule.Id
	extra.value = data.get("value", extra.value)
	extra.override_key = str(data.get("override_key", extra.override_key))
	if extra.id != AbilityExtraRule.Id.NONE:
		extra.override_key = ""
	return extra


static func module_to_dict(
	src: AbilityModule,
	planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION,
	module_index: int = 0,
) -> Dictionary:
	if src == null:
		return {}
	var keywords: Array = []
	for keyword: AbilityKeyword in src.keywords:
		keywords.append(keyword_to_dict(keyword))
	var layers: Array = []
	for layer: AbilityLayer in src.layers:
		layers.append(layer_to_dict(layer))
	var out := {
		"primary_type": src.primary_type,
		"amount": src.amount,
		"aim_binding": src.aim_binding,
		"targeting_flags": src.targeting_flags,
		"keywords": keywords,
		"layers": layers,
		"gate": src.gate,
		"presentation_anim": src.presentation_anim,
		"exclude_caster": src.exclude_caster,
		"terrain_id": String(src.terrain_id),
		"hazard_duration": src.hazard_duration,
		"hazard_status": src.hazard_status,
		"bonus_dmg_from_occupied": src.bonus_dmg_from_occupied,
		"bonus_dmg_per_10_hp": src.bonus_dmg_per_10_hp,
		"bonus_dmg_pct_max_hp": src.bonus_dmg_pct_max_hp,
		"heal_if_targets_gte": src.heal_if_targets_gte,
		"bounce_count": src.bounce_count,
		"bounce_range": src.bounce_range,
		"buff_on_push": src.buff_on_push,
		"frenzy_on_kill_ap": src.frenzy_on_kill_ap,
		"push_board_items": src.push_board_items,
		"item_collision_damage": src.item_collision_damage,
		"item_collision_str_div": src.item_collision_str_div,
		"item_collision_vulnerable": src.item_collision_vulnerable,
		"violent_collision_recast": src.violent_collision_recast,
		"next_attack_strength": src.next_attack_strength,
		"next_attack_bleed_weapon": src.next_attack_bleed_weapon,
		"next_turn": src.next_turn,
		"preserve_facing": src.preserve_facing,
		"ignore_zoc": src.ignore_zoc,
		"next_ranged_attack_strength": src.next_ranged_attack_strength,
		"root_break_on_damage": src.root_break_on_damage,
		"skewer": src.skewer,
		"bounce_walls_45": src.bounce_walls_45,
		"spread_status_adjacent": src.spread_status_adjacent,
		"grapple_wall_pull_self": src.grapple_wall_pull_self,
		"grapple_pass_through_damage": src.grapple_pass_through_damage,
		"destroy_terrain": src.destroy_terrain,
		"ignite_flammable_terrain": src.ignite_flammable_terrain,
		"allies_range_bonus": src.allies_range_bonus,
		"allies_pierce": src.allies_pierce,
		"prevent_stealth_teleport": src.prevent_stealth_teleport,
		"allow_friendly_target": src.allow_friendly_target,
		"ally_damage_zero": src.ally_damage_zero,
		"terrain_hazard_status": src.terrain_hazard_status,
		"trap_damage": src.trap_damage,
		"trap_bleed_weapon": src.trap_bleed_weapon,
		"trap_vulnerable": src.trap_vulnerable,
		"crossing_weapon_damage": src.crossing_weapon_damage,
		"crossing_mov_penalty": src.crossing_mov_penalty,
		"crossing_blind": src.crossing_blind,
		"trap_def_debuff": src.trap_def_debuff,
		"strip_stealth": src.strip_stealth,
		"limit_once_per_turn": src.limit_once_per_turn,
		"range_one_damage_multiplier": src.range_one_damage_multiplier,
		"halve_target_def_one_turn": src.halve_target_def_one_turn,
		"armor_explosion_atk": src.armor_explosion_atk,
		"bonus_atk_vs_fear_or_lower_movement": src.bonus_atk_vs_fear_or_lower_movement,
		"on_kill_max_move": src.on_kill_max_move,
		"next_turn_max_move": src.next_turn_max_move,
		"upgraded_trample": src.upgraded_trample,
		"brace_attacker_stagger": src.brace_attacker_stagger,
		"pull_until_adjacent": src.pull_until_adjacent,
		"pull_self_if_rooted": src.pull_self_if_rooted,
		"paired_ally_charge": src.paired_ally_charge,
		"paired_ally_strike_atk": src.paired_ally_strike_atk,
		"on_kill_both_ap": src.on_kill_both_ap,
		"vault_obstacle_or_gap_only": src.vault_obstacle_or_gap_only,
		"landing_adjacent_push": src.landing_adjacent_push,
		"landing_adjacent_push_stagger": src.landing_adjacent_push_stagger,
		"line_breaker": src.line_breaker,
		"bonus_per_enemy_passed": src.bonus_per_enemy_passed,
		"create_trampled_terrain": src.create_trampled_terrain,
		"blink": src.blink,
		"leave_elemental_surface": src.leave_elemental_surface,
		"reaction_terrain": src.reaction_terrain,
		"reaction_damage": src.reaction_damage,
		"bounce_surface_chain": src.bounce_surface_chain,
		"lightning_surface": src.lightning_surface,
		"strike_all_surface": src.strike_all_surface,
		"teleport_visible": src.teleport_visible,
		"delayed_next_turn": src.delayed_next_turn,
		"create_crater": src.create_crater,
		"pull_to_center": src.pull_to_center,
		"pull_surfaces": src.pull_surfaces,
		"mana_shield": src.mana_shield,
		"mana_shield_casting": src.mana_shield_casting,
		"destroy_corpse_on_kill": src.destroy_corpse_on_kill,
		"kill_grant_ap": src.kill_grant_ap,
		"utility_only": src.utility_only,
		"elemental_surge": src.elemental_surge,
		"elemental_surge_ap": src.elemental_surge_ap,
		"construct_hp_pct": src.construct_hp_pct,
		"density_shift": src.density_shift,
		"ignore_target_magic_pct": src.ignore_target_magic_pct,
		"creation_adjacent_damage": src.creation_adjacent_damage,
		"apply_weaken_enemy": src.apply_weaken_enemy,
		"extras": extras_to_array(src),
	}
	if _ModuleAuthoringRules.module_uses_phase(planner_group):
		out["execution_phase"] = src.execution_phase
	if _ModuleAuthoringRules.module_uses_range(src):
		out["min_range"] = src.min_range
		out["max_range"] = src.max_range
	if _ModuleAuthoringRules.module_uses_los(src):
		out["requires_los"] = src.requires_los
	if _ModuleAuthoringRules.module_uses_range_origin(src, module_index):
		out["range_origin"] = src.range_origin
	if _ModuleAuthoringRules.module_uses_shape(src):
		out["target_shape"] = src.target_shape
		if _ModuleAuthoringRules.module_uses_shape_size(src):
			out["target_shape_size"] = src.target_shape_size
	if GameEnums.effect_type_uses_module_scaling(src.primary_type):
		out["scaling_stat"] = src.scaling_stat
	if GameEnums.effect_type_applies_status(src.primary_type):
		out["status_type"] = src.status_type
		out["status_duration"] = src.status_duration
	if AbilityModuleBridge.is_motion_type(src.primary_type):
		out["motion_mode"] = src.motion_mode
	if src.primary_type == GameEnums.EffectType.DAMAGE:
		if src.bonus_if_adjacent_at_cast != 0:
			out["bonus_if_adjacent_at_cast"] = src.bonus_if_adjacent_at_cast
		if src.def_debuff_before_damage != 0:
			out["def_debuff_before_damage"] = src.def_debuff_before_damage
		if src.hit_count != 1:
			out["hit_count"] = src.hit_count
	if (
		GameEnums.effect_type_uses_spawn_unit(src.primary_type)
		and src.spawn_unit_id != StringName()
	):
		out["spawn_unit_id"] = String(src.spawn_unit_id)
	if src.aim_binding == GameEnums.AimBinding.SAME_AS_MODULE_N:
		out["aim_module_index"] = src.aim_module_index
	if src.target_filter != GameEnums.ModuleTargetFilter.NONE:
		out["target_filter"] = src.target_filter
		if _ModuleAuthoringRules.module_uses_target_filter_hp(src):
			out["target_filter_hp"] = src.target_filter_hp
			if _ModuleAuthoringRules.module_uses_target_filter_hp_pct(src):
				out["target_filter_hp_pct"] = src.target_filter_hp_pct
		if _ModuleAuthoringRules.module_uses_target_filter_status(src):
			out["target_filter_status_mode"] = src.target_filter_status_mode
			if _ModuleAuthoringRules.module_uses_target_filter_status_type(src):
				out["target_filter_status"] = src.target_filter_status
				if src.target_filter_status_or != GameEnums.StatusType.NONE:
					out["target_filter_status_or"] = src.target_filter_status_or
		if _ModuleAuthoringRules.module_uses_target_filter_stat(src):
			out["target_filter_stat"] = src.target_filter_stat
		if _ModuleAuthoringRules.module_uses_target_filter_occupant(src):
			out["target_filter_occupant"] = src.target_filter_occupant
	return out


static func modules_to_dict_array(
	modules: Array[AbilityModule],
	planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION,
) -> Array:
	var out: Array = []
	for index: int in modules.size():
		out.append(module_to_dict(modules[index], planner_group, index))
	return out


static func apply_module_dict(dst: AbilityModule, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.execution_phase = int(data.get("execution_phase", dst.execution_phase))
	dst.primary_type = int(data.get("primary_type", dst.primary_type))
	dst.amount = int(data.get("amount", dst.amount))
	dst.status_type = int(data.get("status_type", dst.status_type))
	dst.status_duration = int(data.get("status_duration", dst.status_duration))
	dst.scaling_stat = int(data.get("scaling_stat", dst.scaling_stat))
	dst.spawn_unit_id = StringName(String(data.get("spawn_unit_id", String(dst.spawn_unit_id))))
	dst.motion_mode = int(data.get("motion_mode", dst.motion_mode))
	dst.min_range = int(data.get("min_range", dst.min_range))
	dst.max_range = int(data.get("max_range", dst.max_range))
	dst.requires_los = bool(data.get("requires_los", dst.requires_los))
	dst.range_origin = int(data.get("range_origin", dst.range_origin))
	dst.target_shape = int(data.get("target_shape", dst.target_shape))
	dst.target_shape_size = int(data.get("target_shape_size", dst.target_shape_size))
	dst.aim_binding = int(data.get("aim_binding", dst.aim_binding))
	dst.aim_module_index = int(data.get("aim_module_index", dst.aim_module_index))
	dst.targeting_flags = int(data.get("targeting_flags", dst.targeting_flags))
	dst.gate = int(data.get("gate", dst.gate))
	dst.target_filter = int(data.get("target_filter", dst.target_filter))
	dst.target_filter_hp = int(data.get("target_filter_hp", dst.target_filter_hp))
	dst.target_filter_hp_pct = int(data.get("target_filter_hp_pct", dst.target_filter_hp_pct))
	dst.target_filter_status_mode = int(
		data.get("target_filter_status_mode", dst.target_filter_status_mode)
	)
	dst.target_filter_status = int(data.get("target_filter_status", dst.target_filter_status))
	dst.target_filter_status_or = int(
		data.get("target_filter_status_or", dst.target_filter_status_or)
	)
	dst.target_filter_stat = int(data.get("target_filter_stat", dst.target_filter_stat))
	dst.target_filter_occupant = int(data.get("target_filter_occupant", dst.target_filter_occupant))
	dst.presentation_anim = int(data.get("presentation_anim", dst.presentation_anim))
	dst.bonus_if_adjacent_at_cast = int(
		data.get("bonus_if_adjacent_at_cast", dst.bonus_if_adjacent_at_cast)
	)
	dst.def_debuff_before_damage = int(
		data.get("def_debuff_before_damage", dst.def_debuff_before_damage)
	)
	dst.hit_count = int(data.get("hit_count", dst.hit_count))
	dst.exclude_caster = bool(data.get("exclude_caster", dst.exclude_caster))
	dst.terrain_id = StringName(str(data.get("terrain_id", String(dst.terrain_id))))
	dst.hazard_duration = int(data.get("hazard_duration", dst.hazard_duration))
	dst.hazard_status = int(data.get("hazard_status", dst.hazard_status))
	dst.bonus_dmg_from_occupied = int(data.get("bonus_dmg_from_occupied", dst.bonus_dmg_from_occupied))
	dst.bonus_dmg_per_10_hp = int(data.get("bonus_dmg_per_10_hp", dst.bonus_dmg_per_10_hp))
	dst.bonus_dmg_pct_max_hp = float(data.get("bonus_dmg_pct_max_hp", dst.bonus_dmg_pct_max_hp))
	dst.heal_if_targets_gte = int(data.get("heal_if_targets_gte", dst.heal_if_targets_gte))
	dst.bounce_count = int(data.get("bounce_count", dst.bounce_count))
	dst.bounce_range = int(data.get("bounce_range", dst.bounce_range))
	dst.buff_on_push = int(data.get("buff_on_push", dst.buff_on_push))
	dst.frenzy_on_kill_ap = int(data.get("frenzy_on_kill_ap", dst.frenzy_on_kill_ap))
	dst.push_board_items = int(data.get("push_board_items", dst.push_board_items))
	dst.item_collision_damage = int(data.get("item_collision_damage", dst.item_collision_damage))
	dst.item_collision_str_div = int(data.get("item_collision_str_div", dst.item_collision_str_div))
	dst.item_collision_vulnerable = int(
		data.get("item_collision_vulnerable", dst.item_collision_vulnerable)
	)
	dst.violent_collision_recast = int(
		data.get("violent_collision_recast", dst.violent_collision_recast)
	)
	dst.next_attack_strength = int(data.get("next_attack_strength", dst.next_attack_strength))
	dst.next_attack_bleed_weapon = bool(
		data.get("next_attack_bleed_weapon", dst.next_attack_bleed_weapon)
	)
	dst.next_turn = bool(data.get("next_turn", dst.next_turn))
	dst.preserve_facing = bool(data.get("preserve_facing", dst.preserve_facing))
	dst.ignore_zoc = bool(data.get("ignore_zoc", dst.ignore_zoc))
	dst.next_ranged_attack_strength = int(
		data.get("next_ranged_attack_strength", dst.next_ranged_attack_strength)
	)
	dst.root_break_on_damage = bool(data.get("root_break_on_damage", dst.root_break_on_damage))
	dst.skewer = int(data.get("skewer", dst.skewer))
	dst.bounce_walls_45 = bool(data.get("bounce_walls_45", dst.bounce_walls_45))
	dst.spread_status_adjacent = bool(
		data.get("spread_status_adjacent", dst.spread_status_adjacent)
	)
	dst.grapple_wall_pull_self = bool(
		data.get("grapple_wall_pull_self", dst.grapple_wall_pull_self)
	)
	dst.grapple_pass_through_damage = int(
		data.get("grapple_pass_through_damage", dst.grapple_pass_through_damage)
	)
	dst.destroy_terrain = bool(data.get("destroy_terrain", dst.destroy_terrain))
	dst.ignite_flammable_terrain = bool(
		data.get("ignite_flammable_terrain", dst.ignite_flammable_terrain)
	)
	dst.allies_range_bonus = int(data.get("allies_range_bonus", dst.allies_range_bonus))
	dst.allies_pierce = bool(data.get("allies_pierce", dst.allies_pierce))
	dst.prevent_stealth_teleport = bool(
		data.get("prevent_stealth_teleport", dst.prevent_stealth_teleport)
	)
	dst.allow_friendly_target = bool(data.get("allow_friendly_target", dst.allow_friendly_target))
	dst.ally_damage_zero = bool(data.get("ally_damage_zero", dst.ally_damage_zero))
	dst.terrain_hazard_status = int(
		data.get("terrain_hazard_status", dst.terrain_hazard_status)
	)
	dst.trap_damage = int(data.get("trap_damage", dst.trap_damage))
	dst.trap_bleed_weapon = bool(data.get("trap_bleed_weapon", dst.trap_bleed_weapon))
	dst.trap_vulnerable = bool(data.get("trap_vulnerable", dst.trap_vulnerable))
	dst.crossing_weapon_damage = bool(
		data.get("crossing_weapon_damage", dst.crossing_weapon_damage)
	)
	dst.crossing_mov_penalty = int(data.get("crossing_mov_penalty", dst.crossing_mov_penalty))
	dst.crossing_blind = bool(data.get("crossing_blind", dst.crossing_blind))
	dst.trap_def_debuff = int(data.get("trap_def_debuff", dst.trap_def_debuff))
	dst.strip_stealth = bool(data.get("strip_stealth", dst.strip_stealth))
	dst.limit_once_per_turn = bool(data.get("limit_once_per_turn", dst.limit_once_per_turn))
	dst.range_one_damage_multiplier = float(
		data.get("range_one_damage_multiplier", dst.range_one_damage_multiplier)
	)
	dst.halve_target_def_one_turn = bool(
		data.get("halve_target_def_one_turn", dst.halve_target_def_one_turn)
	)
	dst.armor_explosion_atk = int(data.get("armor_explosion_atk", dst.armor_explosion_atk))
	dst.bonus_atk_vs_fear_or_lower_movement = int(
		data.get(
			"bonus_atk_vs_fear_or_lower_movement",
			dst.bonus_atk_vs_fear_or_lower_movement,
		)
	)
	dst.on_kill_max_move = int(data.get("on_kill_max_move", dst.on_kill_max_move))
	dst.next_turn_max_move = int(data.get("next_turn_max_move", dst.next_turn_max_move))
	dst.upgraded_trample = bool(data.get("upgraded_trample", dst.upgraded_trample))
	dst.brace_attacker_stagger = int(
		data.get("brace_attacker_stagger", dst.brace_attacker_stagger)
	)
	dst.pull_until_adjacent = bool(data.get("pull_until_adjacent", dst.pull_until_adjacent))
	dst.pull_self_if_rooted = bool(data.get("pull_self_if_rooted", dst.pull_self_if_rooted))
	dst.paired_ally_charge = bool(data.get("paired_ally_charge", dst.paired_ally_charge))
	dst.paired_ally_strike_atk = int(
		data.get("paired_ally_strike_atk", dst.paired_ally_strike_atk)
	)
	dst.on_kill_both_ap = int(data.get("on_kill_both_ap", dst.on_kill_both_ap))
	dst.vault_obstacle_or_gap_only = bool(
		data.get("vault_obstacle_or_gap_only", dst.vault_obstacle_or_gap_only)
	)
	dst.landing_adjacent_push = int(
		data.get("landing_adjacent_push", dst.landing_adjacent_push)
	)
	dst.landing_adjacent_push_stagger = bool(
		data.get("landing_adjacent_push_stagger", dst.landing_adjacent_push_stagger)
	)
	dst.line_breaker = bool(data.get("line_breaker", dst.line_breaker))
	dst.bonus_per_enemy_passed = int(
		data.get("bonus_per_enemy_passed", dst.bonus_per_enemy_passed)
	)
	dst.create_trampled_terrain = bool(
		data.get("create_trampled_terrain", dst.create_trampled_terrain)
	)
	dst.blink = bool(data.get("blink", dst.blink))
	dst.leave_elemental_surface = bool(data.get("leave_elemental_surface", dst.leave_elemental_surface))
	dst.reaction_terrain = StringName(str(data.get("reaction_terrain", String(dst.reaction_terrain))))
	dst.reaction_damage = int(data.get("reaction_damage", dst.reaction_damage))
	dst.bounce_surface_chain = bool(data.get("bounce_surface_chain", dst.bounce_surface_chain))
	dst.lightning_surface = bool(data.get("lightning_surface", dst.lightning_surface))
	dst.strike_all_surface = bool(data.get("strike_all_surface", dst.strike_all_surface))
	dst.teleport_visible = bool(data.get("teleport_visible", dst.teleport_visible))
	dst.delayed_next_turn = bool(data.get("delayed_next_turn", dst.delayed_next_turn))
	dst.create_crater = bool(data.get("create_crater", dst.create_crater))
	dst.pull_to_center = bool(data.get("pull_to_center", dst.pull_to_center))
	dst.pull_surfaces = bool(data.get("pull_surfaces", dst.pull_surfaces))
	dst.mana_shield = bool(data.get("mana_shield", dst.mana_shield))
	dst.mana_shield_casting = bool(data.get("mana_shield_casting", dst.mana_shield_casting))
	dst.destroy_corpse_on_kill = bool(data.get("destroy_corpse_on_kill", dst.destroy_corpse_on_kill))
	dst.kill_grant_ap = int(data.get("kill_grant_ap", dst.kill_grant_ap))
	dst.utility_only = bool(data.get("utility_only", dst.utility_only))
	dst.elemental_surge = bool(data.get("elemental_surge", dst.elemental_surge))
	dst.elemental_surge_ap = int(data.get("elemental_surge_ap", dst.elemental_surge_ap))
	dst.construct_hp_pct = float(data.get("construct_hp_pct", dst.construct_hp_pct))
	dst.density_shift = bool(data.get("density_shift", dst.density_shift))
	dst.ignore_target_magic_pct = float(
		data.get("ignore_target_magic_pct", dst.ignore_target_magic_pct)
	)
	dst.creation_adjacent_damage = int(
		data.get("creation_adjacent_damage", dst.creation_adjacent_damage)
	)
	dst.apply_weaken_enemy = bool(data.get("apply_weaken_enemy", dst.apply_weaken_enemy))
	dst.extras.clear()
	var extra_data: Variant = data.get("extras", [])
	if extra_data is Array:
		for raw: Variant in extra_data as Array:
			if raw is Dictionary:
				dst.extras.append(extra_from_dict(raw as Dictionary))
	dst.keywords.clear()
	var keyword_data: Variant = data.get("keywords", [])
	if keyword_data is Array:
		for raw: Variant in keyword_data as Array:
			if raw is Dictionary:
				dst.keywords.append(keyword_from_dict(raw as Dictionary))
	dst.layers.clear()
	var layer_data: Variant = data.get("layers", [])
	if layer_data is Array:
		for raw: Variant in layer_data as Array:
			if raw is Dictionary:
				dst.layers.append(layer_from_dict(raw as Dictionary))
	AbilityModuleBridge.normalize_module_authoring_fields(dst)


static func _normalize_modules_for_ability(
	modules: Array[AbilityModule],
	planner_group: GameEnums.PlannerGroup,
) -> void:
	for index: int in range(modules.size()):
		var module: AbilityModule = modules[index]
		if module != null:
			AbilityModuleBridge.normalize_module_authoring_fields(module, planner_group, index)


static func modules_from_dict_array(data: Array) -> Array[AbilityModule]:
	var out: Array[AbilityModule] = []
	for entry: Variant in data:
		if entry is Dictionary:
			var module := AbilityModule.new()
			apply_module_dict(module, entry as Dictionary)
			out.append(module)
	return out


static func ability_field_signature(ability: AbilityData, field: String) -> String:
	if ability == null:
		return ""
	var data: Dictionary = ability_to_dict(ability)
	if not data.has(field):
		return ""
	return JSON.stringify(data[field])


static func snapshot_ability_map_from_units(units: Array[UnitData]) -> Dictionary:
	var out: Dictionary = {}
	for unit: UnitData in units:
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability == null or ability.id == &"":
				continue
			out[ability.id] = duplicate_ability(ability)
	return out


const FactoryBaseline = preload("res://ui/class_library_factory_baseline.gd")


static func snapshot_factory_abilities() -> Dictionary:
	var out: Dictionary = {}
	for unit_key: Variant in FactoryBaseline.build_all_player_units().keys():
		var unit: UnitData = FactoryBaseline.build_all_player_units()[unit_key] as UnitData
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability == null or ability.id == &"":
				continue
			out[ability.id] = duplicate_ability(ability)
	return out


static func duplicate_ability(src: AbilityData) -> AbilityData:
	var dst := AbilityData.new()
	copy_ability_into(dst, src)
	return dst


static func copy_ability_into(dst: AbilityData, src: AbilityData) -> void:
	if dst == null or src == null:
		return
	dst.id = src.id
	dst.display_name = src.display_name
	dst.planner_group = src.planner_group
	dst.upgraded_planner_group = src.upgraded_planner_group
	dst.tags = src.tags.duplicate()
	dst.primary_resource = src.primary_resource
	dst.primary_value = src.primary_value
	dst.upgraded_primary_value = src.upgraded_primary_value
	dst.cost_modifier = src.cost_modifier
	dst.cost_modifier_n = src.cost_modifier_n
	dst.secondary_resource = src.secondary_resource
	dst.secondary_value = src.secondary_value
	dst.upgraded_secondary_value = src.upgraded_secondary_value
	dst.upgrade_description = src.upgrade_description
	dst.uses_per_combat = src.uses_per_combat
	dst.once_per_turn = src.once_per_turn
	dst.presentation_key = src.presentation_key
	dst.presentation_anim = src.presentation_anim
	dst.modules = modules_from_dict_array(modules_to_dict_array(src.modules, src.planner_group))
	var upgrade_group: int = _upgrade_planner_group(src)
	dst.upgraded_modules = modules_from_dict_array(
		modules_to_dict_array(src.upgraded_modules, upgrade_group)
	)
	_normalize_modules_for_ability(dst.modules, dst.planner_group)
	_normalize_modules_for_ability(dst.upgraded_modules, upgrade_group)
	if src.is_universal_run() or src.is_universal_wait():
		dst.kind = src.kind
	dst.finalize_modular()


static func _planning_note(ability: AbilityData) -> String:
	if ability.upgraded_planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		return "plan_action; upgraded profile is Pre-Move (skips Action slot, executes immediately)."
	if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		return "plan_pre_move; module targeting flags define the legal aim."
	if ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		return "plan_pre_move (Run)."
	if ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		return "plan_action (Wait); blocks further planning when set."
	return "plan_action (class skill or basic attack)."


static func _upgrade_planner_group(ability: AbilityData) -> int:
	if ability != null and ability.upgraded_planner_group >= 0:
		return ability.upgraded_planner_group
	if ability != null:
		return ability.planner_group
	return GameEnums.PlannerGroup.ACTION


static func _ability_kind_tooltip(k: String) -> String:
	match k:
		"CLASS_SKILL":
			return "Class skill — AP cost, action slot."
		"MOVEMENT_SKILL":
			return "Movement skill — MP cost, pre-move only."
		"UNIVERSAL_RUN":
			return "Run — AP + extended movement."
		"UNIVERSAL_WAIT":
			return "Wait — exhausts unit."
		_:
			return k


static func _ability_kind_system(k: String) -> String:
	match k:
		"CLASS_SKILL":
			return "AbilityData.consumes_action_slot(); plan_action timeline."
		"MOVEMENT_SKILL":
			return "AbilityData.is_movement_kind(); plan_pre_move; AbilitySystem deducts MP."
		"UNIVERSAL_RUN":
			return "plan_pre_move (Run); AP spent on MOVE.uses_run — not Action column."
		"UNIVERSAL_WAIT":
			return "DataLibrary.get_universal_wait(); hidden from skill lists."
		_:
			return ""


static func _module_dump_line(index: int, module: AbilityModule) -> String:
	if module == null:
		return "[%d] <null module>" % index
	var line := "[%d] %s amount=%d range=%d-%d shape=%s" % [
		index,
		GameEnums.EffectType.keys()[module.primary_type],
		module.amount,
		module.min_range,
		module.max_range,
		GameEnums.TargetShape.keys()[module.target_shape],
	]
	if not module.keywords.is_empty():
		line += " keywords=%d" % module.keywords.size()
	if not module.layers.is_empty():
		line += " layers=%d" % module.layers.size()
	if module.hit_count > 1:
		line += " hit_count=%d" % module.hit_count
	if module.gate != GameEnums.ModuleGate.ALWAYS:
		line += " gate=%s" % GameEnums.ModuleGate.keys()[module.gate]
	return line


static func _module_impl_note(module: AbilityModule) -> String:
	var note := "MODULE %s: range %d-%d, phase %s." % [
		GameEnums.EffectType.keys()[module.primary_type],
		module.min_range,
		module.max_range,
		GameEnums.ModulePhase.keys()[module.execution_phase],
	]
	if not module.keywords.is_empty():
		note += " %d keyword(s)." % module.keywords.size()
	if not module.layers.is_empty():
		note += " %d layer(s)." % module.layers.size()
	if module.hit_count > 1:
		note += " hit_count %d." % module.hit_count
	return note


static func _targeting_mode_tooltip(k: String) -> String:
	match k:
		"ALLY_UNIT":
			return "Ally only (not self)"
		"ALLY_OR_SELF":
			return "Ally or self"
		"ENEMY_UNIT":
			return "Enemy only"
		"SELF":
			return "Self tile"
		"ANY_UNIT":
			return "Any unit"
		"TILE":
			return "Empty or any tile"
		"DASH_LINE":
			return "Straight line dash target"
		_:
			return k


static func _targeting_mode_system(k: String) -> String:
	return "AbilitySystem.target_passes_mode() + combat_planning_input hover validation."


static func _target_shape_tooltip(k: String) -> String:
	match k:
		"SINGLE":
			return "Single tile"
		"AOE_SQUARE":
			return "Chebyshev square. Shape size 1 is 3x3 (radius), not a 3-tile diamond."
		"AOE_CROSS":
			return "Cross AoE"
		"ARC":
			return "3-tile arc"
		"CONE":
			return "Cone from caster"
		"LINE":
			return "Line from caster"
		"AOE_DIAMOND":
			return "Diamond radius"
		_:
			return k


static func _target_shape_system(_k: String) -> String:
	return "AbilitySystem gathers affected tiles from target_shape + target_shape_size."


static func _effect_type_tooltip(k: String) -> String:
	return k.replace("_", " ").capitalize()


static func _effect_type_system(k: String) -> String:
	match k:
		"DAMAGE":
			return "AbilitySystem → CombatSystem.calculate_scaled_damage + deal_damage (DEF/MAG, armor, fortitude)."
		"PUSH", "PULL":
			return "AbilitySystem queues pending_pushes → PhysicsSystem.push/pull with collision on blocked tiles."
		"SWAP":
			return "AbilitySystem → PhysicsSystem.swap: swap grid occupancy, terrain landing on both."
		"DASH":
			return "AbilitySystem queues dash pending_pushes → PhysicsSystem.dash along straight line."
		"MOVE":
			return "AbilitySystem executes a non-instant skill walk via MovementSystem.execute_skill_walk()."
		"TRAMPLE":
			return "Paired with movement: pass-through walk via MovementSystem.execute_skill_walk()."
		"BULLDOZE":
			return "Paired with movement: dash pending_pushes or execute_skill_walk(); caster collision immune."
		"HEAL":
			return "AbilitySystem → CombatSystem.heal with ability scaling_stat."
		"ARMOR_UP":
			return "AbilitySystem → CombatSystem.add_armor (temporary HP layer)."
		"ADD_STATUS", "ADD_STATUS_SELF":
			return "AbilitySystem appends StatusData to target/actor; UnitState._recalculate_stats on apply."
		"EXPLODE", "RANGED_EXPLODE":
			return "AbilitySystem gathers AoE tiles then DAMAGE each occupant."
		"TELEPORT_CASTER":
			return "AbilitySystem clears/set occupant if destination passable."
		"CLEANSE", "PURGE":
			return "AbilitySystem filters active_statuses by is_debuff / is_buff."
		"DESTROY_OBSTACLE":
			return "AbilitySystem deal_damage full HP when target is_construct."
		"SPAWN":
			return "AbilitySystem spawns unit from EffectData.spawn_unit_id."
		"DAMAGE_SELF":
			return "AbilitySystem → deal_damage on actor with pierce=true damage type."
		"REFUND_AP_ON_CC":
			return "AbilitySystem refunds 1 AP if target has ROOT or STAGGER at resolve time."
		_:
			return "Resolved in AbilitySystem._apply_effect match branch."


static func _status_system(st: GameEnums.StatusType) -> String:
	const DUR: String = (
		"Duration: StatusData.duration turns; ticks_remaining starts at duration×2+1; "
		+ "Simulator._tick_statuses decrements twice per full round (after player plan, after enemy turn)."
	)
	match st:
		GameEnums.StatusType.STAT_BUFF_STR:
			return "UnitState._recalculate_stats: stat_str += status.value (summed). value from EffectData.amount via ADD_STATUS. %s" % DUR
		GameEnums.StatusType.STAT_BUFF_MAG:
			return "UnitState._recalculate_stats: stat_mag += status.value. %s" % DUR
		GameEnums.StatusType.STAT_BUFF_DEF:
			return (
				"UnitState._recalculate_stats: stat_def += status.value → current_defense = max(0, base+wpn+stat_def). "
				+ "No global amount: EffectData.amount per skill (e.g. Phalanx=5, Defensive Formation=2); Fortify uses scaling_stat DEFENSE → amount+caster DEF. %s"
				% DUR
			)
		GameEnums.StatusType.STAT_BUFF_MOV, GameEnums.StatusType.STAT_BUFF_MP:
			return "UnitState._recalculate_stats: stat_mov += status.value → movement.max_points. Rallying Presence appends STAT_BUFF_MP(1, +1|+2) at turn start. %s" % DUR
		GameEnums.StatusType.STAT_BUFF_ACC:
			return "Enum + UI only. Not read in UnitState._recalculate_stats or combat math yet."
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return "UnitState._recalculate_stats: stat_def -= status.value. Also used as temp pre-hit debuff (def_debuff_before_damage) then erased. %s" % DUR
		GameEnums.StatusType.STAT_DEBUFF_MOV:
			return "UnitState._recalculate_stats: stat_mov -= status.value. %s" % DUR
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return "Enum + UI only. Not applied in UnitState._recalculate_stats yet."
		GameEnums.StatusType.STURDY:
			return "PhysicsSystem/AbilitySystem PUSH-PULL: blocks displacement unless target has VULNERABLE. One STURDY consumed per block."
		GameEnums.StatusType.MARK:
			return "No simulation hook. AbilitySystem._is_backstab only checks tile behind facing (+2 raw ATK); does not read MARK."
		GameEnums.StatusType.INTERCEPT:
			return "CombatSystem.deal_damage: adjacent ally with INTERCEPT takes floor(50% damage); upgraded INTERCEPT (status.value==1) grants ally STAT_BUFF_DEF(1,2)."
		GameEnums.StatusType.STEALTH:
			return "AbilitySystem target validation: enemy STEALTH cannot be targeted."
		GameEnums.StatusType.TAUNT:
			return "Boss CC immunity list only. Intercept Tactics passive: casting TAUNT/INTERCEPT appends STAT_BUFF_DEF(1, 2|3) on actor."
		GameEnums.StatusType.ROOT:
			return "UnitState._recalculate_stats: movement.max_points=0. CombatSystem.deal_damage removes ROOT on HP/armor damage."
		GameEnums.StatusType.STAGGER:
			return "ResolutionPipeline blocks actions; AbilitySystem blocks abilities. Does not zero MOV by itself."
		GameEnums.StatusType.SILENCE:
			return "AbilitySystem: blocks ability use when action_point_cost > 0."
		GameEnums.StatusType.PACIFY:
			return "AbilitySystem: blocks abilities where ability_uses_attack_animation. Removed on damage with ROOT."
		GameEnums.StatusType.BLIND:
			return "UnitState.get_ability_range returns 1."
		GameEnums.StatusType.POLYMORPH:
			return "UnitState._recalculate_stats: STR/MAG=0; MOV max 1."
		GameEnums.StatusType.VULNERABLE:
			return "Bypasses STURDY/ROOT/Stand Ground push immunity; CombatSystem.add_armor blocked. No extra damage in deal_damage."
		GameEnums.StatusType.INVULNERABLE:
			return "CombatSystem.deal_damage early return; AbilitySystem blocks debuff ADD_STATUS."
		GameEnums.StatusType.THORNS:
			return "CombatSystem.deal_damage after hit: if attacker adjacent, reflect floor((hp+armor dmg)×status.amount/100), min 1."
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "CombatSystem.get_dynamic_defense: def = ceili(def/2) while active."
		GameEnums.StatusType.BURN:
			return "Simulator._tick_start_of_turn: deal_damage(..., pierce=true) for status.value."
		GameEnums.StatusType.BLEED:
			return "Movement cost 2/tile in overlays; Simulator._tick_end_of_turn: deal_damage status.value (pierce)."
		GameEnums.StatusType.POISON:
			return "Turn start: ceili(max_hp×0.10) pierce damage; CombatSystem.heal: final_amount = floori(amount×0.5)."
		GameEnums.StatusType.WEAKEN:
			return "UnitState._recalculate_stats: stat_str -= 2; stat_mag -= 2 (fixed, not status.value)."
		GameEnums.StatusType.ELECTRIFIED:
			return "CombatSystem.deal_damage: amount += 1 before mitigation."
		GameEnums.StatusType.WEAK_TRAP:
			return "Not referenced in core systems — placeholder status."
		GameEnums.StatusType.FEAR, GameEnums.StatusType.CONFUSION:
			return "Boss immune (AbilitySystem ADD_STATUS). No enemy AI / player targeting override implemented."
		GameEnums.StatusType.PIERCE:
			return "CombatSystem.deal_damage/deal_damage_raw: mitigation and fortitude set to 0 for attacker with PIERCE."
		GameEnums.StatusType.GHOST:
			return "MovementSystem pathing through units; TerrainSystem ignores terrain costs with AIRBORNE."
		GameEnums.StatusType.TRAMPLE:
			return "MovementSystem.has_trample: pass through enemy-occupied tiles."
		GameEnums.StatusType.AIRBORNE:
			return "TerrainSystem: treated like FLY for hazard/cost bypass."
		GameEnums.StatusType.CANTO:
			return "AbilitySystem.apply_canto_move_refund after class skill: movement.points_left = max_points; append CANTO(1)."
		GameEnums.StatusType.RUNNING:
			return "Turn-local movement boost via UnitState.run_boost_amount; cleared in reset_for_turn(). Not a combat status."
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "CombatSystem.deal_damage on HP dmg: counter ATK 2 scaled; upgraded PUSH 1; range 1 unless RETALIATION_INFINITE_RANGE."
		GameEnums.StatusType.RETALIATION_INFINITE_RANGE:
			return "CombatSystem retaliation range check skipped when present."
		GameEnums.StatusType.INDOMITABLE_WILL:
			return "Knight Indomitable Will: ARMOR_UP shield = caster DEF; on shield break to 0, remove status; upgraded grants STAT_BUFF_STR(99,2)."
		_:
			return "Unhandled StatusType in ClassLibrarySchema._status_system."


static func _stat_type_system(k: String) -> String:
	match k:
		"PHYSICAL":
			return "Scales with STR in damage/heal formulas."
		"MAGICAL":
			return "Scales with MAG."
		"DEFENSE":
			return "Scales with DEF (shields)."
		"MISSING_HP":
			return "Scales with (Max HP - Current HP)."
		"MAX_HP", "CURRENT_HP":
			return "Scales with HP pool."
		_:
			return ""


const EDITOR_OVERRIDES_PATH: String = "res://data/class_library_data.json"


static func read_editor_save() -> Dictionary:
	return read_editor_save_from_path(EDITOR_OVERRIDES_PATH)


static func read_editor_save_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return migrate_editor_save_to_modules(parsed as Dictionary)
	return {}


static func write_editor_save(data: Dictionary) -> bool:
	var payload: Dictionary = data.duplicate(true)
	payload["units"] = {}
	var file := FileAccess.open(EDITOR_OVERRIDES_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func migrate_editor_save_to_modules(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var units_value: Variant = migrated.get("units", {})
	if not units_value is Dictionary:
		return migrated
	var units: Dictionary = units_value
	for unit_key: Variant in units.keys():
		var unit_value: Variant = units[unit_key]
		if not unit_value is Dictionary:
			continue
		var unit_data: Dictionary = unit_value
		var abilities_value: Variant = unit_data.get("abilities", {})
		if not abilities_value is Dictionary:
			continue
		var normalized_abilities: Dictionary = {}
		for ability_key: Variant in (abilities_value as Dictionary).keys():
			var payload: Variant = (abilities_value as Dictionary)[ability_key]
			if not payload is Dictionary:
				continue
			var ability := AbilityData.new()
			apply_ability_dict(ability, payload as Dictionary)
			normalized_abilities[ability_key] = ability_to_dict(ability)
		unit_data["abilities"] = normalized_abilities
		units[unit_key] = unit_data
	migrated["units"] = units
	return migrated


static func collect_player_unit_overrides() -> Dictionary:
	var units: Dictionary = {}
	for unit: UnitData in DataLibrary.get_all_player_units():
		units[String(unit.id)] = unit_to_dict(unit)
	return units


static func apply_unit_overrides(units_data: Dictionary) -> void:
	if units_data.is_empty():
		return
	for unit_key: Variant in units_data.keys():
		var unit: UnitData = DataLibrary.get_unit(StringName(String(unit_key)))
		if unit == null:
			continue
		var payload: Variant = units_data[unit_key]
		if typeof(payload) == TYPE_DICTIONARY:
			apply_unit_dict(unit, payload as Dictionary)


static func apply_saved_unit_overrides() -> void:
	## Skill save is disabled. Combat and the editor always use factory abilities.
	return


static func effect_to_dict(src: EffectData) -> Dictionary:
	var out := {
		"type": src.type,
		"amount": src.amount,
		"modifiers": src.modifiers.duplicate(),
	}
	if GameEnums.effect_type_uses_module_scaling(src.type):
		out["scaling_stat"] = src.scaling_stat
	if GameEnums.effect_type_applies_status(src.type):
		out["status_type"] = src.status_type
		out["status_duration"] = src.status_duration
	if src.type == GameEnums.EffectType.DAMAGE:
		if src.bonus_if_adjacent_at_cast != 0:
			out["bonus_if_adjacent_at_cast"] = src.bonus_if_adjacent_at_cast
		if src.def_debuff_before_damage != 0:
			out["def_debuff_before_damage"] = src.def_debuff_before_damage
	if (
		GameEnums.effect_type_uses_spawn_unit(src.type)
		and src.spawn_unit_id != StringName()
	):
		out["spawn_unit_id"] = String(src.spawn_unit_id)
	return out


static func apply_effect_dict(dst: EffectData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.type = int(data.get("type", dst.type))
	dst.amount = int(data.get("amount", dst.amount))
	dst.status_type = int(data.get("status_type", dst.status_type))
	dst.status_duration = int(data.get("status_duration", dst.status_duration))
	dst.scaling_stat = int(data.get("scaling_stat", dst.scaling_stat))
	dst.bonus_if_adjacent_at_cast = int(data.get("bonus_if_adjacent_at_cast", dst.bonus_if_adjacent_at_cast))
	dst.def_debuff_before_damage = int(data.get("def_debuff_before_damage", dst.def_debuff_before_damage))
	dst.spawn_unit_id = StringName(String(data.get("spawn_unit_id", String(dst.spawn_unit_id))))
	dst.modifiers = data.get("modifiers", {}).duplicate()
	AbilityModuleBridge.normalize_effect_authoring_fields(dst)


static func effects_to_dict_array(effects: Array[EffectData]) -> Array:
	var out: Array = []
	for eff: EffectData in effects:
		out.append(effect_to_dict(eff))
	return out


static func effects_from_dict_array(data: Array) -> Array[EffectData]:
	var out: Array[EffectData] = []
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var eff := EffectData.new()
		apply_effect_dict(eff, entry as Dictionary)
		out.append(eff)
	return out


static func ability_to_dict(src: AbilityData) -> Dictionary:
	var tag_strs: Array = []
	for t: StringName in src.tags:
		tag_strs.append(String(t))
	var payload: Dictionary = {
		"display_name": src.display_name,
		"planner_group": src.planner_group,
		"upgraded_planner_group": src.upgraded_planner_group,
		"tags": tag_strs,
		"primary_resource": src.primary_resource,
		"primary_value": src.primary_value,
		"upgraded_primary_value": src.upgraded_primary_value,
		"cost_modifier": src.cost_modifier,
		"cost_modifier_n": src.cost_modifier_n,
		"secondary_resource": src.secondary_resource,
		"secondary_value": src.secondary_value,
		"upgraded_secondary_value": src.upgraded_secondary_value,
		"upgrade_description": src.upgrade_description,
		"uses_per_combat": src.uses_per_combat,
		"once_per_turn": src.once_per_turn,
		"presentation_key": String(src.presentation_key),
		"presentation_anim": src.presentation_anim,
		"modules": modules_to_dict_array(src.modules, src.planner_group),
		"upgraded_modules": modules_to_dict_array(src.upgraded_modules, _upgrade_planner_group(src)),
		"module_count": src.modules.size(),
		"upgraded_module_count": src.upgraded_modules.size(),
	}
	if src.modules.is_empty():
		payload["range_tiles"] = src.range_tiles
	return payload


static func modules_summary_bbcode(ability: AbilityData) -> String:
	if ability == null:
		return "[i]no ability[/i]"
	if ability.modules.is_empty():
		return "[i]No modules authored yet — add a module to define this ability.[/i]"
	var lines: PackedStringArray = PackedStringArray()
	var i: int = 0
	for mod: AbilityModule in ability.modules:
		if mod == null:
			continue
		var phase: String = GameEnums.ModulePhase.keys()[mod.execution_phase]
		var ptype: String = GameEnums.EffectType.keys()[mod.primary_type]
		var gate: String = GameEnums.ModuleGate.keys()[mod.gate]
		var kw_parts: PackedStringArray = PackedStringArray()
		for kw: AbilityKeyword in mod.keywords:
			if kw != null:
				kw_parts.append(GameEnums.AbilityKeywordId.keys()[kw.keyword_id])
		var kw_s: String = (", ".join(kw_parts)) if not kw_parts.is_empty() else "—"
		lines.append(
			"[b]M%d[/b] %s · %s · range %d–%d · gate %s · keywords [%s] · layers %d"
			% [i, phase, ptype, mod.min_range, mod.max_range, gate, kw_s, mod.layers.size()]
		)
		i += 1
	if not ability.upgraded_modules.is_empty():
		lines.append("[color=#FBBF24]upgraded_modules: %d[/color]" % ability.upgraded_modules.size())
	return "\n".join(lines)


static func apply_ability_dict(dst: AbilityData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.display_name = String(data.get("display_name", dst.display_name))
	if data.has("planner_group"):
		dst.planner_group = int(data.get("planner_group", dst.planner_group))
	if data.has("upgraded_planner_group"):
		dst.upgraded_planner_group = int(data.get("upgraded_planner_group", dst.upgraded_planner_group))
	if data.has("tags"):
		var tags_v: Variant = data.get("tags", [])
		dst.tags = _canonical_tags_from_variant(tags_v)
	dst.primary_resource = int(data.get("primary_resource", dst.primary_resource)) as GameEnums.CostResource
	dst.primary_value = int(data.get("primary_value", dst.primary_value))
	dst.upgraded_primary_value = int(data.get("upgraded_primary_value", dst.upgraded_primary_value))
	dst.cost_modifier = int(data.get("cost_modifier", dst.cost_modifier)) as GameEnums.CostModifier
	dst.cost_modifier_n = int(data.get("cost_modifier_n", dst.cost_modifier_n))
	dst.secondary_resource = int(data.get("secondary_resource", dst.secondary_resource)) as GameEnums.CostResource
	dst.secondary_value = int(data.get("secondary_value", dst.secondary_value))
	dst.upgraded_secondary_value = int(data.get("upgraded_secondary_value", dst.upgraded_secondary_value))
	dst.upgrade_description = String(data.get("upgrade_description", dst.upgrade_description))
	dst.uses_per_combat = int(data.get("uses_per_combat", dst.uses_per_combat))
	dst.once_per_turn = bool(data.get("once_per_turn", dst.once_per_turn))
	dst.presentation_key = StringName(String(data.get("presentation_key", String(dst.presentation_key))))
	dst.presentation_anim = int(data.get("presentation_anim", dst.presentation_anim))
	var authored_range_tiles: int = int(data.get("range_tiles", -1))
	var module_data: Variant = data.get("modules", null)
	var use_legacy_base: bool = (
		not (module_data is Array)
		or ((module_data as Array).is_empty() and data.has("effects"))
	)
	if not use_legacy_base:
		var parsed_modules: Array[AbilityModule] = modules_from_dict_array(module_data as Array)
		var base_errors: Array[String] = AbilityModuleBridge.validate_modules(parsed_modules)
		if not base_errors.is_empty():
			push_error("Ability JSON rejected base module profile: %s" % "; ".join(base_errors))
			return
		dst.modules = parsed_modules
		_normalize_modules_for_ability(dst.modules, dst.planner_group)
	else:
		_apply_legacy_ability_migration(dst, data)
	var upgraded_module_data: Variant = data.get("upgraded_modules", null)
	var use_legacy_upgrade: bool = (
		not (upgraded_module_data is Array)
		or ((upgraded_module_data as Array).is_empty() and data.has("upgraded_effects"))
	)
	if not use_legacy_upgrade:
		var parsed_upgraded_modules: Array[AbilityModule] = modules_from_dict_array(
			upgraded_module_data as Array
		)
		var upgrade_errors: Array[String] = AbilityModuleBridge.validate_modules(parsed_upgraded_modules)
		if not upgrade_errors.is_empty():
			push_error("Ability JSON rejected upgraded module profile: %s" % "; ".join(upgrade_errors))
			return
		dst.upgraded_modules = parsed_upgraded_modules
		_normalize_modules_for_ability(dst.upgraded_modules, _upgrade_planner_group(dst))
	elif use_legacy_upgrade and data.has("upgraded_effects"):
		dst.upgraded_effects = effects_from_dict_array(data.get("upgraded_effects", []))
	dst.finalize_modular()
	if authored_range_tiles >= 0:
		dst.range_tiles = authored_range_tiles


static func _canonical_tags_from_variant(value: Variant) -> Array[StringName]:
	var allowed: Array[StringName] = [
		AbilityModuleBridge.TAG_ATTACK,
		AbilityModuleBridge.TAG_MOVEMENT,
		AbilityModuleBridge.TAG_POSITIONING,
		AbilityModuleBridge.TAG_SPELL,
		AbilityModuleBridge.TAG_HEAL,
	]
	var tags_out: Array[StringName] = []
	if value is Array:
		for tag_value: Variant in value as Array:
			var tag: StringName = StringName(String(tag_value))
			if allowed.has(tag):
				if not tags_out.has(tag):
					tags_out.append(tag)
			else:
				push_warning("Ability JSON rejected unknown tag: %s" % String(tag))
	return tags_out


static func _apply_legacy_ability_migration(dst: AbilityData, data: Dictionary) -> void:
	## One-way migration for pre-module editor saves. New saves never emit this shape.
	if data.has("kind"):
		dst.kind = int(data.get("kind", dst.kind)) as GameEnums.AbilityKind
		dst.planner_group = AbilityModuleBridge.planner_group_from_kind(dst.kind)
	if data.has("action_point_cost"):
		dst.action_point_cost = int(data.get("action_point_cost", dst.action_point_cost))
	if data.has("movement_point_cost"):
		dst.movement_point_cost = int(data.get("movement_point_cost", dst.movement_point_cost))
	if data.has("range_tiles"):
		dst.range_tiles = int(data.get("range_tiles", dst.range_tiles))
	if data.has("targeting_mode"):
		dst.targeting_mode = int(data.get("targeting_mode", dst.targeting_mode))
	if data.has("targeting_flags"):
		dst.targeting_flags = int(data.get("targeting_flags", dst.targeting_flags))
	if data.has("can_target_self"):
		dst.can_target_self = bool(data.get("can_target_self", dst.can_target_self))
	if data.has("target_shape"):
		dst.target_shape = int(data.get("target_shape", dst.target_shape))
	if data.has("target_shape_size"):
		dst.target_shape_size = int(data.get("target_shape_size", dst.target_shape_size))
	if data.has("upgraded_range_tiles"):
		dst.upgraded_range_tiles = int(data.get("upgraded_range_tiles", dst.upgraded_range_tiles))
	if data.has("upgraded_movement_point_cost"):
		dst.upgraded_movement_point_cost = int(
			data.get("upgraded_movement_point_cost", dst.upgraded_movement_point_cost)
		)
	if data.has("upgraded_target_shape"):
		dst.upgraded_target_shape = int(data.get("upgraded_target_shape", dst.upgraded_target_shape))
	if data.has("upgraded_target_shape_size"):
		dst.upgraded_target_shape_size = int(
			data.get("upgraded_target_shape_size", dst.upgraded_target_shape_size)
		)
	if data.has("scaling_stat"):
		dst.scaling_stat = int(data.get("scaling_stat", dst.scaling_stat))
	if data.has("is_movement_skill"):
		dst.is_movement_skill = bool(data.get("is_movement_skill", dst.is_movement_skill))
	if data.has("effects"):
		dst.effects = effects_from_dict_array(data.get("effects", []))
	if data.has("upgraded_effects"):
		dst.upgraded_effects = effects_from_dict_array(data.get("upgraded_effects", []))
	if (
		bool(data.get("can_target_self", false))
		or int(data.get("targeting_mode", -1)) == GameEnums.TargetingMode.SELF
	):
		dst.targeting_flags = GameEnums.TargetingFlags.SELF
		dst.targeting_mode = GameEnums.TargetingMode.SELF
		dst.can_target_self = true


static func passive_to_dict(src: PassiveData) -> Dictionary:
	return {
		"display_name": src.display_name,
		"description": src.description,
		"upgraded_description": src.upgraded_description,
	}


static func apply_passive_dict(dst: PassiveData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.display_name = String(data.get("display_name", dst.display_name))
	dst.description = String(data.get("description", dst.description))
	dst.upgraded_description = String(data.get("upgraded_description", dst.upgraded_description))


static func weapon_to_dict(src: WeaponData) -> Dictionary:
	if src == null:
		return {}
	return {
		"display_name": src.display_name,
		"might": src.might,
		"bonus_strength": src.bonus_strength,
		"bonus_magic": src.bonus_magic,
		"bonus_defense": src.bonus_defense,
		"bonus_max_hp": src.bonus_max_hp,
		"bonus_move": src.bonus_move,
	}


static func apply_weapon_dict(dst: WeaponData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.display_name = String(data.get("display_name", dst.display_name))
	dst.might = int(data.get("might", dst.might))
	dst.bonus_strength = int(data.get("bonus_strength", dst.bonus_strength))
	dst.bonus_magic = int(data.get("bonus_magic", dst.bonus_magic))
	dst.bonus_defense = int(data.get("bonus_defense", dst.bonus_defense))
	dst.bonus_max_hp = int(data.get("bonus_max_hp", dst.bonus_max_hp))
	dst.bonus_move = int(data.get("bonus_move", dst.bonus_move))


static func unit_to_dict(src: UnitData) -> Dictionary:
	var abilities: Dictionary = {}
	for ability: AbilityData in src.abilities:
		if ability == null or ability.id == &"":
			continue
		abilities[String(ability.id)] = ability_to_dict(ability)
	var passives: Dictionary = {}
	for passive: PassiveData in src.passives:
		if passive == null or passive.id == &"":
			continue
		passives[String(passive.id)] = passive_to_dict(passive)
	var innate_passives: Dictionary = {}
	for passive: PassiveData in src.innate_passives:
		if passive == null or passive.id == &"":
			continue
		innate_passives[String(passive.id)] = passive_to_dict(passive)
	return {
		"display_name": src.display_name,
		"base_constitution": src.base_constitution,
		"move_points": src.move_points,
		"action_points": src.action_points,
		"movement_type": src.movement_type,
		"level": src.level,
		"base_strength": src.base_strength,
		"base_magic": src.base_magic,
		"base_defense": src.base_defense,
		"preferred_stat": src.preferred_stat,
		"weapon": weapon_to_dict(src.equipped_weapon),
		"abilities": abilities,
		"passives": passives,
		"innate_passives": innate_passives,
	}


static func apply_unit_dict(dst: UnitData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.display_name = String(data.get("display_name", dst.display_name))
	dst.base_constitution = int(data.get("base_constitution", dst.base_constitution))
	dst.move_points = int(data.get("move_points", dst.move_points))
	dst.action_points = int(data.get("action_points", dst.action_points))
	dst.movement_type = int(data.get("movement_type", dst.movement_type))
	dst.level = int(data.get("level", dst.level))
	dst.base_strength = int(data.get("base_strength", dst.base_strength))
	dst.base_magic = int(data.get("base_magic", dst.base_magic))
	dst.base_defense = int(data.get("base_defense", dst.base_defense))
	dst.preferred_stat = int(data.get("preferred_stat", dst.preferred_stat))
	if data.has("weapon") and dst.equipped_weapon != null:
		var weapon_data: Variant = data.get("weapon")
		if typeof(weapon_data) == TYPE_DICTIONARY:
			apply_weapon_dict(dst.equipped_weapon, weapon_data as Dictionary)
	var abilities_data: Variant = data.get("abilities", {})
	if typeof(abilities_data) == TYPE_DICTIONARY:
		for ability: AbilityData in dst.abilities:
			if ability == null:
				continue
			var ability_key := String(ability.id)
			if (abilities_data as Dictionary).has(ability_key):
				var ability_payload: Variant = (abilities_data as Dictionary)[ability_key]
				if typeof(ability_payload) == TYPE_DICTIONARY:
					apply_ability_dict(ability, ability_payload as Dictionary)
	var passives_data: Variant = data.get("passives", {})
	if typeof(passives_data) == TYPE_DICTIONARY:
		for passive: PassiveData in dst.passives:
			if passive == null:
				continue
			var passive_key := String(passive.id)
			if (passives_data as Dictionary).has(passive_key):
				var passive_payload: Variant = (passives_data as Dictionary)[passive_key]
				if typeof(passive_payload) == TYPE_DICTIONARY:
					apply_passive_dict(passive, passive_payload as Dictionary)
	var innate_data: Variant = data.get("innate_passives", {})
	if typeof(innate_data) == TYPE_DICTIONARY:
		for passive: PassiveData in dst.innate_passives:
			if passive == null:
				continue
			var innate_key := String(passive.id)
			if (innate_data as Dictionary).has(innate_key):
				var innate_payload: Variant = (innate_data as Dictionary)[innate_key]
				if typeof(innate_payload) == TYPE_DICTIONARY:
					apply_passive_dict(passive, innate_payload as Dictionary)
