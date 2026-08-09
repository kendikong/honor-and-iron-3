class_name PlanningIcons
extends RefCounted

## Canonical emoji glyphs for planning UI: timeline, unit info, stats column, skill chips, cursor.

# --- Unit stats (timeline row + unit info panel) ---
const STAT_LEVEL: String = "⭐"
const STAT_HP: String = "❤️"
const STAT_STR: String = "💪"
const STAT_MAG: String = "✨"
const STAT_DEF: String = "🛡️"
const STAT_ARMOR: String = "🪖"
const STAT_MOV: String = "👟"
const STAT_AP: String = "🔵"

# --- Action glyphs (cursor + timeline) ---
const GLYPH_WALK: String = "👟"
const GLYPH_RUN: String = "🏃"
const GLYPH_ATTACK: String = "⚔️"
const GLYPH_SKILL: String = "✨"
const GLYPH_DASH: String = "💨"
const GLYPH_HEAL: String = "💚"
const GLYPH_ARMOR_UP: String = "🛡️"
const GLYPH_SWAP: String = "🔄"
const GLYPH_WAIT: String = "⏸"
const GLYPH_FACE: String = "👀"
const GLYPH_NULL: String = "∅"
const GLYPH_RANGE: String = "🏹"
const GLYPH_TARGET_SELF: String = "🎯"
const GLYPH_COMPOSITE_SEP: String = "/"


static func stat_icon(stat_type: GameEnums.StatType) -> String:
	match stat_type:
		GameEnums.StatType.PHYSICAL:
			return STAT_STR
		GameEnums.StatType.MAGICAL:
			return STAT_MAG
		GameEnums.StatType.DEFENSE:
			return STAT_DEF
	return ""


static func keyword_icon(keyword: String) -> String:
	var kw := keyword.to_upper()
	if kw.begins_with("ATK") or kw.ends_with("ATK") or kw == "EXPLODE":
		return GLYPH_ATTACK
	match kw:
		"HEAL": return GLYPH_HEAL
		"SHIELD": return GLYPH_ARMOR_UP
		"SWAP": return GLYPH_SWAP
		"DASH", "PUSH", "PULL": return GLYPH_DASH
		"MOV", "MOVE": return STAT_MOV
		"AP": return STAT_AP
		"HP": return STAT_HP
		"STR": return STAT_STR
		"MAG": return STAT_MAG
		"DEF": return STAT_DEF
		"ARMOR": return STAT_ARMOR
		"LEVEL": return STAT_LEVEL
		"RANGE", "AOE": return GLYPH_RANGE
		"CLEANSE": return GLYPH_SKILL
		"COLLISION": return "💥"
		"PURGE": return "🌬️"
		"SPAWN": return "🥚"
		"TELEPORT": return "🌀"
		"TRAMPLE", "BULLDOZE": return "🦏"
		"PUSH THROUGH": return GLYPH_DASH
		"WPN": return "🗡️"
		"DESTROY OBSTACLE": return "🔨"
		"ELECTRIFIED": return "⚡"
		"WEAK TRAP", "TRAP": return "🕸️"
		"BURN": return "🔥"
		"BLEED": return "🩸"
		"POISON": return "🧪"
		"WEAKEN": return "📉"
		"VULNERABLE": return "💔"
		"STAGGER": return "💫"
		"ROOT": return "🌱"
		"SILENCE": return "🔇"
		"TAUNT": return "🗯️"
		"BLIND": return "👁️‍🗨️"
		"PACIFY": return "🕊️"
		"FEAR": return "😱"
		"CONFUSION": return "❓"
		"POLYMORPH": return "🐸"
		"MARK": return "🎯"
		"IRON GRIP": return "⛓️"
		"RETALIATION PROTOCOL": return "⚙️"
		"INDOMITABLE WILL": return "🛡️"
		"THORNS": return "🌵"
		"STR UP": return "💪⬆️"
		"MAG UP": return "✨⬆️"
		"DEF UP": return "🛡️⬆️"
		"MOV UP": return "👟⬆️"
		"ACC UP": return "🏹⬆️"
		"MP UP", "AP UP": return "🔵⬆️"
		"DEF DOWN": return "🛡️⬇️"
		"ACC DOWN": return "🏹⬇️"
		"MOV DOWN": return "👟⬇️"
		"PIERCE": return "🏹"
		"GHOST": return "👻"
		"STEALTH": return "🥷"
		"INTERCEPT": return "🛡️"
		"STURDY": return "🧱"
		"INVULNERABLE": return "🛡️✨"
		"AIRBORNE": return "🦅"
		"CANTO": return "🐎"
		"RUNNING": return "🏃"
		"RETALIATION INFINITE RANGE": return "⚙️🏹"
		"INDOMITABLE WILL UPGRADED": return "🛡️⭐"
		"ACC": return "🏹"
	return ""

static func move_glyph(uses_run: bool) -> String:
	return GLYPH_RUN if uses_run else GLYPH_WALK


static func ability_glyph(ability: AbilityData) -> String:
	if ability == null:
		return GLYPH_SKILL
	if DataLibrary.is_universal_wait(ability.id):
		return GLYPH_WAIT
	if AbilitySystem.is_run_ability(ability):
		return GLYPH_RUN
	if ability.is_movement_kind() and AbilitySystem.ability_has_movement_effect(ability):
		return GLYPH_DASH
	if AbilitySystem.ability_is_offensive_dash(ability):
		return GLYPH_ATTACK
	if AbilitySystem.ability_has_movement_effect(ability):
		return GLYPH_DASH
	if ability.is_movement_kind():
		if AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.SWAP):
			return GLYPH_SWAP
		return GLYPH_WALK
	if (
		AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.DAMAGE)
		or AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.EXPLODE)
		or AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.RANGED_EXPLODE)
	):
		return GLYPH_ATTACK
	if AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.HEAL):
		return GLYPH_HEAL
	if AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.ARMOR_UP):
		return GLYPH_ARMOR_UP
	if AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.SWAP):
		return GLYPH_SWAP
	return GLYPH_SKILL


static func awaiting_phase_glyph(ability: AbilityData) -> String:
	match AbilitySystem.planning_awaiting_phase(ability):
		GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT:
			return GLYPH_DASH
		GameEnums.PlanningAwaitingPhase.TARGET_PICK:
			return GLYPH_TARGET_SELF
		_:
			return GLYPH_SKILL


static func action_glyph(action: TimelineAction) -> String:
	if action == null:
		return ""
	match action.type:
		GameEnums.ActionType.MOVE:
			return move_glyph(action.uses_run)
		GameEnums.ActionType.FACE:
			return GLYPH_FACE
		GameEnums.ActionType.ABILITY:
			if action.ability != null and DataLibrary.is_universal_wait(action.ability.id):
				return GLYPH_WAIT
			if action.awaiting_target and action.ability != null:
				return awaiting_phase_glyph(action.ability)
			return ability_glyph(action.ability)
	return ""


static func join_glyphs(parts: Array) -> String:
	var glyphs: PackedStringArray = []
	for raw: Variant in parts:
		var glyph: String = str(raw)
		if glyph != "":
			glyphs.append(glyph)
	if glyphs.is_empty():
		return ""
	if glyphs.size() == 1:
		return glyphs[0]
	return GLYPH_COMPOSITE_SEP.join(glyphs)


static func range_chip_glyph(label: String) -> String:
	if label.begins_with("DASH"):
		return GLYPH_DASH
	if label.begins_with("MOVE"):
		return GLYPH_WALK
	if label == "SELF" or label == "RANGE 0":
		return GLYPH_TARGET_SELF
	return GLYPH_RANGE
