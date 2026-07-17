class_name BoardView
extends Node2D

## Purpose: The combat view + planning UX. Renders the grid, units, ghosts,
## targeting affordances, an editable timeline, a hover info panel and a battle
## log, animates the simulation's event log, and turns input (click, drag,
## right-click) into planning calls on the CombatDirector. PURE presentation: it
## only READS BoardState and REACTS to EventBus signals (constitution Golden Rule).
## Dependencies: CombatDirector, EventBus, BoardState/SimResult/SimEvent (read),
##   GridSystem/MovementSystem (read-only queries only).
## Lifecycle: root of Combat.tscn; subscribes to EventBus, then boots the director.

const CELL: int = 56
const ORIGIN := Vector2(24, 96)
const UNIT_RADIUS: float = 21.0
const ANIM_SPEED: float = 320.0
const HUD_MARGIN: int = 12
const SIDE_PANEL_WIDTH: float = 500.0
const INFO_PANEL_HEIGHT: float = 104.0
const TILE_INFO_PANEL_HEIGHT: float = 68.0
const LOG_FONT_SIZE: int = 9
const LOG_FORMULA_FONT_SIZE: int = 7
const LOG_PANEL_HEIGHT: float = 270.0
const DRAG_SELF_SKILL_DELAY_MS: int = 150
const DRAG_CLICK_MOVE_THRESHOLD: float = 8.0

const COLOR_GRID := Color(0.12, 0.13, 0.16)
const COLOR_TILE := Color(0.24, 0.26, 0.31)
const COLOR_TILE_ALT := Color(0.21, 0.23, 0.28)
const COLOR_TILE_EDGE := Color(0.32, 0.34, 0.40, 0.55)
const COLOR_WALL := Color(0.14, 0.14, 0.17)
const COLOR_WALL_FACE := Color(0.22, 0.22, 0.26)
const COLOR_PIT := Color(0.04, 0.02, 0.06)
const COLOR_PIT_GLOW := Color(0.72, 0.18, 0.22, 0.35)
const COLOR_SPIKES := Color(0.38, 0.16, 0.18)
const COLOR_SPIKE_MARK := Color(0.62, 0.28, 0.30, 0.45)
const COLOR_REACH := Color(0.28, 0.58, 0.48, 0.32)
const COLOR_RANGE := Color(0.92, 0.62, 0.28, 0.28)
const COLOR_TARGET := Color(0.98, 0.72, 0.38)
const COLOR_ARROW := Color(0.98, 0.88, 0.38, 0.95)
const COLOR_ARROW_GLOW := Color(0.98, 0.88, 0.38, 0.22)
const COLOR_ENEMY_ARROW := Color(0.95, 0.42, 0.38, 0.95)
const COLOR_ENEMY_ARROW_GLOW := Color(0.95, 0.42, 0.38, 0.2)
const COLOR_PLAYER_ARROW := Color(0.36, 0.62, 0.92, 0.95)
const COLOR_PLAYER_ARROW_GLOW := Color(0.36, 0.62, 0.92, 0.22)
const COLOR_DRAGPATH := Color(0.98, 0.88, 0.38, 0.65)
const COLOR_FAIL := Color(0.95, 0.45, 0.40)
const COLOR_HOVER := Color(0.98, 0.92, 0.72, 0.95)
const COLOR_PLAYER := Color(0.36, 0.62, 0.92)
const COLOR_ENEMY := Color(0.86, 0.38, 0.34)
const COLOR_SELECT := Color(0.98, 0.86, 0.32)
const COLOR_SKILL_DISABLED := Color(0.48, 0.50, 0.54)
const COLOR_SELECT_GLOW := Color(0.98, 0.86, 0.32, 0.25)
const COLOR_TEXT := Color(0.96, 0.97, 0.99)
const COLOR_TEXT_SHADOW := Color(0.02, 0.02, 0.04, 0.65)
const COLOR_FACING := Color(0.98, 0.98, 0.94, 0.95)
const COLOR_HP_BG := Color(0.08, 0.08, 0.10, 0.94)
const COLOR_HP_FILL := Color(0.38, 0.78, 0.46)
const COLOR_HP_LOSS := Color(0.95, 0.30, 0.28)
const COLOR_DEATH := Color(0.97, 0.26, 0.24)
const COLOR_HOVER_MOVE := Color(0.35, 0.58, 0.92, 0.22)
const COLOR_HOVER_THREAT := Color(0.92, 0.38, 0.32, 0.20)
const COLOR_DANGER := Color(0.9, 0.2, 0.2, 0.2)
const COLOR_BOARD_BG := Color(0.07, 0.08, 0.10, 0.96)
const COLOR_BOARD_FRAME := Color(0.34, 0.36, 0.42, 0.75)
const COLOR_PANEL_BG := Color(0.10, 0.11, 0.14, 0.94)
const COLOR_PANEL_BORDER := Color(0.28, 0.30, 0.36, 0.9)
const COLOR_TOKEN_SHADOW := Color(0.02, 0.02, 0.04, 0.55)
const COLOR_TOKEN_RING := Color(0.98, 0.98, 1.0, 0.22)
const BAR_W: float = 42.0
const BAR_H: float = 6.0

var _floating_text_scene = preload("res://presentation/floating_text.tscn")
var _options_scene = preload("res://scenes/Options.tscn")
var _compendium_scene = preload("res://scenes/Compendium.tscn")

var _sandbox_container: VBoxContainer
var _sandbox_title: Label
var _sandbox_hp: SpinBox
var _sandbox_max_hp: SpinBox
var _sandbox_status_dd: OptionButton

var _map_editor_container: VBoxContainer
var _map_editor_title: Label
var _map_editor_dd: OptionButton

## Per-class token colors (body fill, accent rim).
const CLASS_COLORS: Dictionary = {
	&"knight": [Color(0.42, 0.50, 0.62), Color(0.82, 0.72, 0.38)],
	&"archer": [Color(0.28, 0.52, 0.36), Color(0.62, 0.88, 0.48)],
	&"warden": [Color(0.22, 0.48, 0.52), Color(0.48, 0.82, 0.86)],
	&"swordmaster": [Color(0.58, 0.28, 0.32), Color(0.95, 0.55, 0.48)],
	&"mage": [Color(0.38, 0.28, 0.58), Color(0.72, 0.52, 0.95)],
	&"cleric": [Color(0.48, 0.46, 0.38), Color(0.95, 0.88, 0.55)],
	&"charger": [Color(0.62, 0.32, 0.28), Color(0.95, 0.58, 0.38)],
	&"artillery": [Color(0.48, 0.30, 0.34), Color(0.88, 0.42, 0.38)],
	&"shover": [Color(0.36, 0.34, 0.42), Color(0.72, 0.68, 0.82)],
}

const PLAYER_COLORS: Array[Color] = [
	Color(0.36, 0.62, 0.92), # Blue
	Color(0.36, 0.92, 0.62), # Green
	Color(0.92, 0.92, 0.36), # Yellow
	Color(0.92, 0.36, 0.92)  # Magenta
]

func _get_player_color(player_id: int) -> Color:
	if NetworkManager == null or not NetworkManager.is_multiplayer:
		return PLAYER_COLORS[0]
	var keys = NetworkManager.player_usernames.keys()
	keys.sort()
	var idx = keys.find(player_id)
	if idx >= 0 and idx < PLAYER_COLORS.size():
		return PLAYER_COLORS[idx]
	return PLAYER_COLORS[0]

## bbcode hex colors for panel/log text (kept here so the palette stays in one place).
const HEX_PHASE := "7fd4ff"
const HEX_SELECT := "fde08a"
const HEX_INTENT := "f0907f"
const HEX_PLAYER := "8fb8f0"
const HEX_ENEMY := "f08f88"
const HEX_ATTACK := "e2b7f0"
const HEX_TILE := "e0c071"
const HEX_MOVE := "9fb6d4"
const HEX_DMG := "f5b15a"
const HEX_DEATH := "f06a6a"
const HEX_TURN := "7fd4ff"
const HEX_DIM := "9aa0ad"
const HEX_HEAL := "4ade80"

@onready var _director: CombatDirector = get_node("../CombatDirector")

var _board: BoardState
var _preview: BoardState
var _selected_id: int = -1
var _timeline_hover_id: int = -1
var _selected_ability: int = 0
var _phase: int = CombatDirector.Phase.PLANNING
var _aiming: bool = false
var _force_basic_movement: bool = false
var _is_local_ready: bool = false

var _dragging: bool = false
var _drag_unit_id: int = -1
var _drag_pos: Vector2 = Vector2.ZERO
var _drag_facing: int = -1
var _unit_selected_abilities: Dictionary = {}
## The trail of tiles the cursor traced during the drag (honoured as the move route).
var _drag_route: Array[Vector2i] = []
## Last passable, unoccupied tile hovered while dragging (preferred attack position).
var _drag_last_free: Vector2i = Vector2i(-1, -1)
## Previewed combat events if the unit was dropped here.
var _drag_intents: Array[Intent] = []

var _hover_coord: Vector2i = Vector2i(-1, -1)
var _hover_ability: int = -1
## Cached reachable / threatened tiles for the currently hovered unit.
var _hover_move_tiles: Array[Vector2i] = []
var _hover_threat_tiles: Array[Vector2i] = []
## Enemy ids whose intent should be shown (acting on the selected unit, or hovered).
var _intent_units: Dictionary = {}
var _drag_predicted_hp: Dictionary = {}
var _drag_predicted_armor: Dictionary = {}
var _hover_predicted_hp: Dictionary = {}
var _hover_predicted_armor: Dictionary = {}
## Live enemy intents while aiming (mirrors _drag_intents during drag).
var _aim_intents: Array[Intent] = []
var _drag_sim_actor_pos: Vector2i = Vector2i.ZERO
var _drag_failed: bool = false
var _drag_unit_was_selected: bool = false
var _drag_press_local: Vector2 = Vector2.ZERO
var _drag_press_time_ms: int = 0
## Committed preview snapshot taken at drag start; restored if drag is canceled.
var _drag_saved_preview: BoardState = null
var _drag_saved_preview_paths: Dictionary = {}
var _drag_saved_preview_splits: Dictionary = {}
var _drag_saved_preview_pushes: Dictionary = {}
var _danger_tiles_cache: Dictionary = {}
var _danger_tiles_dirty: bool = true

## Visual model the renderer animates: unit_id -> { is_enemy, label, hp, max_hp,
## pos (current pixel center), waypoints (remaining pixel centers), facing (Vector2),
## alive }.
var _visual: Dictionary = {}

## unit_id -> Array[Vector2i] full tile route from the preview's event log, used to
## draw orthogonal (cardinal) move arrows that follow the actual path.
var _preview_paths: Dictionary = {}
## unit_id -> int: how many leading route points belong to the player phase. Points
## past this index were caused during the enemy phase (drawn in a distinct colour).
var _preview_splits: Dictionary = {}
var _preview_pushes: Dictionary = {}
## Units currently animating a planning-phase trample commit (skip visual snap).
var _planning_anim_units: Dictionary = {}
var _planning_commit_active: bool = false
## unit_id -> predicted HP after the planned turn (for the blinking damage bar).
var _predicted_hp: Dictionary = {}
var _predicted_armor: Dictionary = {}
var _has_pending_change: bool = false

var _font: Font
var _phase_label: Label
var _selected_label: Label
var _intent_label: Label
var _score_lbl: Label
var _ai_calc_enabled: bool = false
var _timeline_box: GridContainer
var _execute_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _warn_label: RichTextLabel
var _players_label: RichTextLabel
var _info_panel: PanelContainer
var _info_label: RichTextLabel
var _tile_info_panel: PanelContainer
var _tile_info_label: RichTextLabel
var _last_math_telemetry: Dictionary
var _top_hud: PanelContainer
var _ability_buttons: Array[Button] = []
var _log_panel: PanelContainer
var _log_label: RichTextLabel
var _banner: Control
var _banner_label: Label

var _players_panel: PanelContainer
var _chat_panel: PanelContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_fade_timer: float = 0.0

var _sfx: SfxPlayer
var _hud_layer: CanvasLayer
var _left_panel: VBoxContainer
var _side_panel: VBoxContainer

var _hit_markers: Array = []
var _show_danger_area: bool = false
var _hover_action_icon: String = ""
var _cached_hover_unit_id: int = -1
var _cached_hover_origin: Vector2i = Vector2i(-999, -999)
var _cached_hover_ability: int = -1
var _cached_hover_force_move: bool = false
var _pause_menu: Control
var _bottom_hud: PanelContainer
var _skill_list: VBoxContainer
var _autobattler_hook: AutobattlerHookRegistry
var _autobattler_active: bool = false

## Number of attack animations (ABILITY_USED tweens) currently in flight.
## UNIT_PUSHED events are held in _pending_push_queue until this reaches 0.
var _active_attack_anims: int = 0
var _pending_push_queue: Array = []
## Counts push/displacement tweens currently animating; when it hits 0 the
## push_animations_complete signal is emitted so the director can proceed.
var _active_push_tweens: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	
	_font = ThemeDB.fallback_font
	_sfx = SfxPlayer.new()
	_sfx._director = _director
	add_child(_sfx)
	_build_hud()
	
	var telemetry_hud = AITelemetryHUD.new()
	add_child(telemetry_hud)

	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.action_rejected.connect(_on_action_rejected)
	EventBus.planning_commit_events.connect(_on_planning_commit_events)
	GlobalTimeline.player_ready_changed.connect(_on_player_ready_changed)
	get_viewport().size_changed.connect(_on_window_resized)

	_director.start()
	_autobattler_hook = AutobattlerHookRegistry.new(_director)

func _on_window_resized() -> void:
	_layout_hud()
	queue_redraw()
func _process(delta: float) -> void:
	queue_redraw()
	var hc = get_viewport().gui_get_hovered_control()
	if hc != null and hc != self:
		if _hover_coord != Vector2i(-1, -1):
			_update_hover(Vector2(-1000, -1000))

	if _chat_panel != null:
		var mouse_in = false
		if _chat_panel.is_inside_tree():
			mouse_in = _chat_panel.get_global_rect().has_point(get_global_mouse_position())
		if _chat_input.has_focus() or mouse_in:
			_chat_panel.modulate.a = 1.0
			_chat_fade_timer = 5.0
		else:
			if _chat_fade_timer > 0.0:
				_chat_fade_timer -= delta
				_chat_panel.modulate.a = 1.0
			else:
				_chat_panel.modulate.a = max(0.0, _chat_panel.modulate.a - delta * 1.5)
				
		if _chat_panel.modulate.a <= 0.01 and not _chat_input.has_focus():
			_chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chat_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_chat_panel.mouse_filter = Control.MOUSE_FILTER_PASS
			_chat_input.mouse_filter = Control.MOUSE_FILTER_STOP

	var moving := false
	
	for i in range(_hit_markers.size() - 1, -1, -1):
		_hit_markers[i][1] -= delta
		if _hit_markers[i][1] <= 0.0:
			_hit_markers.remove_at(i)
			moving = true

	for id in _visual:
		var v: Dictionary = _visual[id]
		var step_speed: float = v.get("move_speed", ANIM_SPEED)
		var step := step_speed * delta
		var waypoints: Array = v["waypoints"]
		if waypoints.size() > 0:
			var pos: Vector2 = v["pos"]
			var next: Vector2 = waypoints[0]
			v["pos"] = pos.move_toward(next, step)
			var diff: Vector2 = next - v["pos"]
			if diff.length() > 0.1:
				v["facing"] = v["facing"].lerp(diff.normalized(), 15.0 * delta)
			if (v["pos"] as Vector2).distance_to(next) <= 0.5:
				v["pos"] = next
				waypoints.remove_at(0)
				if waypoints.is_empty() and v.has("move_speed"):
					v.erase("move_speed")
			moving = true
		elif v.get("shake", 0.0) > 0.0:
			v["shake"] -= delta
			v["shake_offset"] = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			moving = true
			if v["shake"] <= 0.0:
				v["shake_offset"] = Vector2.ZERO
				
	# Keep redrawing while planning or moving so dashed arrows and damage bars animate.
	if moving or CombatDirector.is_planning_phase(_phase):
		queue_redraw()

# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _board == null:
		return
	if event.is_action_pressed("ui_accept"):
		if _chat_input != null:
			_chat_input.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _pause_menu != null:
			_pause_menu.visible = not _pause_menu.visible
			if _pause_menu.visible:
				_refresh_sandbox_panel()
				if _info_panel != null: _info_panel.visible = false
				if _tile_info_panel != null: _tile_info_panel.visible = false
			else:
				_close_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if _pause_menu != null and _pause_menu.visible:
		return
		
	if event is InputEventMouseMotion:
		var local := get_local_mouse_position()
		if _dragging:
			_update_drag(local)
		else:
			_update_hover(local)
		return
	if not CombatDirector.is_planning_phase(_phase):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_viewport().set_input_as_handled()
			_on_right_click()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			get_viewport().set_input_as_handled()
			if _selected_id >= 0 and _board != null:
				var unit = _board.get_unit_by_id(_selected_id)
				if unit != null:
					var abilities = unit.active_abilities
					if abilities.size() > 0:
						var new_idx = (_selected_ability - 1 + abilities.size()) % abilities.size()
						if _director != null:
							_director.select_ability(new_idx)
						if _dragging: _update_drag(get_local_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			get_viewport().set_input_as_handled()
			if _selected_id >= 0 and _board != null:
				var unit = _board.get_unit_by_id(_selected_id)
				if unit != null:
					var abilities = unit.active_abilities
					if abilities.size() > 0:
						var new_idx = (_selected_ability + 1) % abilities.size()
						if _director != null:
							_director.select_ability(new_idx)
						if _dragging: _update_drag(get_local_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if event.pressed:
				_on_left_press(get_local_mouse_position())
			else:
				_on_left_release(get_local_mouse_position())

func _on_right_click() -> void:
	if _aiming:
		_cancel_aim()
		_sfx.play("cancel")
		return
	if (CombatDirector.is_planning_phase(_phase)) and _selected_id >= 0:
		if _unit_has_undoable_actions(_selected_id):
			_remove_last_for_unit(_selected_id)
			_sfx.play("cancel")
		else:
			_director.select_unit(-1)
			_sfx.play("cancel")

func _on_left_press(local: Vector2) -> void:
	var coord := _to_coord(local)
	if not _board.is_in_bounds(coord):
		_cancel_aim()
		return
	var unit := _board.get_unit_at(coord)

	# Grabbing one of your own units always starts a drag and takes priority over
	# aim mode, so you can pick any ability then drag your unit to act with it.
	if unit != null and not unit.is_enemy() and unit.is_alive():
		if NetworkManager != null and NetworkManager.is_multiplayer and unit.controlling_player_id != NetworkManager.local_player_id:
			_cancel_aim()
			_sfx.play("invalid")
			return
		
		if _aiming and unit.id == _selected_id:
			var actor := _proj_unit(_selected_id)
			if actor != null and _ability_range(actor) == 0:
				_plan_attack(_selected_id, _selected_ability, unit.id)
				_sfx.play("ability")
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				_cancel_aim()
				return
			_sfx.play("invalid")
			return
		
		if _aiming:
			_cancel_aim()
		var was_selected := unit.id == _selected_id
		_director.select_unit(unit.id)
		_begin_drag(unit, local, was_selected)
		return

	if _aiming:
		# Aim-click a target (enemy/ally tile). Enemies resolve on preview-final tiles.
		var actor := _proj_unit(_selected_id)
		if actor != null and _try_plan_basic_move(_selected_id, coord, local):
			_cancel_aim()
			return
		var target := _aim_enemy_board().get_unit_at(coord)
		if target != null and actor != null:
			if target.id == actor.id:
				if _ability_range(actor) == 0:
					_plan_attack(_selected_id, _selected_ability, target.id)
					_sfx.play("ability")
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				else:
					_sfx.play("invalid")
			elif _in_ability_range(actor, target):
				_plan_attack(_selected_id, _selected_ability, target.id)
				_sfx.play("ability")
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			else:
				_sfx.play("invalid")
		elif actor != null and _ability_has_dash(_selected_ability_data(actor)):
			if _is_valid_dash_target(actor.position, coord, _ability_range(actor)):
				_plan_ability_at_coord(_selected_id, _selected_ability, coord)
				_sfx.play("ability")
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			else:
				_sfx.play("invalid")
		else:
			_sfx.play("invalid")
		_cancel_aim()
		return

	if unit != null and unit.is_enemy():
		var sel_unit = _board.get_unit_by_id(_selected_id) if _selected_id >= 0 else null
		if sel_unit != null and not sel_unit.is_enemy():
			_plan_approach_or_trample_on_enemy(_selected_id, unit, local, Vector2i(-1, -1))
		else:
			# Click an enemy with no ally selected (or another enemy selected): just select them
			_director.select_unit(unit.id)
	else:
		var sel_unit = _board.get_unit_by_id(_selected_id) if _selected_id >= 0 else null
		if sel_unit != null and not sel_unit.is_enemy():
			if not _try_plan_skill_at_coord(sel_unit, coord, local) and _basic_move_allowed():
				_plan_move(_selected_id, coord, _facing_from_drop(local, coord), [])
				_sfx.play("move")

func _skill_takes_priority_over_basic_move() -> bool:
	return not _force_basic_movement and _selected_ability >= 0

func _prefer_approach_over_trample_move(actor: UnitState, enemy: UnitState) -> bool:
	if _force_basic_movement:
		return false
	if actor == null or enemy == null or not enemy.is_enemy():
		return false
	if _selected_ability < 0:
		return false
	if _movement_blocked_by_dash() and _force_basic_movement:
		return false
	return MovementSystem.has_trample(actor) and _can_move_to(actor, enemy.position)

func _plan_approach_or_trample_on_enemy(unit_id: int, enemy: UnitState, local: Vector2, preferred_tile: Vector2i, waypoints: Array[Vector2i] = []) -> void:
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _board.get_unit_by_id(unit_id) if _board != null else null
	if actor == null:
		return
	if _prefer_approach_over_trample_move(actor, enemy):
		_plan_attack_with_approach(unit_id, _selected_ability, enemy.id, preferred_tile)
		_sfx.play("ability")
	elif _can_move_to(actor, enemy.position):
		_plan_move(unit_id, enemy.position, _facing_from_drop(local, enemy.position), waypoints)
		_sfx.play("move")
	else:
		_plan_attack_with_approach(unit_id, _selected_ability, enemy.id, preferred_tile)
		_sfx.play("ability")

func _begin_drag(unit: UnitState, local: Vector2, was_already_selected: bool = false) -> void:
	_stash_committed_preview()
	_dragging = true
	_clear_hover_attack_preview()
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_drag_press_local = local
	_drag_press_time_ms = Time.get_ticks_msec()
	_drag_pos = local
	_drag_facing = -1
	_drag_route = [unit.position]
	_drag_last_free = unit.position
	_recompute_hover_ranges()
	queue_redraw()

## Update the dragged token: live facing from the tile sub-region, and grow the
## traced route along the tiles the cursor passes through (detours allowed).
func _update_drag(local: Vector2) -> void:
	_drag_pos = local
	var coord := _to_coord(local)
	_drag_facing = _facing_from_drop(local, coord)
	if _board.is_in_bounds(coord):
		_hover_coord = coord
		if _basic_move_allowed():
			_extend_drag_route(coord)
		var occ := _board.get_unit_at(coord)
		var drag_unit := _board.get_unit_by_id(_drag_unit_id)
		if occ == null or occ.id == _drag_unit_id:
			_drag_last_free = coord
		elif drag_unit != null and not drag_unit.is_enemy() and occ.is_enemy() \
		and MovementSystem.has_trample(drag_unit) and _force_basic_movement:
			_drag_last_free = coord
			
		var drag_target_id := -1
		if occ != null and occ.id != _drag_unit_id:
			drag_target_id = occ.id
			
		_refresh_live_interaction_preview(
			_drag_unit_id, _drag_last_free, drag_target_id, _drag_route_waypoints(), &"drag_key")
	_recompute_intent_units()
	_update_intent_label()
	_refresh_info()
	_update_mouse_cursor()
	_recompute_hover_ranges()
	queue_redraw()

func _extend_drag_route(coord: Vector2i) -> void:
	if _drag_route.is_empty():
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if GridSystem.manhattan(last, coord) <= 1:
		_append_route_tile(coord)
	else:
		# Cursor jumped: bridge with the shortest path so the trail stays continuous.
		for c in MovementSystem.find_path(_board, last, coord, 999):
			_append_route_tile(c)

func _append_route_tile(coord: Vector2i) -> void:
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if coord == last:
		return
	if _drag_route.size() >= 2 and coord == _drag_route[_drag_route.size() - 2]:
		_drag_route.remove_at(_drag_route.size() - 1)  # backtrack
		return
		
	var unit := _board.get_unit_by_id(_drag_unit_id)
	var team := GameEnums.Team.PLAYER
	if unit != null: team = unit.team
	
	if GridSystem.manhattan(last, coord) != 1 or not MovementSystem._is_walkable_for(_board, coord, unit):
		return
	if unit != null and not _force_basic_movement and _selected_ability >= 0:
		var occ := _board.get_unit_at(coord)
		if occ != null and occ.is_enemy() and MovementSystem.has_trample(unit):
			return
	if unit != null and _drag_route.size() - 1 >= unit.movement.points_left:
		return  # out of movement budget
	_drag_route.append(coord)

func _drag_route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return waypoints

func _on_planning_commit_events(events: Array) -> void:
	_planning_commit_active = true
	_planning_anim_units.clear()
	var move_events: Array[SimEvent] = []
	var push_events: Array[SimEvent] = []
	for event: SimEvent in events:
		match event.type:
			GameEnums.SimEventType.UNIT_MOVED:
				move_events.append(event)
				_planning_anim_units[event.data.get("actor", -1)] = true
			GameEnums.SimEventType.UNIT_PUSHED, GameEnums.SimEventType.COLLISION:
				push_events.append(event)
				_planning_anim_units[event.data.get("unit", -1)] = true
			GameEnums.SimEventType.UNIT_DAMAGED:
				_on_sim_event(event)
	if not move_events.is_empty():
		var max_path_len := 0
		for e in move_events:
			_on_sim_event(e)
			max_path_len = maxi(max_path_len, (e.data.get("path", []) as Array).size())
		await get_tree().create_timer(maxf(1.0, float(max_path_len)) * CombatDirector.MOVE_STEP_TIME + 0.05).timeout
	for e in push_events:
		_on_sim_event(e)
	if not push_events.is_empty():
		await _await_planning_push_animations()
	_planning_commit_active = false
	_planning_anim_units.clear()
	if _board != null:
		_rebuild_visual(_board)
	queue_redraw()

func _await_planning_push_animations() -> void:
	var done := false
	var on_done := func() -> void:
		done = true
	var on_timeout := func() -> void:
		if not done:
			EventBus.push_animations_complete.emit()
	EventBus.push_animations_complete.connect(on_done, CONNECT_ONE_SHOT)
	get_tree().create_timer(CombatDirector.PUSH_ANIM_FALLBACK).timeout.connect(on_timeout, CONNECT_ONE_SHOT)
	await EventBus.push_animations_complete

func _sync_visual_state_from_board(board: BoardState) -> void:
	for unit in board.units:
		if not unit.is_alive() or not _visual.has(unit.id):
			continue
		if _planning_anim_units.has(unit.id):
			_visual[unit.id]["hp"] = unit.health.current_hp
			_visual[unit.id]["unit"] = unit
			continue
		var center := _coord_center(unit.position)
		_visual[unit.id]["pos"] = center
		_visual[unit.id]["hp"] = unit.health.current_hp
		_visual[unit.id]["unit"] = unit
		_visual[unit.id]["waypoints"] = []
		_visual[unit.id]["facing"] = Vector2(PhysicsSystem.facing_to_vector(unit.facing))

func _stash_committed_preview() -> void:
	_drag_saved_preview = _preview.clone() if _preview != null else null
	_drag_saved_preview_paths = _preview_paths.duplicate(true)
	_drag_saved_preview_splits = _preview_splits.duplicate(true)
	_drag_saved_preview_pushes = _preview_pushes.duplicate(true)

func _restore_committed_preview() -> void:
	if _drag_saved_preview == null:
		return
	_preview = _drag_saved_preview.clone()
	_preview_paths = _drag_saved_preview_paths.duplicate(true)
	_preview_splits = _drag_saved_preview_splits.duplicate(true)
	_preview_pushes = _drag_saved_preview_pushes.duplicate(true)
	_drag_saved_preview = null
	_drag_saved_preview_paths.clear()
	_drag_saved_preview_splits.clear()
	_drag_saved_preview_pushes.clear()

func _on_left_release(local: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var actor := _board.get_unit_by_id(_drag_unit_id)
	var coord := _to_coord(local)
	if actor == null or not _board.is_in_bounds(coord):
		_restore_committed_preview()
		queue_redraw()
		return
	var dropped_on := _board.get_unit_at(coord)
	if dropped_on != null and dropped_on.id != actor.id:
		# Drop onto another unit: trample-move onto enemy, or approach + ability.
		var approach_waypoints: Array[Vector2i] = []
		if _drag_route.size() >= 2 and _drag_route[_drag_route.size() - 1] == coord:
			for i in range(1, _drag_route.size()):
				approach_waypoints.append(_drag_route[i])
		elif _drag_route.size() >= 2 and _drag_route[_drag_route.size() - 1] == _drag_last_free:
			for i in range(1, _drag_route.size()):
				approach_waypoints.append(_drag_route[i])
		_plan_approach_or_trample_on_enemy(_drag_unit_id, dropped_on, local, _drag_last_free, approach_waypoints)
	elif coord == actor.position:
		if _selected_ability >= 0 and _ability_range(actor) == 0 \
		and _drag_unit_was_selected and _drag_self_skill_intent(local):
			_plan_attack(_drag_unit_id, _selected_ability, actor.id)
			_sfx.play("ability")
			if _director != null:
				_director.select_ability(-1)
		else:
			# Dropped on its own tile: turn in place toward the drop sub-region.
			var face := _facing_from_drop(local, coord)
			if face >= 0:
				_plan_face(_drag_unit_id, face)
				_sfx.play("move")
	elif dropped_on == null:
		var waypoints: Array[Vector2i] = []
		if _drag_route.size() >= 2 and _drag_route[_drag_route.size() - 1] == coord:
			for i in range(1, _drag_route.size()):
				waypoints.append(_drag_route[i])
		if _try_plan_skill_at_coord(actor, coord, local):
			pass
		elif _try_plan_basic_move(_drag_unit_id, coord, local, waypoints):
			pass
	queue_redraw()

## Facing implied by where inside a tile the cursor was released. Returns -1 (let
## the movement direction decide) when released near the tile centre.
func _facing_from_drop(local: Vector2, coord: Vector2i) -> int:
	var offset := local - _coord_center(coord)
	if offset.length() < CELL * 0.22:
		return -1
	if absf(offset.x) >= absf(offset.y):
		return GameEnums.Facing.EAST if offset.x > 0 else GameEnums.Facing.WEST
	return GameEnums.Facing.SOUTH if offset.y > 0 else GameEnums.Facing.NORTH

# --- Signal handlers ----------------------------------------------------------

func _on_board_changed(board: BoardState) -> void:
	_board = board
	_layout_hud()
	if _aiming:
		_cancel_aim()
	else:
		_aim_intents.clear()
		_drag_intents.clear()
		if _drag_saved_preview != null:
			_restore_committed_preview()
	_aiming = false
	_dragging = false
	_drag_route.clear()
	_drag_intents.clear()
	_drag_predicted_hp.clear()
	_drag_predicted_armor.clear()
	_clear_hover_attack_preview()
	_drag_failed = false
	_danger_tiles_dirty = true
	if not _planning_commit_active:
		_rebuild_visual(board)
	else:
		_sync_visual_state_from_board(board)
	_cached_hover_unit_id = -1
	_cached_hover_origin = Vector2i(-999, -999)
	_cached_hover_ability = -1
	_recompute_intent_units()
	_recompute_hover_ranges()
	_refresh_info()
	queue_redraw()

## Show only the intents we choose to surface (acting on selection, or hovered).
func _update_intent_label() -> void:
	if _board == null:
		return
	_intent_label.text = "💀 Enemy intent:\n%s" % _summarize_intents(_board)

func _on_action_rejected(reason: String) -> void:
	_sfx.play("invalid")
	var msg: Array[String] = [_reason_text(reason)]
	_set_warnings(msg)

func _on_preview_updated(result: SimResult) -> void:
	_drag_saved_preview = null
	_drag_saved_preview_paths.clear()
	_drag_saved_preview_splits.clear()
	_drag_saved_preview_pushes.clear()
	_preview = result.final_state
	_build_preview_paths(result.events)
	_compute_predicted_change()
	_rebuild_ability_buttons()
	queue_redraw()

## Cache predicted post-turn HP and whether anything visibly changes, so the unit
## health bars can show (and blink) the damage a unit is about to take.
func _compute_predicted_change() -> void:
	_predicted_hp.clear()
	_predicted_armor.clear()
	_has_pending_change = false
	if _board == null or _preview == null:
		return
	for unit in _board.units:
		var pv := _preview.get_unit_by_id(unit.id)
		var predicted: int = pv.health.current_hp if (pv != null and pv.is_alive()) else 0
		var predicted_ar: int = pv.armor if (pv != null and pv.is_alive()) else 0
		_predicted_hp[unit.id] = predicted
		_predicted_armor[unit.id] = predicted_ar
		if predicted != unit.health.current_hp or predicted_ar != unit.armor:
			_has_pending_change = true

func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	if _unit_selected_abilities.has(unit_id):
		_selected_ability = _unit_selected_abilities[unit_id]
	else:
		_selected_ability = 0
		
	if _director != null:
		_director.select_ability(_selected_ability)
	if _drag_saved_preview == null:
		_stash_committed_preview()
	_aiming = false
	_recompute_intent_units()
	_cached_hover_unit_id = -1
	_cached_hover_origin = Vector2i(-999, -999)
	_cached_hover_ability = -1
	_recompute_hover_ranges()
	_update_intent_label()
	_update_players_panel()
	_rebuild_ability_buttons()
	_update_mouse_cursor()
	_refresh_selected_interaction_preview()
	_sfx.play("select")
	queue_redraw()

func _on_ability_selected(index: int) -> void:
	_selected_ability = index
	if _selected_id >= 0:
		_unit_selected_abilities[_selected_id] = index
	if _drag_saved_preview == null:
		_stash_committed_preview()
	_cached_hover_unit_id = -1
	_cached_hover_origin = Vector2i(-999, -999)
	_cached_hover_ability = -1
	_recompute_hover_ranges()
	_rebuild_ability_buttons()
	_update_mouse_cursor()
	_refresh_selected_interaction_preview()
	queue_redraw()

func _skill_button_modulate(index: int, can_afford: bool) -> Color:
	if not can_afford:
		return COLOR_SKILL_DISABLED
	if index == _selected_ability:
		return COLOR_SELECT
	return Color.WHITE

func _on_timeline_changed(timeline: Timeline, statuses: PackedStringArray) -> void:
	for child in _timeline_box.get_children():
		_timeline_box.remove_child(child)
		child.queue_free()
		
	if _board == null:
		return
		
	var plan_active := CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase)
	var pre_col_active: bool = plan_active
	var action_col_active: bool = plan_active
	var BG_ACTIVE := Color(1.0, 1.0, 0.0, 0.25)
	var COLOR_DIM_HEADER := Color(0.6, 0.6, 0.6)
	var headers := ["Name", "Class", "Stats", "Pre-Move", "Action"]
	for i in headers.size():
		var h: String = headers[i]
		var hcol := Color.WHITE
		var hbg := Color.TRANSPARENT
		if i == 3:
			hcol = Color.WHITE if pre_col_active else COLOR_DIM_HEADER
			hbg = BG_ACTIVE if pre_col_active else Color.TRANSPARENT
		elif i == 4:
			hcol = Color.WHITE if action_col_active else COLOR_DIM_HEADER
			hbg = BG_ACTIVE if action_col_active else Color.TRANSPARENT
		_make_table_cell(_timeline_box, h, "", hcol, true, hbg)
		
	var first_warning: Array[String] = []
	
	for unit in _board.units:
		if unit.is_enemy():
			continue
			
		var row_color := Color.WHITE
		var dim_color := Color(0.7, 0.7, 0.7)
		var bg_color := Color.TRANSPARENT
		if unit.id == _selected_id:
			row_color = Color(1.0, 1.0, 0.3)
			dim_color = Color(0.9, 0.9, 0.2)
			bg_color = Color(0.2, 0.3, 0.5, 0.5)
			
		var name_lbl := _make_table_cell(_timeline_box, unit.definition.display_name, unit.definition.display_name, row_color, false, bg_color)
		
		var c_sym := _class_symbol(unit)
		var c_name := unit.definition.display_name
		var class_lbl := _make_table_cell(_timeline_box, c_sym, c_name, row_color, false, bg_color)
		
		var stats_text := "🌟%d ❤️%d/%d 🛡️%d 💪%d 🔮%d 🏰%d 👟%d" % [unit.level, unit.health.current_hp, unit.health.max_hp, unit.armor, unit.current_strength, unit.current_magic, unit.current_defense, unit.movement.max_points]
		var stats_tooltip := "Level: %d, Health: %d/%d, Armor: %d, Strength: %d, Magic: %d, Defense: %d, Move: %d" % [unit.level, unit.health.current_hp, unit.health.max_hp, unit.armor, unit.current_strength, unit.current_magic, unit.current_defense, unit.movement.max_points]
		var stats_lbl := _make_table_cell(_timeline_box, stats_text, stats_tooltip, dim_color, false, bg_color)
		
		var pre_action: TimelineAction = _timeline_pre_move_action(timeline, unit.id)
		var pre_text := _action_symbol_text(pre_action, unit)
		var pre_tooltip := _describe_action(pre_action) if pre_action != null else "No action queued"
		var pre_col := row_color if pre_col_active else Color(row_color.r * 0.45, row_color.g * 0.45, row_color.b * 0.45)
		var pre_bg := bg_color.blend(BG_ACTIVE) if pre_col_active else bg_color
		var pre_lbl := _make_table_cell(_timeline_box, pre_text, pre_tooltip, pre_col, false, pre_bg)
		if pre_action == null:
			pre_lbl.modulate = Color(1, 1, 1, 0.25 if not pre_col_active else 0.4)
		else:
			var combined_idx := timeline.entries.find(pre_action)
			if combined_idx >= 0 and combined_idx < statuses.size():
				var reason := statuses[combined_idx]
				if reason != "":
					pre_lbl.add_theme_color_override("font_color", COLOR_FAIL)
					if first_warning.is_empty():
						first_warning.append("Action %d (%s): %s" % [combined_idx + 1, unit.definition.display_name, _reason_text(reason)])

		var action_entry: TimelineAction = _timeline_action_slot(timeline, unit.id)
		var action_text := _action_symbol_text(action_entry, unit)
		var action_tooltip := _describe_action(action_entry) if action_entry != null else "No action queued"
		var action_col := row_color if action_col_active else Color(row_color.r * 0.45, row_color.g * 0.45, row_color.b * 0.45)
		var action_bg := bg_color.blend(BG_ACTIVE) if action_col_active else bg_color
		var action_lbl := _make_table_cell(_timeline_box, action_text, action_tooltip, action_col, false, action_bg)
		if action_entry == null:
			action_lbl.modulate = Color(1, 1, 1, 0.25 if not action_col_active else 0.4)
		else:
			var combined_idx := timeline.entries.find(action_entry)
			if combined_idx >= 0 and combined_idx < statuses.size():
				var reason := statuses[combined_idx]
				if reason != "":
					action_lbl.add_theme_color_override("font_color", COLOR_FAIL)
					if first_warning.is_empty():
						first_warning.append("Action %d (%s): %s" % [combined_idx + 1, unit.definition.display_name, _reason_text(reason)])

		var u_id = unit.id
		var row_labels := [name_lbl, class_lbl, stats_lbl, pre_lbl, action_lbl]
		var base_colors := [bg_color, bg_color, bg_color, pre_bg, action_bg]
		var hover_colors: Array[Color] = []
		for c in base_colors:
			hover_colors.append(c.lightened(0.2) if c != Color.TRANSPARENT else Color(1, 1, 1, 0.1))
		
		var on_enter := func(id: int, labels: Array):
			_timeline_hover_id = id
			for i in labels.size():
				var l: Label = labels[i]
				if l.has_theme_stylebox_override("normal"):
					var sb: StyleBoxFlat = l.get_theme_stylebox("normal")
					sb.bg_color = hover_colors[i]
			queue_redraw()
		var on_exit := func(id: int, labels: Array):
			if _timeline_hover_id == id:
				_timeline_hover_id = -1
				queue_redraw()
			for i in labels.size():
				var l: Label = labels[i]
				if l.has_theme_stylebox_override("normal"):
					var sb: StyleBoxFlat = l.get_theme_stylebox("normal")
					sb.bg_color = base_colors[i]
		var on_gui := func(ev: InputEvent, id: int):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if _director != null:
					_director.select_unit(id)

		for lbl in row_labels:
			lbl.mouse_entered.connect(on_enter.bind(u_id, row_labels))
			lbl.mouse_exited.connect(on_exit.bind(u_id, row_labels))
			lbl.gui_input.connect(on_gui.bind(u_id))

	_set_warnings(first_warning)
	_recompute_intent_units()
	_update_intent_label()
	_refresh_info()
	if CombatDirector.is_planning_phase(_phase):
		_undo_btn.disabled = not _unit_has_undoable_actions(_selected_id)
	_rebuild_ability_buttons()

## Rebuild the timeline grid using cached last-known timeline/statuses.
## Called on phase changes so column highlights update without a new timeline event.
func _refresh_timeline_grid() -> void:
	if _timeline_box == null or _director == null:
		return
	# Re-emit a fake timeline_changed using the current phase's plan with blank statuses.
	var plan_to_use := _director.get_player_plan()
	var statuses := PackedStringArray()
	for _i in plan_to_use.entries.size():
		statuses.append("")
	_on_timeline_changed(plan_to_use, statuses)

## Show at most one plan problem in a dedicated strip (kept out of the plan list).
func _set_warnings(warnings: Array[String]) -> void:
	if _warn_label == null:
		return
	if warnings.is_empty():
		_warn_label.text = ""
		_warn_label.visible = false
		return
	_warn_label.visible = true
	_warn_label.text = "[color=#%s]! %s[/color]" % [HEX_DEATH, warnings[0]]

func _on_player_ready_changed(player_id: int, is_ready: bool) -> void:
	if player_id == NetworkManager.local_player_id or not NetworkManager.is_multiplayer:
		_is_local_ready = is_ready
		if is_ready:
			_execute_btn.text = "Cancel Ready"
			_execute_btn.modulate = Color(0.4, 0.9, 0.4)
		else:
			_execute_btn.text = "Ready to Execute"
			_execute_btn.modulate = Color.WHITE
	_update_players_panel()

func _on_phase_changed(phase: int) -> void:
	_is_local_ready = false
	_phase = phase
	_clear_hover_attack_preview()
	var _phase_names := {
		CombatDirector.Phase.PLANNING: "PLANNING",
		CombatDirector.Phase.EXECUTING: "EXECUTING...",
		CombatDirector.Phase.ENEMY_TURN: "EXECUTING ENEMY TURN...",
		CombatDirector.Phase.VICTORY: "VICTORY",
	}
	_phase_label.text = _phase_names.get(phase, CombatDirector.Phase.keys()[phase])
	if phase == CombatDirector.Phase.ENEMY_TURN:
		_phase_label.add_theme_color_override("font_color", Color.RED)
	else:
		_phase_label.add_theme_color_override("font_color", Color.html(HEX_PHASE))
	var planning := CombatDirector.is_planning_phase(phase)
	if planning:
		_aiming = false
		_execute_btn.text = "Ready to Execute"
		_execute_btn.modulate = Color.WHITE
	else:
		if _board != null:
			_rebuild_visual(_board)
		_execute_btn.text = "Executing..."
		_execute_btn.modulate = Color.WHITE
	_execute_btn.disabled = not planning
	_undo_btn.visible = planning
	_clear_btn.visible = planning
	_undo_btn.disabled = not planning or not _unit_has_undoable_actions(_selected_id)
	_clear_btn.disabled = not planning
	if phase == CombatDirector.Phase.VICTORY:
		_show_banner("Victory!")
		_append_log("[color=#%s]=== Victory ===[/color]" % HEX_TURN)
		_sfx.play("win")
	elif phase == CombatDirector.Phase.DEFEAT:
		_show_banner("Defeat")
		_append_log("[color=#%s]=== Defeat ===[/color]" % HEX_DEATH)
		_sfx.play("lose")
	else:
		_hide_banner()
	_update_players_panel()
	# Rebuild the timeline grid so phase column highlights update immediately.
	_refresh_timeline_grid()
	queue_redraw()

func _find_action(events: Array[SimEvent], unit_id: int) -> TimelineAction:
	var last_act: TimelineAction = null
	for e in events:
		if e.type == GameEnums.SimEventType.UNIT_MOVED and e.data.get("actor", -1) == unit_id:
			last_act = TimelineAction.make_move(unit_id, e.data["to"], -1, [], GameEnums.MoveTiming.PRE_ACTION)
		elif e.type == GameEnums.SimEventType.ABILITY_USED and e.data.get("actor", -1) == unit_id:
			var act := TimelineAction.new()
			act.type = GameEnums.ActionType.ABILITY
			act.actor_id = unit_id
			act.target_coord = e.data["target_coord"]
			last_act = act
	return last_act

func _on_sim_event(event: SimEvent) -> void:
	var d := event.data
	match event.type:
		GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
			_phase_label.text = "EXECUTING ENEMY PHASE..."
			_phase_label.add_theme_color_override("font_color", Color.RED)
		GameEnums.SimEventType.UNIT_MOVED:
			var actor_id: int = d.get("actor", -1)
			if _should_animate_move(actor_id, d):
				var path: Array = d.get("path", [])
				if path.is_empty() and d.has("to"):
					path = [d["to"]]
				_set_waypoints(actor_id, path)
				_set_facing_from_path(actor_id, d.get("from", Vector2i.ZERO), path)
				if d.get("is_dash", false):
					var dash_step: float = float(d.get("dash_step_time", 0.08))
					if _visual.has(actor_id):
						_visual[actor_id]["move_speed"] = CELL / dash_step
				elif _visual.has(actor_id):
					_visual[actor_id].erase("move_speed")
		GameEnums.SimEventType.UNIT_PUSHED:
			# Count this push so the signal fires after ALL tweens complete.
			_active_push_tweens += 1
			call_deferred("_handle_deferred_push", d)
		GameEnums.SimEventType.UNIT_FACED:
			_set_facing(d.get("unit", -1), d.get("facing", GameEnums.Facing.SOUTH))
		GameEnums.SimEventType.UNIT_DIED:
			var u_id: int = d.get("unit", -1)
			if _visual.has(u_id):
				_visual.erase(u_id)
			queue_redraw()
		GameEnums.SimEventType.ABILITY_USED:
			if not d.get("is_dash", false):
				_play_attack_lunge(d.get("actor", -1), _ability_attack_anim_dir(d.get("actor", -1), d))
		GameEnums.SimEventType.COUNTER_ATTACK:
			_play_attack_lunge(d.get("actor", -1), _counter_attack_anim_dir(d.get("actor", -1), d))
		GameEnums.SimEventType.UNIT_DAMAGED:
			var u_id: int = d.get("unit", -1)
			_set_hp(u_id, d.get("hp", 0))
			if d.has("armor"):
				var unit = _board.get_unit_by_id(u_id) if _board != null else null
				if unit != null:
					unit.armor = d.get("armor")
				if _visual.has(u_id):
					_visual[u_id]["armor"] = d.get("armor")
			if _visual.has(u_id):
				_visual[u_id]["shake"] = 0.4
				_hit_markers.append([_visual[u_id]["pos"], 0.4])
			_spawn_floating_text(u_id, d.get("amount", 0), d.get("damage_type", &"physical"))
		GameEnums.SimEventType.UNIT_ARMORED:
			var u_id: int = d.get("unit", -1)
			if d.has("armor"):
				var unit = _board.get_unit_by_id(u_id) if _board != null else null
				if unit != null:
					unit.armor = d.get("armor")
				if _visual.has(u_id):
					_visual[u_id]["armor"] = d.get("armor")
					_visual[u_id]["shake"] = 0.1
				_sfx.play("invalid")
		GameEnums.SimEventType.UNIT_HEALED:
			var u_id: int = d.get("unit", -1)
			_set_hp(u_id, d.get("hp", 0))
			_spawn_floating_text(u_id, d.get("amount", 0), &"heal")
		_:
			pass
	var line := _log_line(event)
	if line != "":
		_append_log(line)

func _should_animate_move(unit_id: int, event_data: Dictionary = {}) -> bool:
	if _planning_anim_units.has(unit_id):
		return true
	if event_data.get("is_dash", false):
		return true
	if _phase == CombatDirector.Phase.ENEMY_TURN:
		return true
		
	# If full autobattler is playing, we want to watch the units actually walk
	# since we skip the manual planning preview phase.
	if _autobattler_hook != null and _autobattler_hook._active and _autobattler_hook._auto_commit:
		return true
		
	var unit := _board.get_unit_by_id(unit_id)
	if unit != null and not unit.is_enemy():
		return false
	return true

# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if _board == null:
		return
	_draw_board_backdrop()
	_draw_tiles()
	
	var t := Time.get_ticks_msec() / 1000.0
	_draw_clouds(t)
	_draw_particles(t)
	
	_draw_danger_area()
	var show_planning := CombatDirector.is_planning_phase(_phase)
	var show_preview := show_planning
	if show_planning:
		_draw_move_ghosts()
		_draw_hover_ranges()
		if _skill_takes_priority_over_basic_move() and not _dragging:
			_draw_interaction_overlays()
		if _dragging:
			_draw_drag_path()
	if show_preview:
		_draw_ghosts()
		_draw_preview_arrows()
		_draw_ability_intents()
	_draw_hover()
	_draw_units()
	
	for hm in _hit_markers:
		_draw_x(hm[0], COLOR_DEATH)
		
	if _hover_action_icon != "":
		_draw_centered(get_local_mouse_position() + Vector2(10, 10), _hover_action_icon, Color.WHITE, 28)

## Faint movement (blue) and threat (red) tiles for the hovered unit.
func _draw_hover_ranges() -> void:
	for coord in _hover_threat_tiles:
		_draw_tile_tint(coord, COLOR_HOVER_THREAT)
	for coord in _hover_move_tiles:
		_draw_tile_tint(coord, COLOR_HOVER_MOVE)

func _grid_pixel_size() -> Vector2:
	var size := _board.grid_size if _board != null else Vector2i(9, 7)
	return Vector2(size.x * CELL, size.y * CELL)

func _draw_board_backdrop() -> void:
	var frame := Rect2(ORIGIN - Vector2(6, 6), _grid_pixel_size() + Vector2(12, 12))
	# Subtle outer board drop shadow
	draw_rect(frame.grow(4.0), Color(0.0, 0.0, 0.0, 0.35), false, 4.0)
	draw_rect(frame, COLOR_BOARD_BG, true)
	draw_rect(frame, COLOR_BOARD_FRAME, false, 2.0)

func _draw_tile_tint(coord: Vector2i, tint: Color) -> void:
	var rect := Rect2(_to_pixel(coord), Vector2(CELL, CELL)).grow(-2.0)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.4), true)

func _draw_tiles() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	
	for y in range(_board.grid_size.y):
		for x in range(_board.grid_size.x):
			var coord := Vector2i(x, y)
			var tile := _board.get_tile(coord)
			var rect := Rect2(_to_pixel(coord), Vector2(CELL, CELL))
			
			var is_wall = GridSystem.is_wall(_board, coord)
			var is_hazard = GridSystem.is_hazard(_board, coord)
			var is_pit = is_wall and is_hazard
			
			var tile_id = &""
			if tile != null and tile.definition != null:
				tile_id = tile.definition.id

			var is_water = false
			var is_forest = false
			
			# 1. Base terrain (always render Plains base unless it's a Pit, Wall, or Water)
			if is_pit:
				_draw_pit_tile(rect, t)
				continue
			elif is_wall:
				_draw_stone_wall(rect)
				continue
			
			if tile != null and tile.definition != null:
				if tile.definition.id == &"water":
					is_water = true
				elif tile.definition.id == &"tall_grass" or tile.definition.id == &"forest":
					is_forest = true
					
			if is_water:
				_draw_water_base(rect, t)
			else:
				_draw_plains_base(rect, coord, t, is_forest)
				
			# 2. Draw Hazards/Overlays on top of the base terrain
			if is_hazard and not is_pit and tile_id != &"fire" and tile_id != &"smoke":
				_draw_spike_tile(rect, t)
				
			match tile.definition.id if tile != null and tile.definition != null else &"":
				&"fire":
					_draw_fire(rect, t)
				&"oil":
					_draw_oil(rect, t)
				&"steam":
					_draw_steam(rect, t, false)
				&"smoke":
					_draw_steam(rect, t, true)
				&"castle":
					_draw_castle(rect)
				&"cracked":
					_draw_cracked(rect)
				&"frozen":
					_draw_frozen(rect, t)

func _draw_clouds(t: float) -> void:
	# Draw massive, highly transparent shapes slowly drifting diagonally
	var board_size := _grid_pixel_size()
	var offset := Vector2(fposmod(t * -15.0, board_size.x + 200), fposmod(t * -10.0, board_size.y + 200))
	
	# Cloud 1 (draw as one polygon so it doesn't overlap/multiply)
	var c1 := ORIGIN + offset - Vector2(100, 100)
	var pts1 := PackedVector2Array()
	for i in range(16):
		var ang = i * TAU / 16.0
		# Squashed irregular oval
		var r = 80.0 + sin(ang * 2.0) * 15.0 + cos(ang * 3.0) * 10.0
		pts1.append(c1 + Vector2(cos(ang) * 1.5, sin(ang)) * r)
	draw_colored_polygon(pts1, Color(0, 0, 0, 0.08))
	
	# Cloud 2
	var offset2 := Vector2(fposmod(t * -12.0 + 300, board_size.x + 400), fposmod(t * -8.0 + 200, board_size.y + 400))
	var c2 := ORIGIN + offset2 - Vector2(200, 200)
	var pts2 := PackedVector2Array()
	for i in range(16):
		var ang = i * TAU / 16.0
		var r = 100.0 + cos(ang * 2.5) * 20.0
		pts2.append(c2 + Vector2(cos(ang) * 1.6, sin(ang) * 1.1) * r)
	draw_colored_polygon(pts2, Color(0, 0, 0, 0.06))

func _draw_particles(t: float) -> void:
	var board_size := _grid_pixel_size()
	for i in range(25):
		var px := fposmod(float((i * 137) % int(board_size.x)) + sin(t * 0.5 + i) * 20.0, board_size.x)
		var py := fposmod(float((i * 293) % int(board_size.y)) - t * (10.0 + (i % 15)), board_size.y)
		var p_pos := ORIGIN + Vector2(px, py)
		
		var alpha := (sin(t * 2.0 + i) + 1.0) * 0.35
		draw_rect(Rect2(p_pos, Vector2(2, 2)), Color(0.9, 0.9, 0.7, alpha), true)

func _draw_plains_base(rect: Rect2, coord: Vector2i, t: float, is_tall_grass: bool) -> void:
	draw_rect(rect, Color(0.28, 0.52, 0.32), true)
	
	# Dense, tall swaying grass for tall_grass, sparse for plains
	var tuft_count = 14 if is_tall_grass else (1 + (coord.x * 7 + coord.y * 3) % 3)
	var max_height = 16.0 if is_tall_grass else 6.0
	
	for i in range(tuft_count):
		var ox = float((coord.x * 13 + coord.y * 7 + i * 11) % int(CELL))
		var oy = float((coord.x * 3 + coord.y * 17 + i * 5) % int(CELL))
		var base_pos = rect.position + Vector2(ox, oy)
		
		# Global wind phase based on world X/Y coordinates
		var global_x = coord.x * CELL + ox
		var global_y = coord.y * CELL + oy
		var wind_phase = global_x * 0.001 + global_y * 0.0005
		
		# All grass sways the same direction but with slight phase offset
		var sway = sin(t * 1.44 + wind_phase) * (6.0 if is_tall_grass else 3.0)
		var h = float((i * 7) % int(max_height)) + (max_height / 2.0)
		
		var tip_pos = base_pos + Vector2(sway, -h)
		# Draw dark shadows for the grass
		draw_line(base_pos, tip_pos, Color(0.18, 0.38, 0.20, 0.8), 2.0)
		# Draw subtle bright highlight directly beside the shadow
		var hl_pos = base_pos + Vector2(1, 0)
		var hl_tip = tip_pos + Vector2(1, 0)
		draw_line(hl_pos, hl_tip, Color(0.35, 0.65, 0.40, 0.6), 1.0)

func _draw_water_base(rect: Rect2, t: float) -> void:
	# Keep water simple and highly readable like the original prototype
	draw_rect(rect, Color(0.35, 0.68, 0.88), true)
	
	# Very subtle simple horizontal highlight lines
	var c = rect.get_center()
	var glint_x = sin(t * 1.5 + rect.position.y * 0.1) * 8.0
	draw_line(c + Vector2(-6 + glint_x, -4), c + Vector2(4 + glint_x, -4), Color(0.5, 0.8, 0.95, 0.5), 2.0)
	draw_line(c + Vector2(-2 - glint_x, 6), c + Vector2(8 - glint_x, 6), Color(0.5, 0.8, 0.95, 0.5), 2.0)

func _draw_stone_wall(rect: Rect2) -> void:
	draw_rect(rect, Color(0.32, 0.34, 0.40), true)
	
	var brick_color = Color(0.25, 0.27, 0.32)
	var highlight = Color(0.4, 0.42, 0.48, 0.6)
	var shadow = Color(0.15, 0.17, 0.22, 0.8)
	
	# Procedural brick lines
	var rows = 4
	var bh = CELL / rows
	for r in range(rows):
		var y = rect.position.y + r * bh
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), brick_color, 2.0)
		draw_line(Vector2(rect.position.x, y + 2), Vector2(rect.end.x, y + 2), highlight, 1.0)
		draw_line(Vector2(rect.position.x, y + bh - 1), Vector2(rect.end.x, y + bh - 1), shadow, 1.0)
		
		# Vertical staggering
		var cols = 2
		var bw = CELL / cols
		var offset = (bw / 2) if (r % 2 != 0) else 0
		for c in range(cols + 1):
			var x = rect.position.x + c * bw + offset
			if x <= rect.end.x:
				draw_line(Vector2(x, y), Vector2(x, y + bh), brick_color, 2.0)
				draw_line(Vector2(x + 1, y), Vector2(x + 1, y + bh), shadow, 1.0)

func _draw_pit_tile(rect: Rect2, t: float) -> void:
	# A deep void that fades into pure black at the center
	draw_rect(rect, Color(0.06, 0.04, 0.08), true)
	draw_rect(rect.grow(-4.0), Color(0.03, 0.01, 0.04), true)
	draw_rect(rect.grow(-8.0), Color(0.01, 0.0, 0.02), true)
	draw_rect(rect.grow(-12.0), Color(0.0, 0.0, 0.0), true)
	
	# Magical rim pulsing
	var c := rect.get_center()
	for i in range(3):
		var r := 6.0 + i * 4.0 + sin(t * 2.0 + i) * 2.0
		draw_arc(c, r, 0.0, TAU, 12, Color(0.5, 0.1, 0.7, 0.2), 1.0)

func _draw_spike_tile(rect: Rect2, t: float) -> void:
	var c := rect.get_center()
	
	# Draw sharp metallic triangles (spikes)
	var spike_color := Color(0.4, 0.45, 0.5)
	var highlight := Color(0.8, 0.85, 0.9)
	var offsets = [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12), Vector2(0, 0)]
	
	var glint := (sin(t * 4.0) + 1.0) * 0.5
	for off in offsets:
		var pos = c + off
		# Shadow at base
		draw_circle(pos + Vector2(0, 4), 6.0, Color(0.1, 0.15, 0.1, 0.4))
		var pts = PackedVector2Array([
			pos + Vector2(0, -6),
			pos + Vector2(-4, 4),
			pos + Vector2(4, 4)
		])
		draw_colored_polygon(pts, spike_color)
		draw_line(pos + Vector2(0, -6), pos + Vector2(2, 4), highlight * glint, 1.0)

func _draw_fire(rect: Rect2, t: float) -> void:
	var c := rect.get_center()
	
	# Animated flames using bulb shapes (overlapping circles)
	var base_colors = [Color(0.9, 0.2, 0.1, 0.9), Color(0.9, 0.5, 0.1, 0.9), Color(0.9, 0.8, 0.2, 0.9)]
	for i in range(12):
		var ox = sin(t * 2.0 + i * 1.5) * 8.0
		var oy = cos(t * 2.5 + i * 2.1) * 4.0
		var rise = fposmod(t * 7.0 + i * 5.0, 20.0)
		var p = c + Vector2(-10.0 + (i % 5) * 5.0 + ox, 6.0 + oy - rise)
		var size = max(1.0, 6.0 - (rise / 20.0) * 4.0)
		
		draw_circle(p, size, base_colors[i % 3])

func _draw_oil(rect: Rect2, t: float) -> void:
	var c := rect.get_center()
	# Glistening black puddle
	draw_circle(c, 18.0, Color(0.05, 0.05, 0.08, 0.9))
	draw_circle(c + Vector2(8, -6), 12.0, Color(0.05, 0.05, 0.08, 0.9))
	draw_circle(c + Vector2(-10, 6), 10.0, Color(0.05, 0.05, 0.08, 0.9))
	
	# Rainbow/specular sheen
	var spec1 = c + Vector2(sin(t*2.0)*4.0, cos(t*1.5)*2.0)
	draw_arc(spec1, 14.0, PI, PI*1.5, 8, Color(0.4, 0.2, 0.6, 0.4), 2.0)
	var spec2 = c + Vector2(8, -6) + Vector2(cos(t*1.8)*3.0, sin(t*2.2)*3.0)
	draw_arc(spec2, 8.0, 0.0, PI*0.5, 8, Color(0.2, 0.5, 0.4, 0.4), 2.0)

func _draw_steam(rect: Rect2, t: float, is_smoke: bool) -> void:
	var c := rect.get_center()
	# Vents on the ground
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0.2, 0.25, 0.3, 0.7), 2.0)
	draw_line(c + Vector2(-4, -6), c + Vector2(4, -6), Color(0.2, 0.25, 0.3, 0.7), 2.0)
	
	# Rising steam/smoke clouds
	for i in range(5):
		var rise = fposmod(t * 10.0 + i * 8.0, 24.0)
		var drift = sin(t * 2.0 + i) * 6.0
		var p = c + Vector2(drift, 4.0 - rise)
		
		var alpha = 0.6 * (1.0 - (rise / 24.0))
		var base_col = Color(0.15, 0.15, 0.15, alpha + 0.3) if is_smoke else Color(0.8, 0.85, 0.9, alpha)
		var hl_col = Color(0.2, 0.2, 0.2, alpha + 0.3) if is_smoke else Color(0.85, 0.9, 0.95, alpha)
		
		draw_circle(p, 6.0 + rise * 0.2, base_col)
		draw_circle(p + Vector2(4, -4), 4.0 + rise * 0.2, hl_col)

func _draw_castle(rect: Rect2) -> void:
	var c := rect.get_center()
	# Draw a simple grey castle icon
	var stone = Color(0.4, 0.4, 0.45)
	var shadow = Color(0.3, 0.3, 0.35)
	
	# Keep
	draw_rect(Rect2(c.x - 12, c.y - 4, 24, 16), stone)
	# Towers
	draw_rect(Rect2(c.x - 16, c.y - 12, 8, 24), shadow)
	draw_rect(Rect2(c.x + 8, c.y - 12, 8, 24), shadow)
	
	# Battlements
	for ox in [-16, -10, 8, 14]:
		draw_rect(Rect2(c.x + ox, c.y - 16, 4, 4), shadow)
	for ox in [-10, 0, 8]:
		draw_rect(Rect2(c.x + ox, c.y - 8, 4, 4), stone)
		
	# Gate
	draw_rect(Rect2(c.x - 4, c.y + 4, 8, 8), Color(0.1, 0.1, 0.15))

func _draw_cracked(rect: Rect2) -> void:
	var c := rect.get_center()
	
	# Dirt and highlight polygons directly hugging the crack for depth
	var crack_color := Color(0.15, 0.05, 0.02)
	var dirt_shadow := Color(0.2, 0.35, 0.2, 0.8) # Darker grass
	var dirt_highlight := Color(0.35, 0.6, 0.35, 0.8) # Lighter grass
	var raw_dirt := Color(0.35, 0.2, 0.1, 0.9) # Actual exposed dirt
	
	# Draw actual exposed dirt underneath the crack
	var pts0 := PackedVector2Array([
		c + Vector2(-14, -10), c + Vector2(-4, -5), c + Vector2(4, 5), c + Vector2(12, 13),
		c + Vector2(11, 17), c + Vector2(1, 9), c + Vector2(-7, 1), c + Vector2(-16, -7)
	])
	draw_colored_polygon(pts0, raw_dirt)
	
	var pts1 := PackedVector2Array([
		c + Vector2(-13, -9), c + Vector2(-4, -4), c + Vector2(3, 4), c + Vector2(11, 11),
		c + Vector2(10, 15), c + Vector2(1, 8), c + Vector2(-6, 0), c + Vector2(-15, -6)
	])
	draw_colored_polygon(pts1, dirt_shadow)
	
	var pts2 := PackedVector2Array([
		c + Vector2(-11, -7), c + Vector2(-3, -1), c + Vector2(2, 7), c + Vector2(9, 13),
		c + Vector2(14, 13), c + Vector2(6, 4), c + Vector2(0, -3), c + Vector2(-7, -10)
	])
	draw_colored_polygon(pts2, dirt_highlight)
	
	# The jagged cracks themselves
	draw_line(c + Vector2(-12, -8), c + Vector2(-4, -2), crack_color, 2.0)
	draw_line(c + Vector2(-4, -2), c + Vector2(2, 6), crack_color, 2.0)
	draw_line(c + Vector2(2, 6), c + Vector2(10, 12), crack_color, 2.0)
	draw_line(c + Vector2(-4, -2), c + Vector2(8, -6), crack_color, 2.0)
	draw_line(c + Vector2(2, 6), c + Vector2(-6, 12), crack_color, 2.0)

func _draw_frozen(rect: Rect2, t: float) -> void:
	# Ice base
	draw_rect(rect, Color(0.6, 0.8, 0.9, 0.7), true)
	# Ice sheen/reflections
	var c := rect.get_center()
	var glint := (sin(t * 3.0) + 1.0) * 0.5
	draw_line(c + Vector2(-10, -10), c + Vector2(-2, -18), Color(1, 1, 1, 0.6 + glint * 0.4), 2.0)
	draw_line(c + Vector2(4, 6), c + Vector2(12, -2), Color(1, 1, 1, 0.5 + glint * 0.3), 1.0)

func _tile_color(coord: Vector2i) -> Color:
	if GridSystem.is_hazard(_board, coord):
		return COLOR_PIT if GridSystem.is_wall(_board, coord) else COLOR_SPIKES
	if GridSystem.is_wall(_board, coord):
		return COLOR_WALL
	return COLOR_TILE

func _draw_reachable() -> void:
	if _selected_id < 0 or _director == null or _director.base_board == null:
		return
	var proj := _proj()
	var unit := proj.get_unit_by_id(_selected_id)
	if unit == null or not unit.is_alive():
		return
	var points := unit.definition.move_points
	for y in range(proj.grid_size.y):
		for x in range(proj.grid_size.x):
			var coord := Vector2i(x, y)
			if coord == unit.position:
				continue
			if not MovementSystem.find_path(proj, unit.position, coord, points).is_empty():
				_draw_tile_tint(coord, COLOR_REACH)

func _draw_ability_range() -> void:
	# Aim highlights use the actor's projected tile and enemy preview-final tiles.
	var proj := _proj()
	var actor := proj.get_unit_by_id(_selected_id)
	if actor == null or not actor.is_alive():
		return
	var rng := _ability_range(actor)
	if rng < 0:
		return
	var ability := _selected_ability_data(actor)
	if _ability_has_dash(ability):
		for coord in _dash_threat_tiles(_proj_origin(actor), _dash_effect_amount(ability)):
			_draw_tile_tint(coord, COLOR_TARGET)
		return
	var self_aoe := _self_aoe_threat_tiles(actor, ability, _proj_origin(actor))
	if not self_aoe.is_empty():
		for coord in self_aoe:
			_draw_tile_tint(coord, COLOR_TARGET)
		return
	for unit in (_aim_enemy_board() if _aiming else proj).units:
		if unit.is_alive() and unit.id != actor.id and GridSystem.manhattan(actor.position, unit.position) <= rng:
			var center := _coord_center(unit.position)
			draw_arc(center, UNIT_RADIUS + 7.0, 0.0, TAU, 40, COLOR_TARGET, 2.5)
			draw_arc(center, UNIT_RADIUS + 4.0, 0.0, TAU, 40, Color(COLOR_TARGET, 0.35), 1.5)

func _draw_ghosts() -> void:
	if _display_preview_board() == null:
		return
	var plan_to_use = _director.get_player_plan()
	for unit in _board.units:
		if not unit.is_alive():
			continue
		if not _intent_visible(unit):
			continue
		
		# Player dash destination ghost from queued ability
		if not unit.is_enemy() and plan_to_use != null:
			for action in plan_to_use.entries:
				if action.actor_id == unit.id and action.type == GameEnums.ActionType.ABILITY \
				and action.ability != null and _ability_has_dash(action.ability):
					var start_pos: Vector2i = _proj_origin(unit)
					if action.target_coord != start_pos:
						var center := _coord_center(action.target_coord)
						_draw_unit_token(center, _color_from_unit(unit), _accent_from_unit(unit), unit, false, true, 0.35)
						var dash_dir: Vector2i = action.target_coord - start_pos
						var facing_vec := Vector2(dash_dir.x, dash_dir.y).normalized() if dash_dir != Vector2i.ZERO else Vector2(PhysicsSystem.facing_to_vector(unit.facing))
						_draw_facing(center, facing_vec, Color(COLOR_FACING.r, COLOR_FACING.g, COLOR_FACING.b, 0.15))
					break
		
		# Only draw voluntary destination ghosts for enemies when they plan movement
		if unit.is_enemy():
			var route: Array = _display_preview_paths().get(unit.id, [])
			var voluntary_dest: Vector2i = route[route.size() - 1] if route.size() > 0 else unit.position
			if voluntary_dest != unit.position:
				var center := _coord_center(voluntary_dest)
				var ghost_body: Color = _color_from_unit(unit)
				
				# Get the facing of the unit at its destination
				var pv := _display_preview_board().get_unit_by_id(unit.id)
				var facing := pv.facing if pv != null else unit.facing
				
				_draw_unit_token(center, ghost_body, _accent_from_unit(unit), unit,
					false, true, 0.25 if _skill_interaction_active() else 0.1)
				_draw_facing(center, Vector2(PhysicsSystem.facing_to_vector(facing)),
					Color(COLOR_FACING.r, COLOR_FACING.g, COLOR_FACING.b, 0.15))

func _draw_move_ghosts() -> void:
	if _selected_id < 0 or _board == null:
		return
	var unit := _proj_unit(_selected_id)
	if unit == null or not unit.is_alive():
		return
	var ability := _selected_ability_data(unit)
	if not _ability_has_dash(ability):
		return
	if not _board.is_in_bounds(_hover_coord):
		return
	var origin: Vector2i = _proj_origin(unit)
	if not _is_valid_dash_target(origin, _hover_coord, ability.range_tiles):
		return
	var center := _coord_center(_hover_coord)
	var ghost_body: Color = _color_from_unit(unit)
	var dash_dir: Vector2i = _hover_coord - origin
	var facing_vec := Vector2(dash_dir.x, dash_dir.y).normalized() if dash_dir != Vector2i.ZERO else Vector2(PhysicsSystem.facing_to_vector(unit.facing))
	_draw_unit_token(center, ghost_body, _accent_from_unit(unit), unit, false, true, 0.45)
	_draw_facing(center, facing_vec, Color(COLOR_FACING.r, COLOR_FACING.g, COLOR_FACING.b, 0.35))
	var p_col := _get_player_color(unit.controlling_player_id)
	_draw_dashed_route([origin, _hover_coord], Color(p_col.r, p_col.g, p_col.b, 0.85))

func _draw_dashed_route(route: Array, color: Color) -> void:
	if route.size() < 2:
		return
	var dash := 6.0
	var gap := 4.0
	var offset := UNIT_RADIUS + 4.0
	
	# Draw static dashed line segments
	for i in range(route.size() - 1):
		var p1 := _coord_center(route[i])
		var p2 := _coord_center(route[i+1])
		var dir := (p2 - p1).normalized()
		var dist := p1.distance_to(p2)
		
		var start_d := offset if i == 0 else 0.0
		var end_d := dist - offset if i == route.size() - 2 else dist
		
		var d := start_d
		while d < end_d:
			var draw_end := minf(d + dash, end_d)
			draw_line(p1 + dir * d, p1 + dir * draw_end, color, 2.0)
			d += dash + gap

	# Draw flowing arrowheads along the route
	var t := Time.get_ticks_msec() / 1000.0
	var flow_speed := 45.0      # pixels per second
	var wave_spacing := 60.0    # pixels between arrows
	
	# Pre-calculate path segments
	var total_len := 0.0
	var segment_lengths: Array[float] = []
	var segment_dirs: Array[Vector2] = []
	var segment_starts: Array[Vector2] = []
	
	for i in range(route.size() - 1):
		var p1 := _coord_center(route[i])
		var p2 := _coord_center(route[i+1])
		var dir := (p2 - p1).normalized()
		var dist := p1.distance_to(p2)
		
		segment_starts.append(p1)
		segment_dirs.append(dir)
		segment_lengths.append(dist)
		total_len += dist
		
	var path_offset := fmod(t * flow_speed, wave_spacing)
	var arrow_pos := path_offset
	while arrow_pos < total_len - offset:
		if arrow_pos > offset:
			var current_d := arrow_pos
			var seg_idx := 0
			while seg_idx < segment_lengths.size() and current_d > segment_lengths[seg_idx]:
				current_d -= segment_lengths[seg_idx]
				seg_idx += 1
				
			if seg_idx < segment_lengths.size():
				var p1 := segment_starts[seg_idx]
				var dir := segment_dirs[seg_idx]
				var tip := p1 + dir * current_d
				
				# Arrowhead pointing in the direction of travel
				var wing_len := 6.0
				var wing1 := tip - dir.rotated(deg_to_rad(30)) * wing_len
				var wing2 := tip - dir.rotated(deg_to_rad(-30)) * wing_len
				draw_line(tip, wing1, color, 3.0)
				draw_line(tip, wing2, color, 3.0)
				
		arrow_pos += wave_spacing

## Orthogonal move arrows that follow each unit's actual route. Player-phase legs are
## yellow; legs caused during the enemy phase are a distinct colour. Units that will
## die get a clear death marker at their projected end tile.
func _draw_preview_arrows() -> void:
	if _display_preview_board() == null:
		return
	for unit in _board.units:
		if not unit.is_alive():
			continue
		if not _intent_visible(unit):
			continue  # hide unrelated enemy movement to reduce clutter
		var route: Array = _display_preview_paths().get(unit.id, [])
		var split: int = _display_preview_splits().get(unit.id, route.size())
		var player_leg: Array = route.slice(0, split)
		var enemy_leg: Array = route.slice(maxi(split - 1, 0))  # overlap the junction
		
		# Player leg (voluntary movement during planning) is Solid Blue (Dimmed)
		if player_leg.size() >= 2:
			var skip_live_route := false
			if not unit.is_enemy() and unit.id == _selected_id:
				if _dragging and unit.id == _drag_unit_id:
					skip_live_route = true
				elif _skill_takes_priority_over_basic_move() and not _dragging:
					skip_live_route = true
			if not skip_live_route:
				var p_col = _get_player_color(unit.controlling_player_id)
				var dim_col := Color(p_col.r, p_col.g, p_col.b, 0.35)
				_draw_route(player_leg, dim_col, true, true)
			
		# Enemy leg (voluntary movement during enemy turn) is Solid Red (Dimmed)
		if enemy_leg.size() >= 2:
			var dim_col := Color(COLOR_ENEMY_ARROW.r, COLOR_ENEMY_ARROW.g, COLOR_ENEMY_ARROW.b, 0.35)
			_draw_route(enemy_leg, dim_col, split <= 1, true)
			
		# Draw pushes for this unit (Orange double-headed dotted arrow)
		var pushes: Array = _display_preview_pushes().get(unit.id, [])
		for push in pushes:
			_draw_push_arrow(push[0], push[1])
		
		var pv := _display_preview_board().get_unit_by_id(unit.id)
		if pv == null or not pv.is_alive():
			var end_tile: Vector2i = unit.position
			if not pushes.is_empty():
				end_tile = pushes[pushes.size() - 1][1]
			elif route.size() > 0:
				end_tile = route[route.size() - 1]
			_draw_death_marker(_coord_center(end_tile))

func _draw_push_arrow(from: Vector2i, to: Vector2i) -> void:
	var p1 := _coord_center(from)
	var p2 := _coord_center(to)
	var dir := (p2 - p1).normalized()
	var dist := p1.distance_to(p2)
	
	var start_d := UNIT_RADIUS + 4.0
	var end_d := dist - (UNIT_RADIUS + 4.0)
	if start_d >= end_d:
		return
		
	var color := Color(1.0, 0.65, 0.2, 0.95)
	
	# Draw thick dotted line
	var d := start_d
	var dot_spacing := 8.0
	var dot_radius := 2.5
	while d < end_d:
		draw_circle(p1 + dir * d, dot_radius, color)
		d += dot_spacing
		
	# Draw double arrowhead pointing in the direction of the shove
	var tip := p1 + dir * end_d
	var perp := Vector2(-dir.y, dir.x) * 6.0
	
	var tip1 := tip
	draw_line(tip1, tip1 - dir * 10.0 + perp, color, 3.0)
	draw_line(tip1, tip1 - dir * 10.0 - perp, color, 3.0)
	
	var tip2 := tip - dir * 8.0
	draw_line(tip2, tip2 - dir * 10.0 + perp, color, 3.0)
	draw_line(tip2, tip2 - dir * 10.0 - perp, color, 3.0)

func _draw_ability_intents() -> void:
	var plan_to_use = _director.get_player_plan()
	if plan_to_use != null:
		for action in plan_to_use.entries:
			if action.type == GameEnums.ActionType.ABILITY:
				var actor := _board.get_unit_by_id(action.actor_id)
				if actor != null:
					var start_pos := actor.position
					for act in plan_to_use.entries:
						if act.actor_id == action.actor_id and act.type == GameEnums.ActionType.MOVE:
							start_pos = act.target_coord
							break
					var p_col = _get_player_color(actor.controlling_player_id)
					var arr_col = Color(p_col.r, p_col.g, p_col.b, 0.95)
					_draw_dashed_route([start_pos, action.target_coord], arr_col)
						
	# Draw enemy ability intent lines
	var intent_list := _display_intent_list()
	var preview_board := _display_preview_board()
	for intent in intent_list:
		var enemy := _board.get_unit_by_id(intent.enemy_id)
		if enemy == null or not enemy.is_alive():
			continue
		if not _intent_visible(enemy):
			continue
			
		var pv := preview_board.get_unit_by_id(enemy.id) if preview_board != null else null
		var enemy_pos := enemy.position
		if pv != null:
			enemy_pos = pv.position
		
		for action in intent.actions:
			if action.type == GameEnums.ActionType.ABILITY:
				_draw_dashed_route([enemy_pos, action.target_coord], COLOR_ENEMY_ARROW)

func _draw_drag_path() -> void:
	var drag_unit := _board.get_unit_by_id(_drag_unit_id) if _drag_unit_id >= 0 else null
	if drag_unit != null and _should_use_dash_on_input(_selected_ability_data(drag_unit)):
		var origin := _proj_origin(drag_unit)
		var dash_ability := _selected_ability_data(drag_unit)
		if _ability_has_dash(dash_ability) and _is_valid_dash_target(origin, _hover_coord, dash_ability.range_tiles):
			var p_col := _get_player_color(drag_unit.controlling_player_id)
			_draw_dashed_route([origin, _hover_coord], Color(p_col.r, p_col.g, p_col.b, 0.95))
		return
	if _drag_route.size() >= 2:
		var hovered_unit := _board.get_unit_at(_hover_coord) if _board != null and _board.is_in_bounds(_hover_coord) else null
		if hovered_unit != null and hovered_unit.id != _drag_unit_id:
			var idx := _drag_route.find(_drag_sim_actor_pos)
			var move_route := _drag_route.slice(0, idx + 1) if idx >= 0 else _drag_route.slice(0, _drag_route.size() - 1)
			if move_route.size() >= 2:
				_draw_route(move_route, COLOR_DRAGPATH, true, true)
			
			var p_col = _get_player_color(drag_unit.controlling_player_id) if drag_unit != null else COLOR_PLAYER
			var arr_col = Color(p_col.r, p_col.g, p_col.b, 0.95)
			_draw_dashed_route([_drag_sim_actor_pos, _hover_coord], arr_col)
		else:
			_draw_route(_drag_route, COLOR_DRAGPATH, true, true)

## Bright movement + attack lines for the selected unit (drag uses _draw_drag_path instead).
func _draw_interaction_overlays() -> void:
	if _selected_id < 0 or _board == null:
		return
	var actor := _proj_unit(_selected_id)
	if actor == null:
		return
	var route: Array = _display_preview_paths().get(_selected_id, [])
	if route.size() >= 2:
		var p_col := _get_player_color(actor.controlling_player_id)
		_draw_route(route, Color(p_col.r, p_col.g, p_col.b, 0.95), true, true)
	var target_id := _hover_attack_target_id(actor)
	if target_id >= 0:
		var origin := _proj_origin(actor)
		var target_coord := _hover_coord
		var target_unit := _preview.get_unit_by_id(target_id) if _preview != null else null
		if target_unit != null:
			target_coord = target_unit.position
		if origin != target_coord:
			var p_col := _get_player_color(actor.controlling_player_id)
			_draw_dashed_route([origin, target_coord], Color(p_col.r, p_col.g, p_col.b, 0.95))

func _draw_hover() -> void:
	if not _board.is_in_bounds(_hover_coord):
		return
	var rect := Rect2(_to_pixel(_hover_coord), Vector2(CELL, CELL)).grow(-2.0)
	draw_rect(rect, Color(COLOR_HOVER, 0.12), true)
	draw_rect(rect, COLOR_HOVER, false, 2.0)



func _draw_units() -> void:
	var drag_visual_id = -1
	for id in _visual:
		var v: Dictionary = _visual[id]
		if not v["alive"]:
			continue
		var is_drag_token: bool = _dragging and id == _drag_unit_id
		if is_drag_token:
			drag_visual_id = id
			continue
		_draw_single_unit(id, v, false)
		
	if drag_visual_id != -1:
		_draw_single_unit(drag_visual_id, _visual[drag_visual_id], true)

func _draw_single_unit(id: int, v: Dictionary, is_drag_token: bool) -> void:
	var center: Vector2 = _drag_pos if is_drag_token else v["pos"] + v.get("shake_offset", Vector2.ZERO)
	var body: Color = v["body"]
	var accent: Color = v["accent"]
	var selected: bool = int(id) == _selected_id and (CombatDirector.is_planning_phase(_phase))
	if selected:
		draw_arc(center, UNIT_RADIUS + 8.0, 0.0, TAU, 48, COLOR_SELECT_GLOW, 5.0)
		draw_arc(center, UNIT_RADIUS + 5.0, 0.0, TAU, 40, COLOR_SELECT, 3.0)
		
	if int(id) == _timeline_hover_id:
		draw_arc(center, UNIT_RADIUS + 12.0, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 7.0)
	
	if v["is_enemy"] and _intent_units.has(id):
		draw_arc(center, UNIT_RADIUS + 8.0, 0.0, TAU, 48, Color(COLOR_DEATH, 0.25), 5.0)
		draw_arc(center, UNIT_RADIUS + 5.0, 0.0, TAU, 40, Color(COLOR_DEATH, 0.7), 3.0)

	_draw_unit_token(center, body, accent, v["unit"], selected, false, v.get("alpha", 1.0), is_drag_token)
	var facing_vec: Vector2 = v["facing"]
	if is_drag_token and _drag_facing >= 0:
		facing_vec = Vector2(PhysicsSystem.facing_to_vector(_drag_facing as GameEnums.Facing))
	_draw_facing(center, facing_vec, COLOR_FACING)
	var current: int = v["hp"]
	var predicted := current
	var predicted_armor := -1
	if CombatDirector.is_planning_phase(_phase):
		predicted = _get_display_predicted_hp(id, current)
		var current_armor := 0
		var u_ref: UnitState = v.get("unit")
		if u_ref != null:
			var a = u_ref.get("armor")
			current_armor = maxi(0, a if a != null else 0)
		predicted_armor = _get_display_predicted_armor(id, current_armor)
		
	var unit: UnitState = v.get("unit")
	var armor := 0
	var fortitude := 0
	if unit != null and _board != null:
		var u_armor = unit.get("armor")
		armor = maxi(0, u_armor if u_armor != null else 0)
		if predicted_armor < 0:
			predicted_armor = armor
		var coord := _to_coord(center)
		if _board.is_in_bounds(coord):
			var tile = _board.get_tile(coord)
			if tile != null and tile.definition != null:
				var t_fort = tile.definition.get("fortitude")
				fortitude = maxi(0, t_fort if t_fort != null else 0)
				
	_draw_health_bar(center + Vector2(0, UNIT_RADIUS + 6), current, predicted, v["max_hp"], armor, fortitude, predicted_armor, unit.active_statuses if unit != null else [])

func _set(property: StringName, value: Variant) -> bool:
	var s = String(property)
	if s.begins_with("_visual_pos:"):
		var id_str = s.split(":")[1]
		if _visual.has(int(id_str)):
			_visual[int(id_str)]["pos"] = value
			queue_redraw()
		return true
	return false

func _draw_centered(center: Vector2, text: String, color: Color, size: int) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var pos := center - Vector2(width * 0.5, -size * 0.35)
	draw_string(_font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_TEXT_SHADOW)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_unit_token(center: Vector2, body: Color, accent: Color, unit: UnitState, selected: bool, ghost: bool, a: float = 1.0, is_drag_token: bool = false) -> void:
	var is_enemy := unit.is_enemy()
	var abbrev := _abbrev_from_unit(unit)
	
	if is_drag_token:
		if _drag_failed:
			abbrev = "🚫"
		# Otherwise keep the class icon — tile highlights show move vs dash intent.
	
	var max_move := unit.definition.move_points
	var points_left := unit.movement.points_left
	var is_attack_queued := false
	var is_skill_queued := false
	
	if is_drag_token:
		points_left = maxi(0, points_left - maxi(0, _drag_route.size() - 1))
	
	if not ghost and not is_enemy and (CombatDirector.is_planning_phase(_phase)):
		var p_unit = _proj_unit(unit.id)
		if p_unit != null:
			if not is_drag_token:
				points_left = p_unit.movement.points_left
			var plan_to_use = _director.get_player_plan()
			for action in plan_to_use.entries:
				if action.actor_id == unit.id and action.type == GameEnums.ActionType.ABILITY:
					is_skill_queued = true
					if action.ability != null and action.ability.effects.any(func(e): return e.type == GameEnums.EffectType.DAMAGE):
						is_attack_queued = true
	elif not ghost and is_enemy and (CombatDirector.is_planning_phase(_phase)):
		var is_enemy_targeting := false
		var is_enemy_attack := false
		if _intent_visible(unit):
			var intent_list := _display_intent_list()
			for intent in intent_list:
				if intent.enemy_id == unit.id:
					for action in intent.actions:
						if action.type == GameEnums.ActionType.ABILITY:
							var tgt = _board.get_unit_by_id(action.target_unit_id)
							if tgt != null and not tgt.is_enemy():
								is_enemy_targeting = true
								if action.ability != null and action.ability.effects.any(func(e): return e.type == GameEnums.EffectType.DAMAGE):
									is_enemy_attack = true
								break
		if is_enemy_targeting:
			if is_enemy_attack:
				is_attack_queued = true
			else:
				is_skill_queued = true
	
	var body_c := Color(body.r, body.g, body.b, body.a * a)
	var accent_c := Color(accent.r, accent.g, accent.b, accent.a * a)
	var shadow_c := Color(COLOR_TOKEN_SHADOW.r, COLOR_TOKEN_SHADOW.g, COLOR_TOKEN_SHADOW.b, COLOR_TOKEN_SHADOW.a * a)
	var ring_c := Color(COLOR_TOKEN_RING.r, COLOR_TOKEN_RING.g, COLOR_TOKEN_RING.b, COLOR_TOKEN_RING.a * a)
	draw_circle(center + Vector2(0.0, 2.0), UNIT_RADIUS + 1.0, shadow_c)
	draw_circle(center, UNIT_RADIUS, body_c)
	draw_circle(center + Vector2(0.0, UNIT_RADIUS * 0.22), UNIT_RADIUS * 0.72,
		Color(body_c.r * 1.12, body_c.g * 1.12, body_c.b * 1.12, body_c.a * 0.35))
	draw_arc(center, UNIT_RADIUS - 4.0, 0.0, TAU, 48, ring_c, 2.5)
	
	var ring_radius := UNIT_RADIUS + 0.5
	var segments := maxi(1, max_move)
	var gap := 0.2
	var arc_len := (TAU - gap * float(segments)) / float(segments)
	
	# Draw a dark background track for the movement segments to sit in
	draw_arc(center, ring_radius, 0.0, TAU, 48, Color(0.1, 0.1, 0.1, 0.6 * a), 6.0)
	
	for i in range(segments):
		var start_ang := -PI/2 + i * (arc_len + gap)
		var end_ang := start_ang + arc_len
		var segment_color := accent_c
		if i >= points_left:
			segment_color = Color(0.0, 0.0, 0.0, 0.3 * a) # Empty slot is dark
		var flash_color := segment_color
		if is_attack_queued and i < points_left:
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			flash_color = Color(1.0, 0.0, 0.0, blink * a)
		elif is_skill_queued and i < points_left:
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			flash_color = Color(1.0, 1.0, 1.0, blink * a)
		draw_arc(center, ring_radius, start_ang, end_ang, 12, flash_color, 4.0)
	
	if is_enemy and not ghost:
		draw_arc(center, UNIT_RADIUS + 2.0, 0.0, TAU, 40, Color(COLOR_ENEMY, 0.45), 1.5)
	var is_status_symbol := is_drag_token and _drag_failed
	if not is_status_symbol:
		for s in ["🚫", "🏃", "✨", "⚔️", "💚", "🛡️", "🔄"]:
			if abbrev.contains(s):
				is_status_symbol = true
				break
				
	if is_status_symbol:
		var text_size := 18 if abbrev.length() <= 1 else 14
		var text_col := Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, COLOR_TEXT.a * a)
		_draw_centered(center, abbrev, text_col, text_size)
	else:
		var icon_col := Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, COLOR_TEXT.a * a)
		_draw_class_icon(center, unit.definition.id, icon_col)

func _draw_class_icon(c: Vector2, class_id: StringName, color: Color) -> void:
	match class_id:
		&"cleric":
			# Bold solid Greek cross
			draw_rect(Rect2(c.x - 2.5, c.y - 8, 5, 16), color, true)
			draw_rect(Rect2(c.x - 8, c.y - 2.5, 16, 5), color, true)
		&"knight":
			# Chess Knight (Horse head profile silhouette)
			var pts := PackedVector2Array([
				c + Vector2(-5, 8),
				c + Vector2(-5, 0),
				c + Vector2(-1, -7),
				c + Vector2(5, -7),
				c + Vector2(7, -3),
				c + Vector2(2, 0),
				c + Vector2(4, 8)
			])
			draw_polygon(pts, [color])
		&"swordmaster":
			# Thick longsword silhouette pointing up-right
			var start := c + Vector2(-6, 6)
			var tip := c + Vector2(6, -6)
			var dir := (tip - start).normalized()
			var perp := Vector2(-dir.y, dir.x)
			# Thick Blade
			draw_line(start, tip, color, 3.0)
			# Thick Guard
			var guard_pos := start + dir * 4.0
			draw_line(guard_pos - perp * 5.0, guard_pos + perp * 5.0, color, 3.0)
			# Hilt handle
			draw_line(start, guard_pos, color, 2.0)
		&"archer":
			# Bold bow and arrowhead
			# Thick bow arc
			draw_arc(c + Vector2(-3, 0), 7.0, -PI/2, PI/2, 12, color, 2.5)
			# String
			draw_line(c + Vector2(-3, -7), c + Vector2(-3, 7), color, 1.0)
			# Arrow shaft
			draw_line(c + Vector2(-5, 0), c + Vector2(4, 0), color, 2.0)
			# Solid arrowhead
			var arrow_pts := PackedVector2Array([
				c + Vector2(6, 0),
				c + Vector2(1, -4),
				c + Vector2(1, 4)
			])
			draw_polygon(arrow_pts, [color])
		&"warden":
			# Chess Rook (Castle tower/keep silhouette)
			draw_rect(Rect2(c.x - 6, c.y - 4, 12, 12), color, true)
			draw_rect(Rect2(c.x - 7, c.y - 8, 14, 4), color, true)
			# Crenellations
			draw_rect(Rect2(c.x - 7, c.y - 11, 3, 3), color, true)
			draw_rect(Rect2(c.x - 1.5, c.y - 11, 3, 3), color, true)
			draw_rect(Rect2(c.x + 4, c.y - 11, 3, 3), color, true)
		&"mage":
			# Bold 4-pointed spark star
			var pts := PackedVector2Array([
				c + Vector2(0, -9),
				c + Vector2(2.5, -2.5),
				c + Vector2(9, 0),
				c + Vector2(2.5, 2.5),
				c + Vector2(0, 9),
				c + Vector2(-2.5, 2.5),
				c + Vector2(-9, 0),
				c + Vector2(-2.5, -2.5)
			])
			draw_polygon(pts, [color])
		&"charger":
			# Solid charging spearhead / lance
			var pts := PackedVector2Array([
				c + Vector2(8, 0),
				c + Vector2(-2, -5),
				c + Vector2(-2, 5)
			])
			draw_polygon(pts, [color])
			draw_line(c + Vector2(-2, 0), c + Vector2(-8, 0), color, 3.0)
		&"artillery":
			# Solid cannon aiming up-right
			# Cannon barrel
			var pts := PackedVector2Array([
				c + Vector2(-6, 3),
				c + Vector2(5, -8),
				c + Vector2(8, -5),
				c + Vector2(-3, 6)
			])
			draw_polygon(pts, [color])
			# Cannon wheel
			draw_circle(c + Vector2(-4, 3), 3.5, color)
		&"shover":
			# Solid double-headed push arrow
			draw_rect(Rect2(c.x - 7, c.y - 2, 14, 4), color, true)
			var arrow_left := PackedVector2Array([
				c + Vector2(-8, 0),
				c + Vector2(-3, -5),
				c + Vector2(-3, 5)
			])
			draw_polygon(arrow_left, [color])
			var arrow_right := PackedVector2Array([
				c + Vector2(8, 0),
				c + Vector2(3, -5),
				c + Vector2(3, 5)
			])
			draw_polygon(arrow_right, [color])
		&"paladin":
			var pts := PackedVector2Array([
				c + Vector2(-6, -6), c + Vector2(6, -6),
				c + Vector2(6, 2), c + Vector2(0, 8),
				c + Vector2(-6, 2), c + Vector2(-6, -6)
			])
			draw_polyline(pts, color, 2.0)
			draw_rect(Rect2(c.x - 1.5, c.y - 3, 3, 7), color, true)
			draw_rect(Rect2(c.x - 3.5, c.y - 1, 7, 3), color, true)
		&"fighter":
			draw_rect(Rect2(c.x - 5, c.y - 4, 10, 8), color, true)
			draw_rect(Rect2(c.x - 6, c.y - 6, 3, 3), color, true)
			draw_rect(Rect2(c.x - 2, c.y - 7, 3, 4), color, true)
			draw_rect(Rect2(c.x + 2, c.y - 6, 3, 3), color, true)
			draw_rect(Rect2(c.x + 4, c.y - 2, 3, 4), color, true)
		&"cavalier":
			draw_arc(c + Vector2(0, -1), 6.0, PI, TAU, 16, color, 3.0)
			draw_line(c + Vector2(-6, -1), c + Vector2(-6, 6), color, 3.0)
			draw_line(c + Vector2(6, -1), c + Vector2(6, 6), color, 3.0)
			draw_line(c + Vector2(-6, 6), c + Vector2(-3, 6), color, 2.0)
			draw_line(c + Vector2(6, 6), c + Vector2(3, 6), color, 2.0)
		&"assassin":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), color, 2.0)
			draw_line(c + Vector2(-7, -3), c + Vector2(-3, -7), color, 2.0)
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), color, 2.0)
			draw_line(c + Vector2(-7, 3), c + Vector2(-3, 7), color, 2.0)
		&"mercenary":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), color, 2.0)
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), color, 2.0)
			var ax1 := PackedVector2Array([c + Vector2(3, -7), c + Vector2(8, -3), c + Vector2(4, -1)])
			draw_polygon(ax1, [color])
			var ax2 := PackedVector2Array([c + Vector2(-3, -7), c + Vector2(-8, -3), c + Vector2(-4, -1)])
			draw_polygon(ax2, [color])
		&"gryphon":
			draw_line(c + Vector2(-1, 4), c + Vector2(-7, -4), color, 2.0)
			draw_line(c + Vector2(-7, -4), c + Vector2(-3, -2), color, 2.0)
			draw_line(c + Vector2(-3, -2), c + Vector2(-5, 0), color, 2.0)
			draw_line(c + Vector2(-5, 0), c + Vector2(-1, 2), color, 2.0)
			draw_line(c + Vector2(1, 4), c + Vector2(7, -4), color, 2.0)
			draw_line(c + Vector2(7, -4), c + Vector2(3, -2), color, 2.0)
			draw_line(c + Vector2(3, -2), c + Vector2(5, 0), color, 2.0)
			draw_line(c + Vector2(5, 0), c + Vector2(1, 2), color, 2.0)
		&"monk":
			for i in range(8):
				var ang := i * PI / 4.0
				draw_circle(c + Vector2(cos(ang), sin(ang)) * 6.0, 1.5, color)
			draw_line(c + Vector2(0, 6), c + Vector2(0, 9), color, 1.5)
		&"engineer":
			draw_line(c + Vector2(-5, 5), c + Vector2(3, -3), color, 3.0)
			draw_arc(c + Vector2(4, -4), 3.5, PI*0.75, PI*2.25, 8, color, 2.5)
		&"shaman":
			var top_eye := PackedVector2Array([c + Vector2(-7, 0), c + Vector2(0, -5), c + Vector2(7, 0)])
			draw_polyline(top_eye, color, 2.0)
			var bot_eye := PackedVector2Array([c + Vector2(-7, 0), c + Vector2(0, 5), c + Vector2(7, 0)])
			draw_polyline(bot_eye, color, 2.0)
			draw_circle(c, 2.0, color)
		_:
			draw_circle(c, 5.0, color)

func _color_from_unit(unit: UnitState) -> Color:
	if unit.is_enemy():
		var pair: Variant = CLASS_COLORS.get(unit.definition.id, null)
		if pair is Array and pair.size() >= 1:
			return pair[0] as Color
		return COLOR_ENEMY
	else:
		return _get_player_color(unit.controlling_player_id)

func _accent_from_unit(unit: UnitState) -> Color:
	if unit.is_enemy():
		var pair: Variant = CLASS_COLORS.get(unit.definition.id, null)
		if pair is Array and pair.size() >= 2:
			return pair[1] as Color
		return Color(0.95, 0.42, 0.38)
	else:
		return Color(0.56, 0.78, 1.0)

func _abbrev_from_unit(unit: UnitState) -> String:
	match unit.definition.id:
		&"knight": return "K"
		&"archer": return "A"
		&"warden": return "W"
		&"swordmaster": return "S"
		&"mage": return "M"
		&"cleric": return "C"
		&"charger": return "Ch"
		&"artillery": return "Gn"
		&"shover": return "Sh"
	return unit.definition.display_name.substr(0, 1)

## Draw a connected arrow that follows a tile route (cardinal segments). `trim_start`
## pulls the first point off the unit's circle; `with_head` adds an arrowhead whose
## tip is exactly the last polyline vertex (so head and line never separate).
func _draw_route(route: Array, color: Color, trim_start: bool, with_head: bool) -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for tile in route:
		pts.append(_coord_center(tile))
	var last := pts.size() - 1
	if trim_start:
		var d0 := pts[1] - pts[0]
		if d0.length() > 0.0:
			pts[0] += d0.normalized() * UNIT_RADIUS
	var end_dir := (pts[last] - pts[last - 1]).normalized()
	if with_head:
		pts[last] -= end_dir * UNIT_RADIUS
	var glow := COLOR_ARROW_GLOW if color == COLOR_ARROW else COLOR_ENEMY_ARROW_GLOW
	if color != COLOR_ARROW and color != COLOR_ENEMY_ARROW:
		glow = Color(color.r, color.g, color.b, color.a * 0.22)
	draw_polyline(pts, glow, 7.0)
	draw_polyline(pts, color, 3.0)
	if with_head:
		var tip := pts[last]
		var perp := Vector2(-end_dir.y, end_dir.x) * 7.0
		draw_line(tip, tip - end_dir * 12.0 + perp, color, 3.0)
		draw_line(tip, tip - end_dir * 12.0 - perp, color, 3.0)

## A clear "this unit will die" marker (red ringed X) at a tile centre.
func _draw_death_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 2.0), UNIT_RADIUS + 4.0, Color(COLOR_DEATH, 0.25))
	draw_arc(center, UNIT_RADIUS + 4.0, 0.0, TAU, 40, COLOR_DEATH, 3.0)
	var r := UNIT_RADIUS * 0.65
	draw_line(center + Vector2(-r, -r), center + Vector2(r, r), COLOR_DEATH, 4.0)
	draw_line(center + Vector2(-r, r), center + Vector2(r, -r), COLOR_DEATH, 4.0)

## Health bar centred at `top_center`. Green = HP that survives the planned turn;
## the segment about to be lost blinks red; the rest is empty track.
func _draw_health_bar(top_center: Vector2, current: int, predicted: int, max_hp: int, armor: int = 0, fortitude: int = 0, predicted_armor: int = -1, active_statuses: Array = []) -> void:
	if max_hp <= 0:
		return
	if predicted_armor < 0:
		predicted_armor = armor
		
	var origin := top_center - Vector2(BAR_W * 0.5, 0.0)
	var total_max := maxi(max_hp, maxi(current + armor, predicted + predicted_armor))
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), COLOR_HP_BG, true)
	
	var survive := clampi(mini(current, predicted), 0, max_hp)
	var loss := clampi(current - survive, 0, max_hp)
	var heal := clampi(predicted - current, 0, maxi(0, total_max - current))
	
	var survive_armor := clampi(mini(armor, predicted_armor), 0, total_max)
	var armor_loss := clampi(armor - survive_armor, 0, total_max)
	var armor_gain := clampi(predicted_armor - armor, 0, total_max)
	
	var survive_w := BAR_W * (float(survive) / float(total_max))
	var loss_w := BAR_W * (float(loss) / float(total_max))
	var heal_w := BAR_W * (float(heal) / float(total_max))
	
	var survive_armor_w := BAR_W * (float(survive_armor) / float(total_max))
	var armor_loss_w := BAR_W * (float(armor_loss) / float(total_max))
	var armor_gain_w := BAR_W * (float(armor_gain) / float(total_max))
	
	if survive_w > 0.0:
		draw_rect(Rect2(origin, Vector2(survive_w, BAR_H)), COLOR_HP_FILL, true)
	if loss_w > 0.0:
		var blink := 0.35 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
		var col := Color(COLOR_HP_LOSS.r, COLOR_HP_LOSS.g, COLOR_HP_LOSS.b, blink)
		draw_rect(Rect2(origin + Vector2(survive_w, 0.0), Vector2(loss_w, BAR_H)), col, true)
	if heal_w > 0.0:
		var blink := 0.35 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
		var col := Color(COLOR_HP_FILL.r, COLOR_HP_FILL.g, COLOR_HP_FILL.b, blink)
		draw_rect(Rect2(origin + Vector2(survive_w, 0.0), Vector2(heal_w, BAR_H)), col, true)
		
	var hp_end_w: float = survive_w + max(loss_w, heal_w)
	
	if survive_armor_w > 0.0:
		draw_rect(Rect2(origin + Vector2(hp_end_w, 0.0), Vector2(survive_armor_w, BAR_H)), Color(0.9, 0.8, 0.2), true)
	if armor_loss_w > 0.0:
		var blink := 0.35 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
		var col := Color(0.9, 0.8, 0.2, blink)
		draw_rect(Rect2(origin + Vector2(hp_end_w + survive_armor_w, 0.0), Vector2(armor_loss_w, BAR_H)), col, true)
	if armor_gain_w > 0.0:
		var blink := 0.35 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
		var col := Color(0.9, 0.8, 0.2, blink)
		draw_rect(Rect2(origin + Vector2(hp_end_w + survive_armor_w, 0.0), Vector2(armor_gain_w, BAR_H)), col, true)
		
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), COLOR_GRID, false, 1.0)
	
	if armor > 0 or fortitude > 0 or predicted_armor > 0:
		var icon_y := origin.y - 4.0
		var icon_x := origin.x - 4.0
		if armor > 0 or predicted_armor > 0:
			_draw_centered(Vector2(icon_x, icon_y), "🛡️", Color.WHITE, 10)
			icon_x -= 12.0
		if fortitude > 0:
			_draw_centered(Vector2(icon_x, icon_y), "🏰", Color.WHITE, 10)
			icon_x -= 12.0


	if active_statuses.size() > 0:
		var start_x := origin.x + 4.0
		var start_y := origin.y + 16.0
		var count := 0
		
		for status in active_statuses:
			var icon = "✨"
			match status.type:
				GameEnums.StatusType.STAT_BUFF_STR: icon = "💪"
				GameEnums.StatusType.STAT_BUFF_MAG: icon = "🔮"
				GameEnums.StatusType.STAT_BUFF_MP: icon = "👟"
				GameEnums.StatusType.STAT_BUFF_ACC: icon = "🎯"
				GameEnums.StatusType.STAT_DEBUFF_DEF: icon = "💔"
				GameEnums.StatusType.STAT_DEBUFF_ACC: icon = "👁️‍🗨️"
				GameEnums.StatusType.ELECTRIFIED: icon = "⚡"
				GameEnums.StatusType.WEAK_TRAP: icon = "🪤"
				GameEnums.StatusType.BURN: icon = "🔥"
				GameEnums.StatusType.BLEED: icon = "🩸"
				GameEnums.StatusType.POISON: icon = "🧪"
				GameEnums.StatusType.WEAKEN: icon = "📉"
				GameEnums.StatusType.VULNERABLE: icon = "🎯"
				GameEnums.StatusType.STUN: icon = "💫"
				GameEnums.StatusType.ROOT: icon = "🪢"
				GameEnums.StatusType.SILENCE: icon = "🤐"
				GameEnums.StatusType.TAUNT: icon = "🤬"
				GameEnums.StatusType.BLIND: icon = "🕶️"
				GameEnums.StatusType.PACIFY: icon = "🕊️"
				GameEnums.StatusType.FEAR: icon = "😱"
				GameEnums.StatusType.CONFUSION: icon = "😵"
				GameEnums.StatusType.PIERCE: icon = "🗡️"
				GameEnums.StatusType.GHOST: icon = "👻"
				GameEnums.StatusType.TRAMPLE: icon = "🦏"
				GameEnums.StatusType.STEALTH: icon = "🥷"
				GameEnums.StatusType.INTERCEPT: icon = "🛡️"
				GameEnums.StatusType.MARK: icon = "👁️"
				GameEnums.StatusType.STURDY: icon = "🧱"
				GameEnums.StatusType.INVULNERABLE: icon = "⭐"
				GameEnums.StatusType.AIRBORNE: icon = "🦅"
				GameEnums.StatusType.CANTO: icon = "🐎"
				GameEnums.StatusType.POLYMORPH: icon = "🐸"
				
			var pos := Vector2(start_x + (count % 3) * 12.0, start_y + (count / 3) * 12.0)
			_draw_centered(pos, icon, Color.WHITE, 10)
			count += 1

## A small triangle on the unit's rim showing which way it faces (flanking matters).
func _draw_facing(center: Vector2, dir_vec: Vector2, color: Color) -> void:
	if dir_vec == Vector2.ZERO:
		return
	var dir := dir_vec.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := center + dir * (UNIT_RADIUS + 6.0)
	var base := center + dir * (UNIT_RADIUS - 3.0)
	var pts := PackedVector2Array([tip, base + perp * 6.0, base - perp * 6.0])
	draw_colored_polygon(pts, color)

func _draw_x(center: Vector2, color: Color) -> void:
	var r := 15.0
	draw_line(center + Vector2(-r, -r), center + Vector2(r, r), color, 3.0)
	draw_line(center + Vector2(-r, r), center + Vector2(r, -r), color, 3.0)

# --- Visual model -------------------------------------------------------------

func _rebuild_visual(board: BoardState) -> void:
	_visual.clear()
	var start_board := _director.base_board if (_director != null and _director.base_board != null) else board
	var is_full_autobattle := _autobattler_hook != null and _autobattler_hook._active and _autobattler_hook._auto_commit
	var is_planning_or_executing := CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase)
	
	for unit in board.units:
		if not unit.is_alive():
			continue
			
		var pos_coord := unit.position
		var unit_facing := unit.facing
		if is_full_autobattle and is_planning_or_executing and not unit.is_enemy():
			var base_unit := start_board.get_unit_by_id(unit.id)
			if base_unit != null:
				pos_coord = base_unit.position
				unit_facing = base_unit.facing
				
		var center := _coord_center(pos_coord)
		var exhausted := false
		if not unit.is_enemy():
			var p_unit := _proj_unit(unit.id)
			if p_unit != null:
				exhausted = p_unit.turn_action_used
		
		var body := _color_from_unit(unit)
		var accent := _accent_from_unit(unit)
		var alpha := 1.0
		if exhausted:
			body = body.lerp(Color(0.2, 0.2, 0.25), 0.65)
			accent = accent.lerp(Color(0.4, 0.4, 0.45), 0.65)
			alpha = 0.5

		_visual[unit.id] = {
			"is_enemy": unit.is_enemy(),
			"label": _abbrev_from_unit(unit),
			"body": body,
			"accent": accent,
			"alpha": alpha,
			"shake": 0.0,
			"hp": unit.health.current_hp,
			"max_hp": unit.health.max_hp,
			"pos": center,
			"waypoints": [],
			"facing": Vector2(PhysicsSystem.facing_to_vector(unit_facing)),
			"alive": true,
			"unit": unit,
		}

## Rebuild per-unit move routes from a freshly simulated event log so arrows trace
## the actual cardinal path (including bends and enemy reactions).
func _build_preview_paths(events: Array) -> void:
	_build_preview_paths_into(events, _preview_paths, _preview_splits, _preview_pushes)

func _build_preview_paths_into(events: Array, paths: Dictionary, splits: Dictionary, pushes: Dictionary) -> void:
	paths.clear()
	splits.clear()
	pushes.clear()
	var start_board := _director.base_board if _director.base_board != null else _board
	if start_board == null:
		return
		
	var current_positions := {}
	for unit in start_board.units:
		paths[unit.id] = [unit.position]
		splits[unit.id] = 1
		pushes[unit.id] = []
		current_positions[unit.id] = unit.position
		
	var enemy_phase := false
	for event: SimEvent in events:
		var d: Dictionary = event.data
		match event.type:
			GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
				enemy_phase = true
			GameEnums.SimEventType.UNIT_MOVED:
				var id: int = d.get("actor", -1)
				if paths.has(id):
					var path: Array = d.get("path", [])
					for c in path:
						paths[id].append(c)
						if not enemy_phase:
							splits[id] += 1
					if not path.is_empty():
						current_positions[id] = path[path.size() - 1]
			GameEnums.SimEventType.UNIT_PUSHED:
				var pid: int = d.get("unit", -1)
				var to_pos: Vector2i = d.get("to", Vector2i.ZERO)
				if pushes.has(pid):
					var from_pos: Vector2i = current_positions.get(pid, start_board.get_unit_by_id(pid).position if start_board.get_unit_by_id(pid) else to_pos)
					pushes[pid].append([from_pos, to_pos])
					current_positions[pid] = to_pos

func _set_waypoints(unit_id: int, coords: Array) -> void:
	if not _visual.has(unit_id):
		return
	var points: Array = []
	for c in coords:
		points.append(_coord_center(c))
	_visual[unit_id]["waypoints"] = points

func _set_facing_from_path(unit_id: int, from: Vector2i, path: Array) -> void:
	if not _visual.has(unit_id) or path.size() < 1:
		return
	var last: Vector2i = path[path.size() - 1]
	var prev: Vector2i = path[path.size() - 2] if path.size() >= 2 else from
	var delta := last - prev
	if delta != Vector2i.ZERO:
		_visual[unit_id]["facing"] = Vector2(delta)

func _set_facing(unit_id: int, facing: int) -> void:
	if _visual.has(unit_id):
		_visual[unit_id]["facing"] = Vector2(PhysicsSystem.facing_to_vector(facing as GameEnums.Facing))
		queue_redraw()

func _set_hp(unit_id: int, hp: int) -> void:
	if _visual.has(unit_id):
		_visual[unit_id]["hp"] = hp
		queue_redraw()

func _kill(unit_id: int) -> void:
	if _visual.has(unit_id):
		_visual[unit_id]["alive"] = false
		queue_redraw()

## Drain _pending_push_queue and animate each push in sequence.
## Only called when _active_attack_anims == 0 so pushes never overlap attacks.
func _flush_push_queue() -> void:
	var queue := _pending_push_queue.duplicate()
	_pending_push_queue.clear()
	for push_data in queue:
		_handle_deferred_push(push_data)

## Animate a single UNIT_PUSHED event: slide the unit from its current visual
## position to the push destination using the same timing as UNIT_MOVED.
func _handle_deferred_push(push_data: Dictionary) -> void:
	var unit_id: int = push_data.get("unit", -1)
	var to_coord: Vector2i = push_data.get("to", Vector2i.ZERO)
	if not _visual.has(unit_id):
		_active_push_tweens = max(0, _active_push_tweens - 1)
		if _active_push_tweens == 0:
			EventBus.push_animations_complete.emit()
		return
	var from_pos: Vector2 = _visual[unit_id]["pos"]
	var to_pos: Vector2 = _coord_center(to_coord)
	if from_pos.is_equal_approx(to_pos):
		_active_push_tweens = max(0, _active_push_tweens - 1)
		if _active_push_tweens == 0:
			EventBus.push_animations_complete.emit()
		return
	var tw := create_tween()
	tw.tween_method(func(val: Vector2) -> void:
		if _visual.has(unit_id):
			_visual[unit_id]["pos"] = val
			queue_redraw()
	, from_pos, to_pos, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_active_push_tweens = max(0, _active_push_tweens - 1)
	if _active_push_tweens == 0:
		EventBus.push_animations_complete.emit()


# --- Hover / info -------------------------------------------------------------

func _update_hover(local: Vector2) -> void:
	var coord := _to_coord(local)
	if not _board.is_in_bounds(coord):
		coord = Vector2i(-1, -1)
	if coord != _hover_coord:
		_hover_coord = coord
		_recompute_hover_ranges()
		if _selected_id >= 0:
			_refresh_selected_interaction_preview()
			_recompute_intent_units()
		else:
			_update_hover_attack_preview()
			_recompute_intent_units()
		_update_intent_label()
		_refresh_info()
		_update_mouse_cursor()
		queue_redraw()

func _resolve_hover_attack_target(p_unit: UnitState, hover_unit: UnitState) -> int:
	if _skill_interaction_active():
		if hover_unit.id == p_unit.id:
			return p_unit.id if _ability_range(p_unit) == 0 else -1
		if _in_ability_range(p_unit, hover_unit):
			return hover_unit.id
		return -1
	if hover_unit.is_enemy():
		return hover_unit.id
	return -1

func _update_hover_attack_preview() -> void:
	_hover_predicted_hp.clear()
	_hover_predicted_armor.clear()
	if _aiming or _dragging or _director == null or _board == null:
		return
	if not CombatDirector.is_planning_phase(_phase):
		return
	if _selected_id < 0 or not _board.is_in_bounds(_hover_coord):
		return
	var p_unit := _proj_unit(_selected_id)
	if p_unit == null or p_unit.is_enemy() or not p_unit.is_alive():
		return
	if p_unit.active_abilities.is_empty() or _selected_ability < 0:
		return
	if _movement_blocked_by_dash() and not _force_basic_movement:
		var dash_ability := _selected_ability_data(p_unit)
		if dash_ability != null and _is_valid_dash_target(p_unit.position, _hover_coord, dash_ability.range_tiles):
			var dash_res := _director.preview_dash(_selected_id, _hover_coord, _selected_ability)
			var dash_board: BoardState = dash_res.get("temp_board")
			if dash_board != null:
				for temp_u in dash_board.units:
					_hover_predicted_hp[temp_u.id] = temp_u.health.current_hp
					_hover_predicted_armor[temp_u.id] = temp_u.armor
		return
	if _skill_takes_priority_over_basic_move():
		var skill_ability := _selected_ability_data(p_unit)
		if skill_ability != null and _ability_has_dash(skill_ability) \
		and _is_valid_dash_target(p_unit.position, _hover_coord, skill_ability.range_tiles):
			var dash_res := _director.preview_dash(_selected_id, _hover_coord, _selected_ability)
			var dash_board: BoardState = dash_res.get("temp_board")
			if dash_board != null:
				for temp_u in dash_board.units:
					_hover_predicted_hp[temp_u.id] = temp_u.health.current_hp
					_hover_predicted_armor[temp_u.id] = temp_u.armor
			return
	var hover_unit := _proj().get_unit_at(_hover_coord)
	if hover_unit == null:
		return
	var target_id := _resolve_hover_attack_target(p_unit, hover_unit)
	if target_id < 0:
		return
	var rng := _ability_range(p_unit)
	if rng < 0:
		return
	if p_unit.turn_action_used and target_id != p_unit.id:
		var target := _proj().get_unit_by_id(target_id)
		if target != null and GridSystem.manhattan(p_unit.position, target.position) > rng:
			return
	var res := _director.preview_drag(_selected_id, p_unit.position, target_id)
	var temp_board: BoardState = res.get("temp_board")
	if temp_board == null:
		return
	for temp_u in temp_board.units:
		_hover_predicted_hp[temp_u.id] = temp_u.health.current_hp
		_hover_predicted_armor[temp_u.id] = temp_u.armor

## Shared live preview for drag and aim — same simulation, paths, intents, and HP.
func _refresh_live_interaction_preview(
	unit_id: int,
	move_coord: Vector2i,
	attack_target_id: int = -1,
	waypoints: Array[Vector2i] = [],
	cache_field: StringName = &"drag_key",
) -> void:
	if _director == null or _board == null or unit_id < 0:
		return
	var unit := _board.get_unit_by_id(unit_id)
	if unit == null:
		return
	var cur_ability := _selected_ability if _selected_ability >= 0 \
		else (_director.selected_ability_index if _director != null else -1)
	var dash_preview := false
	if _board.is_in_bounds(_hover_coord):
		var dash_ab := _selected_ability_data(unit)
		if _should_use_dash_on_input(dash_ab) and dash_ab != null:
			dash_preview = _is_valid_dash_target(_proj_origin(unit), _hover_coord, dash_ab.range_tiles)
	var cache_key: String
	if dash_preview:
		cache_key = "dash_%s_%s_%s" % [_hover_coord, cur_ability, unit_id]
	else:
		cache_key = "%s_%s_%s" % [move_coord, attack_target_id, cur_ability]
	if not _danger_tiles_cache.has(cache_field) or _danger_tiles_cache[cache_field] != cache_key:
		_danger_tiles_cache[cache_field] = cache_key
		var res: Dictionary
		if dash_preview:
			res = _director.preview_dash(unit_id, _hover_coord, cur_ability)
			_drag_sim_actor_pos = _proj_origin(unit)
		else:
			res = _director.preview_drag(unit_id, move_coord, attack_target_id, waypoints)
			var pv_actor: UnitState = res.temp_board.get_unit_by_id(unit_id) if res.has("temp_board") else null
			_drag_sim_actor_pos = pv_actor.position if pv_actor != null else move_coord
		_drag_intents = res.intents
		_aim_intents = _drag_intents
		_drag_predicted_hp.clear()
		_drag_predicted_armor.clear()
		var temp_board: BoardState = res.temp_board
		for temp_u in temp_board.units:
			_drag_predicted_hp[temp_u.id] = temp_u.health.current_hp
			_drag_predicted_armor[temp_u.id] = temp_u.armor
		_drag_failed = false
		for e in res.events:
			if e.type == GameEnums.SimEventType.ACTION_FAILED and e.data.get("actor", -1) == unit_id:
				_drag_failed = true
				break
		_preview = temp_board
		_build_preview_paths(res.events)

func _refresh_selected_interaction_preview() -> void:
	if _dragging or _director == null or _board == null:
		return
	if _selected_id < 0 or not _board.is_in_bounds(_hover_coord):
		_restore_interaction_preview_stash()
		return
	var p_unit := _proj_unit(_selected_id)
	if p_unit == null or p_unit.is_enemy() or not p_unit.is_alive():
		_restore_interaction_preview_stash()
		return
	if not p_unit.active_abilities.is_empty() and _selected_ability >= 0:
		var target_id := _hover_attack_target_id(p_unit)
		_refresh_live_interaction_preview(_selected_id, _hover_coord, target_id, [], &"hover_key")
		return
	if _force_basic_movement and _can_basic_move_to(p_unit, _hover_coord):
		_refresh_live_interaction_preview(_selected_id, _hover_coord, -1, [], &"hover_key")
		return
	_restore_interaction_preview_stash()

func _restore_interaction_preview_stash() -> void:
	_apply_stashed_preview()
	_drag_predicted_hp.clear()
	_drag_predicted_armor.clear()

func _skill_interaction_active() -> bool:
	return _skill_takes_priority_over_basic_move() and _selected_id >= 0 and not _dragging

func _apply_stashed_preview() -> void:
	if _drag_saved_preview == null:
		return
	_preview = _drag_saved_preview.clone()
	_preview_paths = _drag_saved_preview_paths.duplicate(true)
	_preview_splits = _drag_saved_preview_splits.duplicate(true)
	_preview_pushes = _drag_saved_preview_pushes.duplicate(true)
	_drag_intents.clear()
	_aim_intents.clear()
	_drag_predicted_hp.clear()
	_drag_predicted_armor.clear()

func _hover_attack_target_id(p_unit: UnitState) -> int:
	if not _board.is_in_bounds(_hover_coord):
		return -1
	var boards: Array = [_board, _proj()]
	if _preview != null:
		boards.append(_preview)
	if _drag_saved_preview != null:
		boards.append(_drag_saved_preview)
	for board in boards:
		if board == null:
			continue
		var hover_unit: UnitState = board.get_unit_at(_hover_coord)
		if hover_unit == null:
			continue
		var target_id := _resolve_hover_attack_target(p_unit, hover_unit)
		if target_id >= 0:
			return target_id
	return -1

func _get_display_predicted_hp(unit_id: int, current: int) -> int:
	if not _drag_predicted_hp.is_empty():
		return _drag_predicted_hp.get(unit_id, current)
	if not _hover_predicted_hp.is_empty():
		return _hover_predicted_hp.get(unit_id, current)
	return _predicted_hp.get(unit_id, current)

func _get_display_predicted_armor(unit_id: int, current_armor: int) -> int:
	if not _drag_predicted_armor.is_empty():
		return _drag_predicted_armor.get(unit_id, current_armor)
	if not _hover_predicted_armor.is_empty():
		return _hover_predicted_armor.get(unit_id, current_armor)
	return _predicted_armor.get(unit_id, current_armor)

func _update_mouse_cursor() -> void:
	_hover_action_icon = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _dragging:
		if _drag_unit_was_selected and _drag_unit_id >= 0 and _board != null \
		and _board.is_in_bounds(_hover_coord):
			var drag_unit := _board.get_unit_by_id(_drag_unit_id)
			if drag_unit != null and not drag_unit.is_enemy() \
			and _hover_coord == drag_unit.position:
				var ability := _selected_ability_data(drag_unit)
				if ability != null and ability.range_tiles == 0:
					_hover_action_icon = _ability_action_icon(ability)
		if _hover_action_icon != "":
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		return
		
	if _selected_id >= 0 and _board != null and _board.is_in_bounds(_hover_coord):
		var sel_unit = _board.get_unit_by_id(_selected_id)
		if sel_unit != null and not sel_unit.is_enemy():
			var p_unit = _proj_unit(_selected_id)
			if p_unit != null:
				var hover_unit = _aim_enemy_board().get_unit_at(_hover_coord) if _skill_interaction_active() else _proj().get_unit_at(_hover_coord)
				if _skill_interaction_active():
					if _force_basic_movement and hover_unit == null \
					and _hover_coord != p_unit.position \
					and _can_basic_move_to(p_unit, _hover_coord):
						_hover_action_icon = "🏃"
					else:
						var valid_aim := false
						if hover_unit != null:
							if hover_unit.id == p_unit.id:
								valid_aim = _ability_range(p_unit) == 0
							else:
								valid_aim = _in_ability_range(p_unit, hover_unit)
						elif _selected_ability >= 0 and _selected_ability < p_unit.active_abilities.size():
							var aim_ability: AbilityData = p_unit.active_abilities[_selected_ability]
							if _ability_has_dash(aim_ability):
								valid_aim = _is_valid_dash_target(p_unit.position, _hover_coord, aim_ability.range_tiles)
								
						if valid_aim:
							var abilities = p_unit.active_abilities
							if _selected_ability >= 0 and _selected_ability < abilities.size():
								_hover_action_icon = _ability_action_icon(abilities[_selected_ability])
				else:
					if hover_unit != null and hover_unit.is_enemy():
						if _prefer_approach_over_trample_move(p_unit, hover_unit):
							_hover_action_icon = "⚔️"
						elif _can_move_to(p_unit, _hover_coord):
							_hover_action_icon = "🏃"
						else:
							_hover_action_icon = "⚔️"
					elif hover_unit == null and _hover_coord != p_unit.position:
						var hover_ability := _selected_ability_data(p_unit)
						if _skill_takes_priority_over_basic_move() and hover_ability != null \
						and _ability_has_dash(hover_ability) \
						and _is_valid_dash_target(p_unit.position, _hover_coord, hover_ability.range_tiles):
							if _ability_is_offensive_dash(hover_ability):
								_hover_action_icon = "⚔️"
							else:
								_hover_action_icon = "✨"
						elif _basic_move_allowed() \
						and not MovementSystem.find_path(_proj(), p_unit.position, _hover_coord, p_unit.movement.points_left).is_empty():
							_hover_action_icon = "🏃"
							
	if _hover_action_icon != "":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _recompute_hover_ranges() -> void:
	if _board == null:
		return
		
	var unit: UnitState = null
	if _dragging and _drag_unit_id >= 0:
		unit = _board.get_unit_by_id(_drag_unit_id)
	elif _selected_id >= 0:
		unit = _board.get_unit_by_id(_selected_id)
	elif _board.is_in_bounds(_hover_coord) and _board.get_unit_at(_hover_coord) != null:
		unit = _board.get_unit_at(_hover_coord)
		
	if unit == null or not unit.is_alive():
		_cached_hover_unit_id = -1
		_cached_hover_origin = Vector2i(-999, -999)
		_cached_hover_ability = -1
		_hover_move_tiles.clear()
		_hover_threat_tiles.clear()
		return
	
	var origin := _proj_origin(unit)
	var cache_ability := _selected_ability if unit.id == _selected_id else -1
	var cache_force_move := _force_basic_movement if unit.id == _selected_id else false
	if _cached_hover_unit_id == unit.id and _cached_hover_origin == origin \
	and _cached_hover_ability == cache_ability and _cached_hover_force_move == cache_force_move:
		return
		
	_cached_hover_unit_id = unit.id
	_cached_hover_origin = origin
	_cached_hover_ability = cache_ability
	_cached_hover_force_move = cache_force_move
	_hover_move_tiles.clear()
	_hover_threat_tiles.clear()
		
	var exhausted := false
	if not unit.is_enemy():
		var p_unit := _proj_unit(unit.id)
		if p_unit != null:
			exhausted = p_unit.turn_action_used
	if exhausted:
		return
		
	var move_cost = 1
	if unit.has_status(GameEnums.StatusType.BLEED):
		move_cost = 2
		
	var mt := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	var reach := MovementSystem.get_reachable_tiles(_board, origin, unit.movement.points_left, mt, move_cost)
	
	_hover_move_tiles = reach.duplicate()
	
	if _force_basic_movement and unit.id == _selected_id and not unit.is_enemy():
		return
	
	if unit.id == _selected_id and not _force_basic_movement and _selected_ability >= 0:
		var dash_ab := _selected_ability_data(unit)
		if dash_ab != null and _ability_has_dash(dash_ab):
			_hover_threat_tiles = _dash_threat_tiles(origin, _dash_effect_amount(dash_ab))
			if AbilitySystem.ability_blocks_basic_movement(dash_ab):
				_hover_move_tiles.clear()
			return

	if unit.id == _selected_id and _movement_blocked_by_dash() and not _force_basic_movement:
		_hover_move_tiles.clear()
		var dash_ab := _selected_ability_data(unit)
		_hover_threat_tiles = _dash_threat_tiles(origin, _dash_effect_amount(dash_ab))
		return
	
	if unit.id == _selected_id:
		var sel_ability := _selected_ability_data(unit)
		var self_aoe := _self_aoe_threat_tiles(unit, sel_ability, origin)
		if not self_aoe.is_empty():
			_hover_threat_tiles = self_aoe
			return
	
	var rng := _unit_attack_range(unit)
	if rng <= 0:
		return
		
	var threat_sources = reach if unit.is_enemy() else [origin]
	if unit.id == _selected_id and _ability_has_dash(_selected_ability_data(unit)):
		_hover_threat_tiles = _dash_threat_tiles(origin, _dash_effect_amount(_selected_ability_data(unit)))
		return
	for y in range(_board.grid_size.y):
		for x in range(_board.grid_size.x):
			var coord := Vector2i(x, y)
			for r in threat_sources:
				if GridSystem.manhattan(coord, r) <= rng:
					_hover_threat_tiles.append(coord)
					break

## The reach of a unit's strongest attack (selected ability for the active player
## unit; the configured attack for enemies; max ability range otherwise).
func _proj_origin(unit: UnitState) -> Vector2i:
	var pv := _proj_unit(unit.id)
	if pv != null:
		return pv.position
	return unit.position

func _selected_ability_data(unit: UnitState) -> AbilityData:
	if unit == null or _selected_ability < 0 or _selected_ability >= unit.active_abilities.size():
		return null
	return unit.active_abilities[_selected_ability]

func _ability_action_icon(ability: AbilityData) -> String:
	if ability == null:
		return ""
	if _ability_is_offensive_dash(ability):
		return "⚔️"
	if _ability_has_dash(ability):
		return "✨"
	for eff in ability.effects:
		match eff.type:
			GameEnums.EffectType.DAMAGE: return "⚔️"
			GameEnums.EffectType.HEAL: return "💚"
			GameEnums.EffectType.ARMOR_UP: return "🛡️"
			GameEnums.EffectType.SWAP: return "🔄"
	return "✨"

func _drag_self_skill_intent(release_local: Vector2) -> bool:
	if _drag_route.size() > 1:
		return true
	if release_local.distance_to(_drag_press_local) >= DRAG_CLICK_MOVE_THRESHOLD:
		return true
	return Time.get_ticks_msec() - _drag_press_time_ms >= DRAG_SELF_SKILL_DELAY_MS

func _ability_has_dash(ability: AbilityData) -> bool:
	return AbilitySystem.ability_has_dash(ability)

func _ability_is_offensive_dash(ability: AbilityData) -> bool:
	return AbilitySystem.ability_is_offensive_dash(ability)

func _dash_effect_amount(ability: AbilityData) -> int:
	if ability == null:
		return 0
	for eff in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return eff.amount
	return 0

func _resolved_ability_shape(ability: AbilityData, unit: UnitState) -> Dictionary:
	var shape := ability.target_shape
	var shape_size := ability.target_shape_size
	if unit != null and unit.is_ability_upgraded(ability.id):
		if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
			shape = ability.upgraded_target_shape
		if ability.upgraded_target_shape_size >= 0:
			shape_size = ability.upgraded_target_shape_size
	return {"shape": shape, "size": shape_size}

func _self_aoe_threat_tiles(unit: UnitState, ability: AbilityData, center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if ability == null or _board == null or ability.range_tiles != 0:
		return tiles
	var resolved := _resolved_ability_shape(ability, unit)
	if resolved["shape"] == GameEnums.TargetShape.SINGLE:
		return tiles
	for coord in GridSystem.get_affected_tiles(_board, center, center, resolved["shape"], resolved["size"]):
		if _board.is_in_bounds(coord):
			tiles.append(coord)
	return tiles

func _dash_threat_tiles(origin: Vector2i, dash_distance: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if _board == null or dash_distance <= 0:
		return tiles
	for dir in GridSystem.DIRECTIONS:
		for i in range(1, dash_distance + 1):
			var coord := origin + dir * i
			if _board.is_in_bounds(coord):
				tiles.append(coord)
	return tiles

func _is_valid_dash_target(actor_pos: Vector2i, coord: Vector2i, max_range: int) -> bool:
	if coord == actor_pos or max_range <= 0:
		return false
	var delta := coord - actor_pos
	if delta.x != 0 and delta.y != 0:
		return false
	var dist := GridSystem.manhattan(actor_pos, coord)
	return dist >= 1 and dist <= max_range

func _movement_blocked_by_dash() -> bool:
	if _selected_id < 0:
		return false
	var unit := _proj_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id) if _board != null else null
	return unit != null and AbilitySystem.ability_blocks_basic_movement(_selected_ability_data(unit))

func _basic_move_allowed() -> bool:
	if _force_basic_movement:
		return true
	return not _movement_blocked_by_dash()

func _try_plan_skill_at_coord(unit: UnitState, coord: Vector2i, local: Vector2) -> bool:
	if _force_basic_movement or _selected_ability < 0:
		return false
	var ability := _selected_ability_data(unit)
	if ability == null:
		return false
	var actor := _proj_unit(unit.id)
	if actor == null:
		actor = unit
	if _ability_has_dash(ability):
		if not _is_valid_dash_target(_proj_origin(actor), coord, ability.range_tiles):
			return false
		_plan_ability_at_coord(unit.id, _selected_ability, coord)
		_sfx.play("ability")
		return true
	var target := _proj().get_unit_at(coord)
	if target != null:
		if target.id == actor.id:
			if _ability_range(actor) == 0:
				_plan_attack(unit.id, _selected_ability, target.id)
				_sfx.play("ability")
				return true
		elif _in_ability_range(actor, target):
			_plan_attack(unit.id, _selected_ability, target.id)
			_sfx.play("ability")
			return true
	return false

func _can_move_to(unit: UnitState, coord: Vector2i) -> bool:
	if unit == null or coord == unit.position:
		return false
	if unit.movement.points_left <= 0:
		return false
	var board := _proj()
	if not MovementSystem.can_end_movement_on(board, coord, unit):
		return false
	return not MovementSystem.find_path(board, unit.position, coord, unit.movement.points_left).is_empty()

func _can_basic_move_to(unit: UnitState, coord: Vector2i) -> bool:
	return _can_move_to(unit, coord)

func _try_plan_basic_move(unit_id: int, coord: Vector2i, local: Vector2, waypoints: Array[Vector2i] = []) -> bool:
	if not _basic_move_allowed():
		return false
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _board.get_unit_by_id(unit_id) if _board != null else null
	if actor == null or not _can_basic_move_to(actor, coord):
		return false
	_plan_move(unit_id, coord, _facing_from_drop(local, coord), waypoints)
	_sfx.play("move")
	return true

func _should_use_dash_on_input(ability: AbilityData) -> bool:
	if ability == null or not _ability_has_dash(ability) or _selected_ability < 0:
		return false
	if _skill_interaction_active():
		return true
	if not _force_basic_movement:
		return true
	return AbilitySystem.ability_blocks_basic_movement(ability)

func _unit_attack_range(unit: UnitState) -> int:
	if unit.is_enemy():
		if unit.definition.behavior != null and unit.definition.behavior.attack != null:
			return unit.definition.behavior.attack.range_tiles
		return 1
		
	if unit.id == _selected_id and _selected_ability >= 0 and _selected_ability < unit.active_abilities.size():
		return unit.active_abilities[_selected_ability].range_tiles
		
	var best := 0
	for ability in unit.active_abilities:
		best = maxi(best, ability.range_tiles)
	return best

## Decide which enemy intents to surface: those acting on the selected unit, plus the
## enemy currently hovered. Keeps the board readable instead of showing everything.
func _recompute_intent_units() -> void:
	_intent_units.clear()
	if _board == null:
		return
	var intent_list := _display_intent_list()
	for intent in intent_list:
		for action in intent.actions:
			if action.target_unit_id == _selected_id and _selected_id >= 0:
				_intent_units[intent.enemy_id] = true
				break
	if _board.is_in_bounds(_hover_coord):
		var hovered: UnitState = null
		if _skill_interaction_active():
			for board in [_board, _proj(), _preview]:
				if board == null:
					continue
				hovered = board.get_unit_at(_hover_coord)
				if hovered != null:
					break
		else:
			hovered = _board.get_unit_at(_hover_coord)
		if hovered != null and hovered.is_enemy():
			_intent_units[hovered.id] = true

func _intent_visible(unit: UnitState) -> bool:
	if not unit.is_enemy():
		return true
	if _skill_interaction_active():
		return true
	if _phase == CombatDirector.Phase.ENEMY_TURN:
		return true
	if CombatDirector.is_planning_phase(_phase) or CombatDirector.is_executing_phase(_phase):
		return _intent_units.has(unit.id)
	return false

func _refresh_info() -> void:
	if _board == null or _info_label == null or _tile_info_panel == null: return
	
	var hov := _hover_coord
	if _dragging:
		hov = _drag_last_free
		
	var tile_str = _tile_info(hov)
	_tile_info_label.text = tile_str
	
	if _selected_id >= 0:
		var u = _director.base_board.get_unit_by_id(_selected_id)
		if u != null:
			_info_label.text = _unit_info(u)
			
	else:
		if not _board.is_in_bounds(hov):
			_info_label.text = ""
			return
		
		var unit := _board.get_unit_at(hov)
		var text := ""
		if unit != null:
			text += _unit_info(unit)
		elif _selected_id >= 0:
			var sel_unit = _board.get_unit_by_id(_selected_id)
			if sel_unit != null:
				text += "[color=#%s]--- Selected ---[/color]\n" % HEX_DIM + _unit_info(sel_unit)
		if text == "":
			text = "[color=#%s]Hover a unit or ability for details.[/color]" % HEX_DIM
			
		_info_label.text = text
	
	var score_updated := false
	if _selected_id >= 0 and (CombatDirector.is_planning_phase(_phase)):
		var start_board := _director.base_board if (_director != null and _director.base_board != null) else _board
		var actor := start_board.get_unit_by_id(_selected_id)
		if actor != null and actor.is_alive():
			var action: TimelineAction = null
			if _skill_interaction_active() or _skill_takes_priority_over_basic_move():
				if _force_basic_movement and _can_basic_move_to(actor, _hover_coord):
					action = TimelineAction.make_move(actor.id, _hover_coord, -1, [], _move_timing_bucket())
				else:
					var ability_index := _selected_ability
					var abilities := actor.active_abilities
					if ability_index >= 0 and ability_index < abilities.size():
						var ability := abilities[ability_index]
						if _ability_has_dash(ability):
							var p_actor := _proj_unit(actor.id)
							var dash_origin := p_actor.position if p_actor != null else actor.position
							if _is_valid_dash_target(dash_origin, _hover_coord, ability.range_tiles):
								action = TimelineAction.make_ability(actor.id, ability, _hover_coord, -1, _move_timing_bucket())
						elif GridSystem.manhattan(actor.position, _hover_coord) <= ability.range_tiles:
							var target_unit := start_board.get_unit_at(_hover_coord)
							var target_id := target_unit.id if target_unit != null else -1
							action = TimelineAction.make_ability(actor.id, ability, _hover_coord, target_id, _move_timing_bucket())
			elif _basic_move_allowed():
				var points := actor.movement.points_left
				if points > 0 and _hover_coord != actor.position:
					if not MovementSystem.find_path(start_board, actor.position, _hover_coord, points).is_empty():
						action = TimelineAction.make_move(actor.id, _hover_coord, -1, [], _move_timing_bucket())
						
			if action != null:
				var data := _get_action_autobattler_scores(action)
				_update_score_hud(data)
				score_updated = true
			
	if not score_updated and _selected_id >= 0 and (CombatDirector.is_planning_phase(_phase)):
		var queued := _get_queued_action_for_selected()
		if queued != null:
			var data := _get_action_autobattler_scores(queued)
			_update_score_hud(data)
			score_updated = true
			
	if not score_updated and _score_lbl != null:
		_score_lbl.text = "🤖 AI Score: --"
		_score_lbl.tooltip_text = "Hover over a valid action tile to see its tactical utility breakdown."

func _format_stat_with_tooltip(unit: UnitState, stat_type: GameEnums.StatType) -> String:
	var base_val := 0
	var w_bonus := 0
	var final_val := 0
	var level_bonus := 0
	
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
				if _board != null:
					final_val = CombatSystem.get_dynamic_defense(_board, unit)
				else:
					final_val = ceili(unit.current_defense / 2.0)
			
	var breakdown := "%d (Base)" % base_val
	if level_bonus > 0:
		breakdown += "\n+%d (Level %d)" % [level_bonus, unit.level]
	if w_bonus > 0:
		breakdown += "\n+%d (Weapon)" % w_bonus
		
	var diff = final_val - (base_val + level_bonus + w_bonus)
	if diff != 0:
		for s in unit.active_statuses:
			var amount = 0
			match stat_type:
				GameEnums.StatType.PHYSICAL:
					if s.type == GameEnums.StatusType.STAT_BUFF_STR: amount = s.value
					if s.type == GameEnums.StatusType.WEAKEN: amount = -2
				GameEnums.StatType.MAGICAL:
					if s.type == GameEnums.StatusType.STAT_BUFF_MAG: amount = s.value
					if s.type == GameEnums.StatusType.WEAKEN: amount = -2
				GameEnums.StatType.DEFENSE:
					if s.type == GameEnums.StatusType.STAT_BUFF_DEF: amount = s.value
					if s.type == GameEnums.StatusType.STAT_DEBUFF_DEF: amount = -s.value
			
			if amount != 0:
				var sign_str = "+" if amount > 0 else ""
				breakdown += "\n%s%d (%s)" % [sign_str, amount, _get_status_name(s.type)]
		
		if stat_type == GameEnums.StatType.DEFENSE and unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
			breakdown += "\nHalved (Iron Grip)"
				
		if unit.has_status(GameEnums.StatusType.POLYMORPH) and (stat_type == GameEnums.StatType.PHYSICAL or stat_type == GameEnums.StatType.MAGICAL):
			breakdown += "\nSet to 0 (Polymorph)"
				
	if diff > 0:
		return "[color=#82E0AA][hint=\"%s\"]%d[/hint][/color]" % [breakdown, final_val]
	elif diff < 0:
		return "[color=#E74C3C][hint=\"%s\"]%d[/hint][/color]" % [breakdown, final_val]
	else:
		return "[hint=\"%s\"]%d[/hint]" % [breakdown, final_val]

func _equipment_info(unit: UnitState) -> String:
	var wpn: WeaponData = unit.definition.equipped_weapon if unit.definition != null else null
	if wpn == null:
		return "[font_size=9]🗡️ [b]Equipment:[/b] None[/font_size]"
	var stat_parts: Array[String] = ["WPN %d" % wpn.might]
	if wpn.bonus_strength != 0:
		stat_parts.append("STR %+d" % wpn.bonus_strength)
	if wpn.bonus_magic != 0:
		stat_parts.append("MAG %+d" % wpn.bonus_magic)
	if wpn.bonus_defense != 0:
		stat_parts.append("DEF %+d" % wpn.bonus_defense)
	if wpn.bonus_max_hp != 0:
		stat_parts.append("HP %+d" % wpn.bonus_max_hp)
	if wpn.bonus_move != 0:
		stat_parts.append("MOV %+d" % wpn.bonus_move)
	var tooltip := "Might %d — added to ability base power in damage formula." % wpn.might
	if stat_parts.size() > 1:
		tooltip += "\nAlso modifies unit stats when equipped."
	return "[font_size=9]🗡️ [b]Equipment:[/b] %s  |  [hint=\"%s\"]%s[/hint][/font_size]" % [
		wpn.display_name, tooltip, ", ".join(stat_parts),
	]

func _unit_info(unit: UnitState) -> String:
	var lines: Array[String] = []
	lines.append("[color=#4DB8FF][font_size=13][b]%s[/b][/font_size][/color]  [font_size=10][color=#aaaaaa](%s)[/color][/font_size]" % [
		unit.definition.display_name, "Player" if not unit.is_enemy() else "Enemy"
	])
	
	var move_type = GameEnums.MovementType.keys()[unit.definition.movement_type].capitalize()
	lines.append("[font_size=10]Lv.%d %s  |  Move: %s[/font_size]" % [unit.level, unit.definition.id.capitalize(), move_type])
	lines.append("[font_size=9][color=#4ADE80][b]❤️ HP: %s/%s[/b][/color]    Facing %s[/font_size]" % [
		unit.health.current_hp, unit.health.max_hp,
		_facing_name(unit.facing),
	])
	
	lines.append("[font_size=9][color=#F1C40F][b][hint=Movement Points]👢 MP:[/hint] %d/%d[/b][/color]    [color=#E74C3C][b][hint=Action Points]⚔️ AP:[/hint] %d/%d[/b][/color][/font_size]" % [
		unit.movement.points_left, unit.movement.max_points,
		unit.ability.points_left, unit.ability.max_points
	])
	
	var str_fmt = _format_stat_with_tooltip(unit, GameEnums.StatType.PHYSICAL)
	var mag_fmt = _format_stat_with_tooltip(unit, GameEnums.StatType.MAGICAL)
	var def_fmt = _format_stat_with_tooltip(unit, GameEnums.StatType.DEFENSE)
	
	var stats_str = "[font_size=10]💪 STR: %s  ✨ MAG: %s  🛡️ DEF: %s" % [str_fmt, mag_fmt, def_fmt]
	if unit.armor > 0:
		stats_str += "  [hint=Armor]🪖 ARM:[/hint] %d" % unit.armor
	stats_str += "[/font_size]"
	lines.append(stats_str)
	lines.append(_equipment_info(unit))
	
	if unit.is_enemy():
		if unit.definition.behavior != null and unit.definition.behavior.attack != null:
			var att = unit.definition.behavior.attack
			lines.append("Attack: [hint=\"%s\"]%s[/hint]" % [_ability_desc(att), att.display_name])
	else:
		var names: Array[String] = []
		for ability in unit.active_abilities:
			names.append("[hint=\"%s\"]%s[/hint]" % [_ability_desc(ability, unit), ability.display_name])
		lines.append("[font_size=8]Abilities: %s[/font_size]" % (", ".join(names) if not names.is_empty() else "None"))
		var passives: Array[String] = []
		for p in unit.active_passives:
			passives.append("%s: %s" % [p.display_name, _parse_keywords(p.description)])
		if passives.size() > 0:
			lines.append("[font_size=8][b]Passives[/b][/font_size]")
			for line in passives:
				lines.append("[font_size=8]%s[/font_size]" % line)
	if _board != null and _board.is_in_bounds(unit.position):
		var tile := _board.get_tile(unit.position)
		if tile != null and tile.definition != null and tile.definition.fortitude != 0:
			var fort_val := tile.definition.fortitude
			var sign_str := "+" if fort_val > 0 else ""
			var terrain_hint := "Reduces incoming damage." if fort_val > 0 else "Increases incoming damage."
			lines.append("[font_size=10][hint=\"%s\"]🌿 Terrain: %s (%s%d Fortitude)[/hint][/font_size]" % [
				terrain_hint, tile.definition.display_name, sign_str, fort_val,
			])
	if unit.active_statuses.size() > 0:
		var status_strs: Array[String] = []
		for status in unit.active_statuses:
			var s_name: String = _get_status_name(status.type)
			if status.duration > 0:
				s_name += " (%d turns)" % status.duration
			
			var desc: String = "Status Effect"
			match status.type:
				GameEnums.StatusType.STURDY: desc = "Ignores the next displacement effect (push/pull)."
				GameEnums.StatusType.RETALIATION_PROTOCOL: desc = "Can strike targets anywhere on the map."
				GameEnums.StatusType.INDOMITABLE_WILL: desc = "Immune to displacement and debuffs."
				GameEnums.StatusType.THORNS: desc = "Reflects physical damage back to attacker."
				GameEnums.StatusType.IRON_GRIP_DEBUFF: desc = "Defense is halved."
				GameEnums.StatusType.MARK: desc = "Next attack against this unit will Backstab."
				GameEnums.StatusType.INTERCEPT: desc = "Takes damage in place of adjacent allies."
				GameEnums.StatusType.STEALTH: desc = "Cannot be targeted by direct attacks."
				GameEnums.StatusType.PIERCE: desc = "Attacks ignore armor."
				GameEnums.StatusType.PACIFY: desc = "Cannot use attack abilities."
				GameEnums.StatusType.TAUNT: desc = "Forced to move towards and attack the taunter."
				GameEnums.StatusType.BURN: desc = "Takes 1 damage per turn. Spread to adjacent allies on contact."
				GameEnums.StatusType.ELECTRIFIED: desc = "Spreads damage to adjacent units."
				GameEnums.StatusType.POISON: desc = "Takes damage at end of turn. Cannot heal."
				GameEnums.StatusType.BLEED: desc = "Takes 1 damage whenever moving."
				GameEnums.StatusType.STUN: desc = "Cannot act or move."
				GameEnums.StatusType.INVULNERABLE: desc = "Cannot take damage."
				GameEnums.StatusType.WEAK_TRAP: desc = "Triggers a trap when stepped on."
				GameEnums.StatusType.WEAKEN: desc = "Deals less damage with physical attacks."
				GameEnums.StatusType.VULNERABLE: desc = "Takes additional damage from attacks."
				GameEnums.StatusType.SILENCE: desc = "Cannot use magical abilities."
				GameEnums.StatusType.BLIND: desc = "Attack range is severely reduced."
				GameEnums.StatusType.FEAR: desc = "Forced to run away from the source of fear."
				GameEnums.StatusType.CONFUSION: desc = "Abilities will target friendly units instead."
				GameEnums.StatusType.GHOST: desc = "Can move through other units and solid obstacles."
				GameEnums.StatusType.TRAMPLE: desc = "Move through enemies; PUSH 1 on each enemy entered."
				GameEnums.StatusType.AIRBORNE: desc = "Ignores ground hazards and terrain effects."
				GameEnums.StatusType.CANTO: desc = "Can use remaining movement points after taking an action."
				GameEnums.StatusType.POLYMORPH: desc = "Transformed into a harmless creature, cannot act."
				GameEnums.StatusType.STAT_BUFF_STR: desc = "Increased Strength (STR) by %d." % status.value
				GameEnums.StatusType.STAT_BUFF_MAG: desc = "Increased Magic (MAG) by %d." % status.value
				GameEnums.StatusType.STAT_BUFF_MP: desc = "Increased Movement Points (MP) by %d." % status.value
				GameEnums.StatusType.STAT_BUFF_ACC: desc = "Increased Accuracy (ACC) by %d." % status.value
				GameEnums.StatusType.STAT_DEBUFF_DEF: desc = "Decreased Defense (DEF) by %d." % status.value
				GameEnums.StatusType.STAT_DEBUFF_ACC: desc = "Decreased Accuracy (ACC) by %d." % status.value
				_: desc = s_name
				
			var text = s_name
			if status.duration > 1:
				text += " (%d)" % status.duration
				
			status_strs.append("[hint=\"%s\"]%s[/hint]" % [desc, text])
			
		lines.append("[color=#%s]Statuses: %s[/color]" % [HEX_INTENT, ", ".join(status_strs)])
		
	return "\n".join(lines)

func _tile_info(coord: Vector2i) -> String:
	if not _board.is_in_bounds(coord):
		return "[color=#%s]Hover a tile for details.[/color]" % HEX_DIM
	var tile := _board.get_tile(coord)
	if tile == null or tile.definition == null:
		return "[font_size=9][color=#%s][b]Unknown[/b][/color][right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]" % [HEX_DIM, coord.x, coord.y]
	var desc := _terrain_desc(tile.definition)
	return "[font_size=9][color=#%s][b]%s[/b][/color][right][color=#aaaaaa](%d, %d)[/color][/right][/font_size]\n[font_size=10]%s[/font_size]" % [
		HEX_TILE, tile.definition.display_name, coord.x, coord.y, desc,
	]

func _facing_name(facing: GameEnums.Facing) -> String:
	return GameEnums.Facing.keys()[facing].capitalize()

func _terrain_desc(def: TerrainData) -> String:
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

func _get_status_name(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Iron Grip"
		GameEnums.StatusType.RETALIATION_PROTOCOL: return "Retaliation Protocol"
		GameEnums.StatusType.INDOMITABLE_WILL: return "Indomitable Will"
		GameEnums.StatusType.THORNS: return "Thorns"
		GameEnums.StatusType.STAT_BUFF_STR: return "STR UP"
		GameEnums.StatusType.STAT_BUFF_MAG: return "MAG UP"
		GameEnums.StatusType.STAT_BUFF_DEF: return "DEF UP"
		GameEnums.StatusType.STAT_BUFF_MOV: return "MOV UP"
		GameEnums.StatusType.STAT_BUFF_ACC: return "ACC UP"
		GameEnums.StatusType.STAT_DEBUFF_DEF: return "DEF DOWN"
		GameEnums.StatusType.STAT_DEBUFF_ACC: return "ACC DOWN"
		GameEnums.StatusType.STAT_DEBUFF_MOV: return "MOV DOWN"
	return GameEnums.StatusType.keys()[t].capitalize()

func _get_amount_string(eff: EffectData) -> String:
	var stat_str = ""
	if eff.scaling_stat != GameEnums.StatType.NONE:
		stat_str = "[%s]" % GameEnums.StatType.keys()[eff.scaling_stat]
	
	if eff.amount == 0 and stat_str != "":
		return stat_str
	elif eff.amount > 0 and stat_str != "":
		return "%d + %s" % [eff.amount, stat_str]
	else:
		return str(eff.amount)

func _kw(word: String) -> String:
	return "[color=#FBBF24]%s[/color]" % word

func _kw_hint(word: String, hint: String) -> String:
	return "[hint=\"%s\"]%s[/hint]" % [hint, _kw(word)]

func _highlight_counter_attack_keywords(text: String) -> String:
	var rx := RegEx.new()
	if rx.compile("COUNTER ATTACK \\d+") != OK:
		return text
	var result := text
	var matches := rx.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var phrase := m.get_string()
		var hint := "Retaliates against the attacker for the listed ATK power (scaled by STR and weapon)."
		result = result.substr(0, m.get_start()) + _kw_hint(phrase, hint) + result.substr(m.get_end())
	return result

func _parse_keywords(text: String) -> String:
	var result := _highlight_counter_attack_keywords(text)
	var manual: Dictionary = {
		"DESTROY OBSTACLE": "Instantly removes a wall, trap, or destructible terrain.",
		"AOE ATK": "Deals damage to all units within the target shape.",
		"ATK": "Reduces target HP. Resisted by Armor.",
		"HEAL": "Restores target HP.",
		"PUSH": "Displaces target away from caster. Collisions deal damage.",
		"PULL": "Displaces target towards caster. Collisions deal damage.",
		"SWAP": "Exchanges tile positions.",
		"SHIELD": "Grants temporary hit points that absorb damage before HP.",
		"EXPLODE": "Deals damage to all units in adjacent cardinal tiles.",
		"SPAWN": "Summons a unit.",
		"CLEANSE": "Removes negative status effects.",
		"PURGE": "Removes positive buffs and shields.",
		"DASH": "Moves in a straight line; may apply effects on each tile entered.",
		"TELEPORT": "Moves instantly, ignoring pathing.",
		"TRAMPLE": "Pass through enemy tiles; PUSH 1 (left when passing through, forward when stopping on them).",
		"COLLISION": "Collision damage from displacement into walls or units.",
		"AOE": "Area effect — hits multiple tiles.",
		"RANGE": "Maximum targeting or effect distance in tiles.",
		"PIERCE": "Attacks ignore armor.",
		"THORNS": "Reflects damage back to attackers.",
		"ROOT": "Cannot move.",
		"STUN": "Cannot act or move.",
		"VULNERABLE": "Takes additional damage.",
		"MOV": "Movement Points available per turn.",
		"MOVE": "Movement Points available per turn.",
		"DEF": "Defense — reduces incoming damage.",
		"STR": "Strength — increases physical damage.",
		"MAG": "Magic — increases magical damage.",
	}
	var keys: Array = manual.keys()
	keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	for k in keys:
		result = result.replace(String(k), _kw_hint(String(k), manual[k]))
	for k in GameEnums.StatusType.keys():
		if k == "NONE":
			continue
		var d := _get_status_desc(GameEnums.StatusType[k])
		result = result.replace(k, _kw_hint(k, d))
	return result

func _get_status_desc(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.STURDY: return "Ignores the next displacement effect (push/pull)."
		GameEnums.StatusType.MARK: return "Next attack against this unit will Backstab."
		GameEnums.StatusType.INTERCEPT: return "Takes damage in place of adjacent allies."
		GameEnums.StatusType.STEALTH: return "Cannot be targeted by direct attacks."
		GameEnums.StatusType.PIERCE: return "Attacks ignore armor."
		GameEnums.StatusType.PACIFY: return "Cannot use attack abilities."
		GameEnums.StatusType.TAUNT: return "Forced to move towards and attack the taunter."
		GameEnums.StatusType.BURN: return "Takes 1 damage per turn. Spread to adjacent allies on contact."
		GameEnums.StatusType.ELECTRIFIED: return "Spreads damage to adjacent units."
		GameEnums.StatusType.POISON: return "Takes damage at end of turn. Cannot heal."
		GameEnums.StatusType.BLEED: return "Takes 1 damage whenever moving."
		GameEnums.StatusType.STUN: return "Cannot act or move."
		GameEnums.StatusType.INVULNERABLE: return "Cannot take damage."
		GameEnums.StatusType.WEAK_TRAP: return "Triggers a trap when stepped on."
		GameEnums.StatusType.WEAKEN: return "Deals less damage with physical attacks."
		GameEnums.StatusType.VULNERABLE: return "Takes additional damage from attacks."
		GameEnums.StatusType.SILENCE: return "Cannot use magical abilities."
		GameEnums.StatusType.BLIND: return "Attack range is severely reduced."
		GameEnums.StatusType.FEAR: return "Forced to run away from the source of fear."
	return "No description."

func _ability_is_upgraded(ability: AbilityData, unit: UnitState) -> bool:
	return unit != null and unit.is_ability_upgraded(ability.id)

func _ability_upgrade_suffix(ability: AbilityData, unit: UnitState, bbcode: bool = false) -> String:
	if not _ability_is_upgraded(ability, unit) or ability.upgrade_description.is_empty():
		return ""
	if bbcode:
		return "  [color=#aaaaaa](Upgrade: %s)[/color]" % ability.upgrade_description
	return " (Upgrade: %s)" % ability.upgrade_description

func _ability_effect_bbcode(ability: AbilityData, unit: UnitState = null) -> String:
	if ability.id == &"knight_bowling_charge":
		var body := "%s | %s | %s | %s. This unit does not suffer collision." % [
			_kw_hint("DASH 3", "Move up to 3 tiles in a straight cardinal line."),
			_kw_hint("TRAMPLE", "Pass through enemy tiles; PUSH 1 (left when passing through, forward when stopping on them)."),
			_kw_hint("PUSH 1", "Pushes trampled enemies left when passing through, forward when you stop on them."),
			_kw_hint("COLLISION", "Trample collision on contact; push into walls or units can add another collision."),
		]
		body += _ability_upgrade_suffix(ability, unit, true)
		return body
	var parts: Array[String] = []
	for effect in ability.effects:
		match effect.type:
			GameEnums.EffectType.DAMAGE: parts.append(_kw_hint("ATK %s" % _get_amount_string(effect), "Reduces target's current HP. Resisted by Armor."))
			GameEnums.EffectType.PUSH: parts.append(_kw_hint("PUSH %s" % _get_amount_string(effect), "Displaces target away from caster. Collisions deal damage."))
			GameEnums.EffectType.PULL: parts.append(_kw_hint("PULL %s" % _get_amount_string(effect), "Displaces target towards caster. Collisions deal damage."))
			GameEnums.EffectType.SWAP: parts.append(_kw_hint("SWAP", "Caster and target exchange tile positions."))
			GameEnums.EffectType.HEAL: parts.append(_kw_hint("HEAL %s" % _get_amount_string(effect), "Restores target's current HP."))
			GameEnums.EffectType.ARMOR_UP: parts.append(_kw_hint("SHIELD %s" % _get_amount_string(effect), "Grants temporary hit points that absorb damage before HP."))
			GameEnums.EffectType.EXPLODE: parts.append(_kw_hint("EXPLODE %s" % _get_amount_string(effect), "Deals damage to all units in the 4 adjacent cardinal tiles."))
			GameEnums.EffectType.RANGED_EXPLODE: parts.append(_kw_hint("AOE ATK %s" % _get_amount_string(effect), "Deals damage to all units within the target shape."))
			GameEnums.EffectType.SPAWN: parts.append(_kw_hint("SPAWN %s" % str(effect.spawn_unit_id).capitalize(), "Creates a new unit on the target tile."))
			GameEnums.EffectType.ADD_STATUS:
				var dur = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
				if effect.status_type == GameEnums.StatusType.IRON_GRIP_DEBUFF:
					parts.append("[hint=\"Target Defense (DEF) is halved on their next turn (rounded up).\"]Target DEF halved next turn[/hint]%s" % dur)
				else:
					var hint = _get_status_desc(effect.status_type)
					var amount_str = _get_amount_string(effect)
					if amount_str != "0" and amount_str != "":
						match effect.status_type:
							GameEnums.StatusType.STAT_BUFF_STR: hint = "Increases Strength (STR) by %s." % amount_str
							GameEnums.StatusType.STAT_BUFF_MAG: hint = "Increases Magic (MAG) by %s." % amount_str
							GameEnums.StatusType.STAT_BUFF_DEF: hint = "Increases Defense (DEF) by %s." % amount_str
							GameEnums.StatusType.STAT_BUFF_MOV: hint = "Increases Movement Points (MP) by %s." % amount_str
							GameEnums.StatusType.STAT_BUFF_ACC: hint = "Increases Accuracy (ACC) by %s." % amount_str
							GameEnums.StatusType.STAT_DEBUFF_DEF: hint = "Decreases Defense (DEF) by %s." % amount_str
							GameEnums.StatusType.STAT_DEBUFF_MOV: hint = "Decreases Movement Points (MP) by %s." % amount_str
							GameEnums.StatusType.STAT_DEBUFF_ACC: hint = "Decreases Accuracy (ACC) by %s." % amount_str
					parts.append("Apply %s%s" % [_kw_hint(_get_status_name(effect.status_type), hint), dur])
			GameEnums.EffectType.ADD_STATUS_SELF:
				var dur = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
				var hint = _get_status_desc(effect.status_type)
				var amount_str = _get_amount_string(effect)
				if amount_str != "0" and amount_str != "":
					match effect.status_type:
						GameEnums.StatusType.STAT_BUFF_STR: hint = "Increases Strength (STR) by %s." % amount_str
						GameEnums.StatusType.STAT_BUFF_MAG: hint = "Increases Magic (MAG) by %s." % amount_str
						GameEnums.StatusType.STAT_BUFF_DEF: hint = "Increases Defense (DEF) by %s." % amount_str
						GameEnums.StatusType.STAT_BUFF_MOV: hint = "Increases Movement Points (MP) by %s." % amount_str
						GameEnums.StatusType.STAT_BUFF_ACC: hint = "Increases Accuracy (ACC) by %s." % amount_str
						GameEnums.StatusType.STAT_DEBUFF_DEF: hint = "Decreases Defense (DEF) by %s." % amount_str
						GameEnums.StatusType.STAT_DEBUFF_MOV: hint = "Decreases Movement Points (MP) by %s." % amount_str
						GameEnums.StatusType.STAT_DEBUFF_ACC: hint = "Decreases Accuracy (ACC) by %s." % amount_str
				parts.append("Self %s%s" % [_kw_hint(_get_status_name(effect.status_type), hint), dur])
			GameEnums.EffectType.DAMAGE_SELF: parts.append("Self %s" % _kw_hint("ATK %s" % _get_amount_string(effect), "Ignores Armor and deals direct damage to caster."))
			GameEnums.EffectType.CLEANSE: parts.append(_kw_hint("CLEANSE", "Removes all negative status effects from target."))
			GameEnums.EffectType.PURGE: parts.append(_kw_hint("PURGE", "Removes all positive buffs and shields from target."))
			GameEnums.EffectType.DASH: parts.append(_kw_hint("DASH %s" % _get_amount_string(effect), "Move up to the listed distance in a straight line, passing through units. Stops at walls or immovable targets; may end on a movable enemy when followed by PUSH."))
			GameEnums.EffectType.DESTROY_OBSTACLE: parts.append(_kw_hint("DESTROY OBSTACLE", "Instantly removes a wall, trap, or destructible terrain."))
			GameEnums.EffectType.TELEPORT_CASTER: parts.append(_kw_hint("TELEPORT", "Instantly moves caster to the target tile, ignoring pathing constraints."))
			
	var body := " | ".join(parts) if not parts.is_empty() else "No effect"
	
	var shape_str = ""
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		var s_name = GameEnums.TargetShape.keys()[ability.target_shape].capitalize().replace("Aoe ", "")
		shape_str = "%s: %s %d | " % [
			_kw_hint("AOE", "Area effect — hits multiple tiles in the listed shape."),
			s_name,
			ability.target_shape_size,
		]
		
	return "%s%s%s" % [shape_str, body, _ability_upgrade_suffix(ability, unit, true)]

func _ability_effect_string(ability: AbilityData, unit: UnitState = null) -> String:
	if ability.id == &"knight_bowling_charge":
		return "DASH 3 | TRAMPLE | PUSH 1 | COLLISION. This unit does not suffer collision."
	var parts: Array[String] = []
	for effect in ability.effects:
		match effect.type:
			GameEnums.EffectType.DAMAGE: parts.append("ATK %s" % _get_amount_string(effect))
			GameEnums.EffectType.PUSH: parts.append("PUSH %s" % _get_amount_string(effect))
			GameEnums.EffectType.PULL: parts.append("PULL %s" % _get_amount_string(effect))
			GameEnums.EffectType.SWAP: parts.append("SWAP")
			GameEnums.EffectType.HEAL: parts.append("HEAL %s" % _get_amount_string(effect))
			GameEnums.EffectType.ARMOR_UP: parts.append("SHIELD %s" % _get_amount_string(effect))
			GameEnums.EffectType.EXPLODE: parts.append("EXPLODE %s" % _get_amount_string(effect))
			GameEnums.EffectType.RANGED_EXPLODE: parts.append("AOE ATK %s" % _get_amount_string(effect))
			GameEnums.EffectType.SPAWN: parts.append("SPAWN %s" % str(effect.spawn_unit_id).capitalize())
			GameEnums.EffectType.ADD_STATUS:
				var dur = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
				if effect.status_type == GameEnums.StatusType.IRON_GRIP_DEBUFF:
					parts.append("Target DEF halved next turn%s" % dur)
				else:
					parts.append("Apply %s%s" % [_get_status_name(effect.status_type), dur])
			GameEnums.EffectType.ADD_STATUS_SELF:
				var dur = "" if effect.status_duration == 1 else " (%d turns)" % effect.status_duration
				parts.append("Self %s%s" % [_get_status_name(effect.status_type), dur])
			GameEnums.EffectType.DAMAGE_SELF: parts.append("Self ATK %s" % _get_amount_string(effect))
			GameEnums.EffectType.CLEANSE: parts.append("CLEANSE")
			GameEnums.EffectType.PURGE: parts.append("PURGE")
			GameEnums.EffectType.DASH: parts.append("DASH %s" % _get_amount_string(effect))
			GameEnums.EffectType.DESTROY_OBSTACLE: parts.append("DESTROY OBSTACLE")
			GameEnums.EffectType.TELEPORT_CASTER: parts.append("TELEPORT")
			
	var body := " | ".join(parts) if not parts.is_empty() else "No effect"
	
	var shape_str = ""
	if ability.target_shape != GameEnums.TargetShape.SINGLE:
		var s_name = GameEnums.TargetShape.keys()[ability.target_shape].capitalize().replace("Aoe ", "")
		shape_str = "AOE: %s %d | " % [s_name, ability.target_shape_size]
		
	return "%s%s%s" % [shape_str, body, _ability_upgrade_suffix(ability, unit, false)]

func _ability_desc(ability: AbilityData, unit: UnitState = null) -> String:
	return "%s (RANGE %d | AP %d | %s)" % [ability.display_name, ability.range_tiles, ability.action_point_cost, _ability_effect_string(ability, unit)]

func _ability_hover_text() -> String:
	var unit := _board.get_unit_by_id(_selected_id)
	if unit == null or _hover_ability < 0 or _hover_ability >= unit.active_abilities.size():
		return "Hover a tile, unit, or ability for details."
	return _ability_desc(unit.active_abilities[_hover_ability], unit)

# --- Battle log ---------------------------------------------------------------

func _spawn_floating_text(u_id: int, amount: int, dmg_type: StringName) -> void:
	if amount <= 0:
		return
	if not _visual.has(u_id):
		return
		
	# Apply a random jitter so simultaneous damage numbers from different sources
	# don't completely overlap perfectly.
	var jitter = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
	var pos: Vector2 = _visual[u_id]["pos"] + jitter
	
	var ft = _floating_text_scene.instantiate()
	add_child(ft)
	ft.z_index = 100
	var color := Color.WHITE
	match dmg_type:
		&"physical": color = Color.WHITE
		&"magical": color = Color(0.7, 0.5, 1.0)
		&"burn": color = Color(1.0, 0.5, 0.0)
		&"poison": color = Color(0.6, 1.0, 0.4)
		&"bleed": color = Color(1.0, 0.2, 0.2)
		&"hazard", &"chasm", &"collision": color = Color(0.8, 0.4, 0.1)
		&"heal": color = Color(0.2, 1.0, 0.2)
		_: color = Color.WHITE
	ft.setup(pos, str(amount), color)

func _append_log(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_log_label.append_text("[font_size=%d]%s[/font_size]\n" % [LOG_FONT_SIZE, text])

func _collision_against_label(d: Dictionary) -> String:
	var against = d.get("against", "?")
	if against is String or against is StringName:
		if String(against) == "wall":
			var coord: Vector2i = d.get("coord", Vector2i.ZERO)
			return "a wall at (%d, %d)" % [coord.x, coord.y]
		return String(against)
	if against is int:
		return _unit_name(against)
	return str(against)

func _format_damage_source_tag(dmg_type: StringName, source_label: String) -> String:
	var label := source_label.strip_edges()
	if label.is_empty():
		match String(dmg_type):
			"collision": label = "collision"
			"hazard": label = "terrain"
			"bleed": label = "bleed"
			"burn": label = "burn"
			"poison": label = "poison"
			"true": label = "true damage"
			"magical": label = "magical attack"
			"physical": label = "attack"
			_: label = String(dmg_type)
	return " from %s" % label

func _fmt_calc_num(value: float) -> String:
	if not is_equal_approx(value, snappedf(value, 0.1)):
		return "%.2f" % value
	return "%.1f" % value

func _format_damage_telemetry(m: Dictionary, incoming: int, hp_dmg: int, armor_dmg: int) -> String:
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
		var base: int = m.get("base", 1)
		var wpn: int = m.get("wpn", 0)
		var stat_val: int = m.get("stat_val", 0)
		var excess: int = m.get("excess_push", 0)
		var base_bonus: int = m.get("base_bonus", 0)
		var t_def: int = m.get("target_def", 0)
		var fort: int = m.get("fortitude", m.get("fort", 0))
		var mult_raw: float = m.get("multiplier_raw", float(m.get("floored", m.get("final_raw", 0))))
		var stat_mult: float = 1.0 + float(stat_val) / 5.0
		var raw_base: float = 1.0 + float(excess) / 3.0 + float(base_bonus)
		var base_parts := "1 + %s/3" % _fmt_calc_num(float(excess))
		if base_bonus > 0:
			base_parts += " + %d Retaliator" % base_bonus
		var formula := "%s × (%s + %s) × %s" % [
			_color(c_mult, "0.75"), _color(c_base, "BASE"), _color(c_wpn, "WPN"), _color(c_stat, "STR mult"),
		]
		formula += " - %s" % _color(c_def, "DEF")
		if fort != 0:
			formula += " - %s" % _color(c_fort, "FORT")
		formula += "\n   BASE %s = %s" % [_color(c_base, base_parts), _color(c_base, _fmt_calc_num(raw_base))]
		if int(floorf(raw_base)) != base:
			formula += " → %s" % _color(c_base, _fmt_calc_num(float(base)))
		formula += "\n   %s × (%s + %s) × %s = %s" % [
			_color(c_mult, "0.75"),
			_color(c_base, _fmt_calc_num(float(base))),
			_color(c_wpn, _fmt_calc_num(float(wpn))),
			_color(c_stat, _fmt_calc_num(stat_mult)),
			_color(c_final, _fmt_calc_num(mult_raw)),
		]
		formula += "\n   %s - %s" % [_color(c_final, _fmt_calc_num(mult_raw)), _color(c_def, _fmt_calc_num(float(t_def)))]
		if fort != 0:
			formula += " - %s" % _color(c_fort, _fmt_calc_num(float(fort)))
		formula += " = %s incoming" % _color(c_final, _fmt_calc_num(float(incoming)))
		if armor_dmg > 0:
			formula += "\n   - %s armor → %s HP" % [
				_color(c_def, _fmt_calc_num(float(armor_dmg))),
				_color(c_final, _fmt_calc_num(float(hp_dmg))),
			]
		return formula
	var stat_name: String = m.get("stat_name", "STR")
	var base: int = m.get("base", 0)
	var wpn: int = m.get("wpn", 0)
	var stat_val: int = m.get("stat_val", 0)
	var mult_raw: float = m.get("multiplier_raw", float(m.get("final_raw", m.get("floored", 0))))
	var stat_mult: float = 1.0 + float(stat_val) / 5.0
	var t_def: int = m.get("target_def", 0)
	var fort: int = m.get("fortitude", m.get("fort", 0))
	var vuln: bool = m.get("vulnerable", m.get("vuln", false))
	var elec: bool = m.get("electrified", m.get("elec", false))
	var formula := "(%s + %s) × %s" % [
		_color(c_base, "Base"), _color(c_wpn, "WPN"), _color(c_stat, "%s mult" % stat_name),
	]
	if vuln or elec:
		formula += " + %s" % _color(c_status, "Status")
	formula += " - %s" % _color(c_def, "DEF")
	if fort != 0:
		formula += " - %s" % _color(c_fort, "FORT")
	formula += "\n   (%s + %s) × %s = %s" % [
		_color(c_base, _fmt_calc_num(float(base))),
		_color(c_wpn, _fmt_calc_num(float(wpn))),
		_color(c_stat, _fmt_calc_num(stat_mult)),
		_color(c_final, _fmt_calc_num(mult_raw)),
	]
	if vuln:
		formula += " + %s" % _color(c_status, "2.0 (Vuln)")
	if elec:
		formula += " + %s" % _color(c_status, "1.0 (Elec)")
	formula += " - %s" % _color(c_def, _fmt_calc_num(float(t_def)))
	if fort != 0:
		formula += " - %s" % _color(c_fort, _fmt_calc_num(float(fort)))
	var calc_val := mult_raw
	if vuln:
		calc_val += 2.0
	if elec:
		calc_val += 1.0
	calc_val -= float(t_def)
	calc_val -= float(fort)
	formula += " = %s" % _color(c_final, _fmt_calc_num(maxf(0.0, calc_val)))
	if m.get("backstab", false):
		formula += "\n   + %s (%s)" % [
			_color(c_status, "Backstab"),
			_fmt_calc_num(float(m.get("backstab_bonus", 0))),
		]
	return formula

func _log_line(event: SimEvent) -> String:
	var d := event.data
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			if not d.get("is_dash", false):
				_last_math_telemetry.clear()
			return _color(HEX_MOVE, "%s moves to %s" % [_unit_name(d.get("actor", -1)), d.get("to", Vector2i.ZERO)])
		GameEnums.SimEventType.UNIT_PUSHED:
			_last_math_telemetry.clear()
			return _color(HEX_MOVE, "%s is displaced to %s" % [_unit_name(d.get("unit", -1)), d.get("to", Vector2i.ZERO)])
		GameEnums.SimEventType.COLLISION:
			var excess: int = d.get("excess_push", 0)
			var push_dist: int = d.get("push_distance", 0)
			var detail := "%s collides with %s" % [_unit_name(d.get("unit", -1)), _collision_against_label(d)]
			if push_dist > 0:
				detail += " (push %d, excess %d)" % [push_dist, excess]
			return _color(HEX_DMG, detail)
		GameEnums.SimEventType.MATH_TELEMETRY:
			_last_math_telemetry = d.duplicate(true)
			return ""
		GameEnums.SimEventType.ABILITY_USED:
			if not d.get("is_dash", false):
				_last_math_telemetry.clear()
			var ability_name: String = d.get("ability_name", "an ability")
			var actor_name = _unit_name(d.get("actor", -1))
			var t_id = d.get("target_unit", -1)
			if t_id != -1:
				return _color(HEX_ATTACK, "%s uses %s on %s" % [actor_name, ability_name, _unit_name(t_id)])
			elif d.has("target_coord"):
				var c: Vector2i = d["target_coord"]
				return _color(HEX_ATTACK, "%s uses %s on tile (%d, %d)" % [actor_name, ability_name, c.x, c.y])
			else:
				return _color(HEX_ATTACK, "%s uses %s" % [actor_name, ability_name])
		GameEnums.SimEventType.COUNTER_ATTACK:
			var ca_actor := _unit_name(d.get("actor", -1))
			var ca_target := _unit_name(d.get("target_unit", -1))
			var ca_label: String = d.get("source_label", "Counter Attack")
			var ca_power: int = d.get("atk_power", 1)
			return _color(HEX_ATTACK, "%s counter-attacks %s with ATK %d (%s)" % [ca_actor, ca_target, ca_power, ca_label])
		GameEnums.SimEventType.UNIT_DAMAGED:
			var incoming: int = d.get("amount", 0)
			var hp_dmg: int = d.get("hp_damaged", incoming)
			var armor_dmg: int = d.get("armor_damaged", 0)
			var dmg_type: StringName = d.get("damage_type", &"physical")
			var source_tag := _format_damage_source_tag(dmg_type, d.get("source_label", ""))
			var after_hp: int = d.get("hp", 0)
			var before_hp: int = after_hp + hp_dmg
			var hp_note := " (%d HP -> %d HP)" % [before_hp, after_hp]
			if armor_dmg > 0:
				hp_note += ", %d armor" % armor_dmg
			var final_str := _color(HEX_DMG, "%s takes %d damage%s%s" % [
				_unit_name(d.get("unit", -1)), incoming, source_tag, hp_note,
			])
			if incoming <= 0:
				final_str = _color(HEX_DMG, "%s takes 0 damage (fully mitigated)%s" % [
					_unit_name(d.get("unit", -1)), source_tag,
				])
			if not _last_math_telemetry.is_empty():
				var m = _last_math_telemetry
				var formula := _format_damage_telemetry(m, incoming, hp_dmg, armor_dmg)
				final_str += "\n[color=#aaaaaa][font_size=%d]   %s[/font_size][/color]" % [LOG_FORMULA_FONT_SIZE, formula]
				_last_math_telemetry.clear()
			return final_str
		GameEnums.SimEventType.UNIT_DIED:
			return _color(HEX_DEATH, "%s is defeated" % _unit_name(d.get("unit", -1)))
		GameEnums.SimEventType.UNIT_FACED:
			return _color(HEX_MOVE, "%s turns to face %s" % [_unit_name(d.get("unit", -1)), _facing_name(d.get("facing", GameEnums.Facing.SOUTH))])
		GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
			return _color(HEX_INTENT, "- enemy phase -")
		GameEnums.SimEventType.TURN_ENDED:
			return _color(HEX_TURN, "--- Turn %s ---" % d.get("turn", 0))
		_:
			return ""

func _color(hex: String, text: String) -> String:
	return "[color=#%s]%s[/color]" % [hex, text]

func _unit_name(unit_id: int) -> String:
	if _board != null:
		var unit := _board.get_unit_by_id(unit_id)
		if unit != null:
			return unit.definition.display_name
	return "Unit %d" % unit_id

# --- HUD ----------------------------------------------------------------------

func _update_players_panel() -> void:
	if _players_label == null: return
	var text = "[b]Players[/b]\n"
	var status_text = "Planning"
	if CombatDirector.is_executing_phase(_phase):
		status_text = "Executing"
		
	if NetworkManager != null and NetworkManager.is_multiplayer:
		for peer_id in NetworkManager.player_usernames.keys():
			var username = NetworkManager.player_usernames[peer_id]
			var hex = _get_player_color(peer_id).to_html(false)
			var ready = GlobalTimeline.player_ready_states.get(peer_id, false)
			var status = "Ready" if ready else status_text
			if status_text == "Executing": status = "Executing"
			text += "[font_size=12][color=#%s]%s[/color]: %s[/font_size]\n" % [hex, username, status]
	else:
		var ready = _is_local_ready
		var hex = _get_player_color(1).to_html(false)
		var status = "Ready" if ready else status_text
		if status_text == "Executing": status = "Executing"
		text += "[font_size=12][color=#%s]Player[/color]: %s[/font_size]\n" % [hex, status]
	_players_label.text = text

@rpc("any_peer", "call_local")
func rpc_receive_chat(sender_id: int, message: String) -> void:
	var username = "Player"
	var hex = _get_player_color(sender_id).to_html(false)
	if NetworkManager != null and NetworkManager.is_multiplayer:
		username = NetworkManager.player_usernames.get(sender_id, "Player %d" % sender_id)
	_chat_log.append_text("[font_size=12][b][color=#%s]%s[/color][/b]: %s[/font_size]\n" % [hex, username, message])
	_chat_fade_timer = 5.0
	_chat_panel.modulate.a = 1.0

func _send_chat(text: String) -> void:
	if text.strip_edges() == "": return
	_chat_input.text = ""
	if NetworkManager != null and NetworkManager.is_multiplayer:
		_receive_chat_msg(NetworkManager.local_player_id, text)
	else:
		rpc_receive_chat(1, text)

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	_bottom_hud = PanelContainer.new()
	_bottom_hud.add_theme_stylebox_override("panel", _make_panel_style())
	_hud_layer.add_child(_bottom_hud)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	_bottom_hud.add_child(hbox)

	# Mid column (now the left-most)
	var mid_col = VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mid_col)

	var local_hex = _get_player_color(NetworkManager.local_player_id).to_html(false) if NetworkManager != null and NetworkManager.is_multiplayer else _get_player_color(1).to_html(false)
	_tint(_make_label(mid_col, "👥 Party & Actions:"), local_hex)
	
	var plan_scroll = ScrollContainer.new()
	plan_scroll.custom_minimum_size.y = 180
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid_col.add_child(plan_scroll)
	
	_timeline_box = GridContainer.new()
	_timeline_box.columns = 5
	_timeline_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_box.add_theme_constant_override("h_separation", 12)
	_timeline_box.add_theme_constant_override("v_separation", 8)
	plan_scroll.add_child(_timeline_box)
	
	_warn_label = RichTextLabel.new()
	_warn_label.bbcode_enabled = true
	_warn_label.fit_content = true
	mid_col.add_child(_warn_label)

	# Execute Column (Center)
	var exec_col = VBoxContainer.new()
	exec_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(exec_col)
	
	_phase_label = _make_label(exec_col, "⏱️ Phase: PLANNING")
	_phase_label.add_theme_font_size_override("font_size", 20)
	_tint(_phase_label, HEX_PHASE)
	
	_execute_btn = _make_button(exec_col, "Ready to Execute", func() -> void:
		_sfx.play("execute")
		_set_timeline_ready(not _is_local_ready)
	)
	_execute_btn.custom_minimum_size = Vector2(180, 50)
	_execute_btn.add_theme_font_size_override("font_size", 18)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Right Column: Controls & Info
	var right_col = VBoxContainer.new()
	right_col.custom_minimum_size.x = 280
	hbox.add_child(right_col)

	_intent_label = _make_label(right_col, "💀 Enemy intent:")
	_tint(_intent_label, HEX_INTENT)

	var score_hbox = HBoxContainer.new()
	right_col.add_child(score_hbox)
	
	_score_lbl = _make_label(score_hbox, "🤖 AI Score: --")
	_score_lbl.set_script(preload("res://presentation/rich_tooltip_label.gd"))
	_score_lbl.tooltip_text = "Hover over a valid action tile to see its tactical utility breakdown."
	_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var calc_toggle = CheckButton.new()
	calc_toggle.text = "Calc"
	calc_toggle.button_pressed = _ai_calc_enabled
	calc_toggle.toggled.connect(func(toggled_on: bool) -> void:
		_ai_calc_enabled = toggled_on
		if not _ai_calc_enabled:
			_score_lbl.text = "🤖 AI Score: OFF"
			_score_lbl.tooltip_text = "AI Calculations disabled"
	)
	score_hbox.add_child(calc_toggle)

	var btn_grid = GridContainer.new()
	btn_grid.columns = 2
	right_col.add_child(btn_grid)
	
	_undo_btn = _make_button(btn_grid, "Undo", func() -> void:
		_sfx.play("cancel")
		if _selected_id >= 0:
			_remove_last_for_unit(_selected_id)
	)
	_clear_btn = _make_button(btn_grid, "Clear", func() -> void:
		_sfx.play("cancel")
		if NetworkManager != null and NetworkManager.is_multiplayer:
			for u in _board.units:
				if u.controlling_player_id == NetworkManager.local_player_id:
					_clear_unit_actions(u.id)
		else:
			for u in _board.units:
				if not u.is_enemy():
					_clear_unit_actions(u.id)
	)
		
	var danger_btn = _make_button(btn_grid, "Danger Area", func() -> void:
		_show_danger_area = not _show_danger_area
		queue_redraw())
		
	var full_btn_ref: Array[Button] = [null]
	var phase_btn_ref: Array[Button] = [null]

	var full_btn = _make_button(btn_grid, "Full Autobattle: OFF", func() -> void:
		_autobattler_active = not _autobattler_active
		if _autobattler_active:
			_autobattler_hook.set_active(true)
			full_btn_ref[0].text = "Full Autobattle: ON"
			phase_btn_ref[0].text = "Phase Autobattle: OFF"
		else:
			_autobattler_hook.set_active(false)
			full_btn_ref[0].text = "Full Autobattle: OFF"
	)
	full_btn_ref[0] = full_btn
	
	var phase_btn = _make_button(btn_grid, "Phase Autobattle: OFF", func() -> void:
		_autobattler_active = false
		if not _autobattler_hook.is_active():
			_autobattler_hook.set_active(true, true)
			phase_btn_ref[0].text = "Phase Autobattle: ON"
			full_btn_ref[0].text = "Full Autobattle: OFF"
		else:
			_autobattler_hook.set_active(false)
			phase_btn_ref[0].text = "Phase Autobattle: OFF"
	)
	phase_btn_ref[0] = phase_btn

	var aggro_hbox = HBoxContainer.new()
	aggro_hbox.add_theme_constant_override("separation", 10)
	right_col.add_child(aggro_hbox)
	
	var aggro_label = Label.new()
	aggro_label.text = "Aggro: 0.5"
	aggro_hbox.add_child(aggro_label)
	
	var aggro_slider = HSlider.new()
	aggro_slider.min_value = 0.0
	aggro_slider.max_value = 1.0
	aggro_slider.step = 0.05
	aggro_slider.value = 0.5
	aggro_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aggro_slider.value_changed.connect(func(val: float) -> void:
		aggro_label.text = "Aggro: %.2f" % val
		if _autobattler_hook != null and _autobattler_hook._ai_instance != null:
			_autobattler_hook._ai_instance.aggressiveness = val
	)
	aggro_hbox.add_child(aggro_slider)

	_build_pause_menu()
	_build_banner(_hud_layer)

	# Hover Info HUD
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_hud_layer.add_child(_info_panel)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	_info_panel.add_child(info_vbox)
	
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.add_theme_font_size_override("normal_font_size", 9)
	_info_label.custom_minimum_size = Vector2(290, 180)
	_info_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(_info_label)
	
	var force_move_toggle := CheckBox.new()
	force_move_toggle.text = "Force Basic Movement"
	force_move_toggle.tooltip_text = "When enabled, click or drag to walk instead of using the selected skill when a basic move is possible."
	force_move_toggle.toggled.connect(func(pressed: bool) -> void:
		_force_basic_movement = pressed
		_cached_hover_unit_id = -1
		_recompute_hover_ranges()
		_update_mouse_cursor()
		_refresh_info()
		queue_redraw()
	)
	info_vbox.add_child(force_move_toggle)
	
	var skill_scroll = ScrollContainer.new()
	skill_scroll.custom_minimum_size.y = 200
	skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(skill_scroll)
	
	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_scroll.add_child(_skill_list)

	_tile_info_panel = PanelContainer.new()
	_tile_info_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_hud_layer.add_child(_tile_info_panel)
	
	_tile_info_label = RichTextLabel.new()
	_tile_info_label.bbcode_enabled = true
	_tile_info_label.add_theme_font_size_override("normal_font_size", 9)
	_tile_info_label.custom_minimum_size = Vector2(290, TILE_INFO_PANEL_HEIGHT - 10)
	_tile_info_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_tile_info_panel.add_child(_tile_info_label)

	_left_panel = VBoxContainer.new()
	_left_panel.add_theme_constant_override("separation", 10)
	_hud_layer.add_child(_left_panel)
	
	_players_panel = PanelContainer.new()
	_players_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_left_panel.add_child(_players_panel)
	_players_label = RichTextLabel.new()
	_players_label.bbcode_enabled = true
	_players_label.fit_content = true
	_players_panel.add_child(_players_label)
	_update_players_panel()
	
	_log_panel = PanelContainer.new()
	_log_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_log_panel.visible = true
	_log_panel.custom_minimum_size.y = LOG_PANEL_HEIGHT
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_panel.add_child(_log_panel)
	
	var log_vbox := VBoxContainer.new()
	_log_panel.add_child(log_vbox)
	
	var log_header := HBoxContainer.new()
	log_vbox.add_child(log_header)
	
	var log_title := Label.new()
	log_title.text = "📜 Battle Log"
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint(log_title, local_hex)
	log_header.add_child(log_title)
	
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.add_theme_font_size_override("normal_font_size", LOG_FONT_SIZE)
	_log_label.add_theme_font_size_override("bold_font_size", LOG_FONT_SIZE)
	_log_label.add_theme_font_size_override("italics_font_size", LOG_FONT_SIZE)
	_log_label.add_theme_font_size_override("mono_font_size", LOG_FONT_SIZE)
	_log_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(_log_label)
	
	_chat_panel = PanelContainer.new()
	var chat_style = StyleBoxEmpty.new()
	_chat_panel.add_theme_stylebox_override("panel", chat_style)
	_chat_panel.modulate.a = 0.0
	_chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_panel.add_child(_chat_panel)
	var chat_vbox = VBoxContainer.new()
	_chat_panel.add_child(chat_vbox)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("outline_size", 4)
	_chat_log.add_theme_color_override("font_outline_color", Color.BLACK)
	chat_vbox.add_child(_chat_log)
	var chat_hbox = HBoxContainer.new()
	chat_vbox.add_child(chat_hbox)
	_chat_input = LineEdit.new()
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.text_submitted.connect(_send_chat)
	chat_hbox.add_child(_chat_input)
	
	_layout_hud()

func _layout_hud() -> void:
	if _bottom_hud == null:
		return
	var vp := get_viewport_rect().size
	_bottom_hud.position = Vector2(0, vp.y - 220)
	_bottom_hud.size = Vector2(vp.x, 220)
	
	_tile_info_panel.position = Vector2(vp.x - 310, 20)
	_tile_info_panel.size = Vector2(290, TILE_INFO_PANEL_HEIGHT)
	
	var unit_info_top := 20.0 + TILE_INFO_PANEL_HEIGHT + 10.0
	_info_panel.position = Vector2(vp.x - 310, unit_info_top)
	_info_panel.size = Vector2(290, max(250, vp.y - unit_info_top - 240))
	
	if _left_panel != null:
		_left_panel.position = Vector2(20, 20)
		_left_panel.size = Vector2(280, vp.y - 260)
	
	if _board != null:
		# The board backdrop is drawn at (ORIGIN - 6) with size (grid_px + 12).
		# We need self.position such that the backdrop's center lands in the
		# center of the available screen space between the panels.
		var top_space    := 20.0
		var bottom_space := 220.0
		var left_space   := 300.0
		var right_space  := 310.0

		var avail_y := vp.y - bottom_space - top_space
		var avail_x := vp.x - left_space - right_space

		# Visual bounds of the backdrop in local (unscaled) Node2D space
		var backdrop_tl := ORIGIN - Vector2(6.0, 6.0)
		var backdrop_size := _grid_pixel_size() + Vector2(12.0, 12.0)

		# Scale so the backdrop fits the available space
		var s := minf(avail_y / backdrop_size.y, avail_x / backdrop_size.x)
		self.scale = Vector2(s, s)

		# Screen-space center of the available area
		var screen_cx := left_space + avail_x * 0.5
		var screen_cy := top_space  + avail_y * 0.5

		# Local-space center of the backdrop
		var local_cx := backdrop_tl.x + backdrop_size.x * 0.5
		var local_cy := backdrop_tl.y + backdrop_size.y * 0.5

		# self.position + local_center * s == screen_center  =>
		self.position.x = screen_cx - local_cx * s
		self.position.y = screen_cy - local_cy * s

func _rebuild_ability_buttons() -> void:
	for c in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()

	var unit: UnitState = _proj_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id) if _board != null else null
	if unit == null: return
	
	var abilities := unit.active_abilities
	for i in range(abilities.size()):
		var ability: AbilityData = abilities[i]
		var index := i
		
		var row_btn = Button.new()
		_apply_button_style(row_btn)
		var can_afford := unit.ability.points_left >= ability.action_point_cost
		row_btn.disabled = not can_afford
		row_btn.modulate = _skill_button_modulate(i, can_afford)
		row_btn.pressed.connect(func() -> void: _director.select_ability(index))
		row_btn.tooltip_text = _ability_desc(ability, unit)
		_skill_list.add_child(row_btn)
		
		var btn_vbox = VBoxContainer.new()
		btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		row_btn.add_child(btn_vbox)
		
		# Name (Line 1)
		var name_lbl = Label.new()
		name_lbl.text = ability.display_name
		name_lbl.add_theme_font_size_override("font_size", 9)
		btn_vbox.add_child(name_lbl)
		
		# Values (Line 2)
		var values_hbox = HBoxContainer.new()
		values_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		values_hbox.add_theme_constant_override("separation", 16)
		btn_vbox.add_child(values_hbox)
		
		# AP
		values_hbox.add_child(_make_icon("🔵", str(ability.action_point_cost), "AP (Action Points required)"))
		
		# Range
		values_hbox.add_child(_make_icon("🏹", str(ability.range_tiles), "Range (Max target distance)"))
		
		# Effects (Line 3)
		var special = RichTextLabel.new()
		special.bbcode_enabled = true
		special.fit_content = true
		special.mouse_filter = Control.MOUSE_FILTER_PASS
		special.custom_minimum_size.x = 240
		var eff_bbcode = _ability_effect_bbcode(ability, unit)
		special.text = "[font_size=10]%s[/font_size]" % eff_bbcode
		btn_vbox.add_child(special)
			
		# Enforce button size to wrap the hbox, calculate height dynamically
		var raw_text = ""
		var in_tag = false
		for c_idx in range(eff_bbcode.length()):
			var c = eff_bbcode[c_idx]
			if c == '[': in_tag = true
			elif c == ']': in_tag = false
			elif not in_tag: raw_text += c
			
		var text_lines = 1 + int(raw_text.length() / 38.0)
		row_btn.custom_minimum_size.y = 54 + (text_lines * 16)

func _make_icon(emoji: String, val: String, tip: String) -> Control:
	var c = HBoxContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.tooltip_text = tip
	var e = Label.new()
	e.text = emoji
	e.add_theme_font_size_override("font_size", 14)
	var v = Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 14)
	c.add_child(e)
	c.add_child(v)
	return c

func _close_pause_menu() -> void:
	if _pause_menu != null:
		_pause_menu.visible = false
	if _info_panel != null:
		_info_panel.visible = true
	if _tile_info_panel != null:
		_tile_info_panel.visible = true

func _build_pause_menu() -> void:
	_pause_menu = ColorRect.new()
	_pause_menu.color = Color(0, 0, 0, 0.85)
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false
	_hud_layer.add_child(_pause_menu)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	_pause_menu.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(vbox)
	
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	_make_button(vbox, "Resume", func() -> void:
		_close_pause_menu()
	)
	_make_button(vbox, "Settings", func() -> void:
		var opt = _options_scene.instantiate()
		_hud_layer.add_child(opt)
		opt.close_requested.connect(func(): opt.queue_free())
	)
	_make_button(vbox, "Compendium", func() -> void:
		var comp: CompendiumScreen = _compendium_scene.instantiate()
		comp.overlay_mode = true
		comp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hud_layer.add_child(comp)
	)
	_make_button(vbox, "Restart Turn", func() -> void:
		_close_pause_menu()
		_director.restart_turn()
	)
	_make_button(vbox, "Restart Battle", func() -> void:
		_close_pause_menu()
		_director.restart()
	)
	_make_button(vbox, "Exit to Main Menu", func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	hbox.add_child(margin)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(right_vbox)
	
	_sandbox_container = VBoxContainer.new()
	_sandbox_container.custom_minimum_size = Vector2(300, 0)
	
	var sandbox_panel = PanelContainer.new()
	var sandbox_margin = MarginContainer.new()
	sandbox_margin.add_theme_constant_override("margin_left", 15)
	sandbox_margin.add_theme_constant_override("margin_right", 15)
	sandbox_margin.add_theme_constant_override("margin_top", 15)
	sandbox_margin.add_theme_constant_override("margin_bottom", 15)
	sandbox_panel.add_child(sandbox_margin)
	sandbox_margin.add_child(_sandbox_container)
	right_vbox.add_child(sandbox_panel)
	
	_sandbox_title = Label.new()
	_sandbox_title.text = "Sandbox Overrides"
	_sandbox_title.add_theme_font_size_override("font_size", 24)
	_sandbox_container.add_child(_sandbox_title)
	
	var hp_hbox = HBoxContainer.new()
	var hp_lbl = Label.new()
	hp_lbl.text = "Current HP: "
	hp_hbox.add_child(hp_lbl)
	_sandbox_hp = SpinBox.new()
	_sandbox_hp.max_value = 9999
	_sandbox_hp.value_changed.connect(func(v: float):
		if _director.selected_unit_id >= 0:
			var u = _director.base_board.get_unit_by_id(_director.selected_unit_id)
			if u: 
				u.health.current_hp = int(v)
				_director._refresh_plan()
				EventBus.board_changed.emit(_director.board)
				queue_redraw()
	)
	hp_hbox.add_child(_sandbox_hp)
	_sandbox_container.add_child(hp_hbox)
	
	var max_hp_hbox = HBoxContainer.new()
	var mhp_lbl = Label.new()
	mhp_lbl.text = "Max HP: "
	max_hp_hbox.add_child(mhp_lbl)
	_sandbox_max_hp = SpinBox.new()
	_sandbox_max_hp.max_value = 9999
	_sandbox_max_hp.value_changed.connect(func(v: float):
		if _director.selected_unit_id >= 0:
			var u = _director.base_board.get_unit_by_id(_director.selected_unit_id)
			if u:
				u.health.max_hp = int(v)
				_director._refresh_plan()
				EventBus.board_changed.emit(_director.board)
				queue_redraw()
	)
	max_hp_hbox.add_child(_sandbox_max_hp)
	_sandbox_container.add_child(max_hp_hbox)
	
	var st_hbox = HBoxContainer.new()
	_sandbox_status_dd = OptionButton.new()
	for key in GameEnums.StatusType.keys():
		_sandbox_status_dd.add_item(key, GameEnums.StatusType[key])
	st_hbox.add_child(_sandbox_status_dd)
	var apply_st = Button.new()
	apply_st.text = "Inject Status"
	apply_st.pressed.connect(func():
		if _director.selected_unit_id >= 0:
			var u = _director.base_board.get_unit_by_id(_director.selected_unit_id)
			if u:
				var st = StatusData.new(_sandbox_status_dd.get_selected_id() as GameEnums.StatusType, 3, 1)
				u.active_statuses.append(st)
				u._recalculate_stats()
				_director._refresh_plan()
				EventBus.board_changed.emit(_director.board)
				queue_redraw()
	)
	st_hbox.add_child(apply_st)
	_sandbox_container.add_child(st_hbox)
	
	var clr_st = Button.new()
	clr_st.text = "Clear All Statuses"
	clr_st.pressed.connect(func():
		if _director.selected_unit_id >= 0:
			var u = _director.base_board.get_unit_by_id(_director.selected_unit_id)
			if u:
				u.active_statuses.clear()
				u._recalculate_stats()
				_director._refresh_plan()
				EventBus.board_changed.emit(_director.board)
				queue_redraw()
	)
	_sandbox_container.add_child(clr_st)
	
	_map_editor_container = VBoxContainer.new()
	_map_editor_container.custom_minimum_size = Vector2(300, 0)
	
	var map_panel = PanelContainer.new()
	var map_margin = MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 15)
	map_margin.add_theme_constant_override("margin_right", 15)
	map_margin.add_theme_constant_override("margin_top", 15)
	map_margin.add_theme_constant_override("margin_bottom", 15)
	map_panel.add_child(map_margin)
	map_margin.add_child(_map_editor_container)
	right_vbox.add_child(map_panel)
	
	_map_editor_title = Label.new()
	_map_editor_title.text = "Map Editor: Hovered Tile"
	_map_editor_title.add_theme_font_size_override("font_size", 24)
	_map_editor_container.add_child(Label.new()) # Spacer
	_map_editor_container.add_child(_map_editor_title)
	
	var tile_hbox = HBoxContainer.new()
	_map_editor_dd = OptionButton.new()
	_map_editor_dd.add_item("Plain", 0)
	_map_editor_dd.add_item("Wall", 1)
	_map_editor_dd.add_item("Tall Grass", 2)
	_map_editor_dd.add_item("Castle", 3)
	_map_editor_dd.add_item("Spikes", 4)
	_map_editor_dd.add_item("Shallows", 5)
	tile_hbox.add_child(_map_editor_dd)
	
	var apply_tile = Button.new()
	apply_tile.text = "Set Terrain"
	apply_tile.pressed.connect(func():
		if _director != null and _director.base_board != null and _director.base_board.is_in_bounds(_hover_coord):
			var t := TerrainData.new()
			match _map_editor_dd.get_selected_id():
				0: t.id = &"plain"; t.display_name = "Plain"
				1: t.id = &"wall"; t.display_name = "Wall"; t.blocks_movement = true; t.stops_displacement = true
				2: t.id = &"tall_grass"; t.display_name = "Tall Grass"; t.fortitude = 1
				3: t.id = &"castle"; t.display_name = "Castle"; t.fortitude = 2
				4: t.id = &"spikes"; t.display_name = "Spikes"; t.hazard_damage = 2; t.blocks_movement = false
				5: t.id = &"water"; t.display_name = "Shallows"; t.fortitude = -1; t.blocks_movement = false; t.stops_displacement = false; t.hazard_damage = 0
			var new_tile = TileState.create(_hover_coord, t)
			_director.base_board.tiles[_hover_coord] = new_tile
			_director._refresh_plan()
			EventBus.board_changed.emit(_director.board)
			queue_redraw()
	)
	tile_hbox.add_child(apply_tile)
	_map_editor_container.add_child(tile_hbox)

func _refresh_sandbox_panel() -> void:
	if _map_editor_container != null:
		if _director == null or _director.board == null or not _director.board.is_in_bounds(_hover_coord):
			_map_editor_container.get_parent().get_parent().visible = false
		else:
			_map_editor_container.get_parent().get_parent().visible = true
			_map_editor_title.text = "Map Editor: Tile " + str(_hover_coord)

	if _sandbox_container == null: return
	if _director == null or _director.selected_unit_id < 0:
		_sandbox_container.get_parent().get_parent().visible = false
		return
	var u = _director.board.get_unit_by_id(_director.selected_unit_id)
	if u == null:
		_sandbox_container.get_parent().get_parent().visible = false
		return
	_sandbox_container.get_parent().get_parent().visible = true
	_sandbox_title.text = "Sandbox: Unit " + str(u.id)
	_sandbox_hp.set_value_no_signal(u.health.current_hp)
	_sandbox_max_hp.set_value_no_signal(u.health.max_hp)

func _draw_danger_area() -> void:
	if not _show_danger_area or _board == null:
		return
		
	if _danger_tiles_dirty:
		_danger_tiles_cache.clear()
		for u in _board.units:
			if u.is_alive() and u.is_enemy():
				var reach = [u.position]
				for y in range(_board.grid_size.y):
					for x in range(_board.grid_size.x):
						var c = Vector2i(x, y)
						if c != u.position:
							var path = MovementSystem.find_path(_board, u.position, c, u.movement.points_left)
							if not path.is_empty() and path[path.size() - 1] == c:
								reach.append(c)
				var rng := _unit_attack_range(u)
				for r in reach:
					for y in range(_board.grid_size.y):
						for x in range(_board.grid_size.x):
							var c = Vector2i(x, y)
							if GridSystem.manhattan(c, r) <= rng:
								_danger_tiles_cache[c] = true
		_danger_tiles_dirty = false
								
	for c in _danger_tiles_cache:
		if typeof(c) == TYPE_VECTOR2I:
			_draw_tile_tint(c, COLOR_DANGER)

func _set_panel_inner_size(panel: PanelContainer, inner_size: Vector2) -> void:
	pass


func _build_banner(layer: CanvasLayer) -> void:
	_banner = CenterContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.visible = false
	layer.add_child(_banner)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	_banner.add_child(dim)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_banner.add_child(box)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	box.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(inner)
	panel.add_child(margin)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 48)
	_banner_label.add_theme_color_override("font_color", COLOR_TEXT)
	inner.add_child(_banner_label)

	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void:
		_hide_banner()
		_director.restart())
	_apply_button_style(restart)
	inner.add_child(restart)

func _show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true

func _hide_banner() -> void:
	_banner.visible = false

func _make_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _tint(label: Label, hex: String) -> void:
	label.add_theme_color_override("font_color", Color.html(hex))

func _make_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	_apply_button_style(button)
	parent.add_child(button)
	return button

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_button_style() -> StyleBoxFlat:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.17, 0.21)
	normal.border_color = COLOR_PANEL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	return normal

func _apply_button_style(button: Button) -> void:
	var normal := _make_button_style()
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.24, 0.30)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.13, 0.16)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.11, 0.12, 0.14, 0.7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_HOVER)
	button.add_theme_color_override("font_pressed_color", COLOR_SELECT)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64))

# --- Targeting helpers --------------------------------------------------------

func _cancel_aim() -> void:
	if _aiming:
		_aiming = false
		_hover_predicted_hp.clear()
		_hover_predicted_armor.clear()
		_drag_predicted_hp.clear()
		_drag_predicted_armor.clear()
		_aim_intents.clear()
		_drag_intents.clear()
		_restore_committed_preview()
		_update_mouse_cursor()
		_recompute_intent_units()
		queue_redraw()

func _set_ability_hover(index: int) -> void:
	_hover_ability = index
	_refresh_info()

func _ability_range(actor: UnitState) -> int:
	var abilities := actor.active_abilities
	if _selected_ability < 0 or _selected_ability >= abilities.size():
		return -1
	return abilities[_selected_ability].range_tiles

func _play_attack_lunge(unit_id: int, anim_dir: Vector2) -> void:
	if not _visual.has(unit_id):
		return
	var start_pos: Vector2 = _visual[unit_id]["pos"]
	var pull_back := start_pos - anim_dir * 10.0
	var thrust := start_pos + anim_dir * 20.0
	var tw := create_tween()
	tw.tween_method(func(val: Vector2) -> void:
		if _visual.has(unit_id):
			_visual[unit_id]["pos"] = val
			queue_redraw()
	, start_pos, pull_back, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(val: Vector2) -> void:
		if _visual.has(unit_id):
			_visual[unit_id]["pos"] = val
			queue_redraw()
	, pull_back, thrust, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(val: Vector2) -> void:
		if _visual.has(unit_id):
			_visual[unit_id]["pos"] = val
			queue_redraw()
	, thrust, start_pos, 0.15).set_trans(Tween.TRANS_SINE)

func _ability_attack_anim_dir(unit_id: int, event_data: Dictionary) -> Vector2:
	var ability_id: StringName = event_data.get("ability", &"")
	if ability_id == &"knight_seismic_stomp":
		return Vector2(PhysicsSystem.facing_to_vector(GameEnums.Facing.SOUTH))
	if not _visual.has(unit_id):
		return Vector2(PhysicsSystem.facing_to_vector(GameEnums.Facing.SOUTH))
	var target_coord: Vector2i = event_data.get("target_coord", Vector2i.ZERO)
	var start_pos: Vector2 = _visual[unit_id]["pos"]
	var delta := _coord_center(target_coord) - start_pos
	if delta.length_squared() > 0.01:
		return delta.normalized()
	return Vector2(PhysicsSystem.facing_to_vector(GameEnums.Facing.SOUTH))

func _counter_attack_anim_dir(unit_id: int, event_data: Dictionary) -> Vector2:
	if _board != null:
		var target_id: int = event_data.get("target_unit", -1)
		var target_unit := _board.get_unit_by_id(target_id)
		if target_unit != null and _visual.has(unit_id):
			var start_pos: Vector2 = _visual[unit_id]["pos"]
			var delta: Vector2 = _coord_center(target_unit.position) - start_pos
			if delta.length_squared() > 0.01:
				return delta.normalized()
	if event_data.has("target_coord") and _visual.has(unit_id):
		var start_pos: Vector2 = _visual[unit_id]["pos"]
		var delta: Vector2 = _coord_center(event_data["target_coord"]) - start_pos
		if delta.length_squared() > 0.01:
			return delta.normalized()
	return Vector2(PhysicsSystem.facing_to_vector(GameEnums.Facing.SOUTH))

func _in_ability_range(actor: UnitState, target: UnitState) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _proj_origin(actor) if _skill_interaction_active() else actor.position
	var target_pos: Vector2i = target.position
	if _skill_interaction_active() and target.is_enemy():
		target_pos = _aim_enemy_pos(target.id)
	return GridSystem.manhattan(actor_pos, target_pos) <= rng

func _clear_hover_attack_preview() -> void:
	_hover_predicted_hp.clear()
	_hover_predicted_armor.clear()

## Enemy tiles while aiming resolve on the live preview board.
func _aim_enemy_board() -> BoardState:
	if _preview != null:
		return _preview
	return _proj()

func _display_preview_board() -> BoardState:
	return _preview

func _display_intent_list() -> Array:
	if (_dragging or _skill_interaction_active()) and not _drag_intents.is_empty():
		return _drag_intents
	return _board.intents if _board != null else []

func _display_preview_paths() -> Dictionary:
	return _preview_paths

func _display_preview_splits() -> Dictionary:
	return _preview_splits

func _display_preview_pushes() -> Dictionary:
	return _preview_pushes

func _aim_enemy_pos(unit_id: int) -> Vector2i:
	var live := _board.get_unit_by_id(unit_id) if _board != null else null
	if live == null:
		return Vector2i.ZERO
	if not _skill_interaction_active() or not live.is_enemy():
		return live.position
	var preview_unit := _aim_enemy_board().get_unit_by_id(unit_id)
	return preview_unit.position if preview_unit != null else live.position

## The board after the player's queued actions (falls back to the live board).
func _proj() -> BoardState:
	return _director.projected_state if _director.projected_state != null else _board

func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	return _proj().get_unit_by_id(unit_id)

# --- Helpers ------------------------------------------------------------------

func _update_selected_label() -> void:
	pass

func _to_pixel(coord: Vector2i) -> Vector2:
	return ORIGIN + Vector2(coord.x * CELL, coord.y * CELL)

func _coord_center(coord: Vector2i) -> Vector2:
	return _to_pixel(coord) + Vector2(CELL, CELL) * 0.5

func _to_coord(local_pos: Vector2) -> Vector2i:
	var rel := local_pos - ORIGIN
	return Vector2i(int(floor(rel.x / CELL)), int(floor(rel.y / CELL)))

func _summarize_intents(board: BoardState) -> String:
	var lines: Array[String] = []
	var show_all_enemies := _phase == CombatDirector.Phase.ENEMY_TURN
	var intent_list := _display_intent_list()
	for intent in intent_list:
		if show_all_enemies or _intent_units.has(intent.enemy_id):
			lines.append("  - %s" % intent.summary)
	if lines.is_empty():
		if show_all_enemies:
			return "  (none)"
		return "  (hover an enemy, or select a unit they target)"
	return "\n".join(lines)

func _describe_action(action: TimelineAction) -> String:
	var actor: UnitState = _board.get_unit_by_id(action.actor_id) if _board != null else null
	var actor_name: String = actor.definition.display_name if actor != null else "unit %d" % action.actor_id
	if action.type == GameEnums.ActionType.FACE:
		return "%s face %s" % [actor_name, _facing_name(action.face_dir)]
	if action.type == GameEnums.ActionType.MOVE:
		return "%s move -> %s" % [actor_name, action.target_coord]
	var ability_name: String = action.ability.display_name if action.ability != null else "ability"
	var target_name := actor_name
	if _board != null and action.target_unit_id >= 0:
		var tgt := _board.get_unit_by_id(action.target_unit_id)
		if tgt != null:
			target_name = tgt.definition.display_name
	return "%s %s -> %s" % [actor_name, ability_name, target_name]

func _reason_text(code: String) -> String:
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

func _plan_move(unit_id: int, coord: Vector2i, face_dir: int, waypoints: Array[Vector2i]) -> void:
	if _movement_blocked_by_dash() and not _force_basic_movement:
		return
	if multiplayer.has_multiplayer_peer():
		_director.rpc_plan_move.rpc(unit_id, coord, face_dir, waypoints)
	else:
		_director.rpc_plan_move(unit_id, coord, face_dir, waypoints)

func _plan_face(unit_id: int, face_dir: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_plan_face.rpc(unit_id, face_dir)
	else:
		_director.rpc_plan_face(unit_id, face_dir)

func _plan_attack(unit_id: int, ability_index: int, target_unit_id: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_plan_attack.rpc(unit_id, ability_index, target_unit_id)
	else:
		_director.rpc_plan_attack(unit_id, ability_index, target_unit_id)

func _plan_attack_with_approach(unit_id: int, ability_index: int, target_unit_id: int, preferred_tile: Vector2i) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_plan_attack_with_approach.rpc(unit_id, ability_index, target_unit_id, preferred_tile)
	else:
		_director.rpc_plan_attack_with_approach(unit_id, ability_index, target_unit_id, preferred_tile)

func _plan_ability_at_coord(unit_id: int, ability_index: int, coord: Vector2i) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_plan_ability_at_coord.rpc(unit_id, ability_index, coord)
	else:
		_director.rpc_plan_ability_at_coord(unit_id, ability_index, coord)

func _clear_unit_actions(unit_id: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_clear_unit_actions.rpc(unit_id)
	else:
		_director.rpc_clear_unit_actions(unit_id)

func _remove_last_for_unit(unit_id: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_remove_last_for_unit.rpc(unit_id)
	else:
		_director.rpc_remove_last_for_unit(unit_id)

func _reorder_action(from_index: int, to_index: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_reorder_action.rpc(from_index, to_index)
	else:
		_director.rpc_reorder_action(from_index, to_index)

func _remove_action(index: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_director.rpc_remove_action.rpc(index)
	else:
		_director.rpc_remove_action(index)

func _receive_chat_msg(player_id: int, text: String) -> void:
	if multiplayer.has_multiplayer_peer():
		rpc_receive_chat.rpc(player_id, text)
	else:
		rpc_receive_chat(player_id, text)

func _set_timeline_ready(is_ready: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		GlobalTimeline.rpc_set_ready.rpc(is_ready)
	else:
		GlobalTimeline.rpc_set_ready(is_ready)

func _move_timing_bucket() -> int:
	if _director == null or _selected_id < 0:
		return GameEnums.MoveTiming.PRE_ACTION
	var bucket := _director.get_planning_move_timing(_selected_id)
	return bucket if bucket > 0 else GameEnums.MoveTiming.PRE_ACTION


func _timeline_pre_move_action(plan: Timeline, unit_id: int) -> TimelineAction:
	if plan == null:
		return null
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		if action.type == GameEnums.ActionType.MOVE and action.move_timing == GameEnums.MoveTiming.PRE_ACTION:
			return action
	return null


func _timeline_action_slot(plan: Timeline, unit_id: int) -> TimelineAction:
	if plan == null:
		return null
	var ability_action: TimelineAction = null
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		if action.type == GameEnums.ActionType.ABILITY:
			ability_action = action
		elif action.type == GameEnums.ActionType.MOVE and action.move_timing == GameEnums.MoveTiming.POST_ACTION:
			return action
	return ability_action

## True when the selected unit has actions undoable in the *current* planning phase only.
func _unit_has_undoable_actions(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	return _director.unit_has_undoable_action(unit_id)

func _get_evaluation_timeline(proposed_action: TimelineAction) -> Timeline:
	var timeline := Timeline.new()
	for action in _director.get_player_plan().entries:
		if action.actor_id != _selected_id:
			timeline.add(action)
	timeline.add(proposed_action)
	return timeline

func _get_action_autobattler_scores(action: TimelineAction) -> Dictionary:
	return {}

func _class_symbol(unit: UnitState) -> String:
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

func _action_symbol_text(action: TimelineAction, unit: UnitState) -> String:
	if action == null:
		return "-"
		
	if action.type == GameEnums.ActionType.MOVE:
		return "🏃 (%d,%d)" % [action.target_coord.x, action.target_coord.y]
		
	if action.type == GameEnums.ActionType.FACE:
		return "👀 %s" % _facing_name(action.face_dir)
		
	if action.type == GameEnums.ActionType.ABILITY:
		var symbol := "✨"
		if action.ability != null:
			var has_damage := false
			var has_heal := false
			for eff in action.ability.effects:
				if eff.type == GameEnums.EffectType.DAMAGE or eff.type == GameEnums.EffectType.EXPLODE or eff.type == GameEnums.EffectType.RANGED_EXPLODE:
					has_damage = true
				if eff.type == GameEnums.EffectType.HEAL:
					has_heal = true
			if has_damage:
				symbol = "⚔️"
			elif has_heal:
				symbol = "💚"
				
		var ability_name := ""
		if action.ability != null and action.ability.display_name != "":
			ability_name = action.ability.display_name
		var target_name := ""
		if action.target_unit_id >= 0 and _board != null:
			var tgt := _board.get_unit_by_id(action.target_unit_id)
			if tgt != null:
				target_name = tgt.definition.display_name
		if target_name == "":
			target_name = "(%d,%d)" % [action.target_coord.x, action.target_coord.y]
			
		# Show: [icon] Ability Name > Target (or just [icon] Target if no ability name)
		if ability_name != "":
			return "%s %s > %s" % [symbol, ability_name, target_name]
		return "%s %s" % [symbol, target_name]
		
	return "❓"

func _make_table_cell(parent: Control, text: String, tooltip: String = "", col: Color = Color.WHITE, is_header: bool = false, bg_color: Color = Color.TRANSPARENT) -> Label:
	var lbl := _make_label(parent, text)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if tooltip != "":
		lbl.tooltip_text = tooltip
	if col != Color.WHITE:
		_tint(lbl, col.to_html(false))
	if is_header:
		lbl.add_theme_font_size_override("font_size", 13)
		_tint(lbl, "aaaaaa")
		
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	lbl.add_theme_stylebox_override("normal", sb)
		
	return lbl

func _update_score_hud(data: Dictionary) -> void:
	if _score_lbl == null or not _ai_calc_enabled or data.is_empty():
		return
	var val_str := ("+" if data.total > 0.0 else "") + "%.1f" % data.total
	_score_lbl.text = "🤖 AI Score: %s" % val_str
	
	var s: Dictionary = data.scores
	var w: Variant = data.weights
	
	# Colorize the total score
	var total_color := "#47D147" if data.total > 0.05 else ("#FF4D4D" if data.total < -0.05 else "#8C8C8C")
	var breakdown := "[b]Autobattler Utility Score:[/b] [b][color=%s]%.1f[/color][/b]\n" % [total_color, data.total]
	breakdown += "[i][color=#8C8C8C]Weighted Breakdown (wt × val):[/color][/i]\n"
	
	breakdown += "- [b]Damage:[/b] %s (%.1f × %s)\n" % [_c_val_unsigned(s.damage * w.w_damage), w.w_damage, _c_val(s.damage)]
	breakdown += "- [b]Kill:[/b] %s (%.1f × %s)\n" % [_c_val_unsigned(s.kill * w.w_kill), w.w_kill, _c_val(s.kill)]
	breakdown += "- [b]Team Surv (Net HP):[/b] %s (%.1f × %s)\n" % [_c_val_unsigned(s.team_surv * w.w_team_surv), w.w_team_surv, _c_val(s.team_surv)]
	breakdown += "- [b]Disruption:[/b] %s (%.1f × %s)\n" % [_c_val_unsigned(s.disrupt * w.w_disrupt), w.w_disrupt, _c_val(s.disrupt)]
	breakdown += "- [b]Positioning:[/b] %s (%.1f × %s)\n" % [_c_val_unsigned(s.position * w.w_position), w.w_position, _c_val(s.position)]
	
	breakdown += "  * [color=#FFB366]Approach/Retreat:[/color] %s\n" % _c_val(s.get("pos_approach", 0.0))
	breakdown += "  * [color=#FFB366]Enemy Proximity Danger:[/color] %s\n" % _c_val(s.get("pos_danger", 0.0))
	breakdown += "  * [color=#FFB366]Cohesion/Ally Proximity:[/color] %s\n" % _c_val(s.get("pos_cohesion", 0.0))
	breakdown += "  * [color=#FFB366]Map Centrality:[/color] %s\n" % _c_val(s.get("pos_centrality", 0.0))
	breakdown += "  * [color=#FFB366]Terrain Fortitude/Hazards:[/color] %s" % _c_val(s.get("pos_terrain", 0.0))
	
	_score_lbl.tooltip_text = breakdown

func _c_val(val: float) -> String:
	if val > 0.05:
		return "[color=#47D147]%+.1f[/color]" % val
	elif val < -0.05:
		return "[color=#FF4D4D]%+.1f[/color]" % val
	else:
		return "[color=#8C8C8C]0.0[/color]"

func _c_val_unsigned(val: float) -> String:
	if val > 0.05:
		return "[color=#47D147]%.1f[/color]" % val
	elif val < -0.05:
		return "[color=#FF4D4D]%.1f[/color]" % val
	else:
		return "[color=#8C8C8C]0.0[/color]"

func _get_queued_action_for_selected() -> TimelineAction:
	if _selected_id < 0 or _director == null:
		return null
	var plan := _director.get_player_plan()
	for action in plan.entries:
		if action.actor_id == _selected_id:
			return action
	return null
