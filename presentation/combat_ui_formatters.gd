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
const HEX_STAT_UP: String = "82E0AA"
const HEX_STAT_DOWN: String = "E74C3C"
const LOG_FONT_SIZE: int = 10
const LOG_FORMULA_FONT_SIZE: int = 7

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
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return PLAYER_COLORS[0]
	var network_manager: Node = (main_loop as SceneTree).root.get_node_or_null("NetworkManager")
	if network_manager == null or not bool(network_manager.get("is_multiplayer")):
		return PLAYER_COLORS[0]
	var usernames: Dictionary = network_manager.get("player_usernames") as Dictionary
	var keys: Array = usernames.keys()
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
		"move_already_planned":
			return "undo move before planning another"
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


static func unit_info(
	board: BoardState,
	unit: UnitState,
	move_uses_run: bool = false,
	ap_left_override: int = -1,
) -> String:
	var lines: Array[String] = []
	var team_label: String = "Player" if not unit.is_enemy() else "Enemy"
	lines.append(
		(
			"[color=#4DB8FF][font_size=%d][b]%s[/b][/font_size][/color]"
			+ "  [font_size=%d][color=#aaaaaa](%s)[/color][/font_size]"
		)
		% [scaled_font_size(13), unit.definition.display_name, scaled_font_size(10), team_label],
	)
	var move_type: String = GameEnums.MovementType.keys()[unit.definition.movement_type].capitalize()
	lines.append(
		"[font_size=%d]Lv.%d %s  |  Move: %s[/font_size]"
		% [scaled_font_size(10), unit.level, String(unit.definition.id).capitalize(), move_type],
	)
	lines.append(
		"[font_size=%d][color=#4ADE80][b][hint=Hit Points]%s HP:[/hint] %d/%d[/b][/color]    Facing %s[/font_size]"
		% [scaled_font_size(9), PlanningIcons.STAT_HP, unit.health.current_hp, unit.health.max_hp, facing_name(unit.facing)],
	)
	var mov_glyph: String = PlanningIcons.move_glyph(move_uses_run)
	var mov_hint: String = "Run — Movement Points" if move_uses_run else "Movement Points"
	lines.append(
		(
			"[font_size=%d][color=#F1C40F][b][hint=%s]%s MP:[/hint] %d/%d[/b][/color]"
			+ "    [color=#E74C3C][b][hint=Action Points]%s AP:[/hint] %d/%d[/b][/color][/font_size]"
		)
		% [
			scaled_font_size(9),
			mov_hint,
			mov_glyph,
			unit.movement.points_left, unit.movement.max_points,
			PlanningIcons.STAT_AP,
			unit.ability.points_left if ap_left_override < 0 else ap_left_override,
			unit.ability.max_points,
		],
	)
	lines.append(
		(
			"[font_size=%d]%s STR: %s  %s MAG: %s  %s DEF: %s"
			% [
				scaled_font_size(10),
				PlanningIcons.STAT_STR,
				format_stat_bbcode(unit, GameEnums.StatType.PHYSICAL, board),
				PlanningIcons.STAT_MAG,
				format_stat_bbcode(unit, GameEnums.StatType.MAGICAL, board),
				PlanningIcons.STAT_DEF,
				format_stat_bbcode(unit, GameEnums.StatType.DEFENSE, board),
			]
			+ ("  [hint=Armor]%s ARM:[/hint] %d" % [PlanningIcons.STAT_ARMOR, unit.armor] if unit.armor > 0 else "")
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
			names.append(
				"[hint=\"%s\"]%s[/hint]" % [ability_tooltip_text(ability, unit), ability.display_name],
			)
		var ability_list: String = ", ".join(names) if not names.is_empty() else "None"
		lines.append(
			"[font_size=%d]Abilities: %s[/font_size]"
			% [scaled_font_size(8), ability_list],
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
			var raw_name: String = _status_name(status.type)
			var s_name: String = raw_name
			var icon: String = PlanningIcons.keyword_icon(raw_name)
			if icon != "":
				s_name = "%s %s" % [icon, raw_name]
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
	show_all: bool,
	intent_units: Dictionary,
	intent_list: Array = [],
) -> String:
	if board == null:
		return "  (none)"
	var lines: Array[String] = []
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


## Locked NEW_AIM cells/names for a modular skill, e.g. (6,3)→(6,4)→Training Dummy.
static func ability_module_aim_chain(
	board: BoardState,
	plan: Timeline,
	action: TimelineAction,
	unit: UnitState = null,
) -> String:
	if action == null or action.ability == null:
		return ""
	var actor: UnitState = unit
	if board != null:
		var from_board: UnitState = board.get_unit_by_id(action.actor_id)
		if from_board != null:
			actor = from_board
	var new_aims: Array[int] = AbilitySystem.planning_new_aim_indices(actor, action.ability)
	if (
		new_aims.size() < 2
		and not (action.awaiting_target and action.awaiting_module_index > 0)
	):
		return ""
	var origin: Vector2i = plan_action_origin_cell(board, plan, action, actor)
	if origin.x < -900 and actor != null:
		origin = actor.position
	if origin.x < -900:
		return ""
	var parts: Array[String] = ["(%d,%d)" % [origin.x, origin.y]]
	var stop: int = AbilitySystem.active_modules_for(actor, action.ability).size()
	if action.awaiting_target:
		stop = maxi(0, action.awaiting_module_index)
	for index: int in new_aims:
		if index >= stop:
			break
		var uid: int = AbilitySystem.module_target_unit_id(action, index)
		var coord: Vector2i = AbilitySystem.module_target_coord(action, index)
		if uid >= 0 and board != null:
			var tgt: UnitState = board.get_unit_by_id(uid)
			if tgt != null and tgt.definition != null:
				parts.append(tgt.definition.display_name)
				continue
		parts.append("(%d,%d)" % [coord.x, coord.y])
	if parts.size() <= 1:
		return ""
	return "→".join(parts)


static func describe_action(
	board: BoardState,
	action: TimelineAction,
	plan: Timeline = null,
) -> String:
	if action == null:
		return "—"
	var actor: UnitState = board.get_unit_by_id(action.actor_id) if board != null else null
	var actor_name: String = actor.definition.display_name if actor != null else "unit %d" % action.actor_id
	match action.type:
		GameEnums.ActionType.FACE:
			return "%s face %s" % [actor_name, facing_name(action.face_dir)]
		GameEnums.ActionType.MOVE:
			var origin: Vector2i = plan_action_origin_cell(board, plan, action, actor)
			var dest: Vector2i = action.target_coord
			if origin.x > -900:
				if action.uses_run:
					return "%s run (%d,%d) → (%d,%d)" % [
						actor_name, origin.x, origin.y, dest.x, dest.y,
					]
				return "%s move (%d,%d) → (%d,%d)" % [
					actor_name, origin.x, origin.y, dest.x, dest.y,
				]
			if action.uses_run:
				return "%s run -> %s" % [actor_name, action.target_coord]
			return "%s move -> %s" % [actor_name, action.target_coord]
		GameEnums.ActionType.ABILITY:
			var ability_name: String = action.ability.display_name if action.ability != null else "ability"
			if action.awaiting_target:
				var chain: String = ability_module_aim_chain(board, plan, action, actor)
				if chain.is_empty():
					return "%s %s — awaiting dash endpoint" % [
						PlanningIcons.awaiting_phase_glyph(action.ability), ability_name,
					]
				return "%s %s %s — Awaiting Input" % [
					PlanningIcons.awaiting_phase_glyph(action.ability), ability_name, chain,
				]
			var chain_done: String = ability_module_aim_chain(board, plan, action, actor)
			if not chain_done.is_empty():
				return "%s %s %s" % [actor_name, ability_name, chain_done]
			var target_name: String = actor_name
			if board != null and action.target_unit_id >= 0:
				var tgt := board.get_unit_by_id(action.target_unit_id)
				if tgt != null:
					target_name = tgt.definition.display_name
			if (
				action.ability != null
				and (
					action.ability.is_movement_kind()
					or AbilitySystem.ability_has_movement_effect(action.ability)
				)
			):
				var move_origin: Vector2i = plan_action_origin_cell(board, plan, action, actor)
				var move_dest: Vector2i = action.target_coord
				if move_origin.x > -900:
					return "%s %s (%d,%d) → (%d,%d)" % [
						actor_name, ability_name,
						move_origin.x, move_origin.y, move_dest.x, move_dest.y,
					]
			return "%s %s -> %s" % [actor_name, ability_name, target_name]
	return "?"


static func class_symbol(unit: UnitState) -> String:
	match unit.definition.id:
		&"knight": return "♞"
		&"bruiser", &"fighter": return "✊"
		&"lancer": return "🧲"
		&"archer": return "🏹"
		&"mage": return "✨"
		&"cleric": return "➕"
		&"rogue": return "⚔️"
		&"mercenary": return "🪓"
		&"beast_rider": return "🦅"
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
	plan: Timeline = null,
) -> String:
	if action == null:
		return "-"
	if action.type == GameEnums.ActionType.MOVE:
		var dest: Vector2i = action.target_coord
		var origin: Vector2i = plan_action_origin_cell(board, plan, action, unit)
		if origin.x > -900:
			return "%s (%d,%d)→(%d,%d)" % [
				PlanningIcons.move_glyph(action.uses_run),
				origin.x, origin.y, dest.x, dest.y,
			]
		return "%s (%d,%d)" % [
			PlanningIcons.move_glyph(action.uses_run),
			dest.x,
			dest.y,
		]
	if action.type == GameEnums.ActionType.FACE:
		return "%s %s" % [PlanningIcons.GLYPH_FACE, facing_name(action.face_dir)]
	if action.type == GameEnums.ActionType.ABILITY:
		if action.ability != null and DataLibrary.is_universal_wait(action.ability.id):
			return ""
		if action.awaiting_target:
			var pending_name: String = action.ability.display_name if action.ability != null else "Skill"
			var chain: String = ability_module_aim_chain(board, plan, action, unit)
			if chain.is_empty():
				return "%s %s — Awaiting Input" % [
					PlanningIcons.awaiting_phase_glyph(action.ability), pending_name,
				]
			return "%s %s %s — Awaiting Input" % [
				PlanningIcons.awaiting_phase_glyph(action.ability), pending_name, chain,
			]
		var symbol: String = PlanningIcons.ability_glyph(action.ability)
		if action.ability != null and AbilitySystem.is_run_ability(action.ability):
			return "%s Run" % symbol
		var locked_chain: String = ability_module_aim_chain(board, plan, action, unit)
		if not locked_chain.is_empty():
			return "%s %s %s" % [symbol, action.ability.display_name, locked_chain]
		if action.ability != null and (
			action.ability.is_movement_kind()
			or AbilitySystem.ability_has_movement_effect(action.ability)
		):
			var move_origin: Vector2i = plan_action_origin_cell(board, plan, action, unit)
			var move_dest: Vector2i = action.target_coord
			if move_origin.x > -900:
				return "%s %s (%d,%d)→(%d,%d)" % [
					symbol, action.ability.display_name,
					move_origin.x, move_origin.y, move_dest.x, move_dest.y,
				]
			return "%s %s" % [symbol, action.ability.display_name]
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


## Grid cell where `action` begins — walk prior plan steps for the same actor.
static func plan_action_origin_cell(
	board: BoardState,
	plan: Timeline,
	action: TimelineAction,
	fallback_unit: UnitState = null,
) -> Vector2i:
	if action == null:
		return Vector2i(-999999, -999999)
	var unit: UnitState = board.get_unit_by_id(action.actor_id) if board != null else null
	if unit == null and fallback_unit != null and fallback_unit.id == action.actor_id:
		unit = fallback_unit
	if unit == null:
		return Vector2i(-999999, -999999)
	var origin: Vector2i = unit.position
	if plan == null:
		return origin
	var action_in_plan: bool = plan.entries.has(action)
	var action_col: int = action.timeline_column()
	for act: TimelineAction in plan.entries:
		if act == action:
			break
		if act.actor_id != action.actor_id:
			continue
		if not action_in_plan and act.timeline_column() >= action_col:
			continue
		origin = _plan_step_end_cell(origin, act)
	return origin


static func _plan_step_end_cell(origin: Vector2i, act: TimelineAction) -> Vector2i:
	match act.type:
		GameEnums.ActionType.MOVE:
			return act.target_coord
		GameEnums.ActionType.ABILITY:
			if act.awaiting_target:
				return origin
			if act.ability != null and (
				act.ability.is_movement_kind()
				or AbilitySystem.ability_has_movement_effect(act.ability)
			):
				return act.target_coord
	return origin


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
		var symbol: String = action_symbol_text(board, step, unit, plan)
		if symbol == "":
			continue
		parts.append("%d. %s" % [parts.size() + 1, symbol])
		var detail: String = describe_action(board, step)
		var reason: String = UnitPlanOrder.status_for_action(plan, statuses, step)
		if reason != "":
			failed = true
			tooltip_lines.append(
				"%d. %s — %s" % [i + 1, detail, reason_text(reason)],
			)
		else:
			tooltip_lines.append("%d. %s" % [parts.size(), detail])
	if parts.is_empty():
		return {
			"text": "—",
			"tooltip": "No actions queued",
			"failed": false,
		}
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
			if d.get("presentation_anim", GameEnums.PresentationAnim.WALK) != GameEnums.PresentationAnim.SUPER_RUN:
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
			if d.get("ability") == &"universal_wait":
				line = ""
				return {"line": line, "telemetry": telemetry}
			if d.get("presentation_anim", GameEnums.PresentationAnim.WALK) != GameEnums.PresentationAnim.SUPER_RUN:
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
			var armor_dmg: int = int(d.get("armor_damaged", 0))
			var after_hp: int = int(d.get("hp", 0))
			var before_hp: int = after_hp + hp_dmg
			var hp_note := " (%d HP -> %d HP)" % [before_hp, after_hp]
			if armor_dmg > 0:
				hp_note += ", %d armor" % armor_dmg
			var dmg_type: StringName = d.get("damage_type", &"physical")
			var source_tag: String = format_damage_source_tag(dmg_type, str(d.get("source_label", "")))
			line = _color(HEX_DMG, "%s takes %d damage%s%s" % [
				_unit_name(board, d.get("unit", -1)), incoming, source_tag, hp_note,
			])
			if incoming <= 0:
				line = _color(HEX_DMG, "%s takes 0 damage (fully mitigated)%s" % [
					_unit_name(board, d.get("unit", -1)), source_tag,
				])
			elif not telemetry.is_empty():
				var formula: String = format_damage_telemetry(telemetry, incoming, hp_dmg, armor_dmg)
				line += "\n[font_size=%d]   %s[/font_size]" % [scaled_font_size(LOG_FORMULA_FONT_SIZE), formula]
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
	var cost_label: String = ""
	if ability.is_movement_kind():
		cost_label = "MOV %d" % ability.movement_point_cost
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		cost_label = "AP %d (extends movement)" % ability.action_point_cost
	else:
		cost_label = "AP %d" % ability.action_point_cost
	var target_hint: String = _targeting_flags_hint(ability, unit)
	var range_label: String = _ability_targeting_range_label(ability, unit)
	var aoe_label: String = ClassLibrarySchema.bible_ability_aoe_label(ability)
	if aoe_label != "" and range_label == "RANGE 0":
		range_label = "%s | %s" % [range_label, aoe_label]
	return "%s (%s | %s%s | %s)" % [
		ability.display_name,
		range_label,
		cost_label,
		target_hint,
		ability_effect_string(ability, unit),
	]


static func ability_cost_chip(ability: AbilityData) -> Dictionary:
	if ability == null:
		return {"emoji": PlanningIcons.STAT_AP, "text": "0", "tooltip": _glossary_def("AP")}
	if ability.is_movement_kind():
		return {
			"emoji": PlanningIcons.STAT_MOV,
			"text": str(ability.movement_point_cost),
			"tooltip": "MOV %d — %s" % [ability.movement_point_cost, _glossary_def("MOV")],
		}
	return {
		"emoji": PlanningIcons.STAT_AP,
		"text": str(ability.action_point_cost),
		"tooltip": "AP %d — %s" % [ability.action_point_cost, _glossary_def("AP")],
	}


static func ability_range_chip(ability: AbilityData, unit: UnitState = null) -> Dictionary:
	var label: String = _ability_targeting_range_label(ability, unit)
	var tooltip: String = ""
	if label.begins_with("DASH"):
		tooltip = _glossary_def("DASH")
	elif label.begins_with("MOVE"):
		tooltip = _glossary_def("MOVE")
	elif label == "SELF":
		tooltip = String(ClassLibrarySchema.manual_keywords().get("RANGE 0", "Self only."))
	elif label.begins_with("RANGE"):
		tooltip = _glossary_def("RANGE")
	else:
		tooltip = label
	var display_val: String = label
	if label.begins_with("DASH "):
		display_val = label.substr(5)
	elif label.begins_with("MOVE "):
		display_val = label.substr(5)
	elif label.begins_with("RANGE "):
		display_val = label.substr(6)
	var emoji: String = PlanningIcons.range_chip_glyph(label)
	return {"emoji": emoji, "text": display_val, "tooltip": "%s — %s" % [label, tooltip]}


## In-game skill list: header cost + one bbcode line per authored module (layers on same line).
static func ability_skill_list_layout(ability: AbilityData, unit: UnitState = null) -> Dictionary:
	if ability == null:
		return {
			"title": "",
			"cost": ability_cost_chip(null),
			"module_lines": PackedStringArray(),
			"planner_group": GameEnums.PlannerGroup.ACTION,
		}
	return {
		"title": ability.display_name,
		"cost": ability_cost_chip(ability),
		"module_lines": ability_skill_module_lines_bbcode(ability, unit),
		"planner_group": ability.planner_group,
	}


static func ability_skill_module_lines_bbcode(
	ability: AbilityData,
	unit: UnitState = null,
) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if ability == null:
		return lines
	var modules: Array[AbilityModule] = AbilitySystem.active_modules_for(unit, ability)
	if modules.is_empty():
		var fallback: String = ability_effect_bbcode(ability, unit)
		if fallback != "":
			lines.append(fallback)
		return lines
	for module: AbilityModule in modules:
		var line: String = _ability_module_line_bbcode(module)
		if line != "":
			lines.append(line)
	return lines


static func ability_skill_row_background(ability: AbilityData, selected: bool) -> Color:
	var is_premove: bool = ability != null and ability.is_pre_move_planner()
	var base: Color = (
		Color(0.05, 0.22, 0.42, 1.0)
		if is_premove
		else Color(0.16, 0.16, 0.19, 1.0)
	)
	if selected:
		if is_premove:
			return base.lerp(Color(0.18, 0.52, 0.88, 1.0), 0.62)
		return base.lerp(Color(0.98, 0.86, 0.32, 0.95), 0.28)
	return base


static func ability_skill_row_select_font_color(ability: AbilityData) -> Color:
	if ability != null and ability.is_pre_move_planner():
		return Color(0.70, 0.92, 1.0, 1.0)
	return Color(0.98, 0.86, 0.32, 0.95)


static func _ability_module_line_bbcode(module: AbilityModule) -> String:
	if module == null:
		return ""
	var parts: Array[String] = []
	var range_aoe: String = _module_range_and_aoe_prefix_bbcode(module)
	if range_aoe != "":
		parts.append(range_aoe)
	var primary: String = _module_primary_bbcode(module)
	if primary != "":
		parts.append(primary)
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null or not keyword.emit_as_effect:
			continue
		var kw_label: String = _keyword_emit_label(keyword)
		if kw_label != "":
			parts.append(_kw_hint(kw_label, kw_label + "."))
	for layer: AbilityLayer in module.layers:
		if layer == null or layer.effect == null:
			continue
		var layer_part: String = _module_effect_bbcode_part(layer.effect)
		if layer_part != "":
			parts.append(layer_part)
	var filter_plain: String = ClassLibrarySchema.module_target_filter_line(module)
	if filter_plain != "":
		parts.append(_kw_hint(filter_plain, "Legal click condition for this skill."))
	return " | ".join(parts)


static func _module_range_and_aoe_prefix_bbcode(module: AbilityModule) -> String:
	if module == null:
		return ""
	var chunks: PackedStringArray = PackedStringArray()
	if _module_line_includes_range_prefix(module):
		var range_part: String = _module_range_prefix_bbcode(module)
		if range_part != "":
			chunks.append(range_part)
	if module.target_shape != GameEnums.TargetShape.SINGLE:
		var shape_name: String = GameEnums.TargetShape.keys()[module.target_shape].capitalize().replace(
			"Aoe ", "",
		)
		chunks.append(_kw_hint(
			"AOE %s %d" % [shape_name, module.target_shape_size],
			_glossary_def("AOE"),
		))
	if chunks.is_empty():
		return ""
	return " ".join(chunks)


static func _module_line_includes_range_prefix(module: AbilityModule) -> bool:
	if module == null:
		return false
	if (module.targeting_flags & GameEnums.TargetingFlags.SELF) != 0 and module.max_range <= 0:
		return false
	if module.primary_type == GameEnums.EffectType.MOVE:
		return false
	if module.primary_type == GameEnums.EffectType.DASH:
		return false
	return module.max_range > 0 or module.min_range > 0


static func _module_range_prefix_bbcode(module: AbilityModule) -> String:
	var range_val: String = ""
	if module.min_range > 0 and module.min_range != module.max_range:
		range_val = "%d-%d" % [module.min_range, module.max_range]
	elif module.max_range > 0:
		range_val = str(module.max_range)
	elif module.min_range > 0:
		range_val = str(module.min_range)
	if range_val == "":
		return ""
	var label: String = "RANGE %s" % range_val
	var glyph: String = PlanningIcons.GLYPH_RANGE
	return "[hint=\"%s — %s\"][color=#FBBF24]%s %s[/color][/hint]" % [
		label,
		_glossary_def("RANGE"),
		glyph,
		range_val,
	]


static func _module_primary_bbcode(module: AbilityModule) -> String:
	var effect: EffectData = module.primary_as_effect()
	return _module_effect_bbcode_part(effect)


static func _module_effect_bbcode_part(effect: EffectData) -> String:
	if effect == null:
		return ""
	match effect.type:
		GameEnums.EffectType.DAMAGE:
			var atk_label: String = _damage_atk_label(effect)
			return "[hint=\"%s\"][color=#FBBF24]%s %s[/color][/hint]" % [
				_damage_atk_hint(effect),
				PlanningIcons.GLYPH_ATTACK,
				atk_label,
			]
		GameEnums.EffectType.HEAL:
			return _kw_hint("HEAL %s" % _effect_amount_string(effect), _glossary_def("HEAL"))
		GameEnums.EffectType.PUSH:
			return _kw_hint("PUSH %s" % _effect_amount_string(effect), _glossary_def("PUSH"))
		GameEnums.EffectType.PULL:
			return _kw_hint("PULL %s" % _effect_amount_string(effect), _glossary_def("PULL"))
		GameEnums.EffectType.SWAP:
			return _kw_hint("SWAP", _glossary_def("SWAP"))
		GameEnums.EffectType.MOVE:
			return _kw_hint("MOVE %s" % _effect_amount_string(effect), _glossary_def("MOVE"))
		GameEnums.EffectType.DASH:
			return _kw_hint("DASH %s" % _effect_amount_string(effect), _glossary_def("DASH"))
		GameEnums.EffectType.TRAMPLE:
			return _kw_hint("TRAMPLE %s" % _effect_amount_string(effect), _glossary_def("TRAMPLE"))
		GameEnums.EffectType.BULLDOZE:
			return _kw_hint("BULLDOZE %s" % _effect_amount_string(effect), _glossary_def("BULLDOZE"))
		GameEnums.EffectType.ARMOR_UP:
			return _kw_hint("SHIELD %s" % _effect_amount_string(effect), _glossary_def("SHIELD"))
		GameEnums.EffectType.EXPLODE:
			return _kw_hint("EXPLODE %s" % _effect_amount_string(effect), _glossary_def("EXPLODE"))
		GameEnums.EffectType.RANGED_EXPLODE:
			return _kw_hint(
				_damage_atk_label(effect, "AOE ATK"),
				_glossary_def("AOE ATK"),
			)
		GameEnums.EffectType.SPAWN:
			return _kw_hint(
				"SPAWN %s" % str(effect.spawn_unit_id).capitalize(),
				_glossary_def("SPAWN"),
			)
		GameEnums.EffectType.ADD_STATUS:
			var status_parts: Array[String] = []
			_append_status_effect_part(status_parts, effect, false, true)
			return status_parts[0] if not status_parts.is_empty() else ""
		GameEnums.EffectType.ADD_STATUS_SELF:
			var self_parts: Array[String] = []
			_append_status_effect_part(self_parts, effect, true, true)
			return self_parts[0] if not self_parts.is_empty() else ""
		GameEnums.EffectType.PURGE:
			return _kw_hint("PURGE", _glossary_def("PURGE"))
		GameEnums.EffectType.CLEANSE:
			return _kw_hint("CLEANSE", _glossary_def("CLEANSE"))
		GameEnums.EffectType.TELEPORT_CASTER:
			return _kw_hint("TELEPORT", _glossary_def("TELEPORT"))
		GameEnums.EffectType.MOVE_INTO_AND_PUSH:
			return _kw_hint("PUSH THROUGH", _glossary_def("PUSH THROUGH"))
		GameEnums.EffectType.DESTROY_OBSTACLE:
			return _kw_hint("DESTROY OBSTACLE", _glossary_def("DESTROY OBSTACLE"))
		GameEnums.EffectType.DAMAGE_SELF:
			return _kw_hint(
				_damage_atk_label(effect, "Self ATK"),
				"Ignores Armor and deals direct damage to the caster.",
			)
		GameEnums.EffectType.CREATE_HAZARD:
			return _kw_hint(_hazard_create_label(effect), _glossary_def("CREATE HAZARD"))
		GameEnums.EffectType.THROW_BEHIND:
			return _kw_hint("THROW BEHIND", _glossary_def("THROW BEHIND"))
		GameEnums.EffectType.CHANGE_TERRAIN:
			return _kw_hint(
				_terrain_change_label(effect),
				"Change the terrain of affected tiles.",
			)
		GameEnums.EffectType.REFUND_AP_ON_CC, \
		GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, \
		GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, \
		GameEnums.EffectType.PUSH_CHAIN_COLLISION, \
		GameEnums.EffectType.REMOVE_STATUS:
			var mod_label: String = _modifier_effect_label(effect.type)
			if mod_label.is_empty():
				return ""
			return _kw_hint(mod_label, mod_label + ".")
		_:
			return _kw_hint(
				GameEnums.EffectType.keys()[effect.type].capitalize(),
				GameEnums.EffectType.keys()[effect.type].capitalize(),
			)


static func _keyword_emit_label(keyword: AbilityKeyword) -> String:
	if keyword == null:
		return ""
	match keyword.keyword_id:
		GameEnums.AbilityKeywordId.TRAMPLE:
			return "TRAMPLE"
		GameEnums.AbilityKeywordId.BULLDOZE:
			return "BULLDOZE"
		GameEnums.AbilityKeywordId.GHOST:
			return "GHOST"
		_:
			return ""


static func _ability_targeting_range_label(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return "RANGE 0"
	var bible_label: String = ClassLibrarySchema.bible_ability_targeting_label(ability)
	if bible_label != "":
		return bible_label
	var rng: int = AbilitySystem.active_range_tiles(unit, ability)
	return "RANGE %d" % rng


static func _dash_effect_amount(ability: AbilityData) -> int:
	return AbilitySystem.effect_amount(ability, GameEnums.EffectType.DASH)


static func _targeting_flags_hint(ability: AbilityData, unit: UnitState = null) -> String:
	var flags: int = AbilitySystem.active_targeting_flags(unit, ability)
	var labels: PackedStringArray = []
	if (flags & GameEnums.TargetingFlags.SELF) != 0:
		labels.append("Self")
	if (flags & GameEnums.TargetingFlags.ALLY) != 0:
		labels.append("Ally")
	if (flags & GameEnums.TargetingFlags.ENEMY) != 0:
		labels.append("Enemy")
	if (flags & GameEnums.TargetingFlags.TILE) != 0:
		labels.append("Tile")
	if (flags & GameEnums.TargetingFlags.DASH_LINE) != 0:
		labels.append("Dash line")
	return "" if labels.is_empty() else " | %s" % ", ".join(labels)


static func ability_tooltip_text(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	var lines: PackedStringArray = []
	lines.append(ability.display_name)
	lines.append("")
	var range_label: String = _ability_targeting_range_label(ability, unit)
	var aoe_label: String = ClassLibrarySchema.bible_ability_aoe_label(ability)
	if aoe_label != "" and range_label == "RANGE 0":
		lines.append("%s | %s" % [range_label, aoe_label])
	else:
		lines.append("%s — %s" % [range_label, _targeting_glossary_hint(range_label)])
	if ability.is_movement_kind():
		lines.append(
			"MOV %d — %s" % [ability.movement_point_cost, _glossary_def("MOV")],
		)
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		lines.append(
			"AP %d — Uses your action slot and extends how far you can move this turn."
			% ability.action_point_cost,
		)
	else:
		lines.append("AP %d — %s" % [ability.action_point_cost, _glossary_def("AP")])
	var dump: String = _targeting_flags_hint(ability, unit).trim_prefix(" | ")
	if dump != "none":
		lines.append("Target — %s." % dump)
	var keyword_lines: PackedStringArray = _ability_keyword_tooltip_lines(ability, unit)
	if not keyword_lines.is_empty():
		lines.append("")
		for kw_line: String in keyword_lines:
			lines.append(kw_line)
	if (
		unit != null
		and unit.is_ability_upgraded(ability.id)
		and not ability.upgrade_description.is_empty()
	):
		lines.append("")
		lines.append("Upgrade — %s" % ability.upgrade_description)
	return "\n".join(lines)


static func _glossary_def(key: String) -> String:
	return String(ClassLibrarySchema.manual_keywords().get(key, ""))


static func _kw_tooltip_line(label: String, definition: String) -> String:
	var first_word = label.split(" ")[0]
	if label.begins_with("AOE ATK"):
		first_word = "AOE ATK"
	var icon = PlanningIcons.keyword_icon(first_word)
	var final_label = label
	if icon != "":
		final_label = "%s %s" % [icon, label]
		
	if definition.is_empty():
		return final_label
	return "%s — %s" % [final_label, definition]


static func _targeting_glossary_hint(range_label: String) -> String:
	if range_label.begins_with("DASH"):
		return _glossary_def("DASH")
	if range_label.begins_with("MOVE"):
		return _glossary_def("MOVE")
	if range_label == "SELF" or range_label == "RANGE 0":
		return String(ClassLibrarySchema.manual_keywords().get("RANGE 0", "Self only."))
	if range_label.begins_with("RANGE"):
		return _glossary_def("RANGE")
	return range_label


static func _ability_keyword_tooltip_lines(
	ability: AbilityData,
	unit: UnitState = null,
) -> PackedStringArray:
	var lines: PackedStringArray = []
	var bible_line: String = ClassLibrarySchema.bible_ability_effect_line(ability)
	if bible_line != "":
		for segment: String in bible_line.split("|", false):
			var kw: String = segment.strip_edges()
			if kw.is_empty():
				continue
			lines.append(_kw_tooltip_line(kw, _bible_segment_hint(kw)))
		return _with_target_filter_tooltip(lines, ability, unit)
	for effect: EffectData in AbilitySystem.active_effects_for(unit, ability):
		var line: String = _effect_tooltip_line(effect)
		if not line.is_empty():
			lines.append(line)
	var target_shape: GameEnums.TargetShape = AbilitySystem.active_target_shape(unit, ability)
	if target_shape != GameEnums.TargetShape.SINGLE:
		var shape_name: String = GameEnums.TargetShape.keys()[target_shape].capitalize().replace(
			"Aoe ", "",
		)
		lines.append(_kw_tooltip_line(
			"AOE %s %d" % [shape_name, AbilitySystem.active_target_shape_size(unit, ability)],
			_glossary_def("AOE"),
		))
	return _with_target_filter_tooltip(lines, ability, unit)


static func _with_target_filter_tooltip(
	lines: PackedStringArray,
	ability: AbilityData,
	unit: UnitState,
) -> PackedStringArray:
	var filter_line: String = ClassLibrarySchema.ability_target_filter_line(ability, unit)
	if filter_line != "":
		lines.append(_kw_tooltip_line(filter_line, "Legal click condition for this skill."))
	return lines


static func _effect_tooltip_line(effect: EffectData) -> String:
	if effect == null:
		return ""
	var amount: String = _effect_amount_string(effect)
	match effect.type:
		GameEnums.EffectType.DAMAGE:
			return _kw_tooltip_line(_damage_atk_label(effect), _damage_atk_hint(effect))
		GameEnums.EffectType.HEAL:
			return _kw_tooltip_line("HEAL %s" % amount, _glossary_def("HEAL"))
		GameEnums.EffectType.PUSH:
			return _kw_tooltip_line("PUSH %s" % amount, _glossary_def("PUSH"))
		GameEnums.EffectType.PULL:
			return _kw_tooltip_line("PULL %s" % amount, _glossary_def("PULL"))
		GameEnums.EffectType.SWAP:
			return _kw_tooltip_line("SWAP", _glossary_def("SWAP"))
		GameEnums.EffectType.ARMOR_UP:
			return _kw_tooltip_line("SHIELD %s" % amount, _glossary_def("SHIELD"))
		GameEnums.EffectType.EXPLODE:
			return _kw_tooltip_line("EXPLODE %s" % amount, _glossary_def("EXPLODE"))
		GameEnums.EffectType.RANGED_EXPLODE:
			return _kw_tooltip_line(
				_damage_atk_label(effect, "AOE ATK"),
				_glossary_def("AOE ATK"),
			)
		GameEnums.EffectType.SPAWN:
			return _kw_tooltip_line(
				"SPAWN %s" % str(effect.spawn_unit_id).capitalize(),
				_glossary_def("SPAWN"),
			)
		GameEnums.EffectType.DASH:
			return _kw_tooltip_line("DASH %s" % amount, _glossary_def("DASH"))
		GameEnums.EffectType.TRAMPLE:
			return _kw_tooltip_line("TRAMPLE %s" % amount, _glossary_def("TRAMPLE"))
		GameEnums.EffectType.BULLDOZE:
			return _kw_tooltip_line("BULLDOZE %s" % amount, _glossary_def("BULLDOZE"))
		GameEnums.EffectType.TELEPORT_CASTER:
			return _kw_tooltip_line("TELEPORT", _glossary_def("TELEPORT"))
		GameEnums.EffectType.MOVE_INTO_AND_PUSH:
			return _kw_tooltip_line("PUSH THROUGH", _glossary_def("PUSH THROUGH"))
		GameEnums.EffectType.DESTROY_OBSTACLE:
			return _kw_tooltip_line("DESTROY OBSTACLE", _glossary_def("DESTROY OBSTACLE"))
		GameEnums.EffectType.CLEANSE:
			return _kw_tooltip_line("CLEANSE", _glossary_def("CLEANSE"))
		GameEnums.EffectType.PURGE:
			return _kw_tooltip_line("PURGE", _glossary_def("PURGE"))
		GameEnums.EffectType.DAMAGE_SELF:
			return _kw_tooltip_line(
				_damage_atk_label(effect, "Self ATK"),
				"Ignores Armor and deals direct damage to the caster.",
			)
		GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF:
			var self_target: bool = effect.type == GameEnums.EffectType.ADD_STATUS_SELF
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
			return _kw_tooltip_line("%s%s%s" % [prefix, label, dur], hint)
		GameEnums.EffectType.MOVE:
			return _kw_tooltip_line("MOVE %s" % amount, _glossary_def("MOVE"))
		GameEnums.EffectType.CREATE_HAZARD:
			return _kw_tooltip_line(_hazard_create_label(effect), _glossary_def("CREATE HAZARD"))
		GameEnums.EffectType.THROW_BEHIND:
			return _kw_tooltip_line("THROW BEHIND", _glossary_def("THROW BEHIND"))
		GameEnums.EffectType.CHANGE_TERRAIN:
			return _kw_tooltip_line(_terrain_change_label(effect), "Change the terrain of affected tiles.")
		GameEnums.EffectType.REFUND_AP_ON_CC, \
		GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, \
		GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, \
		GameEnums.EffectType.PUSH_CHAIN_COLLISION, \
		GameEnums.EffectType.REMOVE_STATUS:
			var mod_label: String = _modifier_effect_label(effect.type)
			if mod_label.is_empty():
				return ""
			return _kw_tooltip_line(mod_label, mod_label + ".")
		_:
			return ""


static func _status_name(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "Iron Grip"
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "Retaliation Protocol"
		GameEnums.StatusType.RETALIATION_INFINITE_RANGE:
			return "Retaliation (Infinite Range)"
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
	return ClassLibrarySchema.status_player_tooltip(t)


static func _bible_segment_hint(segment: String) -> String:
	var manual: Dictionary = ClassLibrarySchema.manual_keywords()
	if manual.has(segment):
		return String(manual[segment])
	if segment.begins_with("ATK "):
		return _glossary_def("ATK")
	if segment.begins_with("PUSH "):
		return _glossary_def("PUSH")
	if segment.begins_with("PULL "):
		return _glossary_def("PULL")
	if segment.begins_with("DASH "):
		return _glossary_def("DASH")
	if segment.begins_with("TRAMPLE "):
		return _glossary_def("TRAMPLE")
	if segment.begins_with("BULLDOZE "):
		return _glossary_def("BULLDOZE")
	if segment == "PUSH THROUGH":
		return _glossary_def("PUSH THROUGH")
	if segment.begins_with("CREATE "):
		return _glossary_def("CREATE HAZARD")
	if segment == "THROW BEHIND":
		return _glossary_def("THROW BEHIND")
	if segment == "MOVE into occupied ally":
		return "Move into an adjacent tile occupied by an ally, then enter that tile."
	if segment.begins_with("DEF +"):
		return ClassLibrarySchema.status_player_tooltip(GameEnums.StatusType.STAT_BUFF_DEF)
	if segment.begins_with("Apply "):
		var status_name: String = segment.substr(6).strip_edges()
		return "Apply %s." % status_name
	if segment == "STURDY":
		return ClassLibrarySchema.status_player_tooltip(GameEnums.StatusType.STURDY)
	if segment.contains("INTERCEPT"):
		return ClassLibrarySchema.status_player_tooltip(GameEnums.StatusType.INTERCEPT)
	return segment


static func _status_bible_label(effect: EffectData, self_target: bool) -> String:
	if effect == null:
		return ""
	var amount_str: String = _effect_amount_string(effect)
	match effect.status_type:
		GameEnums.StatusType.STAT_BUFF_STR:
			return "STR +%s" % amount_str if amount_str not in ["0", ""] else "STR UP"
		GameEnums.StatusType.STAT_BUFF_MAG:
			return "MAG +%s" % amount_str if amount_str not in ["0", ""] else "MAG UP"
		GameEnums.StatusType.STAT_BUFF_DEF:
			if effect.scaling_stat == GameEnums.StatType.DEFENSE:
				return "DEF +X (X = caster DEF)"
			return "DEF +%s" % amount_str if amount_str not in ["0", ""] else "DEF UP"
		GameEnums.StatusType.STAT_BUFF_MOV, GameEnums.StatusType.STAT_BUFF_MP:
			return "MOVEMENT +%s" % amount_str if amount_str not in ["0", ""] else "MOV UP"
		GameEnums.StatusType.STAT_BUFF_ACC:
			return "ACC +%s" % amount_str if amount_str not in ["0", ""] else "ACC UP"
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return "DEF −%s" % amount_str if amount_str not in ["0", ""] else "DEF DOWN"
		GameEnums.StatusType.STAT_DEBUFF_MOV:
			return "MAX MOVEMENT −%s" % amount_str if amount_str not in ["0", ""] else "MOV DOWN"
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return "ACC −%s" % amount_str if amount_str not in ["0", ""] else "ACC DOWN"
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return "DEF halved next turn"
		GameEnums.StatusType.INTERCEPT:
			return "INTERCEPT 50%"
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return "Counter ATK 2 on melee hit"
		GameEnums.StatusType.THORNS:
			return "THORNS %s%%" % amount_str if amount_str not in ["0", ""] else "THORNS"
		_:
			var prefix: String = "Self " if self_target else "Apply "
			return "%s%s" % [prefix, _status_name(effect.status_type)]


static func _append_status_effect_part(
	parts: Array[String],
	effect: EffectData,
	self_target: bool,
	bbcode: bool,
) -> void:
	if effect == null:
		return
	var dur: String = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
	var label: String = _status_bible_label(effect, self_target)
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
	var prefix: String = ""
	if not (
		label.begins_with("Apply ")
		or label.begins_with("Self ")
		or label.contains("+")
		or label.contains("−")
		or label.contains("halved")
		or label.contains("INTERCEPT")
		or label.contains("Counter ")
		or label.contains("THORNS")
	):
		prefix = "Self " if self_target else "Apply "
	if bbcode:
		parts.append("%s%s%s" % [prefix, _kw_hint(label, hint), dur])
	else:
		parts.append("%s%s%s" % [prefix, label, dur])


static func _movement_destination_label(effect: EffectData) -> String:
	if effect == null:
		return "MOVE"
	var verb: String = "MOVE"
	match effect.type:
		GameEnums.EffectType.JUMP, \
		GameEnums.EffectType.JUMP_ADJACENT_TO, \
		GameEnums.EffectType.JUMP_TO_BEHIND, \
		GameEnums.EffectType.JUMP_TOWARD:
			verb = "JUMP"
		GameEnums.EffectType.TELEPORT_CASTER, \
		GameEnums.EffectType.TELEPORT_ADJACENT_TO, \
		GameEnums.EffectType.TELEPORT_TO_BEHIND, \
		GameEnums.EffectType.TELEPORT_TOWARD:
			verb = "TELEPORT"
		_:
			verb = "MOVE"
	var destination: String = ""
	match effect.type:
		GameEnums.EffectType.MOVE_ADJACENT_TO, \
		GameEnums.EffectType.JUMP_ADJACENT_TO, \
		GameEnums.EffectType.TELEPORT_ADJACENT_TO:
			destination = " ADJACENT"
		GameEnums.EffectType.MOVE_TO_BEHIND, \
		GameEnums.EffectType.JUMP_TO_BEHIND, \
		GameEnums.EffectType.TELEPORT_TO_BEHIND:
			destination = " BEHIND"
		GameEnums.EffectType.MOVE_TOWARD, \
		GameEnums.EffectType.JUMP_TOWARD, \
		GameEnums.EffectType.TELEPORT_TOWARD:
			destination = " TOWARD"
		_:
			pass
	return "%s%s %s" % [verb, destination, _effect_amount_string(effect)]


static func ability_effect_string(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	var bible_line: String = ClassLibrarySchema.bible_ability_effect_line(ability)
	if bible_line != "":
		var header: Array[String] = []
		var aoe_label: String = ClassLibrarySchema.bible_ability_aoe_label(ability)
		if aoe_label != "":
			header.append(aoe_label)
		header.append(bible_line)
		var filter_line: String = ClassLibrarySchema.ability_target_filter_line(ability, unit)
		if filter_line != "":
			header.append(filter_line)
		return " | ".join(header)
	var parts: Array[String] = []
	for effect: EffectData in AbilitySystem.active_effects_for(unit, ability):
		match effect.type:
			GameEnums.EffectType.DAMAGE:
				parts.append(_damage_atk_label(effect))
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
				parts.append(_damage_atk_label(effect, "AOE ATK"))
			GameEnums.EffectType.SPAWN:
				parts.append("SPAWN %s" % str(effect.spawn_unit_id).capitalize())
			GameEnums.EffectType.ADD_STATUS:
				_append_status_effect_part(parts, effect, false, false)
			GameEnums.EffectType.ADD_STATUS_SELF:
				_append_status_effect_part(parts, effect, true, false)
			GameEnums.EffectType.MOVE:
				parts.append("MOVE %s" % _effect_amount_string(effect))
			GameEnums.EffectType.JUMP, \
			GameEnums.EffectType.MOVE_ADJACENT_TO, \
			GameEnums.EffectType.JUMP_ADJACENT_TO, \
			GameEnums.EffectType.TELEPORT_ADJACENT_TO, \
			GameEnums.EffectType.MOVE_TO_BEHIND, \
			GameEnums.EffectType.JUMP_TO_BEHIND, \
			GameEnums.EffectType.TELEPORT_TO_BEHIND, \
			GameEnums.EffectType.MOVE_TOWARD, \
			GameEnums.EffectType.JUMP_TOWARD, \
			GameEnums.EffectType.TELEPORT_TOWARD:
				parts.append(_movement_destination_label(effect))
			GameEnums.EffectType.DASH:
				parts.append("DASH %s" % _effect_amount_string(effect))
			GameEnums.EffectType.TRAMPLE:
				parts.append("TRAMPLE %s" % _effect_amount_string(effect))
			GameEnums.EffectType.BULLDOZE:
				parts.append("BULLDOZE %s" % _effect_amount_string(effect))
			GameEnums.EffectType.PURGE:
				parts.append("PURGE")
			GameEnums.EffectType.CLEANSE:
				parts.append("CLEANSE")
			GameEnums.EffectType.MOVE_INTO_AND_PUSH:
				parts.append("PUSH THROUGH")
			GameEnums.EffectType.TELEPORT_CASTER:
				parts.append("TELEPORT")
			GameEnums.EffectType.DESTROY_OBSTACLE:
				parts.append("DESTROY OBSTACLE")
			GameEnums.EffectType.DAMAGE_SELF:
				parts.append(_damage_atk_label(effect, "Self ATK"))
			GameEnums.EffectType.CREATE_HAZARD:
				parts.append(_hazard_create_label(effect))
			GameEnums.EffectType.THROW_BEHIND:
				parts.append("THROW BEHIND")
			GameEnums.EffectType.CHANGE_TERRAIN:
				parts.append(_terrain_change_label(effect))
			GameEnums.EffectType.REFUND_AP_ON_CC, \
			GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, \
			GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, \
			GameEnums.EffectType.PUSH_CHAIN_COLLISION, \
			GameEnums.EffectType.REMOVE_STATUS:
				var mod_label: String = _modifier_effect_label(effect.type)
				if not mod_label.is_empty():
					parts.append(mod_label)
			_:
				parts.append(GameEnums.EffectType.keys()[effect.type].capitalize())
	var filter_line: String = ClassLibrarySchema.ability_target_filter_line(ability, unit)
	if filter_line != "":
		parts.append(filter_line)
	return " | ".join(parts) if not parts.is_empty() else "No effect"


static func ability_effect_bbcode(ability: AbilityData, unit: UnitState = null) -> String:
	if ability == null:
		return ""
	var plain: String = ability_effect_string(ability, unit)
	if ClassLibrarySchema.bible_ability_effect_line(ability) != "":
		return _bbcode_from_bible_effect_line(plain)
	var parts: Array[String] = []
	for effect: EffectData in AbilitySystem.active_effects_for(unit, ability):
		match effect.type:
			GameEnums.EffectType.DAMAGE:
				parts.append(_kw_hint(_damage_atk_label(effect), _damage_atk_hint(effect)))
			GameEnums.EffectType.HEAL:
				parts.append(_kw_hint("HEAL %s" % _effect_amount_string(effect), _glossary_def("HEAL")))
			GameEnums.EffectType.PUSH:
				parts.append(_kw_hint("PUSH %s" % _effect_amount_string(effect), _glossary_def("PUSH")))
			GameEnums.EffectType.PULL:
				parts.append(_kw_hint("PULL %s" % _effect_amount_string(effect), _glossary_def("PULL")))
			GameEnums.EffectType.SWAP:
				parts.append(_kw_hint("SWAP", _glossary_def("SWAP")))
			GameEnums.EffectType.MOVE:
				parts.append(_kw_hint("MOVE %s" % _effect_amount_string(effect), "Move up to the listed distance."))
			GameEnums.EffectType.JUMP, \
			GameEnums.EffectType.MOVE_ADJACENT_TO, \
			GameEnums.EffectType.JUMP_ADJACENT_TO, \
			GameEnums.EffectType.TELEPORT_ADJACENT_TO, \
			GameEnums.EffectType.MOVE_TO_BEHIND, \
			GameEnums.EffectType.JUMP_TO_BEHIND, \
			GameEnums.EffectType.TELEPORT_TO_BEHIND, \
			GameEnums.EffectType.MOVE_TOWARD, \
			GameEnums.EffectType.JUMP_TOWARD, \
			GameEnums.EffectType.TELEPORT_TOWARD:
				parts.append(_kw_hint(
					_movement_destination_label(effect),
					"Resolve the destination using the selected movement mode.",
				))
			GameEnums.EffectType.DASH:
				parts.append(_kw_hint(
					"DASH %s" % _effect_amount_string(effect),
					"Move up to the listed distance in a straight line.",
				))
			GameEnums.EffectType.TRAMPLE:
				parts.append(_kw_hint(
					"TRAMPLE %s" % _effect_amount_string(effect),
					_glossary_def("TRAMPLE"),
				))
			GameEnums.EffectType.BULLDOZE:
				parts.append(_kw_hint(
					"BULLDOZE %s" % _effect_amount_string(effect),
					_glossary_def("BULLDOZE"),
				))
			GameEnums.EffectType.ARMOR_UP:
				parts.append(_kw_hint("SHIELD %s" % _effect_amount_string(effect), _glossary_def("SHIELD")))
			GameEnums.EffectType.EXPLODE:
				parts.append(_kw_hint("EXPLODE %s" % _effect_amount_string(effect), _glossary_def("EXPLODE")))
			GameEnums.EffectType.RANGED_EXPLODE:
				parts.append(_kw_hint(
					_damage_atk_label(effect, "AOE ATK"),
					_glossary_def("AOE ATK"),
				))
			GameEnums.EffectType.SPAWN:
				parts.append(_kw_hint(
					"SPAWN %s" % str(effect.spawn_unit_id).capitalize(),
					_glossary_def("SPAWN"),
				))
			GameEnums.EffectType.ADD_STATUS:
				_append_status_effect_part(parts, effect, false, true)
			GameEnums.EffectType.ADD_STATUS_SELF:
				_append_status_effect_part(parts, effect, true, true)
			GameEnums.EffectType.PURGE:
				parts.append(_kw_hint("PURGE", _glossary_def("PURGE")))
			GameEnums.EffectType.CLEANSE:
				parts.append(_kw_hint("CLEANSE", _glossary_def("CLEANSE")))
			GameEnums.EffectType.TELEPORT_CASTER:
				parts.append(_kw_hint("TELEPORT", _glossary_def("TELEPORT")))
			GameEnums.EffectType.MOVE_INTO_AND_PUSH:
				parts.append(_kw_hint("PUSH THROUGH", _glossary_def("PUSH THROUGH")))
			GameEnums.EffectType.DESTROY_OBSTACLE:
				parts.append(_kw_hint("DESTROY OBSTACLE", _glossary_def("DESTROY OBSTACLE")))
			GameEnums.EffectType.DAMAGE_SELF:
				parts.append(_kw_hint(
					_damage_atk_label(effect, "Self ATK"),
					"Ignores Armor and deals direct damage to the caster.",
				))
			GameEnums.EffectType.CREATE_HAZARD:
				parts.append(_kw_hint(_hazard_create_label(effect), _glossary_def("CREATE HAZARD")))
			GameEnums.EffectType.THROW_BEHIND:
				parts.append(_kw_hint("THROW BEHIND", _glossary_def("THROW BEHIND")))
			GameEnums.EffectType.CHANGE_TERRAIN:
				parts.append(_kw_hint(
					_terrain_change_label(effect),
					"Change the terrain of affected tiles.",
				))
			GameEnums.EffectType.REFUND_AP_ON_CC, \
			GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, \
			GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, \
			GameEnums.EffectType.PUSH_CHAIN_COLLISION, \
			GameEnums.EffectType.REMOVE_STATUS:
				var mod_label: String = _modifier_effect_label(effect.type)
				if not mod_label.is_empty():
					parts.append(_kw_hint(mod_label, mod_label + "."))
			_:
				parts.append(_effect_amount_string(effect))
	var filter_line: String = ClassLibrarySchema.ability_target_filter_line(ability, unit)
	if filter_line != "":
		parts.append(_kw_hint(filter_line, "Legal click condition for this skill."))
	var body: String = " | ".join(parts) if not parts.is_empty() else "No effect"
	var target_shape: GameEnums.TargetShape = AbilitySystem.active_target_shape(unit, ability)
	if target_shape != GameEnums.TargetShape.SINGLE:
		var shape_name: String = GameEnums.TargetShape.keys()[target_shape].capitalize().replace("Aoe ", "")
		var shape: String = "%s: %s %d | " % [
			_kw_hint("AOE", _glossary_def("AOE")),
			shape_name,
			AbilitySystem.active_target_shape_size(unit, ability),
		]
		return shape + body
	return body


static func format_damage_source_tag(dmg_type: StringName, source_label: String) -> String:
	var label: String = source_label.strip_edges()
	if label.is_empty():
		match String(dmg_type):
			"collision":
				label = "collision"
			"hazard":
				label = "terrain"
			"bleed":
				label = "bleed"
			"burn":
				label = "burn"
			"poison":
				label = "poison"
			"true":
				label = "true damage"
			"magical":
				label = "magical attack"
			"physical":
				label = "attack"
			_:
				label = String(dmg_type)
	return " from %s" % label


static func format_damage_telemetry(m: Dictionary, incoming: int, hp_dmg: int, armor_dmg: int) -> String:
	var c_base := "F39C12"
	var c_wpn := "E74C3C"
	var c_stat := "9B59B6"
	var c_def := "3498DB"
	var c_fort := "1ABC9C"
	var c_status := "F1C40F"
	var c_final := "2ECC71"
	var c_mult := "95A5A6"
	var dmg_type: StringName = m.get("type", &"damage")
	if dmg_type == &"collision":
		var base: int = int(m.get("base", 1))
		var wpn: int = int(m.get("wpn", 0))
		var stat_val: int = int(m.get("stat_val", 0))
		var excess: int = int(m.get("excess_push", 0))
		var base_bonus: int = int(m.get("base_bonus", 0))
		var t_def: int = int(m.get("target_def", 0))
		var fort: int = int(m.get("fortitude", m.get("fort", 0)))
		var mult_raw: float = float(m.get("multiplier_raw", m.get("floored", m.get("final_raw", 0))))
		var stat_mult: float = 1.0 + float(stat_val) / 5.0
		var raw_base: float = 1.0 + float(excess) / 3.0 + float(base_bonus)
		var base_parts := "1 + %s/3" % _fmt_calc_num(float(excess))
		if base_bonus > 0:
			base_parts += " + %d Retaliator" % base_bonus
		var formula := "%s × (%s + %s) × %s" % [
			_damage_formula_color(c_mult, "0.75"),
			_damage_formula_color(c_base, "BASE"),
			_damage_formula_color(c_wpn, "WPN"),
			_damage_formula_color(c_stat, "STR mult"),
		]
		formula += " - %s" % _damage_formula_color(c_def, "DEF")
		if fort != 0:
			formula += " - %s" % _damage_formula_color(c_fort, "FORT")
		formula += "\n   BASE %s = %s" % [
			_damage_formula_color(c_base, base_parts),
			_damage_formula_color(c_base, _fmt_calc_num(raw_base)),
		]
		if int(floorf(raw_base)) != base:
			formula += " → %s" % _damage_formula_color(c_base, _fmt_calc_num(float(base)))
		formula += "\n   %s × (%s + %s) × %s = %s" % [
			_damage_formula_color(c_mult, "0.75"),
			_damage_formula_color(c_base, _fmt_calc_num(float(base))),
			_damage_formula_color(c_wpn, _fmt_calc_num(float(wpn))),
			_damage_formula_color(c_stat, _fmt_calc_num(stat_mult)),
			_damage_formula_color(c_final, _fmt_calc_num(mult_raw)),
		]
		formula += "\n   %s - %s" % [
			_damage_formula_color(c_final, _fmt_calc_num(mult_raw)),
			_damage_formula_color(c_def, _fmt_calc_num(float(t_def))),
		]
		if fort != 0:
			formula += " - %s" % _damage_formula_color(c_fort, _fmt_calc_num(float(fort)))
		formula += " = %s incoming" % _damage_formula_color(c_final, _fmt_calc_num(float(incoming)))
		if armor_dmg > 0:
			formula += "\n   - %s armor → %s HP" % [
				_damage_formula_color(c_def, _fmt_calc_num(float(armor_dmg))),
				_damage_formula_color(c_final, _fmt_calc_num(float(hp_dmg))),
			]
		return formula
	var stat_name: String = str(m.get("stat_name", "STR"))
	var base: int = int(m.get("base", 0))
	var wpn: int = int(m.get("wpn", 0))
	var stat_val: int = int(m.get("stat_val", 0))
	var mult_raw: float = float(m.get("multiplier_raw", m.get("final_raw", m.get("floored", 0))))
	var stat_mult: float = 1.0 + float(stat_val) / 5.0
	var t_def: int = int(m.get("target_def", 0))
	var fort: int = int(m.get("fortitude", m.get("fort", 0)))
	var vuln: bool = bool(m.get("vulnerable", m.get("vuln", false)))
	var elec: bool = bool(m.get("electrified", m.get("elec", false)))
	var formula := "(%s + %s) × %s" % [
		_damage_formula_color(c_base, "Base"),
		_damage_formula_color(c_wpn, "WPN"),
		_damage_formula_color(c_stat, "%s mult" % stat_name),
	]
	if vuln or elec:
		formula += " + %s" % _damage_formula_color(c_status, "Status")
	formula += " - %s" % _damage_formula_color(c_def, "DEF")
	if fort != 0:
		formula += " - %s" % _damage_formula_color(c_fort, "FORT")
	formula += "\n   (%s + %s) × %s = %s" % [
		_fmt_calc_num(float(base)),
		_fmt_calc_num(float(wpn)),
		_fmt_calc_num(stat_mult),
		_damage_formula_color(c_final, _fmt_calc_num(mult_raw)),
	]
	if vuln:
		formula += " + %s" % _damage_formula_color(c_status, "2.0 (Vuln)")
	if elec:
		formula += " + %s" % _damage_formula_color(c_status, "1.0 (Elec)")
	formula += " - %s" % _damage_formula_color(c_def, _fmt_calc_num(float(t_def)))
	if fort != 0:
		formula += " - %s" % _damage_formula_color(c_fort, _fmt_calc_num(float(fort)))
	var calc_val: float = mult_raw
	if vuln:
		calc_val += 2.0
	if elec:
		calc_val += 1.0
	calc_val -= float(t_def)
	calc_val -= float(fort)
	formula += " = %s" % _damage_formula_color(c_final, _fmt_calc_num(maxf(0.0, calc_val)))
	if bool(m.get("backstab", false)):
		formula += "\n   + %s (%s)" % [
			_damage_formula_color(c_status, "Backstab"),
			_fmt_calc_num(float(m.get("backstab_bonus", 0))),
		]
	return formula


static func _damage_formula_color(hex: String, text: String) -> String:
	return "[color=#%s]%s[/color]" % [hex, text]


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


## Player-facing attack label: physical is plain ATK; magical is MAG ATK (no +PHYSICAL suffix).
static func _damage_atk_label(effect: EffectData, prefix: String = "ATK") -> String:
	if effect == null:
		return "%s 0" % prefix
	var amount: String = str(effect.amount)
	var label: String
	if effect.scaling_stat == GameEnums.StatType.MAGICAL:
		if prefix == "ATK":
			label = "MAG ATK %s" % amount
		else:
			label = "%s MAG ATK %s" % [prefix, amount]
	else:
		label = "%s %s" % [prefix, amount]
	var hits: int = _effect_hit_count(effect)
	if hits > 1:
		return "%s × %d" % [label, hits]
	return label


static func _effect_hit_count(effect: EffectData) -> int:
	if effect == null:
		return 1
	return maxi(1, int(effect.modifiers.get(
		"repeat_hits",
		effect.modifiers.get("hit_count", 1),
	)))


static func _damage_atk_hint(effect: EffectData) -> String:
	if effect != null and effect.scaling_stat == GameEnums.StatType.MAGICAL:
		return _glossary_def("MAG ATK")
	return _glossary_def("ATK")


static func _hazard_create_label(effect: EffectData) -> String:
	if effect == null:
		return "CREATE HAZARD"
	var terrain_id: String = String(effect.modifiers.get("terrain_id", ""))
	if not terrain_id.is_empty():
		return "CREATE %s" % terrain_id.replace("_", " ").to_upper()
	var amount: String = _effect_amount_string(effect)
	if amount != "0" and amount != "":
		return "CREATE HAZARD %s" % amount
	return "CREATE HAZARD"


static func _terrain_change_label(effect: EffectData) -> String:
	if effect == null:
		return "CHANGE TERRAIN"
	var terrain_id: String = String(effect.modifiers.get("terrain_id", ""))
	if not terrain_id.is_empty():
		return "CREATE %s" % terrain_id.replace("_", " ").to_upper()
	return "CREATE CRACKED terrain"


static func _modifier_effect_label(effect_type: GameEnums.EffectType) -> String:
	match effect_type:
		GameEnums.EffectType.REFUND_AP_ON_CC:
			return "REFUND AP on CC"
		GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION:
			return "PUSH STAGGER on collision"
		GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT:
			return "PULL VULNERABLE if adjacent"
		GameEnums.EffectType.PUSH_CHAIN_COLLISION:
			return "PUSH CHAIN on collision"
		GameEnums.EffectType.REMOVE_STATUS:
			return "REMOVE STATUS"
		_:
			return ""


static func _fmt_calc_num(value: float) -> String:
	if not is_equal_approx(value, snappedf(value, 0.1)):
		return "%.2f" % value
	return "%.1f" % value


static func _bbcode_from_bible_effect_line(line: String) -> String:
	var parts: Array[String] = []
	for segment: String in line.split("|", false):
		var kw: String = segment.strip_edges()
		if kw.is_empty():
			continue
		parts.append(_kw_hint(kw, _bible_segment_hint(kw)))
	return " | ".join(parts)


static func _kw_hint(word: String, hint: String) -> String:
	var icon := PlanningIcons.keyword_icon(word)
	if icon != "":
		return "[hint=\"%s\"][color=#FBBF24]%s %s[/color][/hint]" % [hint, icon, word]
	return "[hint=\"%s\"][color=#FBBF24]%s[/color][/hint]" % [hint, word]


static func format_stat_bbcode(
	unit: UnitState,
	stat_type: GameEnums.StatType,
	board: BoardState = null,
) -> String:
	var bd: Dictionary = stat_breakdown(unit, stat_type, board)
	var breakdown: String = str(bd.get("tooltip", ""))
	var final_val: int = int(bd.get("final_val", 0))
	var diff: int = int(bd.get("diff", 0))
	if diff > 0:
		return "[color=#%s][hint=\"%s\"]%d[/hint][/color]" % [HEX_STAT_UP, breakdown, final_val]
	if diff < 0:
		return "[color=#%s][hint=\"%s\"]%d[/hint][/color]" % [HEX_STAT_DOWN, breakdown, final_val]
	return "[hint=\"%s\"]%d[/hint]" % [breakdown, final_val]


## Plain Label chip for the planning timeline (value + tooltip + tint when buffed/debuffed).
static func timeline_stat_chip(
	unit: UnitState,
	stat_type: GameEnums.StatType,
	board: BoardState = null,
) -> Dictionary:
	var bd: Dictionary = stat_breakdown(unit, stat_type, board)
	var diff: int = int(bd.get("diff", 0))
	var col: Color = Color.WHITE
	if diff > 0:
		col = Color.html("#" + HEX_STAT_UP)
	elif diff < 0:
		col = Color.html("#" + HEX_STAT_DOWN)
	return {
		"text": "%s%d" % [PlanningIcons.stat_icon(stat_type), int(bd.get("final_val", 0))],
		"tooltip": str(bd.get("tooltip", "")),
		"color": col,
	}


static func stat_breakdown(
	unit: UnitState,
	stat_type: GameEnums.StatType,
	board: BoardState = null,
) -> Dictionary:
	var base_val: int = 0
	var w_bonus: int = 0
	var final_val: int = 0
	var level_bonus: int = UnitLevelGrowth.bonus_for_stat(unit.definition, unit.level, stat_type)
	match stat_type:
		GameEnums.StatType.PHYSICAL:
			base_val = unit.definition.base_strength
			w_bonus = unit.definition.equipped_weapon.bonus_strength if unit.definition.equipped_weapon != null else 0
			final_val = unit.current_strength
		GameEnums.StatType.MAGICAL:
			base_val = unit.definition.base_magic
			w_bonus = unit.definition.equipped_weapon.bonus_magic if unit.definition.equipped_weapon != null else 0
			final_val = unit.current_magic
		GameEnums.StatType.DEFENSE:
			base_val = unit.definition.base_defense
			w_bonus = unit.definition.equipped_weapon.bonus_defense if unit.definition.equipped_weapon != null else 0
			final_val = unit.current_defense
			if unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
				if board != null:
					final_val = CombatSystem.get_dynamic_defense(board, unit)
				else:
					final_val = int(ceil(float(unit.current_defense) * 0.5))
	var natural_total: int = base_val + level_bonus + w_bonus
	var diff: int = final_val - natural_total
	var tooltip_lines: Array[String] = ["%d (Base)" % base_val]
	if level_bonus > 0:
		tooltip_lines.append("+%d (Level %d)" % [level_bonus, unit.level])
	if w_bonus > 0:
		tooltip_lines.append("+%d (Weapon)" % w_bonus)
	if diff != 0:
		for status: StatusData in unit.active_statuses:
			var amount: int = _status_stat_delta(status, stat_type)
			if amount == 0:
				continue
			var sign_str: String = "+" if amount > 0 else ""
			tooltip_lines.append("%s%d (%s)" % [sign_str, amount, _status_source_name(status.type)])
		if stat_type == GameEnums.StatType.DEFENSE and unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
			tooltip_lines.append("Halved (Iron Grip)")
		if unit.has_status(GameEnums.StatusType.POLYMORPH) and stat_type in [
			GameEnums.StatType.PHYSICAL, GameEnums.StatType.MAGICAL,
		]:
			tooltip_lines.append("Set to 0 (Polymorph)")
	return {
		"base_val": base_val,
		"level_bonus": level_bonus,
		"w_bonus": w_bonus,
		"final_val": final_val,
		"natural_total": natural_total,
		"diff": diff,
		"tooltip": "\n".join(tooltip_lines),
	}


static func _status_stat_delta(status: StatusData, stat_type: GameEnums.StatType) -> int:
	if status == null:
		return 0
	match stat_type:
		GameEnums.StatType.PHYSICAL:
			if status.type == GameEnums.StatusType.STAT_BUFF_STR:
				return status.value
			if status.type == GameEnums.StatusType.WEAKEN:
				return -2
		GameEnums.StatType.MAGICAL:
			if status.type == GameEnums.StatusType.STAT_BUFF_MAG:
				return status.value
			if status.type == GameEnums.StatusType.WEAKEN:
				return -2
		GameEnums.StatType.DEFENSE:
			if status.type == GameEnums.StatusType.STAT_BUFF_DEF:
				return status.value
			if status.type == GameEnums.StatusType.STAT_DEBUFF_DEF:
				return -status.value
	return 0


static func _status_source_name(status_type: int) -> String:
	match status_type:
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
		GameEnums.StatusType.WEAKEN:
			return "Weaken"
		GameEnums.StatusType.POLYMORPH:
			return "Polymorph"
	return GameEnums.StatusType.keys()[status_type].capitalize()


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
		GameEnums.StatusType.STAGGER: return "Cannot act or move."
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Defense is halved."
		_: return ""
