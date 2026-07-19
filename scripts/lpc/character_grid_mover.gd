class_name CharacterGridMover
extends Node

## Grid-step LPC movement — chains tiles only while a direction is still held.

const TILE_PX: int = 16
const STEP_SEC: float = 0.16
## Diagonal cell centers are sqrt(2)× farther — match cardinal world speed.
const DIAGONAL_STEP_SEC: float = STEP_SEC * sqrt(2.0)

const ANIM_UP: StringName = &"walk_up"
const ANIM_LEFT: StringName = &"walk_left"
const ANIM_DOWN: StringName = &"walk_down"
const ANIM_RIGHT: StringName = &"walk_right"

var grid_cell: Vector2i = Vector2i.ZERO

var _actor: CharacterActor
var _grid: PlayerGrid
var _trees: TileMapLayer
var _overlay: TileMapLayer
var _scatter: TileMapLayer
var _ground: TileMapLayer
var _walk_settings: EffectsSettings
var _busy: bool = false
var _tween: Tween


func setup(
	actor: CharacterActor,
	grid: PlayerGrid,
	start_cell: Vector2i,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	walk_settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
	ground: TileMapLayer = null,
) -> void:
	_actor = actor
	_grid = grid
	_trees = trees
	_overlay = overlay
	_scatter = scatter
	_ground = ground
	_walk_settings = walk_settings
	grid_cell = start_cell
	set_process(true)
	_sync_position_instant()


func set_map_layers(
	trees: TileMapLayer,
	overlay: TileMapLayer,
	walk_settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
	ground: TileMapLayer = null,
) -> void:
	_scatter = scatter
	_trees = trees
	_overlay = overlay
	if ground != null:
		_ground = ground
	if walk_settings != null:
		_walk_settings = walk_settings


func is_busy() -> bool:
	return _busy


func cancel_movement() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_busy = false
	if _actor != null:
		_actor.position = _cell_foot_px(grid_cell)
		_actor.set_walking(false)


func request_step(dir: Vector2i, grid: PlayerGrid = null) -> void:
	if grid != null:
		_grid = grid
	if _grid == null or _actor == null or _busy:
		return
	_start_step(dir)


func try_step(dir: Vector2i, grid: PlayerGrid = null) -> bool:
	request_step(dir, grid)
	return true


func sync_grid(
	grid: PlayerGrid,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	walk_settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
	ground: TileMapLayer = null,
) -> void:
	_grid = grid
	if trees != null:
		_trees = trees
	if overlay != null:
		_overlay = overlay
	if scatter != null:
		_scatter = scatter
	if ground != null:
		_ground = ground
	if walk_settings != null:
		_walk_settings = walk_settings
	if _grid == null or _actor == null:
		return
	if not Walkability.is_walkable(_grid, grid_cell, _trees, _overlay, _walk_settings, _scatter):
		grid_cell = Walkability.find_spawn_cell(
			_grid,
			Vector2i(_grid.width >> 1, _grid.height >> 1),
			_trees,
			_overlay,
			_walk_settings,
			_scatter,
		)
	cancel_movement()
	_sync_position_instant()
	if _actor != null:
		_actor.set_walking(false)


func refresh_depth_sort() -> void:
	if _actor != null:
		_actor.update_tree_depth_sort(_grid, _trees, _overlay, _walk_settings)


func _process(_delta: float) -> void:
	if _actor == null:
		return
	refresh_depth_sort()
	if _busy:
		return
	var held: Vector2i = _held_move_dir()
	if held != Vector2i.ZERO:
		_start_step(held)


static func move_dir_from_input() -> Vector2i:
	var dir: Vector2i = Vector2i.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	return dir


func _start_step(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var next: Vector2i = grid_cell + dir
	if not _can_step_to(dir):
		_actor.set_facing(_anim_for_dir(dir))
		_actor.set_walking(false)
		return
	_actor.set_facing(_anim_for_dir(dir))
	_actor.set_walking(true)
	_busy = true
	grid_cell = next
	refresh_depth_sort()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = _actor.create_tween()
	_tween.tween_property(_actor, "position", _cell_foot_px(next), _step_duration(dir))
	_tween.finished.connect(_on_step_finished, CONNECT_ONE_SHOT)


func _on_step_finished() -> void:
	_busy = false
	if _actor != null:
		_actor.position = _cell_foot_px(grid_cell)
	refresh_depth_sort()
	var held: Vector2i = _held_move_dir()
	if held == Vector2i.ZERO:
		if _actor != null:
			_actor.set_walking(false)
		return
	_start_step(held)


func _held_move_dir() -> Vector2i:
	return move_dir_from_input()


var is_running: bool = false
var _action_timer: SceneTreeTimer = null

func request_action(action: StringName) -> bool:
	if _busy or _actor == null:
		return false
	_busy = true
	var suffix: String = ""
	if action == &"hurt":
		suffix = "down"
	else:
		var facing_str := str(_actor._facing)
		var parts := facing_str.split("_")
		if parts.size() > 1:
			suffix = parts[-1]
		else:
			suffix = "down"
	var anim: StringName = StringName(str(action) + "_" + suffix)
	if action == &"hurt":
		_actor.play_hurt(StringName("hurt_" + suffix))
		_action_timer = _actor.get_tree().create_timer(0.8)
		_action_timer.timeout.connect(_on_action_finished)
		return true
	_actor.play_one_shot_action(
		anim,
		CharacterActor.ACTION_HOLD_SANDBOX_SEC,
		Callable(self, "_on_action_finished"),
	)
	return true


func _on_action_finished() -> void:
	_action_timer = null
	_busy = false
	if _actor != null:
		_actor.set_walking(false)
	var held: Vector2i = _held_move_dir()
	if held != Vector2i.ZERO:
		_start_step(held)


func _step_duration(dir: Vector2i) -> float:
	var dur: float = STEP_SEC
	if dir.x != 0 and dir.y != 0:
		dur = DIAGONAL_STEP_SEC
	return dur * 0.6 if is_running else dur


func _can_step_to(dir: Vector2i) -> bool:
	var next: Vector2i = grid_cell + dir
	if not _is_walkable(next):
		return false
	if dir.x != 0 and dir.y != 0:
		if not _is_walkable(grid_cell + Vector2i(dir.x, 0)):
			return false
		if not _is_walkable(grid_cell + Vector2i(0, dir.y)):
			return false
	return true


func _anim_for_dir(dir: Vector2i) -> StringName:
	var prefix = "run_" if is_running else "walk_"
	if dir.x != 0 and dir.y != 0:
		if dir.y > 0:
			return StringName(prefix + ("left" if dir.x < 0 else "right"))
		return StringName(prefix + "up")
	if dir.y < 0:
		return StringName(prefix + "up")
	if dir.y > 0:
		return StringName(prefix + "down")
	if dir.x < 0:
		return StringName(prefix + "left")
	return StringName(prefix + "right")


func _is_walkable(cell: Vector2i) -> bool:
	return Walkability.is_walkable(_grid, cell, _trees, _overlay, _walk_settings, _scatter)


func _cell_foot_px(cell: Vector2i) -> Vector2:
	return MapPixelSpace.cell_foot_px(_ground, cell)


func _sync_position_instant() -> void:
	if _actor != null:
		_actor.position = _cell_foot_px(grid_cell)
		_actor.update_tree_depth_sort(_grid, _trees, _overlay, _walk_settings)
