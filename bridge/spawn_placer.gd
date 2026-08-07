class_name SpawnPlacer
extends RefCounted

## Deterministic spawn placement for random skirmishes.
## Players: center-left band. Enemies: center-right band. Y: middle rows only.

const MVP_PLAYER_COUNT: int = 4
const MVP_ENEMY_COUNT: int = 6
const MIN_SPAWN_GAP: int = 2

const MVP_ENEMY_IDS: Array[StringName] = [&"hatchling", &"charger", &"shover", &"brute", &"artillery", &"flanker"]


static func spawn_edge_margin(grid_height: int) -> int:
	return maxi(2, grid_height / 5)


static func spawn_y_min(grid_height: int) -> int:
	return spawn_edge_margin(grid_height)


static func spawn_y_max(grid_height: int) -> int:
	return maxi(spawn_y_min(grid_height), grid_height - 1 - spawn_edge_margin(grid_height))


static func player_band_x_min(grid_width: int) -> int:
	return maxi(0, grid_width / 4)


static func player_band_x_max(grid_width: int) -> int:
	return maxi(0, grid_width / 2 - 1)


static func enemy_band_x_min(grid_width: int) -> int:
	return mini(grid_width - 1, grid_width / 2)


static func enemy_band_x_max_exclusive(grid_width: int) -> int:
	return mini(grid_width, grid_width * 3 / 4)


static func prefer_player_anchor(grid: PlayerGrid) -> Vector2i:
	return Vector2i(maxi(0, grid.width * 2 / 5), grid.height / 2)


static func prefer_enemy_anchor(grid: PlayerGrid) -> Vector2i:
	return Vector2i(mini(grid.width - 1, grid.width * 3 / 5), grid.height / 2)


static func is_in_spawn_y_band(cell: Vector2i, grid_height: int) -> bool:
	return cell.y >= spawn_y_min(grid_height) and cell.y <= spawn_y_max(grid_height)


static func is_in_player_band(cell: Vector2i, grid_width: int) -> bool:
	return cell.x >= player_band_x_min(grid_width) and cell.x <= player_band_x_max(grid_width)


static func is_in_enemy_band(cell: Vector2i, grid_width: int) -> bool:
	return cell.x >= enemy_band_x_min(grid_width) and cell.x < enemy_band_x_max_exclusive(grid_width)


static func is_in_player_spawn_zone(cell: Vector2i, grid_width: int, grid_height: int) -> bool:
	return is_in_player_band(cell, grid_width) and is_in_spawn_y_band(cell, grid_height)


static func is_in_enemy_spawn_zone(cell: Vector2i, grid_width: int, grid_height: int) -> bool:
	return is_in_enemy_band(cell, grid_width) and is_in_spawn_y_band(cell, grid_height)


static func place_mvp_roster(
	grid: PlayerGrid,
	_blocked_cells: Dictionary,
	map_seed: int,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> Dictionary:
	var player_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		player_band_x_min(grid.width),
		player_band_x_max(grid.width) + 1,
		MVP_PLAYER_COUNT,
		map_seed,
		9109,
		prefer_player_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	var enemy_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		enemy_band_x_min(grid.width),
		enemy_band_x_max_exclusive(grid.width),
		MVP_ENEMY_COUNT,
		map_seed,
		9203,
		prefer_enemy_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)

	var player_spawns: Array[UnitPlacement] = []
	var player_defs := _pick_random_player_roster(player_cells.size(), map_seed)
	for i in range(player_cells.size()):
		if i < player_defs.size():
			var placement := UnitPlacement.new()
			placement.unit = player_defs[i]
			placement.coord = player_cells[i]
			player_spawns.append(placement)

	var enemy_spawns: Array[UnitPlacement] = []
	var enemy_defs := _pick_enemy_roster(enemy_cells.size(), map_seed)
	for i in range(enemy_cells.size()):
		if i < enemy_defs.size():
			var placement := UnitPlacement.new()
			placement.unit = enemy_defs[i]
			placement.coord = enemy_cells[i]
			enemy_spawns.append(placement)

	return {
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
	}


static func place_skirmish_roster(
	grid: PlayerGrid,
	_blocked_cells: Dictionary,
	map_seed: int,
	setup: MassSimSkirmishSetup,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> Dictionary:
	var player_count: int = setup.player_count
	var enemy_count: int = setup.enemy_count
	var player_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		player_band_x_min(grid.width),
		player_band_x_max(grid.width) + 1,
		player_count,
		map_seed,
		9109,
		prefer_player_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	var enemy_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		enemy_band_x_min(grid.width),
		enemy_band_x_max_exclusive(grid.width),
		enemy_count,
		map_seed,
		9203,
		prefer_enemy_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	var player_spawns: Array[UnitPlacement] = []
	var player_defs := _pick_random_player_roster(mini(player_count, player_cells.size()), map_seed)
	for i: int in range(player_cells.size()):
		if i >= player_defs.size():
			break
		var placement := UnitPlacement.new()
		placement.unit = player_defs[i]
		placement.coord = player_cells[i]
		placement.spawn_config = MassSimUnitConfig.build(
			player_defs[i], GameEnums.Team.PLAYER, map_seed, i, setup,
		)
		player_spawns.append(placement)
	var enemy_spawns: Array[UnitPlacement] = []
	var enemy_defs := _pick_enemy_roster(mini(enemy_count, enemy_cells.size()), map_seed)
	for i: int in range(enemy_cells.size()):
		if i >= enemy_defs.size():
			break
		var e_placement := UnitPlacement.new()
		e_placement.unit = enemy_defs[i]
		e_placement.coord = enemy_cells[i]
		e_placement.spawn_config = MassSimUnitConfig.build(
			enemy_defs[i], GameEnums.Team.ENEMY, map_seed, i, setup,
		)
		enemy_spawns.append(e_placement)
	return {
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
	}


static func place_custom_player_roster(
	grid: PlayerGrid,
	_blocked_cells: Dictionary,
	map_seed: int,
	player_unit: UnitData,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> Dictionary:
	var player_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		player_band_x_min(grid.width),
		player_band_x_max(grid.width) + 1,
		1,  # Single player unit for preview
		map_seed,
		9109,
		prefer_player_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	var enemy_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		enemy_band_x_min(grid.width),
		enemy_band_x_max_exclusive(grid.width),
		MVP_ENEMY_COUNT,
		map_seed,
		9203,
		prefer_enemy_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)

	var player_spawns: Array[UnitPlacement] = []
	if player_unit != null and not player_cells.is_empty():
		var placement := UnitPlacement.new()
		placement.unit = player_unit
		placement.coord = player_cells[0]
		player_spawns.append(placement)

	var enemy_spawns: Array[UnitPlacement] = []
	var enemy_defs := _pick_enemy_roster(enemy_cells.size(), map_seed)
	for i in range(enemy_cells.size()):
		if i < enemy_defs.size():
			var placement := UnitPlacement.new()
			placement.unit = enemy_defs[i]
			placement.coord = enemy_cells[i]
			enemy_spawns.append(placement)

	return {
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
	}

static func _pick_random_player_roster(count: int, map_seed: int) -> Array[UnitData]:
	var all_defs := DataLibrary.get_all_player_units().duplicate()
	if all_defs.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(map_seed, 9110)
	var pool := all_defs.duplicate()
	var selected: Array[UnitData] = []
	for _i in range(mini(count, pool.size())):
		var idx: int = rng.randi() % pool.size()
		selected.append(pool[idx])
		pool.remove_at(idx)
	return selected

static func _pick_enemy_roster(count: int, map_seed: int) -> Array[UnitData]:
	var hatchling: UnitData = DataLibrary.get_unit(&"hatchling")
	var non_hatchlings: Array[UnitData] = []
	for def in DataLibrary.get_all_enemy_units():
		if def.id != &"hatchling":
			non_hatchlings.append(def)
	
	if non_hatchlings.is_empty() or hatchling == null:
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(map_seed, 9204)
	
	var selected: Array[UnitData] = [hatchling]
	var pool := non_hatchlings.duplicate()
	
	for _i in range(maxi(0, count - 1)):
		if pool.is_empty():
			pool = non_hatchlings.duplicate()
		var idx: int = rng.randi() % pool.size()
		selected.append(pool[idx])
		pool.remove_at(idx)
		
	for i in range(selected.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp := selected[i]
		selected[i] = selected[j]
		selected[j] = tmp
		
	return selected


static func refine_encounter_spawns(
	grid: PlayerGrid,
	player_spawns: Array[UnitPlacement],
	enemy_spawns: Array[UnitPlacement],
	map_seed: int,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings,
	scatter: TileMapLayer,
) -> void:
	if grid == null:
		return
	var player_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		player_band_x_min(grid.width),
		player_band_x_max(grid.width) + 1,
		player_spawns.size(),
		map_seed,
		9311,
		prefer_player_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	var enemy_cells: Array[Vector2i] = _pick_band_spawns(
		grid,
		enemy_band_x_min(grid.width),
		enemy_band_x_max_exclusive(grid.width),
		enemy_spawns.size(),
		map_seed,
		9317,
		prefer_enemy_anchor(grid),
		trees,
		overlay,
		settings,
		scatter,
	)
	for i: int in range(player_spawns.size()):
		if i < player_cells.size():
			player_spawns[i].coord = player_cells[i]
	for i: int in range(enemy_spawns.size()):
		if i < enemy_cells.size():
			enemy_spawns[i].coord = enemy_cells[i]


static func _pick_band_spawns(
	grid: PlayerGrid,
	x_min: int,
	x_max_exclusive: int,
	count: int,
	map_seed: int,
	salt: int,
	prefer: Vector2i,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings,
	scatter: TileMapLayer,
) -> Array[Vector2i]:
	if count <= 0:
		return []

	var y_min: int = spawn_y_min(grid.height)
	var y_max: int = spawn_y_max(grid.height)
	var candidates: Array[Vector2i] = _walkable_cells_in_band(
		grid, x_min, x_max_exclusive, y_min, y_max, trees, overlay, settings, scatter, prefer,
	)
	var picked: Array[Vector2i] = _pick_spaced_cells(candidates, count, map_seed, salt, prefer)
	if picked.size() >= count:
		return picked

	var used: Dictionary = {}
	for cell: Vector2i in picked:
		used[cell] = true

	while picked.size() < count:
		var fallback: Vector2i = _find_band_spawn(
			grid,
			prefer,
			x_min,
			x_max_exclusive,
			y_min,
			y_max,
			used,
			trees,
			overlay,
			settings,
			scatter,
		)
		if fallback.x < 0:
			fallback = _find_band_spawn(
				grid,
				prefer,
				x_min,
				x_max_exclusive,
				y_min,
				y_max,
				used,
				trees,
				overlay,
				settings,
				scatter,
				false,
			)
		if fallback.x < 0:
			break
		picked.append(fallback)
		used[fallback] = true
		prefer = fallback + Vector2i(1, 0)

	return picked


static func _walkable_cells_in_band(
	grid: PlayerGrid,
	x_min: int,
	x_max_exclusive: int,
	y_min: int,
	y_max: int,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings,
	scatter: TileMapLayer,
	prefer: Vector2i,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(y_min, y_max + 1):
		for x: int in range(x_min, mini(x_max_exclusive, grid.width)):
			var cell := Vector2i(x, y)
			if not Walkability.is_walkable(grid, cell, trees, overlay, settings, scatter):
				continue
			if TreeGameplay.spawn_cell_occluded_by_tree(cell, trees, settings):
				continue
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _sort_cells_by_prefer(a, b, prefer),
	)
	return cells


static func _sort_cells_by_prefer(a: Vector2i, b: Vector2i, prefer: Vector2i) -> bool:
	var da: int = (a - prefer).length_squared()
	var db: int = (b - prefer).length_squared()
	if da != db:
		return da < db
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


static func _pick_spaced_cells(
	candidates: Array[Vector2i],
	count: int,
	map_seed: int,
	salt: int,
	prefer: Vector2i,
) -> Array[Vector2i]:
	if candidates.is_empty() or count <= 0:
		return []

	var sorted: Array[Vector2i] = candidates.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _sort_cells_by_prefer(a, b, prefer),
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(map_seed, salt)
	var start_idx: int = rng.randi() % sorted.size()
	var picked: Array[Vector2i] = []

	for offset: int in range(sorted.size()):
		if picked.size() >= count:
			break
		var cell: Vector2i = sorted[(start_idx + offset) % sorted.size()]
		if _has_spawn_gap(cell, picked):
			picked.append(cell)

	return picked


static func _find_band_spawn(
	grid: PlayerGrid,
	prefer: Vector2i,
	x_min: int,
	x_max_exclusive: int,
	y_min: int,
	y_max: int,
	used: Dictionary,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings,
	scatter: TileMapLayer,
	enforce_gap: bool = true,
) -> Vector2i:
	var max_radius: int = maxi(grid.width, grid.height)
	for radius: int in range(0, max_radius + 1):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell: Vector2i = prefer + Vector2i(dx, dy)
				if cell.x < x_min or cell.x >= x_max_exclusive:
					continue
				if cell.y < y_min or cell.y > y_max:
					continue
				if used.has(cell):
					continue
				if not Walkability.is_walkable(grid, cell, trees, overlay, settings, scatter):
					continue
				if TreeGameplay.spawn_cell_occluded_by_tree(cell, trees, settings):
					continue
				if enforce_gap and not _has_spawn_gap(cell, used.keys()):
					continue
				return cell
	return Vector2i(-1, -1)


static func _has_spawn_gap(cell: Vector2i, others: Array) -> bool:
	for other: Variant in others:
		if other is Vector2i and _chebyshev_distance(cell, other) < MIN_SPAWN_GAP:
			return false
	return true


static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _mix_seed(map_seed: int, salt: int) -> int:
	return int(hash(Vector2i(map_seed, salt)))
