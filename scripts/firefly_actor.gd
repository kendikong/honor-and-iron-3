class_name FireflyActor
extends EcologySparseActor

## Random wandering near water — density varies with swarm boost.

var _home: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _swarm_boost: float = 1.0
var _sprite: Sprite2D


func setup(water_cell: Vector2i, seed: int) -> void:
	_rng.seed = seed
	_home = Vector2(water_cell) * float(TILE_PX) + Vector2(_rng.randi_range(-4, 4), _rng.randi_range(-4, 4))
	position = _snap_pos(_home)
	_pick_wander_target()
	_sprite = Sprite2D.new()
	_sprite.texture = PixelTextureFactory.solid(3, Color(0.78, 0.92, 0.38, 1.0))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	begin_life(true)
	set_process(true)


func set_swarm_boost(mult: float) -> void:
	_swarm_boost = clampf(mult, 1.0, 3.5)


func _process(delta: float) -> void:
	var step_dt: float = _quantized_step(delta)
	if step_dt <= 0.0:
		return
	_advance_state_machine(step_dt)
	match actor_state:
		State.IDLE:
			position = _snap_pos(_home)
			_sprite.modulate = Color(0.55, 0.7, 0.32, 0.65)
		State.ACTIVE, State.TRANSITION:
			var speed: float = (1.2 + _swarm_boost * 0.4) * step_dt * 16.0
			var to: Vector2 = _wander_target - position
			if to.length() < 2.0:
				_pick_wander_target()
				to = _wander_target - position
			position = _snap_pos(position + to.normalized() * speed)
			_sprite.modulate = Color(0.92, 1.0, 0.55, 1.0) if int(_step_clock * 8.0) % 2 == 0 else Color(0.7, 0.88, 0.42, 0.85)


func _pick_wander_target() -> void:
	var radius: float = 12.0 + _swarm_boost * 8.0
	_wander_target = _home + Vector2(
		_rng.randf_range(-radius, radius),
		_rng.randf_range(-radius, radius),
	)


func is_high_attention() -> bool:
	return _swarm_boost > 1.5 and actor_state == State.ACTIVE
