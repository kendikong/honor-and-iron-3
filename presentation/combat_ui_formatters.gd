class_name CombatUiFormatters
extends RefCounted

## Shared BBCode formatters for tactical combat (extracted from board_view).

const HEX_DIM: String = "777777"
const HEX_TILE: String = "82E0AA"
const HEX_INTENT: String = "E74C3C"
const HEX_DEATH: String = "E74C3C"
const HEX_MOVE: String = "9fb6d4"
const HEX_DMG: String = "f5b15a"
const HEX_ATTACK: String = "e2b7f0"
const HEX_TURN: String = "7fd4ff"
const LOG_FORMULA_FONT_SIZE: int = 7
const LOG_FONT_SIZE: int = 10

const PLAYER_COLORS: Array[Color] = [
	Color(0.36, 0.62, 0.92),
	Color(0.36, 0.92, 0.62),
	Color(0.92, 0.92, 0.36),
	Color(0.92, 0.36, 0.92),
]

## Legacy BBCode tier keys → ratio of inspector body font (medium body = 20px design ref).
const _FONT_TIER_RATIO: Dictionary = {
	13: 1.0,
	10: 0.9,
	9: 0.82,
	8: 0.75,
	7: 0.65,
}

static var _body_font_px: int = 20


static func configure_body_font(body_px: int) -> void:
	_body_font_px = maxi(10, body_px)


static func set_text_scale(_scale: float) -> void:
	# Kept for call-site compat; body font already includes text scale via GameSettings.
	pass


static func scaled_font_size(legacy_tier: int) -> int:
	var ratio: float = float(_FONT_TIER_RATIO.get(legacy_tier, float(legacy_tier) / 20.0))
	return maxi(1, int(round(float(_body_font_px) * ratio)))


static func player_color(player_id: int) -> Color:
	if NetworkManager == null or not NetworkManager.is_multiplayer:
		return PLAYER_COLORS[0]
	var keys: Array = NetworkManager.player_usernames.keys()
	keys.sort()
	var idx: int = keys.find(player_id)
	if idx >= 0 and idx < PLAYER_COLORS.size():
		return PLAYER_COLORS[idx]
	return PLAYER_COLORS[0]


static func facing_name(facing: int) -> String:
	return GameEnums.Facing.keys()[facing].capitalize()


static func reason_text(code: String) -> String:
	match code:
		"no_path":
			return "can't reach"
		"cannot_use_ability":
			return "out of range / no AP"
		"no_actor":
			return "unit gone"
		"unknown_action_type":
			return "invalid"
		"target_displaced":
			return "ally plan cancelled — target moved"
		"cannot_undo_trample":
			return "cannot undo trample move"
		_:
			return code


static func tile_info(board: BoardState, coord: Vector2i) -> String:
	if board == null or not board.is_in_bounds(coord):
		return "[font_size=%d][color=#%s]Hover a tile for details.[/color][/font_size]" % [
			CombatUiFormatters.scaled_font_size(10),
			HEX_DIM,
		]
	var tile := board.get_tile(coord)
	if tile == null or tile.definition == null:
		return (
			"[font_size=%d][color=#%s][b]Unknown[/b][/color]"
			+ "[right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]"
		) % [scaled_font_size(9), HEX_DIM, coord.x, coord.y]
	var desc: String = _terrain_desc(tile.definition)
	return (
		"[font_size=%d][color=#%s][b]%s[/b][/color]"
		+ "[right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]\n[font_size=%d]%s[/font_size]"
	) % [scaled_font_size(9), HEX_TILE, tile.definition.display_name, coord.x, coord.y, scaled_font_size(10), desc]


static func unit_info(board: BoardState, unit: UnitState) -> String:
	var lines: Array[String] = []
	lines.append(
		(
			"[color=#4DB8FF][font_size=%d][b]%s[/b][/font_size][/color]"
			+ "  [font_size=%d][color=#aaaaaa](%s)[/color][/font_size]"
		)
		% [scaled_font_size(13), unit.definition.display_name, scaled_font_size(10), "Player" if not unit.is_enemy() else "Enemy"],
	)
	var move_type: String = GameEnums.MovementType.keys()[unit.definition.movement_type].capitalize()
	lines.append(
		"[font_size=%d]Lv.%d %s  |  Move: %s[/font_size]"
		% [scaled_font_size(10), unit.level, String(unit.definition.id).capitalize(), move_type],
	)
	lines.append(
		"[font_size=%d][color=#4ADE80][b][hint=Hit Points]❤️ HP:[/hint] %d/%d[/b][/color]    Facing %s[/font_size]"
		% [scaled_font_size(9), unit.health.current_hp, unit.health.max_hp, facing_name(unit.facing)],
	)
	lines.append(
		(
			"[font_size=%d][color=#F1C40F][b][hint=Movement Points]👢 MP:[/hint] %d/%d[/b][/color]"
			+ "    [color=#E74C3C][b][hint=Action Points]⚔️ AP:[/hint] %d/%d[/b][/color][/font_size]"
		)
		% [
			scaled_font_size(9),
			unit.movement.points_left, unit.movement.max_points,
			unit.ability.points_left, unit.ability.max_points,
		],
	)
	lines.append(
		(
			"[font_size=%d]💪 STR: %s  ✨ MAG: %s  🛡️ DEF: %s"
			% [
				scaled_font_size(10),
				_format_stat_with_tooltip(unit, GameEnums.StatType.PHYSICAL),
				_format_stat_with_tooltip(unit, GameEnums.StatType.MAGICAL),
				_format_stat_with_tooltip(unit, GameEnums.StatType.DEFENSE),
			]
			+ ("  [hint=Armor]🪖 ARM:[/hint] %d" % unit.armor if unit.armor > 0 else "")
			+ "[/font_size]"
		),
	)
	lines.append(_equipment_info(unit))
	if unit.is_enemy():
		if unit.definition.behavior != null and unit.definition.behavior.attack != null:
			var att: AbilityData = unit.definition.behavior.attack
			lines.append("Attack: %s" % att.display_name)
	else:
		var names: Array[String] = []
		for ability: AbilityData in unit.active_abilities:
			names.append("[hint=\"%s\"]%s[/hint]" % [ability_desc(ability, unit), ability.display_name])
		lines.append(
			"[font_size=%d]Abilities: %s[/font_size]"
			% [scaled_font_size(8), ", ".join(names) if not names.is_empty() else "None"],
		)
		var passives: Array[String] = []
		for p: PassiveData in unit.active_passives:
			passives.append("%s: %s" % [p.display_name, _parse_keywords(p.description)])
		if not passives.is_empty():
			lines.append("[font_size=%d][b]Passives[/b][/font_size]" % scaled_font_size(8))
			for line: String in passives:
				lines.append("[font_size=%d]%s[/font_size]" % [scaled_font_size(8), line])
	if board != null and board.is_in_bounds(unit.position):
		var tile := board.get_tile(unit.position)
		if tile != null and tile.definition != null and tile.definition.fortitude != 0:
			var fort_val: int = tile.definition.fortitude
			var sign_str: String = "+" if fort_val > 0 else ""
			lines.append(
				"[font_size=%d][hint=\"%s\"]🌿 Terrain: %s (%s%d Fortitude)[/hint][/font_size]"
				% [
					scaled_font_size(10),
					"Reduces incoming damage." if fort_val > 0 else "Increases incoming damage.",
					tile.definition.display_name,
					sign_str,
					fort_val,
				],
			)
	if unit.active_statuses.size() > 0:
		var status_strs: Array[String] = []
		for status in unit.active_statuses:
			var s_name: String = _status_name(status.type)
			if status.duration > 1:
				s_name += " (%d)" % status.duration
			var hint: String = _status_hint(status.type)
			if hint != "":
				status_strs.append("[hint=\"%s\"]%s[/hint]" % [hint, s_name])
			else:
				status_strs.append(s_name)
		lines.append("[color=#%s]Statuses: %s[/color]" % [HEX_INTENT, ", ".join(status_strs)])
	return "\n".join(lines)


static func summarize_intents(
	board: BoardState,
	phase: int,
	intent_units: Dictionary,
	intent_list: Array = [],
) -> String:
	if board == null:
		return "  (none)"
	var lines: Array[String] = []
	var show_all: bool = phase == CombatDirector.Phase.ENEMY_TURN
	var intents: Array = intent_list if not intent_list.is_empty() else board.intents
	for intent: Variant in intents:
		if not intent is Intent:
			continue
		var row: Intent = intent as Intent
		if show_all or intent_units.has(row.enemy_id):
			lines.append("  - %s" % row.summary)
	if lines.is_empty():
		if show_all:
			return "  (none)"
		return "  (hover an enemy, or select a unit they target)"
	return "\n".join(lines)


static func describe_action(board: BoardState, action: TimelineAction) -> String:
	if action == null:
		return "—"
	var actor: UnitState = board.get_unit_by_id(action.actor_id) if board != null else null
	var actor_name: String = actor.definition.display_name if actor != null else "unit %d" % action.actor_id
	match action.type:
		GameEnums.ActionType.FACE:
			return "%s face %s" % [actor_name, facing_name(action.face_dir)]
		GameEnums.ActionType.MOVE:
			return "%s move -> %s" % [actor_name, action.target_coord]
		GameEnums.ActionType.ABILITY:
			var ability_name: String = action.ability.display_name if action.ability != null else "ability"
			var target_name: String = actor_name
			if board != null and action.target_unit_id >= 0:
				var tgt := board.get_unit_by_id(action.target_unit_id)
				if tgt != null:
					target_name = tgt.definition.display_name
			return "%s %s -> %s" % [actor_name, ability_name, target_name]
	return "?"


static func class_symbol(unit: UnitState) -> String:
	match unit.definition.id:
		&"knight": return "♞"
		&"paladin": return "🛡️"
		&"fighter": return "✊"
		&"cavalier": return "🧲"
		&"archer": return "🏹"
		&"mage": return "✨"
		&"cleric": return "➕"
		&"assassin": return "⚔️"
		&"mercenary": return "🪓"
		&"gryphon": return "🦅"
		&"monk": return "📿"
		&"engineer": return "🔧"
		&"shaman": return "👁️"
		&"warden": return "♜"
		&"swordmaster": return "🗡️"
		&"charger": return "🔱"
		&"artillery": return "💣"
		&"shover": return "↔️"
	return "👤"


static func action_symbol_text(
	board: BoardState,
	action: TimelineAction,
	unit: UnitState,
) -> String:
	if action == null:
		return "-"
	if action.type == GameEnums.ActionType.MOVE:
		return "🏃 (%d,%d)" % [action.target_coord.x, action.target_coord.y]
	if action.type == GameEnums.ActionType.FACE:
		return "👀 %s" % facing_name(action.face_dir)
	if action.type == GameEnums.ActionType.ABILITY:
		var symbol: String = "✨"
		if action.ability != null:
			if action.ability.id == &"universal_run":
				return "🏃 Run"
			if action.ability.id == &"universal_swap":
				return "↔️ Swap"
			var has_damage: bool = false
			var has_heal: bool = false
			for eff: EffectData in action.ability.effects:
				if eff.type in [
					GameEnums.EffectType.DAMAGE,
					GameEnums.EffectType.EXPLODE,
					GameEnums.EffectType.RANGED_EXPLODE,
				]:
					has_damage = true
				if eff.type == GameEnums.EffectType.HEAL:
					has_heal = true
			if has_damage:
				symbol = "⚔️"
			elif has_heal:
				symbol = "💚"
		var ability_name: String = action.ability.display_name if action.ability != null else ""
		var target_name: String = ""
		if action.target_unit_id >= 0 and board != null:
			var tgt := board.get_unit_by_id(action.target_unit_id)
			if tgt != null:
				target_name = tgt.definition.display_name
		if target_name == "":
			target_name = "(%d,%d)" % [action.target_coord.x, action.target_coord.y]
		if ability_name != "":
			return "%s %s > %s" % [symbol, ability_name, target_name]
		return "%s %s" % [symbol, target_name]
	return "❓"


static func format_unit_plan_timeline(
	board: BoardState,
	plan: Timeline,
	unit: UnitState,
	statuses: PackedStringArray,
) -> Dictionary:
	var steps: Array[TimelineAction] = UnitPlanOrder.ordered_steps_for_unit(plan, unit.id)
	if steps.is_empty():
		return {
			"text": "—",
			"tooltip": "No actions queued",
			"failed": false,
		}
	var parts: PackedStringArray = []
	var tooltip_lines: PackedStringArray = []
	var failed: bool = false
	for i: int in range(steps.size()):
		var step: TimelineAction = steps[i]
		var symbol: String = action_symbol_text(board, step, unit)
		parts.append("%d. %s" % [i + 1, symbol])
		var detail: String = describe_action(board, step)
		var reason: String = UnitPlanOrder.status_for_action(plan, statuses, step)
		if reason != "":
			failed = true
			tooltip_lines.append(
				"%d. %s — %s" % [i + 1, detail, reason_text(reason)],
			)
		else:
			tooltip_lines.append("%d. %s" % [i + 1, detail])
	var arrow: String = " → "
	return {
		"text": arrow.join(parts),
		"tooltip": "\n".join(tooltip_lines),
		"failed": failed,
	}


## Returns { "line": String, "telemetry": Dictionary } — pass telemetry dict in/out for damage formulas.
static func log_line(board: BoardState, event: SimEvent, last_telemetry: Dictionary) -> Dictionary:
	var d: Dictionary = event.data
	var telemetry: Dictionary = last_telemetry.duplicate(true)
	var line: String = ""
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			if not d.get("is_dash", false):
				telemetry.clear()
			line = _color(HEX_MOVE, "%s moves to %s" % [
				_unit_name(board, d.get("actor", -1)),
				str(d.get("to", Vector2i.ZERO)),
			])
		GameEnums.SimEventType.UNIT_PUSHED:
			telemetry.clear()
			line = _color(HEX_MOVE, "%s is displaced to %s" % [
				_unit_name(board, d.get("unit", -1)),
				str(d.get("to", Vector2i.ZERO)),
			])
		GameEnums.SimEventType.COLLISION:
			var detail := "%s collides" % _unit_name(board, d.get("unit", -1))
			line = _color(HEX_DMG, detail)
		GameEnums.SimEventType.MATH_TELEMETRY:
			telemetry = d.duplicate(true)
			line = ""
		GameEnums.SimEventType.ABILITY_USED:
			if not d.get("is_dash", false):
				telemetry.clear()
			var ability_name: String = d.get("ability_name", "an ability")
			var actor_name: String = _unit_name(board, d.get("actor", -1))
			var t_id: int = int(d.get("target_unit", -1))
			if t_id != -1:
				line = _color(HEX_ATTACK, "%s uses %s on %s" % [
					actor_name, ability_name, _unit_name(board, t_id),
				])
			elif d.has("target_coord"):
				var c: Vector2i = d["target_coord"]
				line = _color(HEX_ATTACK, "%s uses %s on tile (%d, %d)" % [
					actor_name, ability_name, c.x, c.y,
				])
			else:
				line = _color(HEX_ATTACK, "%s uses %s" % [actor_name, ability_name])
		GameEnums.SimEventType.COUNTER_ATTACK:
			line = _color(HEX_ATTACK, "%s counter-attacks %s" % [
				_unit_name(board, d.get("actor", -1)),
				_unit_name(board, d.get("target_unit", -1)),
			])
		GameEnums.SimEventType.UNIT_DAMAGED:
			var incoming: int = int(d.get("amount", 0))
			var hp_dmg: int = int(d.get("hp_damaged", incoming))
			var after_hp: int = int(d.get("hp", 0))
			var before_hp: int = after_hp + hp_dmg
			var hp_note := " (%d HP -> %d HP)" % [before_hp, after_hp]
			line = _color(HEX_DMG, "%s takes %d damage%s" % [
				_unit_name(board, d.get("unit", -1)), incoming, hp_note,
			])
			if incoming <= 0:
				line = _color(HEX_DMG, "%s takes 0 damage (fully mitigated)" % [
					_unit_name(board, d.get("unit", -1)),
				])
			elif not telemetry.is_empty():
				var formula: String = format_damage_telemetry(telemetry, incoming, hp_dmg, int(d.get("armor_damaged", 0)))
				line += "\n[color=#aaaaaa][font_size=%d]   %s[/font_size][/color]" % [scaled_font_size(LOG_FORMULA_FONT_SIZE), formula]
				telemetry.clear()
		GameEnums.SimEventType.UNIT_DIED:
			telemetry.clear()
			line = _color(HEX_DEATH, "%s is defeated" % _unit_name(board, d.get("unit", -1)))
		GameEnums.SimEventType.UNIT_FACED:
			line = _color(HEX_MOVE, "%s turns to face %s" % [
				_unit_name(board, d.get("unit", -1)),
				facing_name(int(d.get("facing", GameEnums.Facing.SOUTH))),
			])
		GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
			line = _color(HEX_INTENT, "- enemy phase -")
		GameEnums.SimEventType.TURN_ENDED:
			line = _color(HEX_TURN, "--- Turn %s ---" % d.get("turn", 0))
	return {"line": line, "telemetry": telemetry}


static func _unit_name(board: BoardState, unit_id: int) -> String:
	if board != null:
		var unit := board.get_unit_by_id(unit_id)
		if unit != null:
			return unit.definition.display_name
	return "Unit %d" % unit_id


static func _color(hex: String, text: String) -> String:
	return "[color=#%s]%s[/color]" % [hex, text]


static func _terrain_desc(def: TerrainData) -> String:
	if def.id == &"tall_grass" or def.id == &"forest":
		return "Tall Grass. +1 Fortitude."
	if def.id == &"castle":
		return "Castle. +2 Fortitude."
	if def.id == &"water":
		return "Water. -1 Fortitude."
	if def.hazard_damage > 0 and def.blocks_movement:
		return "Pit. Can't be walked into, but a unit shoved in falls and takes %d damage." % def.hazard_damage
	if def.hazard_damage > 0:
		return "Hazard. Deals %d damage to a unit that enters it." % def.hazard_damage
	if def.blocks_movement:
		return "Wall. Blocks movement; displaced units collide with it."
	return "Open ground. No special effect."


static func ability_desc(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	return "%s (RANGE %d | AP %d | %s)" % [
		ability.display_name,
		ability.range_tiles,
		ability.action_point_cost,
		ability_effect_string(ability, unit),
	]


static func _status_name(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "Iron Grip"
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "Retaliation Protocol"
		GameEnums.StatusType.INDOMITABLE_WILL:
			return "Indomitable Will"
		GameEnums.StatusType.THORNS:
			return "Thorns"
		GameEnums.StatusType.STAT_BUFF_STR:
			return "STR UP"
		GameEnums.StatusType.STAT_BUFF_MAG:
			return "MAG UP"
		GameEnums.StatusType.STAT_BUFF_DEF:
			return "DEF UP"
		GameEnums.StatusType.STAT_BUFF_MOV:
			return "MOV UP"
		GameEnums.StatusType.STAT_BUFF_ACC:
			return "ACC UP"
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return "DEF DOWN"
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return "ACC DOWN"
		GameEnums.StatusType.STAT_DEBUFF_MOV:
			return "MOV DOWN"
		_:
			return GameEnums.StatusType.keys()[t].capitalize()


static func _status_desc(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.STURDY:
			return "Ignores the next displacement effect (push/pull)."
		GameEnums.StatusType.MARK:
			return "Next attack against this unit will Backstab."
		GameEnums.StatusType.INTERCEPT:
			return "Takes damage in place of adjacent allies."
		GameEnums.StatusType.STEALTH:
			return "Cannot be targeted by direct attacks."
		GameEnums.StatusType.TAUNT:
			return "Forces enemies to target this unit."
		GameEnums.StatusType.ROOT:
			return "Cannot move."
		GameEnums.StatusType.STUN:
			return "Cannot act or move."
		GameEnums.StatusType.VULNERABLE:
			return "Takes additional damage."
		GameEnums.StatusType.THORNS:
			return "Reflects damage back to attackers."
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "Target Defense (DEF) is halved on their next turn (rounded up)."
		_:
			return _status_name(t)


static func _append_status_effect_part(
	parts: Array[String],
	effect: EffectData,
	self_target: bool,
	bbcode: bool,
) -> void:
	if effect == null:
		return
	var dur: String = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
	var label: String = _status_name(effect.status_type)
	var hint: String = _status_desc(effect.status_type)
	var amount_str: String = _effect_amount_string(effect)
	if amount_str != "0" and amount_str != "":
		match effect.status_type:
			GameEnums.StatusType.STAT_BUFF_STR:
				hint = "Increases Strength (STR) by %s." % amount_str
			GameEnums.StatusType.STAT_BUFF_MAG:
				hint = "Increases Magic (MAG) by %s." % amount_str
			GameEnums.StatusType.STAT_BUFF_DEF:
				hint = "Increases Defense (DEF) by %s." % amount_str
			GameEnums.StatusType.STAT_BUFF_MOV:
				hint = "Increases Movement Points (MP) by %s." % amount_str
			GameEnums.StatusType.STAT_BUFF_ACC:
				hint = "Increases Accuracy (ACC) by %s." % amount_str
			GameEnums.StatusType.STAT_DEBUFF_DEF:
				hint = "Decreases Defense (DEF) by %s." % amount_str
			GameEnums.StatusType.STAT_DEBUFF_MOV:
				hint = "Decreases Movement Points (MP) by %s." % amount_str
			GameEnums.StatusType.STAT_DEBUFF_ACC:
				hint = "Decreases Accuracy (ACC) by %s." % amount_str
	var prefix: String = "Self " if self_target else "Apply "
	if bbcode:
		parts.append("%s%s%s" % [prefix, _kw_hint(label, hint), dur])
	else:
		parts.append("%s%s%s" % [prefix, label, dur])


static func ability_effect_string(ability: AbilityData, _unit: UnitState = null) -> String:
	if ability == null:
		return ""
	if ability.id == &"knight_bowling_charge":
		return "DASH 3 | TRAMPLE | PUSH 1 | COLLISION"
	var parts: Array[String] = []
	for effect: EffectData in ability.effects:
		match effect.type:
			GameEnums.EffectType.DAMAGE:
				parts.append("ATK %s" % _effect_amount_string(effect))
			GameEnums.EffectType.HEAL:
				parts.append("HEAL %s" % _effect_amount_string(effect))
			GameEnums.EffectType.PUSH:
				parts.append("PUSH %s" % _effect_amount_string(effect))
			GameEnums.EffectType.PULL:
				parts.append("PULL %s" % _effect_amount_string(effect))
			GameEnums.EffectType.SWAP:
				parts.append("SWAP")
			GameEnums.EffectType.ARMOR_UP:
				parts.append("SHIELD %s" % _effect_amount_string(effect))
			GameEnums.EffectType.EXPLODE:
				parts.append("EXPLODE %s" % _effect_amount_string(effect))
			GameEnums.EffectType.RANGED_EXPLODE:
				parts.append("AOE ATK %s" % _effect_amount_string(effect))
			GameEnums.EffectType.SPAWN:
				parts.append("SPAWN %s" % str(effect.spawn_unit_id).capitalize())
			GameEnums.EffectType.ADD_STATUS:
				_append_status_effect_part(parts, effect, false, false)
			GameEnums.EffectType.ADD_STATUS_SELF:
				_append_status_effect_part(parts, effect, true, false)
			GameEnums.EffectType.DASH:
				parts.append("DASH %s" % _effect_amount_string(effect))
			GameEnums.EffectType.PURGE:
				parts.append("PURGE")
			GameEnums.EffectType.CLEANSE:
				parts.append("CLEANSE")
			_:
				parts.append(GameEnums.EffectType.keys()[effect.type].capitalize())
	return " | ".join(parts) if not parts.is_empty() else "No effect"


static func ability_effect_bbcode(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	if ability.id == &"knight_bowling_charge":
		return "%s | %s | %s | %s" % [
			_kw_hint("DASH 3", "Move up to 3 tiles in a straight line."),
			_kw_hint("TRAMPLE", "Pass through enemy tiles."),
			_kw_hint("PUSH 1", "Push enemies on contact."),
			_kw_hint("COLLISION", "Collision damage on contact."),
		]
	var parts: Array[String] = []
	for effect: EffectData in ability.effects:
		match effect.type:
			GameEnums.EffectType.DAMAGE:
				parts.append(_kw_hint("ATK %s" % _effect_amount_string(effect), "Reduces target HP."))
			GameEnums.EffectType.HEAL:
				parts.append(_kw_hint("HEAL %s" % _effect_amount_string(effect), "Restores target HP."))
			GameEnums.EffectType.PUSH:
				parts.append(_kw_hint("PUSH %s" % _effect_amount_string(effect), "Displaces target away."))
			GameEnums.EffectType.PULL:
				parts.append(_kw_hint("PULL %s" % _effect_amount_string(effect), "Displaces target toward caster."))
			GameEnums.EffectType.SWAP:
				parts.append(_kw_hint("SWAP", "Caster and target exchange positions."))
			GameEnums.EffectType.DASH:
				parts.append(_kw_hint("DASH %s" % _effect_amount_string(effect), "Straight-line movement."))
			GameEnums.EffectType.ARMOR_UP:
				parts.append(_kw_hint("SHIELD %s" % _effect_amount_string(effect), "Temporary armor."))
			GameEnums.EffectType.EXPLODE:
				parts.append(_kw_hint("EXPLODE %s" % _effect_amount_string(effect), "Damages adjacent units."))
			GameEnums.EffectType.RANGED_EXPLODE:
				parts.append(_kw_hint("AOE ATK %s" % _effect_amount_string(effect), "Damages units in target shape."))
			GameEnums.EffectType.SPAWN:
				parts.append(_kw_hint("SPAWN %s" % str(effect.spawn_unit_id).capitalize(), "Summons a unit."))
			GameEnums.EffectType.ADD_STATUS:
				_append_status_effect_part(parts, effect, false, true)
			GameEnums.EffectType.ADD_STATUS_SELF:
				_append_status_effect_part(parts, effect, true, true)
			GameEnums.EffectType.PURGE:
				parts.append(_kw_hint("PURGE", "Removes positive buffs and shields."))
			GameEnums.EffectType.CLEANSE:
				parts.append(_kw_hint("CLEANSE", "Removes negative status effects."))
			_:
				parts.append(_effect_amount_string(effect))
	var body: String = " | ".join(parts) if not parts.is_empty() else "No effect"
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		var shape_name: String = GameEnums.TargetShape.keys()[ability.target_shape].capitalize().replace("Aoe ", "")
		var shape: String = "%s: %s %d | " % [
			_kw_hint("AOE", "Area effect — hits multiple tiles."),
			shape_name,
			ability.target_shape_size,
		]
		return shape + body
	return body


static func format_damage_telemetry(m: Dictionary, incoming: int, hp_dmg: int, armor_dmg: int) -> String:
	var base: int = int(m.get("base", 0))
	var wpn: int = int(m.get("wpn", 0))
	var stat_val: int = int(m.get("stat_val", 0))
	var stat_mult: float = 1.0 + float(stat_val) / 5.0
	var mult_raw: float = float(m.get("multiplier_raw", m.get("floored", m.get("final_raw", 0))))
	var t_def: int = int(m.get("target_def", 0))
	var fort: int = int(m.get("fortitude", m.get("fort", 0)))
	var formula := "(%s + %s) × %s = %s" % [base, wpn, _fmt_calc_num(stat_mult), _fmt_calc_num(mult_raw)]
	formula += " - %s" % t_def
	if fort != 0:
		formula += " - %s" % fort
	formula += " → %d incoming" % incoming
	if armor_dmg > 0:
		formula += " (-%d armor → %d HP)" % [armor_dmg, hp_dmg]
	return formula


static func append_victory_log(log_label: RichTextLabel, victory: bool) -> void:
	if log_label == null:
		return
	var hex: String = HEX_TURN if victory else HEX_DEATH
	var text: String = "=== Victory ===" if victory else "=== Defeat ==="
	log_label.append_text("[color=#%s][font_size=%d]%s[/font_size]\n" % [hex, scaled_font_size(LOG_FONT_SIZE), text])


static func _effect_amount_string(eff: EffectData) -> String:
	if eff == null:
		return "0"
	if eff.scaling_stat != GameEnums.StatType.NONE and eff.amount > 0:
		return "%d + %s" % [eff.amount, GameEnums.StatType.keys()[eff.scaling_stat]]
	if eff.scaling_stat != GameEnums.StatType.NONE:
		return GameEnums.StatType.keys()[eff.scaling_stat]
	return str(eff.amount)


static func _fmt_calc_num(value: float) -> String:
	if not is_equal_approx(value, snappedf(value, 0.1)):
		return "%.2f" % value
	return "%.1f" % value


static func _kw_hint(word: String, hint: String) -> String:
	return "[hint=\"%s\"][color=#FBBF24]%s[/color][/hint]" % [hint, word]


static func _format_stat_with_tooltip(unit: UnitState, stat_type: GameEnums.StatType) -> String:
	var base_val: int = 0
	var w_bonus: int = 0
	var final_val: int = 0
	var level_bonus: int = 0
	match stat_type:
		GameEnums.StatType.PHYSICAL:
			base_val = unit.definition.base_strength
			w_bonus = unit.definition.equipped_weapon.bonus_strength if unit.definition.equipped_weapon != null else 0
			if unit.definition.preferred_stat == GameEnums.StatType.PHYSICAL:
				level_bonus = (unit.level - 1) * 2
			final_val = unit.current_strength
		GameEnums.StatType.MAGICAL:
			base_val = unit.definition.base_magic
			w_bonus = unit.definition.equipped_weapon.bonus_magic if unit.definition.equipped_weapon != null else 0
			if unit.definition.preferred_stat == GameEnums.StatType.MAGICAL:
				level_bonus = (unit.level - 1) * 2
			final_val = unit.current_magic
		GameEnums.StatType.DEFENSE:
			base_val = unit.definition.base_defense
			w_bonus = unit.definition.equipped_weapon.bonus_defense if unit.definition.equipped_weapon != null else 0
			if unit.definition.preferred_stat == GameEnums.StatType.DEFENSE:
				level_bonus = (unit.level - 1) * 2
			final_val = unit.current_defense
			if unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
				final_val = int(ceil(float(final_val) * 0.5))
	var tooltip := "Base %d" % base_val
	if w_bonus != 0:
		tooltip += " + WPN %d" % w_bonus
	if level_bonus != 0:
		tooltip += " + Lv %d" % level_bonus
	tooltip += " = %d" % final_val
	return "[hint=\"%s\"]%d[/hint]" % [tooltip, final_val]


static func _equipment_info(unit: UnitState) -> String:
	var wpn: WeaponData = unit.definition.equipped_weapon if unit.definition != null else null
	if wpn == null:
		return "[font_size=%d]🗡️ [b]Equipment:[/b] None[/font_size]" % scaled_font_size(9)
	var stat_parts: Array[String] = ["WPN %d" % wpn.might]
	if wpn.bonus_strength != 0:
		stat_parts.append("STR %+d" % wpn.bonus_strength)
	if wpn.bonus_magic != 0:
		stat_parts.append("MAG %+d" % wpn.bonus_magic)
	if wpn.bonus_defense != 0:
		stat_parts.append("DEF %+d" % wpn.bonus_defense)
	var tooltip := "Might %d — added to ability base power in damage formula." % wpn.might
	return "[font_size=%d]🗡️ [b]Equipment:[/b] %s  |  [hint=\"%s\"]%s[/hint][/font_size]" % [
		scaled_font_size(9), wpn.display_name, tooltip, ", ".join(stat_parts),
	]


static func _parse_keywords(text: String) -> String:
	var manual: Dictionary = {
		"ATK": "Reduces target HP. Resisted by Armor.",
		"HEAL": "Restores target HP.",
		"PUSH": "Displaces target away from caster.",
		"DASH": "Moves in a straight line.",
		"TRAMPLE": "Pass through enemy tiles.",
		"COLLISION": "Collision damage from displacement.",
	}
	var out: String = text
	for key: String in manual.keys():
		if out.find(key) >= 0:
			out = out.replace(key, _kw_hint(key, String(manual[key])))
	return out


static func _status_hint(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.STURDY: return "Ignores the next displacement effect."
		GameEnums.StatusType.BURN: return "Takes 1 damage per turn."
		GameEnums.StatusType.BLEED: return "Takes 1 damage whenever moving."
		GameEnums.StatusType.STUN: return "Cannot act or move."
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Defense is halved."
		_: return ""
