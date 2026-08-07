class_name AmbientEventDirector
extends RefCounted

## Seeded rare events â€” bird, fish splash, heavy gust (bible Â§3 #9).

const _C = preload("res://scripts/mana_seed_constants.gd")

const _Bird = preload("res://scripts/bird_flyover_actor.gd")

const MIN_BIRD_INTERVAL: float = 90.0
const MAX_BIRD_INTERVAL: float = 300.0

var _map_root: Node2D
var _water_burst: WaterBurstDirector
var _map_seed: int = 1
var _enabled: bool = false
var _readability: ReadabilityEnforcer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_event_timer: float = 20.0
var _event_index: int = 0
var _map_size_px: Vector2 = Vector2.ZERO
var _active_bird: Node2D


func setup(
	map_root: Node2D,
	water_burst: WaterBurstDirector,
	map_seed: int,
	readability: ReadabilityEnforcer,
) -> void:
	_map_root = map_root
	_water_burst = water_burst
	_map_seed = map_seed
	_readability = readability
	_rng.seed = map_seed + 12007
	_schedule_next(8.0, 18.0)


func sync_map(size_cells: Vector2i, enabled: bool) -> void:
	_enabled = enabled
	_map_size_px = Vector2(size_cells) * 16.0
	if not enabled and _active_bird != null and is_instance_valid(_active_bird):
		_active_bird.queue_free()
		_active_bird = null
		if _readability != null:
			_readability.release()


func set_map_seed(map_seed: int) -> void:
	_map_seed = map_seed
	_rng.seed = map_seed + 12007


func process(delta: float, fish_splash_on: bool) -> void:
	if not _enabled:
		return
	_next_event_timer -= delta
	if _next_event_timer > 0.0:
		return
	_fire_next_event(fish_splash_on)


func _fire_next_event(fish_splash_on: bool) -> void:
	var events: Array[StringName] = [&"bird", &"gust"]
	if fish_splash_on:
		events.append(&"splash")
	var kind: StringName = events[_event_index % events.size()]
	_event_index += 1
	match kind:
		&"bird":
			_spawn_bird()
		&"gust":
			WindBus.trigger_heavy_gust()
			_schedule_next(45.0, 120.0)
		&"splash":
			if _water_burst != null:
				_water_burst.force_burst()
			_schedule_next(30.0, 90.0)
		_:
			_schedule_next(20.0, 40.0)


func _spawn_bird() -> void:
	if _map_root == null or _readability == null:
		_schedule_next(MIN_BIRD_INTERVAL, MAX_BIRD_INTERVAL)
		return
	if not _readability.try_acquire():
		_schedule_next(12.0, 24.0)
		return
	if _active_bird != null and is_instance_valid(_active_bird):
		_readability.release()
		_active_bird.queue_free()
	var bird: Node2D = _Bird.new()
	bird.setup(_map_size_px, _map_seed + _event_index)
	bird.tree_exited.connect(_on_bird_done)
	_map_root.add_child(bird)
	bird.z_as_relative = false
	bird.z_index = _C.Z_BIRD
	_active_bird = bird
	_schedule_next(MIN_BIRD_INTERVAL, MAX_BIRD_INTERVAL)


func _on_bird_done() -> void:
	_active_bird = null
	if _readability != null:
		_readability.release()


func _schedule_next(min_s: float, max_s: float) -> void:
	_next_event_timer = _rng.randf_range(min_s, max_s)
