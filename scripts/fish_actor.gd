class_name FishActor
extends Node2D

## Top-down thin silhouette — straight cardinal glide; snake wave is sprite-only.

const TILE_PX: int = 16
const STEP_HZ: float = 10.0
const _SWIM_SPEED: float = 1.5
const _PAUSE_CHANCE: float = 0.12

const _C = preload("res://scripts/mana_seed_constants.gd")

var _grid: PlayerGrid
var _cell: Vector2i = Vector2i.ZERO
var _target_cell: Vector2i = Vector2i.ZERO
var _pause_timer: float = 0.0
var _step_clock: float = 0.0
var _sprite: AnimatedSprite2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(grid: PlayerGrid, cell: Vector2i, seed: int) -> void:
	_grid = grid
	_cell = cell
	_target_cell = cell
	_rng.seed = seed
	z_as_relative = false
	z_index = _C.Z_UNDER_TREE
	position = _cell_center(cell)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = EcologyActorArt.fish_frames()
	_sprite.animation = &"swim_h"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.speed_scale = _rng.randf_range(0.82, 0.98)
	add_child(_sprite)
	_pick_swim_target()
	_pause_timer = _rng.randf_range(0.6, 1.4)
	set_process(true)


func _process(delta: float) -> void:
	_step_clock += delta
	var step_dt: float = 1.0 / STEP_HZ
	if _step_clock < step_dt:
		return
	_step_clock = fmod(_step_clock, step_dt)
	if _pause_timer > 0.0:
		_pause_timer -= step_dt
		_sprite.stop()
		_sprite.frame = 0
		return
	var move_dir: Vector2i = _cardinal_toward(_target_cell)
	if move_dir == Vector2i.ZERO:
		_cell = _target_cell
		position = _cell_center(_cell)
		_pick_swim_target()
		if _rng.randf() < _PAUSE_CHANCE:
			_pause_timer = _rng.randf_range(0.6, 1.8)
		return
	var forward: Vector2 = Vector2(move_dir)
	var goal: Vector2 = _cell_center(_target_cell)
	var axis_goal: float = goal.x if move_dir.x != 0 else goal.y
	var axis_pos: float = position.x if move_dir.x != 0 else position.y
	var axis_remain: float = absf(axis_goal - axis_pos)
	var step: float = minf(_SWIM_SPEED, axis_remain)
	if step <= 0.0:
		_cell = _target_cell
		position = _cell_center(_cell)
		_pick_swim_target()
		return
	var next_pos: Vector2 = _snap_pos(position + forward * step)
	if not _is_swimmable(_pos_to_cell(next_pos)):
		_pick_swim_target()
		return
	position = next_pos
	_cell = _pos_to_cell(position)
	_apply_facing(move_dir)
	_sprite.play()


func _apply_facing(move_dir: Vector2i) -> void:
	if move_dir.x != 0:
		_sprite.animation = &"swim_h"
		_sprite.scale = Vector2(-1.0 if move_dir.x < 0 else 1.0, 1.0)
	else:
		_sprite.animation = &"swim_v"
		_sprite.scale = Vector2(1.0, -1.0 if move_dir.y < 0 else 1.0)


func _cardinal_toward(target: Vector2i) -> Vector2i:
	var delta: Vector2i = target - _cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if delta.x != 0 and delta.y != 0:
		if absi(delta.x) >= absi(delta.y):
			delta.y = 0
		else:
			delta.x = 0
	if delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return Vector2i(0, signi(delta.y))
	return Vector2i.ZERO


func _pick_swim_target() -> void:
	var candidates: Array[Vector2i] = []
	for dir: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]:
		var dist_min: int = _rng.randi_range(2, 3)
		var dist_max: int = _rng.randi_range(5, 8)
		for dist: int in range(dist_min, dist_max + 1):
			var candidate: Vector2i = _cell + dir * dist
			if _is_swimmable(candidate):
				candidates.append(candidate)
			else:
				break
	if candidates.is_empty():
		for offset: Vector2i in [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		]:
			var candidate: Vector2i = _cell + offset
			if _is_swimmable(candidate):
				candidates.append(candidate)
	if candidates.is_empty():
		_target_cell = _cell
		return
	_target_cell = candidates[_rng.randi() % candidates.size()]


func _is_swimmable(cell: Vector2i) -> bool:
	if _grid == null:
		return false
	if not WaterCellMask.in_bounds(_grid, cell):
		return false
	return WaterCellMask.is_interior_water(_grid, cell)


func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(TILE_PX))), int(floor(pos.y / float(TILE_PX))))


func _cell_center(cell: Vector2i) -> Vector2:
	return _snap_pos(Vector2(cell) * float(TILE_PX) + Vector2(8.0, 8.0))


func _snap_pos(p: Vector2) -> Vector2:
	return Vector2(roundi(p.x), roundi(p.y))
