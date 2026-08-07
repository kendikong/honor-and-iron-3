class_name ButterflyActor
extends EcologySparseActor

## Flutter on scatter_flora â€” spawns on flower tile; drifts â‰¤1 cell, returns to land.

const _DRIFT_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

var _home_flora: Vector2i = Vector2i.ZERO
var _drift_cell: Vector2i = Vector2i.ZERO
var _flutter_phase: float = 0.0
var _landed: bool = false
var _sprite: AnimatedSprite2D


func setup(
	flora_cell: Vector2i,
	seed: int,
	_flora_cells_unused: Array = [],
	flora_center: Vector2i = Vector2i.ZERO,
) -> void:
	_rng.seed = seed
	_home_flora = flora_center if flora_center != Vector2i.ZERO else flora_cell
	_drift_cell = _home_flora
	position = _snap_cell_center(_home_flora)
	var variant: int = _rng.randi() % EcologyActorArt.butterfly_variant_count()
	_sprite = _make_flap_sprite(EcologyActorArt.butterfly_frames(variant), &"flap")
	add_child(_sprite)
	begin_life(_rng.randf() < 0.35)
	set_process(true)


func _process(delta: float) -> void:
	var step_dt: float = _quantized_step(delta)
	if step_dt <= 0.0:
		return
	var prev_state: State = actor_state
	_advance_state_machine(step_dt)
	if prev_state == State.IDLE and actor_state == State.ACTIVE:
		_pick_drift_cell()
	if prev_state == State.ACTIVE and actor_state == State.TRANSITION:
		_drift_cell = _home_flora
	match actor_state:
		State.IDLE:
			_landed = true
			_drift_cell = _home_flora
			_set_flap_active(_sprite, false)
			position = _snap_cell_center(_home_flora)
		State.TRANSITION:
			_landed = false
			_set_flap_active(_sprite, true)
			_move_toward_cell(_home_flora, 2.4)
		State.ACTIVE:
			_landed = false
			_set_flap_active(_sprite, true)
			_flutter_phase += step_dt * _rng.randf_range(5.0, 8.0)
			var flutter: Vector2 = Vector2(
				roundi(sin(_flutter_phase)),
				roundi(cos(_flutter_phase * 0.7)),
			)
			position = _snap_pos(_cell_center(_drift_cell) + flutter)


func is_high_attention() -> bool:
	return not _landed and actor_state == State.ACTIVE


func _pick_drift_cell() -> void:
	var offset: Vector2i = _DRIFT_OFFSETS[_rng.randi() % _DRIFT_OFFSETS.size()]
	_drift_cell = _home_flora + offset


func _move_toward_cell(cell: Vector2i, speed: float) -> void:
	var goal: Vector2 = _cell_center(cell)
	var delta_px: Vector2 = goal - position
	if delta_px.length() < 1.5:
		position = _snap_cell_center(cell)
		return
	var step: float = minf(speed, delta_px.length())
	position = _snap_pos(position + delta_px.normalized() * step)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(TILE_PX) + Vector2(8.0, 8.0)


func _snap_cell_center(cell: Vector2i) -> Vector2:
	return _snap_pos(_cell_center(cell))
