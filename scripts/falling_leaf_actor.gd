class_name FallingLeafActor
extends EcologySparseActor

const _Spring = preload("res://scripts/second_order_spring.gd")

## Flutter / drift — falls from tree anchor, settles on ground via spring snap.

var _start_px: Vector2 = Vector2.ZERO
var _ground_px: Vector2 = Vector2.ZERO
var _fall_t: float = 0.0
var _fall_duration: float = 2.4
var _settled: bool = false
var _spring: SecondOrderSpring = _Spring.new()
var _sprite: AnimatedSprite2D


func setup(tree_cell: Vector2i, ground_cell: Vector2i, seed: int) -> void:
	_rng.seed = seed
	_start_px = Vector2(tree_cell) * float(TILE_PX) + Vector2(8.0, -6.0)
	_ground_px = Vector2(ground_cell) * float(TILE_PX) + Vector2(8.0, 8.0)
	position = _start_px
	_fall_duration = _rng.randf_range(1.8, 3.2)
	_spring.reset(_start_px)
	_spring.frequency = _rng.randf_range(1.8, 2.6)
	_spring.damping = _rng.randf_range(0.55, 0.85)
	_sprite = _make_flap_sprite(EcologyActorArt.leaf_frames(), &"tumble")
	add_child(_sprite)
	begin_life(false)
	set_process(true)


func _process(delta: float) -> void:
	var step_dt: float = _quantized_step(delta)
	if step_dt <= 0.0:
		return
	if _settled:
		_advance_state_machine(step_dt)
		_set_flap_active(_sprite, actor_state == State.ACTIVE)
		if actor_state == State.ACTIVE:
			var wobble: Vector2 = Vector2(roundi(sin(_step_clock * 3.0)), 0.0)
			_spring.set_target(_ground_px + wobble)
		else:
			_spring.set_target(_ground_px)
		position = _spring.step(step_dt)
		return
	_set_flap_active(_sprite, true)
	_fall_t += step_dt
	var t: float = clampf(_fall_t / _fall_duration, 0.0, 1.0)
	var wind: Vector2 = WindBus.direction * 6.0 if WindBus.process_mode != Node.PROCESS_MODE_DISABLED else Vector2(2.0, 0.0)
	var p: Vector2 = _start_px.lerp(_ground_px, t)
	p.x += roundi(wind.x * t)
	p.y += roundi(sin(t * PI) * -4.0)
	position = _snap_pos(p)
	if t >= 1.0:
		_settled = true
		actor_state = State.IDLE
		_state_timer = _rng.randf_range(3.0, 8.0)
		_set_flap_active(_sprite, false)
		_spring.reset(_ground_px)
		_spring.set_target(_ground_px)


func is_high_attention() -> bool:
	return not _settled
