class_name ClassLibrarySchema
extends RefCounted

## Reference data for the Class Library Editor: glossary, enum definitions,
## ability data dumps, and simulation implementation notes.

const KW_COLOR: String = "#FBBF24"

static var _ABILITY_CODE_BRANCHES: Dictionary = {
	&"knight_defensive_formation": "Phalanx: ability_system applies DEF buff to self and adjacent allies (ID branch).",
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
		"AOE SQUARE": "Square array of tiles (e.g., 2x2, 3x3).",
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
			return "Apply INTERCEPT 50%"
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
		_:
			return ""


static func bible_ability_targeting_label(ability: AbilityData) -> String:
	if ability == null:
		return ""
	for eff: EffectData in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return "DASH %d" % eff.amount
	match ability.id:
		&"knight_redirect_strike":
			return "RANGE 2"
		_:
			pass
	if ability.range_tiles > 0:
		if AbilitySystem.ability_has_movement_effect(ability):
			var move_amount := AbilitySystem.effect_amount(ability, GameEnums.EffectType.MOVE)
			if move_amount > 0:
				return "MOVE %d" % move_amount
			return "MOVE %d" % ability.range_tiles
		return "MOVE"
	if ability.targeting_mode == GameEnums.TargetingMode.SELF and ability.range_tiles == 0:
		if ability.target_shape != GameEnums.TargetShape.SINGLE:
			return "RANGE 0"
		return "SELF"
	if ability.range_tiles == 0 and ability.target_shape != GameEnums.TargetShape.SINGLE:
		return "RANGE 0"
	if ability.range_tiles >= 0:
		return "RANGE %d" % ability.range_tiles
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
	lines.append("id: %s" % String(ability.id))
	lines.append("display_name: %s" % ability.display_name)
	lines.append("kind: %s" % GameEnums.AbilityKind.keys()[ability.kind])
	lines.append("action_point_cost: %d" % ability.action_point_cost)
	lines.append("movement_point_cost: %d" % ability.movement_point_cost)
	lines.append("range_tiles: %d" % ability.range_tiles)
	lines.append("targeting_flags: %s" % targeting_flags_dump(ability))
	lines.append("target_shape: %s" % GameEnums.TargetShape.keys()[ability.target_shape])
	lines.append("target_shape_size: %d" % ability.target_shape_size)
	lines.append("scaling_stat: %s" % GameEnums.StatType.keys()[ability.scaling_stat])
	lines.append("uses_per_combat: %d" % ability.uses_per_combat)
	lines.append("presentation_key: %s" % String(ability.presentation_key))
	lines.append("presentation_anim: %s" % GameEnums.PresentationAnim.keys()[ability.presentation_anim])
	if ability.upgraded_range_tiles >= 0:
		lines.append("upgraded_range_tiles: %d" % ability.upgraded_range_tiles)
	if ability.upgraded_target_shape_size >= 1:
		lines.append("upgraded_target_shape: %s size %d" % [
			GameEnums.TargetShape.keys()[ability.upgraded_target_shape],
			ability.upgraded_target_shape_size,
		])
	if not ability.upgrade_description.is_empty():
		lines.append("upgrade_description: %s" % ability.upgrade_description)
	lines.append("--- effects (%d) ---" % ability.effects.size())
	for i: int in ability.effects.size():
		lines.append(_effect_dump_line(i, ability.effects[i]))
	if not ability.upgraded_effects.is_empty():
		lines.append("--- upgraded_effects (%d) ---" % ability.upgraded_effects.size())
		for j: int in ability.upgraded_effects.size():
			lines.append(_effect_dump_line(j, ability.upgraded_effects[j]))
	return "\n".join(lines)


static func ability_implementation_notes(ability: AbilityData) -> String:
	if ability == null:
		return ""
	var parts: Array[String] = []
	parts.append("Planning: %s" % _planning_note(ability))
	parts.append("Targeting: AbilitySystem.target_passes_mode via targeting_flags bitmask.")
	if ability.is_movement_kind():
		parts.append("Economy: spends movement_point_cost (MP); PRE_MOVE timeline bucket; no action slot.")
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		parts.append("Economy: PRE_MOVE only — spends 1 AP on move (uses_run); does not consume the Action slot.")
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		parts.append("Economy: consumes the Action slot; ends planning for this unit.")
	else:
		parts.append("Economy: spends action_point_cost (AP); ACTION timeline bucket; consumes action slot.")
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		parts.append("Shape: hits tiles in %s (size %d), not only the selected tile." % [
			GameEnums.TargetShape.keys()[ability.target_shape],
			ability.target_shape_size,
		])
	for eff: EffectData in ability.effects:
		parts.append(_effect_impl_note(eff))
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
	ability.ensure_targeting_flags_from_mode()
	var labels: PackedStringArray = []
	if ability.has_targeting(GameEnums.TargetingFlags.SELF):
		labels.append("Self")
	if ability.has_targeting(GameEnums.TargetingFlags.ALLY):
		labels.append("Ally")
	if ability.has_targeting(GameEnums.TargetingFlags.ENEMY):
		labels.append("Enemy")
	if ability.has_targeting(GameEnums.TargetingFlags.TILE):
		labels.append("Tile")
	if ability.has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		labels.append("Dash line")
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
	return e


static func duplicate_ability(src: AbilityData) -> AbilityData:
	var dst := AbilityData.new()
	copy_ability_into(dst, src)
	return dst


static func copy_ability_into(dst: AbilityData, src: AbilityData) -> void:
	if dst == null or src == null:
		return
	dst.id = src.id
	dst.display_name = src.display_name
	dst.kind = src.kind
	dst.action_point_cost = src.action_point_cost
	dst.movement_point_cost = src.movement_point_cost
	dst.range_tiles = src.range_tiles
	dst.targeting_mode = src.targeting_mode
	dst.targeting_flags = src.targeting_flags
	dst.can_target_self = src.can_target_self
	dst.target_shape = src.target_shape
	dst.target_shape_size = src.target_shape_size
	dst.upgraded_range_tiles = src.upgraded_range_tiles
	dst.upgraded_target_shape = src.upgraded_target_shape
	dst.upgraded_target_shape_size = src.upgraded_target_shape_size
	dst.upgrade_description = src.upgrade_description
	dst.uses_per_combat = src.uses_per_combat
	dst.presentation_key = src.presentation_key
	dst.presentation_anim = src.presentation_anim
	dst.scaling_stat = src.scaling_stat
	dst.is_movement_skill = src.kind == GameEnums.AbilityKind.MOVEMENT_SKILL
	dst.effects.clear()
	for eff: EffectData in src.effects:
		dst.effects.append(duplicate_effect(eff))
	dst.upgraded_effects.clear()
	for eff: EffectData in src.upgraded_effects:
		dst.upgraded_effects.append(duplicate_effect(eff))
	dst.sync_legacy_targeting()


static func _effect_dump_line(index: int, eff: EffectData) -> String:
	var base: String = "[%d] %s amount=%d" % [
		index,
		GameEnums.EffectType.keys()[eff.type],
		eff.amount,
	]
	if eff.scaling_stat != GameEnums.StatType.NONE:
		base += " scaling_stat=%s" % GameEnums.StatType.keys()[eff.scaling_stat]
	if eff.type == GameEnums.EffectType.ADD_STATUS or eff.type == GameEnums.EffectType.ADD_STATUS_SELF:
		base += " status=%s duration=%d" % [
			GameEnums.StatusType.keys()[eff.status_type],
			eff.status_duration,
		]
	if eff.bonus_if_adjacent_at_cast != 0:
		base += " bonus_if_adjacent_at_cast=%d" % eff.bonus_if_adjacent_at_cast
	if eff.def_debuff_before_damage != 0:
		base += " def_debuff_before_damage=%d" % eff.def_debuff_before_damage
	if eff.spawn_unit_id != &"":
		base += " spawn_unit_id=%s" % String(eff.spawn_unit_id)
	return base


static func _planning_note(ability: AbilityData) -> String:
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			return "plan_pre_move; ally-only when targeting_mode=ALLY_UNIT."
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			return "plan_pre_move (Run)."
		GameEnums.AbilityKind.UNIVERSAL_WAIT:
			return "plan_action (Wait); blocks further planning when set."
		_:
			return "plan_action (class skill or basic attack)."


static func _effect_impl_note(eff: EffectData) -> String:
	match eff.type:
		GameEnums.EffectType.DAMAGE:
			var s: String = "DAMAGE: CombatSystem physical/magical formula; ability.scaling_stat selects STR/MAG."
			if eff.bonus_if_adjacent_at_cast > 0:
				s += " +%d if target adjacent at cast (data-driven)." % eff.bonus_if_adjacent_at_cast
			if eff.def_debuff_before_damage > 0:
				s += " Applies DEF debuff %d before damage (data-driven)." % eff.def_debuff_before_damage
			return s
		GameEnums.EffectType.DASH:
			return "DASH: straight-line path; may combine with TRAMPLE or BULLDOZE on the same ability."
		GameEnums.EffectType.TRAMPLE:
			return "TRAMPLE: resolve_pass_through_tile during dash or execute_pass_through_walk; open end tile."
		GameEnums.EffectType.BULLDOZE:
			return "BULLDOZE: resolve_pass_through_tile → collision + push; dash or path walk (no DASH required)."
		GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF:
			return "ADD_STATUS: StatusSystem applies %s for %d turn(s)." % [
				GameEnums.StatusType.keys()[eff.status_type],
				eff.status_duration,
			]
		GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL:
			return "%s: DisplacementSystem; collision formula on blocked tiles." % GameEnums.EffectType.keys()[eff.type]
		_:
			return "%s: resolved by AbilitySystem effect handler." % GameEnums.EffectType.keys()[eff.type]


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
			return "Square AoE"
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


const EDITOR_OVERRIDES_PATH: String = "user://class_library_editor_overrides.json"


static func read_editor_save() -> Dictionary:
	if not FileAccess.file_exists(EDITOR_OVERRIDES_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EDITOR_OVERRIDES_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


static func write_editor_save(data: Dictionary) -> bool:
	var file := FileAccess.open(EDITOR_OVERRIDES_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


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
	apply_unit_overrides(read_editor_save().get("units", {}))


static func effect_to_dict(src: EffectData) -> Dictionary:
	return {
		"type": src.type,
		"amount": src.amount,
		"status_type": src.status_type,
		"status_duration": src.status_duration,
		"scaling_stat": src.scaling_stat,
		"bonus_if_adjacent_at_cast": src.bonus_if_adjacent_at_cast,
		"def_debuff_before_damage": src.def_debuff_before_damage,
		"spawn_unit_id": String(src.spawn_unit_id),
	}


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
	return {
		"display_name": src.display_name,
		"kind": src.kind,
		"action_point_cost": src.action_point_cost,
		"movement_point_cost": src.movement_point_cost,
		"range_tiles": src.range_tiles,
		"targeting_mode": src.targeting_mode,
		"targeting_flags": src.targeting_flags,
		"can_target_self": src.can_target_self,
		"target_shape": src.target_shape,
		"target_shape_size": src.target_shape_size,
		"upgraded_range_tiles": src.upgraded_range_tiles,
		"upgraded_target_shape": src.upgraded_target_shape,
		"upgraded_target_shape_size": src.upgraded_target_shape_size,
		"upgrade_description": src.upgrade_description,
		"uses_per_combat": src.uses_per_combat,
		"presentation_key": String(src.presentation_key),
		"presentation_anim": src.presentation_anim,
		"scaling_stat": src.scaling_stat,
		"is_movement_skill": src.is_movement_skill,
		"effects": effects_to_dict_array(src.effects),
		"upgraded_effects": effects_to_dict_array(src.upgraded_effects),
	}


static func apply_ability_dict(dst: AbilityData, data: Dictionary) -> void:
	if dst == null or data.is_empty():
		return
	dst.display_name = String(data.get("display_name", dst.display_name))
	dst.kind = int(data.get("kind", dst.kind))
	dst.action_point_cost = int(data.get("action_point_cost", dst.action_point_cost))
	dst.movement_point_cost = int(data.get("movement_point_cost", dst.movement_point_cost))
	dst.range_tiles = int(data.get("range_tiles", dst.range_tiles))
	dst.targeting_mode = int(data.get("targeting_mode", dst.targeting_mode))
	dst.targeting_flags = int(data.get("targeting_flags", dst.targeting_flags))
	dst.can_target_self = bool(data.get("can_target_self", dst.can_target_self))
	dst.target_shape = int(data.get("target_shape", dst.target_shape))
	dst.target_shape_size = int(data.get("target_shape_size", dst.target_shape_size))
	dst.upgraded_range_tiles = int(data.get("upgraded_range_tiles", dst.upgraded_range_tiles))
	dst.upgraded_target_shape = int(data.get("upgraded_target_shape", dst.upgraded_target_shape))
	dst.upgraded_target_shape_size = int(data.get("upgraded_target_shape_size", dst.upgraded_target_shape_size))
	dst.upgrade_description = String(data.get("upgrade_description", dst.upgrade_description))
	dst.uses_per_combat = int(data.get("uses_per_combat", dst.uses_per_combat))
	dst.presentation_key = StringName(String(data.get("presentation_key", String(dst.presentation_key))))
	dst.presentation_anim = int(data.get("presentation_anim", dst.presentation_anim))
	dst.scaling_stat = int(data.get("scaling_stat", dst.scaling_stat))
	dst.is_movement_skill = bool(data.get("is_movement_skill", dst.kind == GameEnums.AbilityKind.MOVEMENT_SKILL))
	if data.has("effects"):
		dst.effects = effects_from_dict_array(data.get("effects", []))
	if data.has("upgraded_effects"):
		dst.upgraded_effects = effects_from_dict_array(data.get("upgraded_effects", []))
	dst.sync_legacy_targeting()


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
