class_name EcologySparseActor
extends Node2D

## Base sparse ecology actor â€” Active / Idle / Transition with stepped motion.

enum State { ACTIVE, IDLE, TRANSITION }

const TILE_PX: int = 16

var actor_state: State = State.IDLE
var _state_timer: float = 0.0
var _step_clock: float = 0.0
const STEP_HZ: float = 8.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func begin_life(idle_first: bool = false) -> void:
	actor_state = State.IDLE if idle_first else State.ACTIVE
	_state_timer = _rand_state_duration()
	_step_clock = 0.0


func _advance_state_machine(delta: float) -> void:
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	match actor_state:
		State.ACTIVE:
			actor_state = State.TRANSITION
			_state_timer = _rng.randf_range(0.35, 0.9)
		State.IDLE:
			actor_state = State.TRANSITION
			_state_timer = _rng.randf_range(0.25, 0.65)
		State.TRANSITION:
			actor_state = State.ACTIVE if _rng.randf() < 0.62 else State.IDLE
			_state_timer = _rand_state_duration()


func _quantized_step(delta: float) -> float:
	_step_clock += delta
	var step_dt: float = 1.0 / STEP_HZ
	if _step_clock < step_dt:
		return 0.0
	_step_clock = fmod(_step_clock, step_dt)
	return step_dt


func _snap_pos(p: Vector2) -> Vector2:
	return Vector2(roundi(p.x), roundi(p.y))


func _make_flap_sprite(frames: SpriteFrames, anim: StringName) -> AnimatedSprite2D:
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.animation = anim
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.speed_scale = _rng.randf_range(0.88, 1.08)
	spr.centered = true
	return spr


func _set_flap_active(spr: AnimatedSprite2D, active: bool) -> void:
	if spr == null:
		return
	if active:
		if not spr.is_playing():
			spr.play()
	else:
		spr.stop()
		spr.frame = 0


func _rand_state_duration() -> float:
	return _rng.randf_range(1.8, 5.5)


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
