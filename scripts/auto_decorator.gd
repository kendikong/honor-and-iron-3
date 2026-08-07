class_name AutoDecorator
extends RefCounted

## Reads PlayerGrid â†’ writes TileMapLayer cells. Sole owner of tile cell placement.

const SOURCE_FOREST: int = TileSetFactory.SOURCE_FOREST
const SOURCE_PROPS_32: int = TileSetFactory.SOURCE_PROPS_32
const _C = preload("res://scripts/mana_seed_constants.gd")

const TERRAIN_SET: int = TileSetFactory.TERRAIN_SET
const TERRAIN_DIRT: int = TileSetFactory.TERRAIN_DIRT
const TERRAIN_WATER: int = TileSetFactory.TERRAIN_WATER

# Opaque grass base â€” interior tiles only (no Wang dirt/elevation/water assignment).
const _GRASS_BASE_VARIANTS: Array[int] = [98, 97]
# 16Ã—16 forest scatter on OverlayLayer.
const _PEBBLE_VARIANTS: Array[int] = [88, 89]
const _FLORA_VARIANTS: Array[int] = [91, 90, 104, 105, 106]
## Rare weed/flower patches â€” only when a flora scatter roll already succeeded.
const _FLORA_CLUSTER_CHANCE: float = 0.06
const _FLORA_CLUSTER_SIZE_MIN: int = 2
const _FLORA_CLUSTER_SIZE_MAX: int = 5
# 32Ã—32 environmental props (stump, boulder, bush, plant) â€” not farm crops.
const _PROPS_32_ATLAS_X: Array[int] = [0, 1, 2, 3]
## Extra grass cells to keep clear around each 80Ã—96 tree (canopy overshoot + prop spill).
const _TREE_SCATTER_MARGIN: int = 1

const _ROCK_TILE: int = 52
const _RUIN_TILE: int = 107

## Overall decoration scatter multiplier (0 = none, 1 = dense).
var decoration_density: float = 0.14
var map_seed: int = 1
var tree_variant_b: bool = false
var render_provenance: MapRenderProvenance = null
var logical_provenance: PlayerGridProvenance = null

var ecology_hints: Dictionary = {}

var _ground: TileMapLayer
## Pebbles/flora â€” sparse overlay art above grass (never replaces grass cells).
var _scatter: TileMapLayer
var _overlay: TileMapLayer
var _trees: TileMapLayer
var _vfx: TileMapLayer
var _shadow_sprites: Node2D
## Visual-only OOB extension ring â€” not in PlayerGrid, not used for gameplay queries.
var _phantom: TileMapLayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(
	ground: TileMapLayer,
	scatter: TileMapLayer,
	overlay: TileMapLayer,
	trees: TileMapLayer,
	vfx: TileMapLayer,
	phantom: TileMapLayer,
	shadow_sprites: Node2D,
	tile_set: TileSet,
) -> void:
	_ground = ground
	_scatter = scatter
	_overlay = overlay
	_trees = trees
	_vfx = vfx
	_phantom = phantom
	_shadow_sprites = shadow_sprites
	_ground.tile_set = tile_set
	_scatter.tile_set = tile_set
	_overlay.tile_set = tile_set
	_overlay.y_sort_enabled = true
	_overlay.z_as_relative = false
	_overlay.z_index = _C.Z_OVERLAY
	_trees.tile_set = tile_set
	_trees.y_sort_enabled = true
	_trees.z_as_relative = false
	_trees.z_index = _C.Z_TREE
	_vfx.tile_set = tile_set
	_phantom.tile_set = tile_set
	if _shadow_sprites != null:
		_shadow_sprites.y_sort_enabled = false


func regenerate(grid: PlayerGrid) -> void:
	PlayerGridRepair.repair(grid, logical_provenance)
	_ground.clear()
	_scatter.clear()
	_phantom.clear()
	_overlay.clear()
	_trees.clear()
	_vfx.clear()
	if render_provenance != null:
		render_provenance.clear()
	ecology_hints = {}
	_rng.seed = map_seed

	var water_cells: Array[Vector2i] = []
	var dirt_cells: Array[Vector2i] = []
	var tree_cells: Array[Vector2i] = []

	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			match grid.get_cell(pos):
				TileId.Type.GRASS:
					pass
				TileId.Type.WATER:
					water_cells.append(pos)
				TileId.Type.DIRT:
					dirt_cells.append(pos)
				TileId.Type.ROCK:
					_set_ground(
						pos,
						_ROCK_TILE,
						"player_grid_rock",
						"PlayerGrid ROCK â€” single-tile elevation art #52",
					)
				TileId.Type.RUIN:
					_set_ground(
						pos,
						_RUIN_TILE,
						"player_grid_ruin",
						"PlayerGrid RUIN â€” ruin floor prop #107",
					)
				TileId.Type.TREE:
					tree_cells.append(pos)
				_:
					push_error("AutoDecorator: unknown TileId %d at %s" % [grid.get_cell(pos), pos])
					assert(false, "Unknown TileId in PlayerGrid")

	var edge_phantom_info: Dictionary = _paint_edge_phantoms(grid)

	if not dirt_cells.is_empty():
		_terrain_connect_in_map(dirt_cells, TERRAIN_DIRT)
	if not water_cells.is_empty():
		_terrain_connect_in_map(water_cells, TERRAIN_WATER)

	_commit_edge_phantoms_visible(edge_phantom_info)

	const MAX_DOUBLE_CORNER_PASSES: int = 8
	for _dc_pass: int in range(MAX_DOUBLE_CORNER_PASSES):
		if not PlayerGridRepair.repair_painted_water_double_corners(
			grid, _ground, logical_provenance,
		):
			break
		_reconnect_water_terrain(grid)

	WaterDepthPainter.apply(grid, _ground, _rng, render_provenance)

	_fill_deferred_grass_interiors(grid)

	# Ground/water painting may flip PlayerGrid cells â€” stabilize before any overlay/props.
	PlayerGridRepair.repair(grid, logical_provenance)

	for pos: Vector2i in tree_cells:
		EcologySeeder.apply_tree_stub(_trees, pos, _rng, render_provenance, tree_variant_b)
		EcologySeeder.apply_tree_surroundings(grid, pos, _overlay, _rng, render_provenance)

	_strip_overlay_under_tree_footprints(tree_cells)
	_strip_scatter_under_tree_footprints(tree_cells)
	_scatter_decorations(grid, tree_cells)
	_strip_overlay_under_tree_footprints(tree_cells)
	_strip_scatter_under_tree_footprints(tree_cells)

	if render_provenance != null:
		render_provenance.finalize_overlay_index()

	ecology_hints = EcologySeeder.build_ecology_hints(grid, tree_cells, render_provenance, _rng)


func _paint_grass_base(pos: Vector2i) -> void:
	var tile_id: int = _pick_variant(_GRASS_BASE_VARIANTS)
	_set_ground(
		pos,
		tile_id,
		"grass_base",
		"Opaque grass interior #%d (random variant, not Wang)" % tile_id,
	)


## After terrain_connect â€” fill only grass/tree cells Godot did not assign wang tiles to.
func _fill_deferred_grass_interiors(grid: PlayerGrid) -> void:
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var tile_id: int = grid.get_cell(pos)
			if tile_id != TileId.Type.GRASS and tile_id != TileId.Type.TREE:
				continue
			if _ground.get_cell_source_id(pos) != -1:
				continue
			_paint_grass_base(pos)


## Paint one-cell OOB extensions matching each edge cell's logical type, then erase after connect.
## Water/dirt phantoms use terrain_connect; grass/tree/rock/ruin use opaque grass #97.
## Returns oob_pos â†’ { tile_id, extends_from }.
func _paint_edge_phantoms(grid: PlayerGrid) -> Dictionary:
	var phantom_info: Dictionary = _collect_edge_phantom_types(grid)
	var grass_oob: Array[Vector2i] = []
	var dirt_oob: Array[Vector2i] = []
	var water_oob: Array[Vector2i] = []

	for oob_pos: Vector2i in phantom_info.keys():
		match int(phantom_info[oob_pos]["tile_id"]):
			TileId.Type.WATER:
				water_oob.append(oob_pos)
			TileId.Type.DIRT:
				dirt_oob.append(oob_pos)
			_:
				grass_oob.append(oob_pos)

	for pos: Vector2i in grass_oob:
		var atlas: Vector2i = Vector2i(97 % 16, int(97 / 16))
		_ground.set_cell(pos, SOURCE_FOREST, atlas, 0)

	if not dirt_oob.is_empty():
		_ground.set_cells_terrain_connect(dirt_oob, TERRAIN_SET, TERRAIN_DIRT, false)
	if not water_oob.is_empty():
		_ground.set_cells_terrain_connect(water_oob, TERRAIN_SET, TERRAIN_WATER, false)

	return phantom_info


## Move OOB peering tiles off GroundLayer onto the transparent PhantomLayer (visual only).
func _commit_edge_phantoms_visible(phantom_info: Dictionary) -> void:
	for pos: Vector2i in phantom_info.keys():
		var source_id: int = _ground.get_cell_source_id(pos)
		if source_id == -1:
			continue
		var atlas: Vector2i = _ground.get_cell_atlas_coords(pos)
		var alternative: int = _ground.get_cell_alternative_tile(pos)
		_phantom.set_cell(pos, source_id, atlas, alternative)
		_ground.erase_cell(pos)
		var meta: Dictionary = phantom_info[pos]
		var logical_type: int = int(meta["tile_id"])
		var extends_from: Vector2i = meta["extends_from"]
		if render_provenance != null:
			render_provenance.record_phantom(
				pos,
				source_id,
				atlas,
				logical_type,
				extends_from,
				"edge_phantom",
				"Hidden map extension from (%d,%d) %s â€” peering only, not PlayerGrid"
				% [
					extends_from.x,
					extends_from.y,
					TileId.type_name(logical_type),
				],
			)


func _terrain_connect_in_map(cells: Array[Vector2i], terrain: int) -> void:
	_ground.set_cells_terrain_connect(cells, TERRAIN_SET, terrain, false)

	var terrain_name: String = TerrainPeeringBridge.terrain_label(terrain)
	var reason: String = "terrain_connect(%s)" % terrain_name
	for pos: Vector2i in cells:
		if _ground.get_cell_source_id(pos) == -1:
			continue
		var atlas: Vector2i = _ground.get_cell_atlas_coords(pos)
		var local_id: int = atlas.x + atlas.y * 16
		var entry: Dictionary = TileCatalog.describe_forest_tile(local_id)
		_record_ground(
			pos,
			SOURCE_FOREST,
			atlas,
			reason,
			"Godot peering picked #%d â€” %s Â· %s"
			% [local_id, TileCatalog.category_title(str(entry["category"])), str(entry["orientation"])],
		)


func _reconnect_water_terrain(grid: PlayerGrid) -> void:
	var water_cells: Array[Vector2i] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			water_cells.append(pos)
			_ground.erase_cell(pos)
	if water_cells.is_empty():
		return
	var staged_oob: Array[Vector2i] = _stage_edge_phantoms_on_ground(grid)
	var water_oob: Array[Vector2i] = _collect_water_phantom_oob(grid)
	if not water_oob.is_empty():
		_ground.set_cells_terrain_connect(water_oob, TERRAIN_SET, TERRAIN_WATER, false)
	_terrain_connect_in_map(water_cells, TERRAIN_WATER)
	_sync_edge_phantoms_from_ground(staged_oob, grid)


## Copy PhantomLayer peering halo onto GroundLayer so terrain_connect sees off-map neighbors.
func _stage_edge_phantoms_on_ground(grid: PlayerGrid) -> Array[Vector2i]:
	var staged: Array[Vector2i] = []
	if _phantom == null:
		return staged
	for oob: Vector2i in _collect_edge_phantom_oob_positions(grid):
		if _phantom.get_cell_source_id(oob) == -1:
			continue
		_ground.set_cell(
			oob,
			_phantom.get_cell_source_id(oob),
			_phantom.get_cell_atlas_coords(oob),
			_phantom.get_cell_alternative_tile(oob),
		)
		staged.append(oob)
	return staged


func _sync_edge_phantoms_from_ground(staged_oob: Array[Vector2i], grid: PlayerGrid) -> void:
	if _phantom == null:
		return
	for oob: Vector2i in staged_oob:
		var source_id: int = _ground.get_cell_source_id(oob)
		if source_id == -1:
			continue
		var atlas: Vector2i = _ground.get_cell_atlas_coords(oob)
		var alternative: int = _ground.get_cell_alternative_tile(oob)
		_phantom.set_cell(oob, source_id, atlas, alternative)
		_ground.erase_cell(oob)
		if render_provenance == null:
			continue
		var owner: Vector2i = _owner_in_map_cell_for_oob(grid, oob)
		if owner.x < 0:
			continue
		render_provenance.record_phantom(
			oob,
			source_id,
			atlas,
			grid.get_cell(owner),
			owner,
			"edge_phantom_reconnect",
			"Peering halo refreshed after water terrain_connect from (%d,%d) %s"
			% [owner.x, owner.y, TileId.type_name(grid.get_cell(owner))],
		)


static func _collect_water_phantom_oob(grid: PlayerGrid) -> Array[Vector2i]:
	var phantom_info: Dictionary = _collect_edge_phantom_types(grid)
	var water_oob: Array[Vector2i] = []
	for oob_pos: Vector2i in phantom_info.keys():
		if int(phantom_info[oob_pos]["tile_id"]) == TileId.Type.WATER:
			water_oob.append(oob_pos)
	return water_oob


static func _collect_edge_phantom_types(grid: PlayerGrid) -> Dictionary:
	var phantoms: Dictionary = {}
	for oob: Vector2i in _collect_edge_phantom_oob_positions(grid):
		var owner: Vector2i = _owner_in_map_cell_for_oob(grid, oob)
		if owner.x < 0:
			continue
		phantoms[oob] = {
			"tile_id": grid.get_cell(owner),
			"extends_from": owner,
		}
	return phantoms


## Each OOB cell is owned by its cardinal in-map neighbor (not first diagonal scan hit).
static func _owner_in_map_cell_for_oob(grid: PlayerGrid, oob: Vector2i) -> Vector2i:
	var bottom_owner: Vector2i = PlayerGrid.bottom_phantom_owner(grid, oob)
	if bottom_owner.x >= 0:
		return bottom_owner
	const CARDINALS: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	]
	for offset: Vector2i in CARDINALS:
		var candidate: Vector2i = oob + offset
		if _cell_in_bounds(grid, candidate):
			return candidate
	for offset: Vector2i in _PEER_OFFSETS:
		var candidate: Vector2i = oob + offset
		if _cell_in_bounds(grid, candidate):
			return candidate
	return Vector2i(-1, -1)


static func _collect_edge_phantom_oob_positions(grid: PlayerGrid) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var result: Array[Vector2i] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			for offset: Vector2i in _PEER_OFFSETS:
				var oob: Vector2i = pos + offset
				if _cell_in_bounds(grid, oob):
					continue
				if seen.has(oob):
					continue
				seen[oob] = true
				result.append(oob)
	for x: int in range(grid.width):
		var bottom: Vector2i = Vector2i(x, grid.height - 1)
		if not PlayerGrid.tile_extends_grass_phantom(grid.get_cell(bottom)):
			continue
		for depth: int in range(1, PlayerGrid.BOTTOM_PHANTOM_GRASS_DEPTH + 1):
			var south: Vector2i = Vector2i(x, grid.height - 1 + depth)
			if seen.has(south):
				continue
			seen[south] = true
			result.append(south)
	return result


static func _cell_in_bounds(grid: PlayerGrid, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid.width and pos.y < grid.height


const _PEER_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


func _scatter_decorations(grid: PlayerGrid, tree_cells: Array[Vector2i]) -> void:
	if decoration_density <= 0.0:
		return
	var scatter_blocked: Dictionary = MapRenderProvenance.blocked_cells_for_anchors(
		tree_cells,
		TileSetFactory.SOURCE_TREES,
		_TREE_SCATTER_MARGIN,
	)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.GRASS:
				continue
			if scatter_blocked.has(pos):
				continue
			if _has_blocking_overlay(pos):
				continue
			_try_scatter_at(grid, pos, scatter_blocked)

	_strip_forest_under_prop_footprints()


func _try_scatter_at(grid: PlayerGrid, pos: Vector2i, scatter_blocked: Dictionary) -> void:
	var roll: float = _rng.randf()
	if roll >= decoration_density:
		return

	var pool_roll: float = _rng.randf()
	if pool_roll < 0.12:
		if _can_place_props_32(pos, scatter_blocked):
			_place_props_32(pos)
			MapRenderProvenance.mark_footprint_blocked(
				scatter_blocked, pos, SOURCE_PROPS_32,
			)
			_strip_forest_overlay_in_footprint(pos, SOURCE_PROPS_32)
	elif pool_roll < 0.42:
		_place_forest_ground_scatter(
			pos,
			_PEBBLE_VARIANTS,
			"scatter_pebble",
			"Decoration scatter â€” pebble pool (~30%% of hits)",
		)
	else:
		if _rng.randf() < _FLORA_CLUSTER_CHANCE:
			_scatter_flora_cluster(grid, pos, scatter_blocked)
		else:
			_place_forest_ground_scatter(
				pos,
				_FLORA_VARIANTS,
				"scatter_flora",
				"Decoration scatter â€” weed/flower pool (~58%% of hits)",
			)


func _can_scatter_flora_at(
	grid: PlayerGrid,
	pos: Vector2i,
	scatter_blocked: Dictionary,
) -> bool:
	if not _cell_in_bounds(grid, pos):
		return false
	if grid.get_cell(pos) != TileId.Type.GRASS:
		return false
	if scatter_blocked.has(pos):
		return false
	return not _has_blocking_overlay(pos)


func _scatter_flora_cluster(
	grid: PlayerGrid,
	origin: Vector2i,
	scatter_blocked: Dictionary,
) -> void:
	var goal: int = _rng.randi_range(_FLORA_CLUSTER_SIZE_MIN, _FLORA_CLUSTER_SIZE_MAX)
	var open: Array[Vector2i] = [origin]
	var placed: int = 0
	var seen: Dictionary = {}
	while placed < goal and not open.is_empty():
		var pick_idx: int = _rng.randi() % open.size()
		var pos: Vector2i = open[pick_idx]
		open.remove_at(pick_idx)
		var key: String = "%d,%d" % [pos.x, pos.y]
		if seen.has(key):
			continue
		seen[key] = true
		if not _can_scatter_flora_at(grid, pos, scatter_blocked):
			continue
		_place_forest_ground_scatter(
			pos,
			_FLORA_VARIANTS,
			"scatter_flora_cluster",
			"Flora cluster patch (%d/%d)" % [placed + 1, goal],
		)
		placed += 1
		for offset: Vector2i in _PEER_OFFSETS:
			if _rng.randf() >= 0.62:
				continue
			var next: Vector2i = pos + offset
			if not _cell_in_bounds(grid, next):
				continue
			open.append(next)
	if placed == 0 and _can_scatter_flora_at(grid, origin, scatter_blocked):
		_place_forest_ground_scatter(
			origin,
			_FLORA_VARIANTS,
			"scatter_flora",
			"Decoration scatter â€” weed/flower pool (~58%% of hits)",
		)


static func _fits_footprint(
	pos: Vector2i,
	footprint: Vector2i,
	blocked: Dictionary,
) -> bool:
	for dy: int in range(footprint.y):
		for dx: int in range(footprint.x):
			if blocked.has(pos + Vector2i(dx, dy)):
				return false
	return true


func _can_place_props_32(pos: Vector2i, scatter_blocked: Dictionary) -> bool:
	var footprint: Vector2i = MapRenderProvenance.footprint_for_source(SOURCE_PROPS_32)
	if not _fits_footprint(pos, footprint, scatter_blocked):
		return false
	return not _footprint_has_overlay(pos, footprint)


func _strip_forest_overlay_in_footprint(anchor: Vector2i, source_id: int) -> void:
	var footprint: Vector2i = MapRenderProvenance.footprint_for_source(source_id)
	for dy: int in range(footprint.y):
		for dx: int in range(footprint.x):
			var cell: Vector2i = anchor + Vector2i(dx, dy)
			if _overlay.get_cell_source_id(cell) == SOURCE_FOREST:
				_overlay.erase_cell(cell)
				if render_provenance != null:
					render_provenance.erase_overlay_anchor(cell)


func _strip_forest_under_prop_footprints() -> void:
	if render_provenance == null:
		return
	for entry: Dictionary in render_provenance.overlay_anchors.values():
		if int(entry.get("source_id", -1)) != SOURCE_PROPS_32:
			continue
		_strip_forest_overlay_in_footprint(entry["anchor"], SOURCE_PROPS_32)


func _footprint_has_overlay(pos: Vector2i, footprint: Vector2i) -> bool:
	for dy: int in range(footprint.y):
		for dx: int in range(footprint.x):
			if _has_blocking_overlay(pos + Vector2i(dx, dy)):
				return true
	return false


func _strip_overlay_under_tree_footprints(tree_cells: Array[Vector2i]) -> void:
	var footprint: Vector2i = MapRenderProvenance.footprint_for_source(TileSetFactory.SOURCE_TREES)
	for anchor: Vector2i in tree_cells:
		for dy: int in range(-1, footprint.y):
			for dx: int in range(-1, footprint.x):
				var cell: Vector2i = anchor + Vector2i(dx, dy)
				if not MapRenderProvenance.forest_occluded_by_tree_canopy(anchor, cell):
					continue
				var source_id: int = _overlay.get_cell_source_id(cell)
				if source_id == SOURCE_FOREST or source_id == SOURCE_PROPS_32:
					_overlay.erase_cell(cell)
					if render_provenance != null:
						render_provenance.erase_overlay_anchor(cell)


func _place_forest_overlay(
	pos: Vector2i,
	variants: Array[int],
	reason: String,
	detail_prefix: String,
) -> void:
	var local_id: int = _pick_scatter_safe_variant(variants)
	if local_id < 0:
		return
	var atlas: Vector2i = Vector2i(local_id % 16, local_id / 16)
	_overlay.set_cell(pos, SOURCE_FOREST, atlas, 0)
	if render_provenance == null:
		return
	var entry: Dictionary = TileCatalog.describe_forest_tile(local_id)
	render_provenance.record_overlay_anchor(
		pos,
		SOURCE_FOREST,
		atlas,
		MapRenderProvenance.footprint_for_source(SOURCE_FOREST),
		reason,
		"%s Â· forest #%d â€” %s" % [detail_prefix, local_id, str(entry["use_case"])],
	)


func _place_forest_ground_scatter(
	pos: Vector2i,
	variants: Array[int],
	reason: String,
	detail_prefix: String,
) -> void:
	## Pebbles / flora on ScatterLayer (z=0, above grass) so shadows darken them
	## without replacing grass â€” sparse overlay tiles must not erase grass underneath.
	var local_id: int = _pick_scatter_safe_variant(variants)
	if local_id < 0:
		return
	var atlas: Vector2i = Vector2i(local_id % 16, local_id / 16)
	_scatter.set_cell(pos, SOURCE_FOREST, atlas, 0)
	if render_provenance == null:
		return
	var entry: Dictionary = TileCatalog.describe_forest_tile(local_id)
	render_provenance.record_overlay_anchor(
		pos,
		SOURCE_FOREST,
		atlas,
		Vector2i.ONE,
		reason,
		"%s Â· forest #%d â€” %s" % [detail_prefix, local_id, str(entry["use_case"])],
	)


func _is_scatter_tile(local_id: int) -> bool:
	return local_id in _PEBBLE_VARIANTS or local_id in _FLORA_VARIANTS


func _strip_scatter_under_tree_footprints(tree_cells: Array[Vector2i]) -> void:
	var footprint: Vector2i = MapRenderProvenance.footprint_for_source(TileSetFactory.SOURCE_TREES)
	for anchor: Vector2i in tree_cells:
		for dy: int in range(-1, footprint.y):
			for dx: int in range(-1, footprint.x):
				var cell: Vector2i = anchor + Vector2i(dx, dy)
				if not MapRenderProvenance.forest_occluded_by_tree_canopy(anchor, cell):
					continue
				if _scatter.get_cell_source_id(cell) != SOURCE_FOREST:
					continue
				var atlas: Vector2i = _scatter.get_cell_atlas_coords(cell)
				var local_id: int = atlas.x + atlas.y * 16
				if not _is_scatter_tile(local_id):
					continue
				_scatter.erase_cell(cell)
				if render_provenance != null:
					render_provenance.erase_overlay_anchor(cell)


func _place_props_32(pos: Vector2i) -> void:
	var atlas_x: int = _PROPS_32_ATLAS_X[_rng.randi() % _PROPS_32_ATLAS_X.size()]
	_place_props_32_at(
		pos,
		atlas_x,
		"scatter_props_32",
		"Decoration scatter â€” 32Ã—32 prop pool (~12%% of hits) Â· %s"
		% TileCatalog.PROPS_32_LABELS[clampi(atlas_x, 0, TileCatalog.PROPS_32_LABELS.size() - 1)],
	)


func _place_props_32_at(pos: Vector2i, atlas_x: int, reason: String, detail: String) -> void:
	var atlas: Vector2i = Vector2i(atlas_x, 0)
	_overlay.set_cell(pos, SOURCE_PROPS_32, atlas, 0)
	if render_provenance == null:
		return
	render_provenance.record_overlay_anchor(
		pos,
		SOURCE_PROPS_32,
		atlas,
		MapRenderProvenance.footprint_for_source(SOURCE_PROPS_32),
		reason,
		detail,
	)


func _has_blocking_overlay(pos: Vector2i) -> bool:
	if _overlay.get_cell_source_id(pos) != -1:
		return true
	if _trees != null and _trees.get_cell_source_id(pos) != -1:
		return true
	return false


func _pick_variant(variants: Array[int]) -> int:
	return variants[_rng.randi() % variants.size()]


func _pick_scatter_safe_variant(variants: Array[int]) -> int:
	if variants.is_empty():
		return -1
	for _attempt: int in range(maxi(variants.size() * 4, 4)):
		var local_id: int = variants[_rng.randi() % variants.size()]
		if TileCatalog.is_random_scatter_allowed(local_id):
			return local_id
	return -1


func _set_ground(pos: Vector2i, local_tile_id: int, reason: String, detail: String) -> void:
	var atlas: Vector2i = Vector2i(local_tile_id % 16, local_tile_id / 16)
	_ground.set_cell(pos, SOURCE_FOREST, atlas, 0)
	_record_ground(pos, SOURCE_FOREST, atlas, reason, detail)


func _record_ground(
	pos: Vector2i,
	source_id: int,
	atlas: Vector2i,
	reason: String,
	detail: String,
) -> void:
	if render_provenance == null:
		return
	render_provenance.record_ground(pos, source_id, atlas, reason, detail)
