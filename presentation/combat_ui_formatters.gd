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
		return "[color=#%s]Hover a tile for details.[/color]" % HEX_DIM
	var tile := board.get_tile(coord)
	if tile == null or tile.definition == null:
		return (
			"[font_size=9][color=#%s][b]Unknown[/b][/color]"
			+ "[right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]"
		) % [HEX_DIM, coord.x, coord.y]
	var desc: String = _terrain_desc(tile.definition)
	return (
		"[font_size=9][color=#%s][b]%s[/b][/color]"
		+ "[right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]\n[font_size=10]%s[/font_size]"
	) % [HEX_TILE, tile.definition.display_name, coord.x, coord.y, desc]


static func unit_info(board: BoardState, unit: UnitState) -> String:
	var lines: Array[String] = []
	lines.append(
		"[color=#4DB8FF][font_size=13][b]%s[/b][/font_size][/color]"
		+ "  [font_size=10][color=#aaaaaa](%s)[/color][/font_size]"
		% [unit.definition.display_name, "Player" if not unit.is_enemy() else "Enemy"],
	)
	var move_type: String = GameEnums.MovementType.keys()[unit.definition.movement_type].capitalize()
	lines.append(
		"[font_size=10]Lv.%d %s  |  Move: %s[/font_size]"
		% [unit.level, String(unit.definition.id).capitalize(), move_type],
	)
	lines.append(
		"[font_size=9][color=#4ADE80][b][hint=Hit Points]❤️ HP:[/hint] %d/%d[/b][/color]    Facing %s[/font_size]"
		% [unit.health.current_hp, unit.health.max_hp, facing_name(unit.facing)],
	)
	lines.append(
		"[font_size=9][color=#F1C40F][b][hint=Movement Points]👢 MP:[/hint] %d/%d[/b][/color]"
		+ "    [color=#E74C3C][b][hint=Action Points]⚔️ AP:[/hint] %d/%d[/b][/color][/font_size]"
		% [
			unit.movement.points_left, unit.movement.max_points,
			unit.ability.points_left, unit.ability.max_points,
		],
	)
	lines.append(
		"[font_size=10]💪 STR: %d  ✨ MAG: %d  🛡️ DEF: %d"
		% [unit.current_strength, unit.current_magic, unit.current_defense]
		+ ("  [hint=Armor]🪖 ARM:[/hint] %d" % unit.armor if unit.armor > 0 else "")
		+ "[/font_size]",
	)
	if unit.is_enemy():
		if unit.definition.behavior != null and unit.definition.behavior.attack != null:
			var att: AbilityData = unit.definition.behavior.attack
			lines.append("Attack: %s" % att.display_name)
	else:
		var names: Array[String] = []
		for ability: AbilityData in unit.active_abilities:
			names.append(ability.display_name)
		lines.append(
			"[font_size=8]Abilities: %s[/font_size]"
			% (", ".join(names) if not names.is_empty() else "None"),
		)
	if board != null and board.is_in_bounds(unit.position):
		var tile := board.get_tile(unit.position)
		if tile != null and tile.definition != null and tile.definition.fortitude != 0:
			var fort_val: int = tile.definition.fortitude
			var sign_str: String = "+" if fort_val > 0 else ""
			lines.append(
				"[font_size=10]🌿 Terrain: %s (%s%d Fortitude)[/font_size]"
				% [tile.definition.display_name, sign_str, fort_val],
			)
	if unit.active_statuses.size() > 0:
		var status_strs: Array[String] = []
		for status in unit.active_statuses:
			var s_name: String = _status_name(status.type)
			if status.duration > 1:
				s_name += " (%d)" % status.duration
			status_strs.append(s_name)
		lines.append("[color=#%s]Statuses: %s[/color]" % [HEX_INTENT, ", ".join(status_strs)])
	return "\n".join(lines)


static func summarize_intents(
	board: BoardState,
	phase: int,
	intent_units: Dictionary,
) -> String:
	if board == null:
		return "  (none)"
	var lines: Array[String] = []
	var show_all: bool = phase == CombatDirector.Phase.ENEMY_TURN
	for intent in board.intents:
		if show_all or intent_units.has(intent.enemy_id):
			lines.append("  - %s" % intent.summary)
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


static func _status_name(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Iron Grip"
		GameEnums.StatusType.TRAMPLE: return "Trample"
		GameEnums.StatusType.GHOST: return "Ghost"
		_: return GameEnums.StatusType.keys()[t].capitalize()


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
