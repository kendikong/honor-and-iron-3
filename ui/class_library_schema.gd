class_name ClassLibrarySchema
extends RefCounted

## Reference data for the Class Library Editor: glossary, enum definitions,
## ability data dumps, and simulation implementation notes.

const KW_COLOR: String = "#FBBF24"

static var _ABILITY_CODE_BRANCHES: Dictionary = {
	&"knight_defensive_formation": "Phalanx: ability_system applies DEF buff to self and adjacent allies (ID branch).",
	&"knight_shield_bash": "Shield Bash: upgrade adds PUSH 1 on hit (ID branch in ability_system).",
	&"knight_chain_hook": "Chain Hook: upgrade extends PULL range / behavior (ID branch in ability_system).",
	&"knight_bowling_charge": "Bowling Charge: dash + trample + collision; custom BBCode in CombatUiFormatters; dash resolution in ability_system (ID branches).",
	&"knight_trampling_advance": "Trampling Advance: movement skill trample/push rules in ability_system (ID branch).",
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
			"Unit can move through enemy tiles. Per skill text, passing through an enemy triggers the effect "
			+ "as a hit on that enemy."
		),
		# Economy
		"AP": "Action Points — spent on class Active Skills and Run.",
		"MOV": "Movement Points — spent on basic walks and class Movement Skills.",
		"MOVE": "Move up to X tiles.",
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
		GameEnums.StatusType.STUN:
			return "Target loses their Phase Action for the current/next round."
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
			return "DASH 3 | On collision: ATK 3 | PUSH 2"
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
		&"knight_trampling_advance":
			return "MOVE 2 | ATK 2 | PUSH 1"
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
		&"knight_trampling_advance":
			return "MOVE 2"
		_:
			pass
	if ability.is_movement_kind():
		if ability.range_tiles > 0:
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
	lines.append("is_movement_skill: %s" % str(ability.is_movement_skill))
	lines.append("action_point_cost: %d" % ability.action_point_cost)
	lines.append("movement_point_cost: %d" % ability.movement_point_cost)
	lines.append("range_tiles: %d" % ability.range_tiles)
	lines.append("targeting_mode: %s" % GameEnums.TargetingMode.keys()[ability.targeting_mode])
	lines.append("can_target_self: %s" % str(ability.can_target_self))
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
	parts.append("Targeting: AbilitySystem.target_passes_mode + can_target_self gate hover/plan.")
	if ability.is_movement_kind():
		parts.append("Economy: spends movement_point_cost (MP); PRE_MOVE timeline bucket; no action slot.")
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		parts.append("Economy: spends action_point_cost (AP) + extends movement; PRE_MOVE bucket.")
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		parts.append("Economy: turn modifier — exhausts unit (turn_action_used); hidden slot, not Action column.")
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
	if ability.id == &"knight_bowling_charge":
		parts.append("⚠ UI: CombatUiFormatters.ability_effect_bbcode uses hardcoded lines for this id.")
	return "\n".join(parts)


static func in_game_ability_bbcode(ability: AbilityData) -> String:
	if ability == null:
		return ""
	CombatUiFormatters.configure_body_font(ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	var header: String = CombatUiFormatters.ability_desc(ability)
	var body: String = CombatUiFormatters.ability_effect_bbcode(ability)
	var title_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE)
	var body_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY)
	var meta_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL)
	return (
		"[font_size=%d][b]%s[/b][/font_size]\n"
		+ "[font_size=%d]%s[/font_size]\n"
		+ "[font_size=%d][color=#888888]%s[/color][/font_size]"
	) % [title_px, ability.display_name, body_px, body, meta_px, header]


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
			return "DASH: straight-line path; collision damage; may combine with trample ID logic."
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
			return "DataLibrary.get_universal_run(); not listed per-class."
		"UNIVERSAL_WAIT":
			return "DataLibrary.get_universal_wait(); hidden from skill lists."
		_:
			return ""


static func _targeting_mode_tooltip(k: String) -> String:
	match k:
		"ALLY_UNIT":
			return "Ally only"
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
			return "CombatSystem damage pipeline; respects DEF/MAG/armor."
		"PUSH", "PULL":
			return "DisplacementSystem with collision damage."
		"SWAP":
			return "Swaps actor and target tile occupancy."
		"DASH":
			return "Moves actor along line; may apply contact effects."
		"ADD_STATUS", "ADD_STATUS_SELF":
			return "StatusSystem.add_status on target or self."
		"ARMOR_UP":
			return "Adds temporary armor (shield)."
		_:
			return "Handled in AbilitySystem._apply_effect."


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
		GameEnums.StatusType.STUN:
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
