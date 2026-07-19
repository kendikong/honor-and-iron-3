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
	return {
		"AOE ATK": "Deals damage to all units within the target shape.",
		"AOE": "Area effect — hits multiple tiles.",
		"AP": "Action Points consumed to use an ability.",
		"ATK": "Reduces target HP. Armor absorbs damage before HP.",
		"CLEANSE": "Removes all negative status effects from the target.",
		"COLLISION": "Damage dealt when displacement hits a wall or another unit.",
		"COUNTER ATTACK": "Retaliates against the attacker for listed ATK power, scaled by STR and weapon.",
		"DASH": "Moves in a straight line; may apply effects on each tile entered.",
		"DESTROY OBSTACLE": "Instantly removes a wall, trap, or destructible terrain.",
		"EXPLODE": "Deals damage to all units in adjacent cardinal tiles.",
		"HEAL": "Restores target HP, capped at Max HP.",
		"MOV": "Movement Points available per turn.",
		"MOVE": "Movement Points available per turn.",
		"PULL": "Displaces target towards caster. Collisions deal damage.",
		"PUSH": "Displaces target away from caster. Collisions deal damage.",
		"PURGE": "Removes all positive buffs and shields from the target.",
		"RANGE": "Maximum targeting or effect distance in tiles.",
		"SHIELD": "Grants temporary armor that absorbs damage before HP.",
		"SPAWN": "Creates a new unit on the target tile.",
		"SWAP": "Caster and target exchange tile positions.",
		"TELEPORT": "Moves instantly, ignoring pathing constraints.",
		"TRAMPLE": "Pass through enemy tiles; PUSH 1 when passing through or stopping on them.",
		"WPN": "Weapon Might — added to ability base power in the damage formula.",
		"DEF": "Defense — reduces incoming physical damage.",
		"STR": "Strength — increases physical attack power.",
		"MAG": "Magic — increases magical attack power and mitigates magical damage.",
	}


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
			"tooltip": CombatUiFormatters._status_desc(st),
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
	return "\n\n".join(parts)


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
		parts.append("Economy: exhausts unit (turn_action_used); hidden plan_action slot.")
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
	var header: String = CombatUiFormatters.ability_desc(ability)
	var body: String = CombatUiFormatters.ability_effect_bbcode(ability)
	return "[b]%s[/b]\n%s\n[color=#888888]%s[/color]" % [
		ability.display_name,
		body,
		header,
	]


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
	match st:
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "On taking damage, counter-attacks attacker (passive hook + status)."
		GameEnums.StatusType.RETALIATION_INFINITE_RANGE:
			return "Phalanx [+] upgrade: retaliation ignores range."
		GameEnums.StatusType.BURN:
			return "Start of turn: unmitigated damage equal to status value."
		GameEnums.StatusType.POISON:
			return "Start of turn: 10% max HP; blocks healing."
		GameEnums.StatusType.BLEED:
			return "On move: unmitigated damage equal to status value."
		_:
			return "StatusSystem tick/apply; stat buffs modify derived stats."


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
