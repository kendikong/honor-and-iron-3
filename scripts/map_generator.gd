class_name MapGenerator
extends RefCounted

## Seeded procedural PlayerGrid — few large water bodies grown to water_ratio, then smoothed.

const ASPECT_W: int = 2
const ASPECT_H: int = 1
const DEFAULT_MAP_WIDTH: int = 32
const DEFAULT_MAP_HEIGHT: int = 16
const MIN_MAP_HEIGHT: int = 8
const MAX_MAP_HEIGHT: int = 20
const MIN_MAP_WIDTH: int = 16
const MAX_MAP_WIDTH: int = 40

var width: int = DEFAULT_MAP_WIDTH
var height: int = DEFAULT_MAP_HEIGHT
var water_ratio: float = 0.22
var map_seed: int = 1
var smooth_passes: int = 4
var tree_count: int = -1
## When tree_count < 0, target ~this fraction of map cells at the **rim** (max density).
## Center receives less via linear edge bias; hard-capped by tree_min_spacing.
var tree_density: float = 0.022
## Minimum Chebyshev gap between tree anchors — 3 ⇒ at least 2 grass cells between trunks.
var tree_min_spacing: int = 3
## Linear edge bias: scatter accept weight at map center (1.0 = rim / tree_density max).
var tree_edge_center_weight: float = 0.14
## Few lake/pond seeds — bodies grow outward until water_ratio is met.
var water_body_seed_count: int = 3
## Few wandering 2-wide dirt trails (not scatter patches).
var dirt_path_count: int = 3
var dirt_path_min_steps: int = 14
var dirt_path_max_steps: int = 26
## Inner 50%×50% band kept sparse — lakes grow on the rim for central movement lanes.
var water_avoid_center_half: bool = true
## Lateral lake spread (~1.6 ≈ +60% vs baseline 1.0; same water_ratio).
var water_spread_scale: float = 1.6

const _MIN_SIZE: int = 16
const _MAX_SIZE: int = 32
## Grass + shore checks use this cell relative to the TREE anchor (NW of 5×6 sprite).
const _TREE_PLACEMENT_CHECK_OFFSET: Vector2i = Vector2i(0, 2)


static func width_for_height(map_height: int) -> int:
	var h: int = clampi(map_height, MIN_MAP_HEIGHT, MAX_MAP_HEIGHT)
	h = int(round(float(h) / 2.0)) * 2
	return h * 2


static func default_size() -> Vector2i:
	return Vector2i(DEFAULT_MAP_WIDTH, DEFAULT_MAP_HEIGHT)


static func snap_widescreen(requested_width: int, requested_height: int) -> Vector2i:
	var h: int = clampi(requested_height, MIN_MAP_HEIGHT, MAX_MAP_HEIGHT)
	h = int(round(float(h) / 2.0)) * 2
	var w: int = h * 2
	if requested_width > 0 and absi(requested_width - w) > absi(requested_height - h):
		w = clampi(requested_width, MIN_MAP_WIDTH, MAX_MAP_WIDTH)
		w = int(round(float(w) / 4.0)) * 4
		h = w / 2
		w = h * 2
	return Vector2i(w, h)


func generate(provenance: PlayerGridProvenance = null) -> PlayerGrid:
	var wide_size: Vector2i = snap_widescreen(width, height)
	var w: int = wide_size.x
	var h: int = wide_size.y
	width = w
	height = h
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed
	if provenance != null:
		provenance.clear()

	var grid: PlayerGrid = PlayerGrid.new(w, h, TileId.Type.GRASS)
	grid = _grow_water_bodies(grid, rng, provenance)
	for pass_idx: int in range(smooth_passes):
		grid = _smooth_pass(grid, provenance, pass_idx + 1)
	grid = _adjust_water_ratio(grid, rng, provenance)
	grid = _scatter_dirt_paths(grid, rng, provenance)
	PlayerGridRepair.repair(grid, provenance)
	grid = _scatter_trees(grid, rng, provenance)
	return grid


## Phase 4 Boredom Test — 16×16 GRASS + DIRT only (no WATER/TREE).
func generate_boredom_wind(provenance: PlayerGridProvenance = null) -> PlayerGrid:
	var w: int = 16
	var h: int = 16
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed
	if provenance != null:
		provenance.clear()
	var grid: PlayerGrid = PlayerGrid.new(w, h, TileId.Type.GRASS)
	var saved_paths: int = dirt_path_count
	dirt_path_count = maxi(dirt_path_count, 2)
	grid = _scatter_dirt_paths(grid, rng, provenance)
	dirt_path_count = saved_paths
	PlayerGridRepair.repair(grid, provenance)
	return grid


## Phase 5 Boredom Test — 16×16 GRASS + scattered RUIN (no WATER/TREE).
func generate_boredom_atmosphere(provenance: PlayerGridProvenance = null) -> PlayerGrid:
	var w: int = 16
	var h: int = 16
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed
	if provenance != null:
		provenance.clear()
	var grid: PlayerGrid = PlayerGrid.new(w, h, TileId.Type.GRASS)
	grid = _scatter_ruins(grid, rng, provenance, 5)
	PlayerGridRepair.repair(grid, provenance)
	return grid


## Phase 6 Boredom Test — 16×16 GRASS + central WATER pond (no TREE/RUIN/DIRT).
func generate_boredom_water(provenance: PlayerGridProvenance = null) -> PlayerGrid:
	var w: int = 16
	var h: int = 16
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed
	if provenance != null:
		provenance.clear()
	var grid: PlayerGrid = PlayerGrid.new(w, h, TileId.Type.GRASS)
	var center: Vector2i = Vector2i(w / 2, h / 2)
	for y: int in range(h):
		for x: int in range(w):
			var pos: Vector2i = Vector2i(x, y)
			if pos.distance_to(center) <= 4.5 + rng.randf_range(-0.4, 0.6):
				grid.set_cell(pos, TileId.Type.WATER)
				if provenance != null:
					provenance.add_step(
						pos,
						"boredom_water_pond",
						TileId.Type.WATER,
						"Phase 6 Boredom Test — central pond cell",
					)
	PlayerGridRepair.repair(grid, provenance)
	return grid


func _scatter_ruins(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	provenance: PlayerGridProvenance,
	count: int,
) -> PlayerGrid:
	if count <= 0:
		return grid
	var placed: int = 0
	var attempts: int = grid.width * grid.height * 2
	while placed < count and attempts > 0:
		attempts -= 1
		var pos: Vector2i = Vector2i(
			rng.randi_range(1, grid.width - 2),
			rng.randi_range(1, grid.height - 2),
		)
		if grid.get_cell(pos) != TileId.Type.GRASS:
			continue
		if _has_water_neighbor(grid, pos):
			continue
		grid.set_cell(pos, TileId.Type.RUIN)
		if provenance != null:
			provenance.add_step(
				pos,
				"ruin_scatter",
				TileId.Type.RUIN,
				"MapGenerator ruin scatter #%d for atmosphere review" % [placed + 1],
			)
		placed += 1
	return grid


func _grow_water_bodies(grid: PlayerGrid, rng: RandomNumberGenerator, provenance: PlayerGridProvenance) -> PlayerGrid:
	var target: int = int(roundf(float(grid.width * grid.height) * water_ratio))
	if target <= 0:
		return grid
	var seed_target: int = _water_body_seed_target(grid)
	var seeds: Array[Vector2i] = []
	var min_spacing: int = maxi(3, mini(grid.width, grid.height) / int(roundf(6.0 * water_spread_scale)))
	var margin: int = 3
	for _attempt: int in range(grid.width * grid.height * 4):
		if seeds.size() >= seed_target:
			break
		var pos: Vector2i = _pick_water_seed_pos(grid, rng, seeds, min_spacing, margin)
		if pos.x < 0:
			continue
		grid.set_cell(pos, TileId.Type.WATER)
		seeds.append(pos)
		if provenance != null:
			provenance.add_step(
				pos,
				"water_body_seed",
				TileId.Type.WATER,
				"Water body seed %d/%d — rim-biased lake start" % [seeds.size(), seed_target],
			)
	if seeds.is_empty():
		var fallback: Vector2i = _pick_edge_fallback_seed(grid, rng, margin)
		grid.set_cell(fallback, TileId.Type.WATER)
		seeds.append(fallback)
	var body_of: Dictionary = {}
	for seed_idx: int in range(seeds.size()):
		body_of[seeds[seed_idx]] = seed_idx
	var current: int = _count_tile(grid, TileId.Type.WATER)
	var grow_attempts: int = int(float(grid.width * grid.height * 16) * water_spread_scale)
	while current < target and grow_attempts > 0:
		grow_attempts -= 1
		var body_idx: int = rng.randi_range(0, seeds.size() - 1)
		if not _grow_water_body_step(grid, rng, provenance, body_of, body_idx):
			if not _grow_water_body_step(grid, rng, provenance, body_of, -1):
				break
		current = _count_tile(grid, TileId.Type.WATER)
	return grid


func _water_body_seed_target(grid: PlayerGrid) -> int:
	if water_body_seed_count <= 0:
		return 0
	var area: int = grid.width * grid.height
	return clampi(maxi(water_body_seed_count, area / 384), 2, 5)


func _is_far_from_points(pos: Vector2i, points: Array[Vector2i], min_spacing: int) -> bool:
	for other: Vector2i in points:
		var dist: int = maxi(absi(pos.x - other.x), absi(pos.y - other.y))
		if dist < min_spacing:
			return false
	return true


func _grow_water_body_step(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	provenance: PlayerGridProvenance,
	body_of: Dictionary,
	body_idx: int,
) -> bool:
	var water_pos: Vector2i = _pick_water_cell_for_body(grid, rng, body_of, body_idx)
	if water_pos.x < 0:
		return false
	var grass_neighbors: Array[Vector2i] = _grass_cardinal_neighbors(grid, water_pos)
	if grass_neighbors.is_empty():
		return false
	var pick: Vector2i = _pick_water_growth_cell(grid, rng, grass_neighbors)
	grid.set_cell(pick, TileId.Type.WATER)
	if body_of.has(water_pos):
		body_of[pick] = int(body_of[water_pos])
	_stamp_water_width_bulge(grid, rng, pick, water_pos, body_of, body_idx, provenance)
	if provenance != null:
		var body_label: String = str(body_of.get(pick, body_idx))
		provenance.add_step(
			pick,
			"water_body_grow",
			TileId.Type.WATER,
			"Water body %s grow — expand lake toward ratio %.2f"
			% [body_label, water_ratio],
		)
	return true


func _pick_water_cell_for_body(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	body_of: Dictionary,
	body_idx: int,
) -> Vector2i:
	for _probe: int in range(grid.width * grid.height):
		var pos: Vector2i = Vector2i(
			rng.randi_range(0, grid.width - 1),
			rng.randi_range(0, grid.height - 1),
		)
		if grid.get_cell(pos) != TileId.Type.WATER:
			continue
		if body_idx < 0:
			return pos
		if int(body_of.get(pos, -1)) == body_idx:
			return pos
	return Vector2i(-1, -1)


func _grass_cardinal_neighbors(grid: PlayerGrid, pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	]:
		var neighbor: Vector2i = pos + offset
		if _in_bounds(grid, neighbor) and grid.get_cell(neighbor) == TileId.Type.GRASS:
			result.append(neighbor)
	return result


func _smooth_pass(
	grid: PlayerGrid,
	provenance: PlayerGridProvenance,
	pass_num: int,
) -> PlayerGrid:
	var next: PlayerGrid = grid.duplicate_grid()
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var water_neighbors: int = _count_water_neighbors(grid, pos)
			var before: int = grid.get_cell(pos)
			var after: int = before
			if water_neighbors >= 5:
				if not water_avoid_center_half or not _is_center_half_cell(grid, pos):
					after = TileId.Type.WATER
			elif water_neighbors <= 2:
				after = TileId.Type.GRASS
			if after != before:
				next.set_cell(pos, after)
				if provenance != null:
					provenance.add_step(
						pos,
						"ca_smooth_%d" % pass_num,
						after,
						"%d water neighbors in 3×3 — CA smooth pass %d"
						% [water_neighbors, pass_num],
					)
	return next


func _adjust_water_ratio(grid: PlayerGrid, rng: RandomNumberGenerator, provenance: PlayerGridProvenance) -> PlayerGrid:
	var target: int = int(roundf(float(grid.width * grid.height) * water_ratio))
	var current: int = _count_tile(grid, TileId.Type.WATER)
	var attempts: int = grid.width * grid.height * 4

	if current == 0 and target > 0:
		var seed_pos: Vector2i = _pick_edge_fallback_seed(grid, rng, 1)
		grid.set_cell(seed_pos, TileId.Type.WATER)
		if provenance != null:
			provenance.add_step(
				seed_pos,
				"water_ratio_seed",
				TileId.Type.WATER,
				"Forced water seed — map had 0 water but target > 0",
			)
		current = 1

	var total_cells: int = grid.width * grid.height
	if current == total_cells and target < total_cells:
		var seed_pos: Vector2i = Vector2i(
			rng.randi_range(0, grid.width - 1),
			rng.randi_range(0, grid.height - 1),
		)
		grid.set_cell(seed_pos, TileId.Type.GRASS)
		if provenance != null:
			provenance.add_step(
				seed_pos,
				"water_ratio_seed",
				TileId.Type.GRASS,
				"Forced grass seed — map was all water",
			)
		current = total_cells - 1

	while current != target and attempts > 0:
		attempts -= 1
		var pos: Vector2i = Vector2i(
			rng.randi_range(0, grid.width - 1),
			rng.randi_range(0, grid.height - 1),
		)
		var tile: int = grid.get_cell(pos)
		if current < target and tile == TileId.Type.GRASS and _has_water_neighbor(grid, pos):
			if water_avoid_center_half and _is_center_half_cell(grid, pos):
				continue
			grid.set_cell(pos, TileId.Type.WATER)
			if provenance != null:
				provenance.add_step(
					pos,
					"water_ratio_expand",
					TileId.Type.WATER,
					"Expand water toward target ratio (%.2f)" % water_ratio,
				)
			current += 1
		elif current > target and tile == TileId.Type.WATER and _has_grass_neighbor(grid, pos):
			if water_avoid_center_half and not _is_center_half_cell(grid, pos) and rng.randf() < 0.35:
				continue
			grid.set_cell(pos, TileId.Type.GRASS)
			if provenance != null:
				provenance.add_step(
					pos,
					"water_ratio_shrink",
					TileId.Type.GRASS,
					"Shrink water toward target ratio (%.2f)" % water_ratio,
				)
			current -= 1

	return grid


func _count_water_neighbors(grid: PlayerGrid, pos: Vector2i) -> int:
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor: Vector2i = pos + Vector2i(dx, dy)
			if not _in_bounds(grid, neighbor):
				continue
			if grid.get_cell(neighbor) == TileId.Type.WATER:
				count += 1
	return count


func _has_water_neighbor(grid: PlayerGrid, pos: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor: Vector2i = pos + Vector2i(dx, dy)
			if _in_bounds(grid, neighbor) and grid.get_cell(neighbor) == TileId.Type.WATER:
				return true
	return false


func _has_grass_neighbor(grid: PlayerGrid, pos: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor: Vector2i = pos + Vector2i(dx, dy)
			if _in_bounds(grid, neighbor) and grid.get_cell(neighbor) == TileId.Type.GRASS:
				return true
	return false


func _count_tile(grid: PlayerGrid, tile_id: int) -> int:
	var count: int = 0
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			if grid.get_cell(Vector2i(x, y)) == tile_id:
				count += 1
	return count


func _in_bounds(grid: PlayerGrid, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid.width and pos.y < grid.height


func _is_center_half_cell(grid: PlayerGrid, pos: Vector2i) -> bool:
	var inset_x: int = maxi(1, grid.width / 4)
	var inset_y: int = maxi(1, grid.height / 4)
	return (
		pos.x >= inset_x
		and pos.x < grid.width - inset_x
		and pos.y >= inset_y
		and pos.y < grid.height - inset_y
	)


func _water_edge_weight(grid: PlayerGrid, pos: Vector2i) -> float:
	var cx: float = (float(grid.width) - 1.0) * 0.5
	var cy: float = (float(grid.height) - 1.0) * 0.5
	var nx: float = absf(float(pos.x) - cx) / maxf(cx, 1.0)
	var ny: float = absf(float(pos.y) - cy) / maxf(cy, 1.0)
	return maxf(nx, ny)


func _pick_water_seed_pos(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	seeds: Array[Vector2i],
	min_spacing: int,
	margin: int,
) -> Vector2i:
	var best_pos: Vector2i = Vector2i(-1, -1)
	var best_weight: float = -1.0
	for _attempt: int in range(grid.width * grid.height):
		var pos: Vector2i = Vector2i(
			rng.randi_range(margin, grid.width - 1 - margin),
			rng.randi_range(margin, grid.height - 1 - margin),
		)
		if grid.get_cell(pos) != TileId.Type.GRASS:
			continue
		if not _is_far_from_points(pos, seeds, min_spacing):
			continue
		if water_avoid_center_half and _is_center_half_cell(grid, pos):
			continue
		var weight: float = _water_edge_weight(grid, pos)
		if weight > best_weight or (weight == best_weight and rng.randf() < 0.5):
			best_weight = weight
			best_pos = pos
	return best_pos


func _pick_edge_fallback_seed(grid: PlayerGrid, rng: RandomNumberGenerator, margin: int) -> Vector2i:
	var edge_positions: Array[Vector2i] = []
	for y: int in range(margin, grid.height - margin):
		for x: int in range(margin, grid.width - margin):
			var pos: Vector2i = Vector2i(x, y)
			if water_avoid_center_half and _is_center_half_cell(grid, pos):
				continue
			if _water_edge_weight(grid, pos) >= 0.72:
				edge_positions.append(pos)
	if edge_positions.is_empty():
		return Vector2i(margin, margin)
	return edge_positions[rng.randi_range(0, edge_positions.size() - 1)]


func _water_neighbor_count(grid: PlayerGrid, pos: Vector2i) -> int:
	var count: int = 0
	for offset: Vector2i in [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	]:
		var neighbor: Vector2i = pos + offset
		if _in_bounds(grid, neighbor) and grid.get_cell(neighbor) == TileId.Type.WATER:
			count += 1
	return count


func _pick_water_growth_cell(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	candidates: Array[Vector2i],
) -> Vector2i:
	var pool: Array[Vector2i] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for pos: Vector2i in candidates:
		if water_avoid_center_half and _is_center_half_cell(grid, pos):
			continue
		var bulk: float = float(_water_neighbor_count(grid, pos))
		# Favor wide fill (2+ water cardinals) over thin rim tendrils.
		var spread: float = water_spread_scale
		var weight: float = 0.2 + bulk * bulk * 0.55 * spread + _water_edge_weight(grid, pos) * 0.18
		pool.append(pos)
		weights.append(weight)
		total += weight
	if pool.is_empty():
		for pos: Vector2i in candidates:
			var bulk: float = float(_water_neighbor_count(grid, pos))
			var spread: float = water_spread_scale
			var weight: float = 0.1 + bulk * bulk * 0.45 * spread + _water_edge_weight(grid, pos) * 0.12
			pool.append(pos)
			weights.append(weight)
			total += weight
	var roll: float = rng.randf() * total
	for i: int in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _stamp_water_width_bulge(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	primary: Vector2i,
	from_water: Vector2i,
	body_of: Dictionary,
	body_idx: int,
	provenance: PlayerGridProvenance,
) -> void:
	if rng.randf() > minf(0.68, 0.44 * water_spread_scale):
		return
	var grow_dir: Vector2i = primary - from_water
	var side_offsets: Array[Vector2i] = []
	if grow_dir.x != 0:
		side_offsets = [Vector2i(0, -1), Vector2i(0, 1)]
	elif grow_dir.y != 0:
		side_offsets = [Vector2i(-1, 0), Vector2i(1, 0)]
	else:
		side_offsets = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var best: Vector2i = Vector2i(-1, -1)
	var best_bulk: int = -1
	for offset: Vector2i in side_offsets:
		var buddy: Vector2i = primary + offset
		if not _in_bounds(grid, buddy):
			continue
		if grid.get_cell(buddy) != TileId.Type.GRASS:
			continue
		if water_avoid_center_half and _is_center_half_cell(grid, buddy):
			continue
		var bulk: int = _water_neighbor_count(grid, buddy)
		if bulk > best_bulk or (bulk == best_bulk and rng.randf() < 0.5):
			best_bulk = bulk
			best = buddy
	if best.x < 0:
		return
	grid.set_cell(best, TileId.Type.WATER)
	if body_of.has(primary):
		body_of[best] = int(body_of[primary])
	elif body_of.has(from_water):
		body_of[best] = int(body_of[from_water])
	if provenance != null:
		provenance.add_step(
			best,
			"water_body_bulge",
			TileId.Type.WATER,
			"Water body %s width bulge beside (%d,%d)"
			% [str(body_of.get(best, body_idx)), primary.x, primary.y],
		)


func _scatter_dirt_paths(grid: PlayerGrid, rng: RandomNumberGenerator, provenance: PlayerGridProvenance) -> PlayerGrid:
	var path_target: int = _dirt_path_target(grid)
	if path_target <= 0:
		return grid
	const CARDINALS: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for path_idx: int in range(path_target):
		var carved: bool = false
		for _attempt: int in range(grid.width * grid.height):
			var start: Vector2i = Vector2i(
				rng.randi_range(2, grid.width - 3),
				rng.randi_range(2, grid.height - 3),
			)
			var dir: Vector2i = CARDINALS[rng.randi_range(0, CARDINALS.size() - 1)]
			if not _can_carve_dirt_brush(grid, start, dir):
				continue
			if _has_water_neighbor(grid, start):
				continue
			var steps: int = rng.randi_range(dirt_path_min_steps, dirt_path_max_steps)
			var pos: Vector2i = start
			var painted: int = 0
			for step: int in range(steps):
				if not _can_carve_dirt_brush(grid, pos, dir):
					break
				painted += _stamp_dirt_path_brush(
					grid, pos, dir, provenance, path_idx + 1, step + 1,
				)
				pos += dir
				var roll: float = rng.randf()
				if roll < 0.62:
					pass
				elif roll < 0.81:
					dir = Vector2i(-dir.y, dir.x)
				else:
					dir = Vector2i(dir.y, -dir.x)
			if painted >= 8:
				carved = true
				break
		if not carved:
			break
	return grid


func _dirt_path_target(grid: PlayerGrid) -> int:
	if dirt_path_count <= 0:
		return 0
	var area: int = grid.width * grid.height
	return clampi(maxi(dirt_path_count, area / 512), 1, 6)


func _can_carve_dirt_brush(grid: PlayerGrid, center: Vector2i, dir: Vector2i) -> bool:
	var perp: Vector2i = Vector2i(-dir.y, dir.x)
	for side: int in 2:
		var pos: Vector2i = center + perp * side
		if not _in_bounds(grid, pos):
			return false
		var tile: int = grid.get_cell(pos)
		if tile == TileId.Type.WATER or tile == TileId.Type.TREE:
			return false
	return true


func _stamp_dirt_path_brush(
	grid: PlayerGrid,
	center: Vector2i,
	dir: Vector2i,
	provenance: PlayerGridProvenance,
	path_idx: int,
	step_idx: int,
) -> int:
	var perp: Vector2i = Vector2i(-dir.y, dir.x)
	var painted: int = 0
	for side: int in 2:
		var pos: Vector2i = center + perp * side
		if not _in_bounds(grid, pos):
			continue
		var tile: int = grid.get_cell(pos)
		if tile != TileId.Type.GRASS and tile != TileId.Type.DIRT:
			continue
		if tile == TileId.Type.DIRT:
			continue
		grid.set_cell(pos, TileId.Type.DIRT)
		painted += 1
		if provenance != null:
			provenance.add_step(
				pos,
				"dirt_path",
				TileId.Type.DIRT,
				"Dirt path %d step %d — 2-wide trail brush" % [path_idx, step_idx],
			)
	return painted


func _scatter_trees(grid: PlayerGrid, rng: RandomNumberGenerator, provenance: PlayerGridProvenance) -> PlayerGrid:
	var target: int = _tree_scatter_target(grid)
	if target <= 0:
		return grid
	var placed: int = 0
	var anchors: Array[Vector2i] = []
	var attempts: int = grid.width * grid.height * 28
	while placed < target and attempts > 0:
		attempts -= 1
		var pos: Vector2i = _pick_tree_scatter_pos(grid, rng, anchors)
		if not _can_place_tree(grid, pos, anchors):
			continue
		if rng.randf() > _tree_edge_scatter_weight(grid, pos):
			continue
		grid.set_cell(pos, TileId.Type.TREE)
		anchors.append(pos)
		if provenance != null:
			provenance.add_step(
				pos,
				"tree_scatter",
				TileId.Type.TREE,
				"Forest scatter #%d/%d (spacing=%d)"
				% [placed + 1, target, tree_min_spacing],
			)
		placed += 1
	return grid


func _tree_scatter_target(grid: PlayerGrid) -> int:
	if tree_count >= 0:
		return tree_count
	var area: int = grid.width * grid.height
	var edge_max_density: float = minf(tree_density, _tree_edge_density_cap(grid))
	var by_density: int = int(roundf(float(area) * edge_max_density))
	var spacing: int = maxi(tree_min_spacing, 2)
	var slots_per_axis: int = maxi(1, int(grid.width / spacing))
	var slots: int = slots_per_axis * maxi(1, int(grid.height / spacing))
	return clampi(by_density, 0, slots)


## Rim density ceiling from spacing — spacing 3 ⇒ ~0.056 (below Chebyshev packing 1/9).
func _tree_edge_density_cap(grid: PlayerGrid) -> float:
	var spacing: int = maxi(tree_min_spacing, 2)
	return 1.0 / float(spacing * spacing) * 0.5


## 0 at map center → 1 at rim (linear). Used for tree scatter accept weight.
func _tree_edge_scatter_weight(grid: PlayerGrid, pos: Vector2i) -> float:
	var edge: float = _water_edge_weight(grid, pos)
	return lerpf(clampf(tree_edge_center_weight, 0.0, 1.0), 1.0, edge)


func _pick_tree_scatter_pos(
	grid: PlayerGrid,
	rng: RandomNumberGenerator,
	anchors: Array[Vector2i],
) -> Vector2i:
	if not anchors.is_empty() and rng.randf() < 0.42:
		var base: Vector2i = anchors[rng.randi() % anchors.size()]
		return base + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
	const SAMPLE_BATCH: int = 14
	var best_pos: Vector2i = Vector2i(
		rng.randi_range(0, grid.width - 1),
		rng.randi_range(0, grid.height - 1),
	)
	var best_score: float = _tree_edge_scatter_weight(grid, best_pos) * rng.randf()
	for _i: int in range(SAMPLE_BATCH):
		var candidate: Vector2i = Vector2i(
			rng.randi_range(0, grid.width - 1),
			rng.randi_range(0, grid.height - 1),
		)
		var score: float = _tree_edge_scatter_weight(grid, candidate) * rng.randf()
		if score > best_score:
			best_score = score
			best_pos = candidate
	return best_pos


func _can_place_tree(grid: PlayerGrid, pos: Vector2i, anchors: Array[Vector2i]) -> bool:
	if not _in_bounds(grid, pos):
		return false
	var check: Vector2i = pos + _TREE_PLACEMENT_CHECK_OFFSET
	if not _tree_placement_check_ok(grid, check):
		return false
	if not _tree_footprint_fits_south_phantom(grid, pos):
		return false
	var gap: int = maxi(tree_min_spacing, 2)
	for anchor: Vector2i in anchors:
		var dist: int = maxi(absi(pos.x - anchor.x), absi(pos.y - anchor.y))
		if dist < gap:
			return false
	return true


func _tree_placement_check_ok(grid: PlayerGrid, check: Vector2i) -> bool:
	if _in_bounds(grid, check):
		if grid.get_cell(check) != TileId.Type.GRASS:
			return false
		return not _has_water_neighbor(grid, check)
	var owner: Vector2i = PlayerGrid.bottom_phantom_owner(grid, check)
	if owner.x < 0:
		return false
	if not PlayerGrid.tile_extends_grass_phantom(grid.get_cell(owner)):
		return false
	return not _has_water_neighbor(grid, owner)


## 5×6 footprint rows below the map need grass phantom columns on the bottom row.
func _tree_footprint_fits_south_phantom(grid: PlayerGrid, anchor: Vector2i) -> bool:
	const FOOTPRINT: Vector2i = Vector2i(5, 6)
	var south_last: int = anchor.y + FOOTPRINT.y - 1
	if south_last < grid.height:
		return true
	for dx: int in range(FOOTPRINT.x):
		var col_x: int = anchor.x + dx
		if col_x < 0 or col_x >= grid.width:
			return false
		var owner: Vector2i = Vector2i(col_x, grid.height - 1)
		if not PlayerGrid.tile_extends_grass_phantom(grid.get_cell(owner)):
			return false
		if _has_water_neighbor(grid, owner):
			return false
	return true
