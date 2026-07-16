class_name FrogActor
extends Node2D

## Shore frog — 6×5 px; hops forward×3 / back×3 with long random idles between.

const TILE_PX: int = 16
const _HOP_DURATION_MIN: float = 0.20
const _HOP_DURATION_MAX: float = 0.32
const _IDLE_MIN: float = 2.4
const _IDLE_MAX: float = 5.2

const _PATTERN: Array[String] = [
	"hop_fwd", "hop_fwd", "hop_fwd",
	"hop_back", "hop_back", "hop_back",
]

enum _Phase { REST, HOP }

var _grid: PlayerGrid
var _cell: Vector2i = Vector2i.ZERO
var _facing: Vector2i = Vector2i(1, 0)
var _pattern_i: int = 0
var _phase: _Phase = _Phase.REST
var _rest_timer: float = 0.0
var _hop_t: float = 0.0
var _hop_duration: float = 0.24
var _hop_from: Vector2 = Vector2.ZERO
var _hop_to: Vector2 = Vector2.ZERO
var _hop_target: Vector2i = Vector2i.ZERO
var _sprite: AnimatedSprite2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(grid: PlayerGrid, cell: Vector2i, seed: int) -> void:
	_grid = grid
	_cell = cell
	_rng.seed = seed
	var facings: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	_facing = facings[_rng.randi() % facings.size()]
	position = _cell_px(_cell)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = EcologyActorArt.frog_frames()
	_sprite.animation = &"idle"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	if _facing.x < 0:
		_sprite.scale.x = -1.0
	add_child(_sprite)
	_begin_idle()
	set_process(true)


func _process(delta: float) -> void:
	match _phase:
		_Phase.REST:
			_rest_timer -= delta
			if _rest_timer <= 0.0:
				_run_next_hop()
		_Phase.HOP:
			_hop_t += delta
			var t: float = clampf(_hop_t / _hop_duration, 0.0, 1.0)
			var pos: Vector2 = _hop_from.lerp(_hop_to, t)
			pos.y += roundi(sin(t * PI) * -3.0)
			position = Vector2(roundi(pos.x), roundi(pos.y))
			if t >= 1.0:
				_cell = _hop_target
				position = _cell_px(_cell)
				_begin_idle()


func _run_next_hop() -> void:
	var step: String = _PATTERN[_pattern_i]
	_pattern_i = (_pattern_i + 1) % _PATTERN.size()
	match step:
		"hop_fwd":
			_try_hop(_facing)
		"hop_back":
			_try_hop(-_facing)
		_:
			_begin_idle()


func _begin_idle() -> void:
	_phase = _Phase.REST
	_sprite.animation = &"idle"
	_sprite.play()
	var duration: float = _rng.randf_range(_IDLE_MIN, _IDLE_MAX)
	if _rng.randf() < 0.22:
		duration *= _rng.randf_range(1.25, 1.65)
	_rest_timer = duration


func _try_hop(dir: Vector2i) -> void:
	var next: Vector2i = _cell + dir
	if not _can_stand(next):
		_begin_idle()
		return
	_hop_target = next
	_hop_from = position
	_hop_to = _cell_px(next)
	_hop_t = 0.0
	_hop_duration = _rng.randf_range(_HOP_DURATION_MIN, _HOP_DURATION_MAX)
	_phase = _Phase.HOP
	_sprite.animation = &"hop"
	_sprite.frame = 0
	_sprite.stop()


func _can_stand(cell: Vector2i) -> bool:
	if _grid == null:
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= _grid.width or cell.y >= _grid.height:
		return false
	var tid: int = _grid.get_cell(cell)
	return tid == TileId.Type.GRASS or tid == TileId.Type.DIRT


func _cell_px(cell: Vector2i) -> Vector2:
	return Vector2(roundi(cell.x * TILE_PX + 8.0), roundi(cell.y * TILE_PX + 8.0))
