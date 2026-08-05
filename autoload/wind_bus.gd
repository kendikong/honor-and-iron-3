extends Node

## Global Wind Field â€” CPU targets, smooth interpolation, map-local gust front.
## Shaders never read this node directly; WindFieldBinder pushes uniforms each frame.

signal field_changed

const GUST_BAND_PX: float = 44.0

var direction: Vector2 = Vector2(1.0, 0.0)
var turbulence: float = 0.0
var gust_strength: float = 0.0
var gust_front: float = 0.0

var map_origin_px: Vector2 = Vector2.ZERO
var map_size_cells: Vector2i = Vector2i.ZERO
var tile_px: float = 16.0
var map_scale: float = 1.0

var _target_dir: Vector2 = Vector2(1.0, 0.0)
var _target_turbulence: float = 0.12
var _target_gust: float = 0.0
var _gust_running: bool = false
var _gust_speed_px: float = 52.0
var _gust_time_left: float = 0.0
var _calm_time_left: float = 4.0
var _dir_time_left: float = 8.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_pick_new_direction()
	_calm_time_left = _rng.randf_range(4.0, 8.0)


func _process(delta: float) -> void:
	_advance_targets(delta)
	_smooth_state(delta)
	field_changed.emit()


func set_map_frame(origin_world: Vector2, size_cells: Vector2i, cell_px: float, scale: float) -> void:
	map_origin_px = origin_world
	map_size_cells = size_cells
	tile_px = maxf(cell_px, 1.0)
	map_scale = maxf(scale, 0.001)


func gust_envelope_at_map_local(map_local_px: Vector2) -> float:
	var dir: Vector2 = direction.normalized()
	var along: float = map_local_px.dot(dir)
	var dist: float = absf(along - gust_front)
	var t: float = 1.0 - clampf(dist / GUST_BAND_PX, 0.0, 1.0)
	return gust_strength * t * t


func shader_uniforms() -> Dictionary:
	return {
		"wind_dir": direction,
		"wind_turbulence": turbulence,
		"gust_strength": gust_strength,
		"gust_front": gust_front,
		"map_origin_px": map_origin_px,
		"map_size_cells": Vector2(map_size_cells),
		"tile_px": tile_px,
		"map_scale": map_scale,
		"gust_band_px": GUST_BAND_PX,
	}


func _advance_targets(delta: float) -> void:
	_dir_time_left -= delta
	if _dir_time_left <= 0.0:
		_pick_new_direction()

	if _gust_running:
		_gust_time_left -= delta
		gust_front += _gust_speed_px * delta
		_target_gust = 0.82
		_target_turbulence = 0.58
		var span: float = maxf(float(map_size_cells.x), float(map_size_cells.y)) * tile_px + 96.0
		if _gust_time_left <= 0.0 or gust_front > span:
			_gust_running = false
			_target_gust = 0.0
			_calm_time_left = _rng.randf_range(4.0, 10.0)
	else:
		_calm_time_left -= delta
		_target_gust = 0.0
		_target_turbulence = 0.06 if _calm_time_left > 1.5 else 0.18
		if _calm_time_left <= 0.0:
			_start_gust()


func _smooth_state(delta: float) -> void:
	var k_dir: float = clampf(delta * 1.6, 0.0, 1.0)
	var k_amp: float = clampf(delta * 2.8, 0.0, 1.0)
	direction = direction.lerp(_target_dir, k_dir).normalized()
	turbulence = lerpf(turbulence, _target_turbulence, k_amp)
	gust_strength = lerpf(gust_strength, _target_gust, k_amp)


func _pick_new_direction() -> void:
	var options: Array[Vector2] = [
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.0, -1.0),
		Vector2(1.0, 0.35).normalized(),
		Vector2(-1.0, 0.28).normalized(),
	]
	_target_dir = options[_rng.randi() % options.size()]
	_dir_time_left = _rng.randf_range(7.0, 16.0)


func _start_gust() -> void:
	_gust_running = true
	_gust_time_left = _rng.randf_range(2.0, 3.8)
	_gust_speed_px = _rng.randf_range(40.0, 68.0)
	var dir: Vector2 = _target_dir.normalized()
	var center: Vector2 = Vector2(map_size_cells) * tile_px * 0.5
	var half: float = maxf(float(map_size_cells.x), float(map_size_cells.y)) * tile_px * 0.55
	gust_front = center.dot(dir) - half
	_target_gust = 0.95
	_target_turbulence = 0.62


## Phase 7 rare event â€” sudden heavy gust (AmbientEventDirector).
func trigger_heavy_gust() -> void:
	_start_gust()
	_gust_time_left = _rng.randf_range(4.5, 7.0)
	_target_gust = 1.0
	_target_turbulence = 0.78
	_calm_time_left = 0.0
