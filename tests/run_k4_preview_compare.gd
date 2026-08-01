extends Node

## Visible-window K4 preview compare. Run:
##   godot --path . res://tests/k4_preview_compare_runner.tscn
## Or: scripts/run_k4_preview_compare.ps1

const _BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"
const _K4_CELL := Vector2i(4, 1)
const _K2_CELL := Vector2i(1, 3)
const _K3_CELL := Vector2i(5, 4)
const _E_BASH_CELL := Vector2i(7, 5)
const _E_HOOK_CELL := Vector2i(4, 3)
const _RUN_TRIGGER := Vector2i(3, 2)
const _ROUTE: Array[Vector2i] = [
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2), _RUN_TRIGGER,
]
const _SETTLE_MS := 20
const _PAUSE_SEC := 2.5

var _scene: TestBattleMapView
var _director: CombatDirector
var _input: CombatPlanningInput
var _overlay: TacticalPlanningOverlay
var _board: BoardState
var _k4_id: int = -1


func _ready() -> void:
	call_deferred("_main")


func _main() -> void:
	_print_banner()
	var packed: PackedScene = load("res://scenes/TestBattle.tscn") as PackedScene
	_scene = packed.instantiate() as TestBattleMapView
	get_tree().root.add_child(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var session: TestBattleSession = _scene.get_session()
	session.reset_defaults()
	session.extra_player_coords = [_K2_CELL, _K3_CELL, _K4_CELL]
	session.dummy_coords = [_E_BASH_CELL, _E_HOOK_CELL]
	_scene.apply_training_board()
	await _wait_frames(8)
	var shell: TacticalCombatShell = _scene.get_node("CombatShell") as TacticalCombatShell
	_director = _scene.get_node("CombatDirector") as CombatDirector
	_input = shell.planning_input
	_overlay = _scene.get_node("WorldModulate/MapRoot/PlanningOverlay") as TacticalPlanningOverlay
	_board = _director.board
	_director.auto_run = true
	_k4_id = _unit_id_at(_K4_CELL)
	if _k4_id < 0:
		push_error("K4 unit missing at %s" % _K4_CELL)
		get_tree().quit(1)
		return
	_director.select_unit(_k4_id)
	await _wait_frames(12)
	await _hover(_K4_CELL)
	if not _select_ability(_BOWLING_CHARGE_ID):
		push_error("Bowling Charge missing on K4")
		get_tree().quit(1)
		return
	await _wait_frames(12)
	await _hover(_ROUTE[0])
	_push_mouse_button(MOUSE_BUTTON_LEFT, true)
	await _wait_frames(4)
	for step_index: int in range(1, _ROUTE.size()):
		await _hover(_ROUTE[step_index])
		await _wait_frames(4)
		var stand: Vector2i = _ROUTE[step_index]
		if stand == Vector2i(4, 2):
			_log_snapshot("walk_loop_end", stand)
			await get_tree().create_timer(_PAUSE_SEC).timeout
		elif stand == _RUN_TRIGGER:
			_log_snapshot("run_trigger", stand)
			await get_tree().create_timer(_PAUSE_SEC).timeout
	_push_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _wait_frames(20)
	_log_snapshot("after_commit", _RUN_TRIGGER)
	print("Done — compare PNGs in reports/k4_preview/ then close the window.")
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()


func _print_banner() -> void:
	print("")
	print("========== K4 PREVIEW COMPARE (visible window) ==========")
	print("Bowling selected | Auto Run ON")
	print("| Walk loop end (4,2)  -> red ON,  AP 1, no Run")
	print("| Run trigger (3,2)    -> red OFF, AP 0, Run queued")
	print("| Your F5 screenshot   -> (3,6), red ON at 0 AP (likely bug)")
	print("Snapshots: reports/k4_preview/")
	print("=========================================================")
	print("")


func _log_snapshot(label: String, stand: Vector2i) -> void:
	var requires_run: bool = _input.unit_move_requires_run(_k4_id)
	var display_ap: int = _input.planning_display_ap_left(_k4_id)
	var red_gate: bool = _input.action_range_visible_for_hover()
	var overlay_red: bool = _overlay_has_red()
	print(
		"[K4-SNAPSHOT] %s | stand=%s requires_run=%s display_ap=%d red_gate=%s overlay_red=%s"
		% [label, stand, requires_run, display_ap, red_gate, overlay_red],
	)
	await _wait_frames(4)
	var vp: Viewport = _scene.get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	var out_dir: String = "res://reports/k4_preview/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out_path: String = "%sk4_%s.png" % [out_dir, label]
	img.save_png(out_path)
	print("[K4-SNAPSHOT] saved %s" % out_path)


func _overlay_has_red() -> bool:
	if _overlay == null or _board == null:
		return false
	for y: int in range(_board.grid_size.y):
		for x: int in range(_board.grid_size.x):
			if _overlay.is_hover_action_range_tile(Vector2i(x, y)):
				return true
	return false


func _unit_id_at(cell: Vector2i) -> int:
	var unit: UnitState = _board.get_unit_at(cell)
	return unit.id if unit != null else -1


func _select_ability(ability_id: StringName) -> bool:
	var unit: UnitState = _board.get_unit_by_id(_k4_id)
	if unit == null:
		return false
	for index: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[index]
		if ability != null and ability.id == ability_id:
			_director.select_ability(index)
			return true
	return false


func _hover(cell: Vector2i) -> void:
	var map_root: Node2D = _scene.get_node("WorldModulate/MapRoot") as Node2D
	var screen_pos: Vector2 = _scene.position + _scene.grid_to_local(cell) * map_root.scale.x
	var event := InputEventMouseMotion.new()
	event.position = screen_pos
	event.global_position = screen_pos
	_scene.get_viewport().push_input(event)
	await _wait_frames(2)


func _push_mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	_scene.get_viewport().push_input(event)


func _wait_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame
