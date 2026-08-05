class_name WaterBurstDirector
extends RefCounted

## Rare fish-splash preview â€” brief waterfall foam tile on deep water (Phase 7 director stub).

const SOURCE_WATERFALL: int = TileSetFactory.SOURCE_WATERFALL
const SPLASH_ATLAS: Vector2i = Vector2i(0, 7)
const SPLASH_DURATION: float = 0.85
const MIN_INTERVAL: float = 14.0
const MAX_INTERVAL: float = 38.0

var _vfx: TileMapLayer
var _deep_cells: Array[Vector2i] = []
var _active_pos: Vector2i = Vector2i(-1, -1)
var _active_timer: float = 0.0
var _wait_timer: float = 6.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(vfx: TileMapLayer, map_seed: int) -> void:
	_vfx = vfx
	_rng.seed = map_seed + 9061
	_wait_timer = _rng.randf_range(4.0, 10.0)


func sync_grid(grid: PlayerGrid) -> void:
	_deep_cells.clear()
	if grid == null:
		return
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) == TileId.Type.WATER and WaterCellMask.is_deep_water(grid, pos):
				_deep_cells.append(pos)


func force_burst() -> void:
	if _vfx == null or _deep_cells.is_empty():
		return
	if _active_timer > 0.0:
		return
	_wait_timer = 0.0


func process(delta: float, enabled: bool) -> void:
	if _vfx == null:
		return
	if not enabled:
		_clear_active()
		return
	if _active_timer > 0.0:
		_active_timer -= delta
		if _active_timer <= 0.0:
			_clear_active()
			_wait_timer = _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
		return
	_wait_timer -= delta
	if _wait_timer > 0.0 or _deep_cells.is_empty():
		return
	var pick: Vector2i = _deep_cells[_rng.randi() % _deep_cells.size()]
	_active_pos = pick
	_active_timer = SPLASH_DURATION
	_vfx.set_cell(pick, SOURCE_WATERFALL, SPLASH_ATLAS, 0)


func _clear_active() -> void:
	if _vfx == null or _active_pos.x < 0:
		return
	if _vfx.get_cell_source_id(_active_pos) == SOURCE_WATERFALL:
		_vfx.erase_cell(_active_pos)
	_active_pos = Vector2i(-1, -1)
	_active_timer = 0.0
