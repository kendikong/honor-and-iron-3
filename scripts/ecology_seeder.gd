class_name EcologySeeder
extends RefCounted

## Opportunism registry (Phase 3 stub). Full 6-step loop deferred to Phase 9.

const SOURCE_FOREST: int = TileSetFactory.SOURCE_FOREST
const SOURCE_TREES: int = TileSetFactory.SOURCE_TREES

# TileIDs that trigger opportunism steps 1–2 when present on PlayerGrid.
const OPPORTUNISM_TILES: Dictionary = {
	TileId.Type.TREE: true,
}

# Moss / base decor at tree foot (16×16 forest overlay decor).
const _MOSS_VARIANTS: Array[int] = [91, 90]
const _MOSS_CHANCE: float = 0.72


static func triggers_opportunism(tile_id: int) -> bool:
	return OPPORTUNISM_TILES.get(tile_id, false)


# 80×96 tree atlas column — 0 = Large tree A (baked ground shadow), 1 = Large tree B.
const TREE_ATLAS_A: int = 0
const TREE_ATLAS_B: int = 1


static func tree_atlas_x(use_tree_b: bool) -> int:
	return TREE_ATLAS_B if use_tree_b else TREE_ATLAS_A


static func apply_tree_stub(
	trees: TileMapLayer,
	pos: Vector2i,
	rng: RandomNumberGenerator,
	provenance: MapRenderProvenance = null,
	use_tree_b: bool = false,
) -> void:
	var atlas_x: int = tree_atlas_x(use_tree_b)
	var atlas: Vector2i = Vector2i(atlas_x, 0)
	trees.set_cell(pos, SOURCE_TREES, atlas, 0)
	if provenance == null:
		return
	provenance.record_overlay_anchor(
		pos,
		SOURCE_TREES,
		atlas,
		MapRenderProvenance.footprint_for_source(SOURCE_TREES),
		"ecology_tree",
		"MapGenerator TREE anchor — %s"
		% TileCatalog.TREE_80_LABELS[clampi(atlas_x, 0, TileCatalog.TREE_80_LABELS.size() - 1)],
	)


static func apply_tree_surroundings(
	grid: PlayerGrid,
	pos: Vector2i,
	overlay: TileMapLayer,
	rng: RandomNumberGenerator,
	provenance: MapRenderProvenance = null,
) -> void:
	for offset: Vector2i in _neighbor_offsets():
		var neighbor: Vector2i = pos + offset
		if not _in_bounds(grid, neighbor):
			continue
		if grid.get_cell(neighbor) != TileId.Type.GRASS:
			continue
		if MapRenderProvenance.forest_occluded_by_tree_canopy(pos, neighbor):
			continue
		if rng.randf() >= _MOSS_CHANCE:
			continue
		var moss_id: int = _MOSS_VARIANTS[rng.randi() % _MOSS_VARIANTS.size()]
		var atlas: Vector2i = Vector2i(moss_id % 16, moss_id / 16)
		overlay.set_cell(neighbor, SOURCE_FOREST, atlas, 0)
		if provenance == null:
			continue
		var entry: Dictionary = TileCatalog.describe_forest_tile(moss_id)
		provenance.record_overlay_anchor(
			neighbor,
			SOURCE_FOREST,
			atlas,
			MapRenderProvenance.footprint_for_source(SOURCE_FOREST),
			"ecology_moss",
			"Tree foot moss — neighbor of TREE at (%d,%d) · #%d %s"
			% [pos.x, pos.y, moss_id, str(entry["use_case"])],
		)


static func _neighbor_offsets() -> Array[Vector2i]:
	return [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]


static func _in_bounds(grid: PlayerGrid, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid.width and pos.y < grid.height


## Opportunism step 4 — tree + flora ecology weights, shore firefly anchors.
static func build_ecology_hints(
	grid: PlayerGrid,
	tree_cells: Array[Vector2i],
	provenance: MapRenderProvenance,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var hints: Dictionary = _build_tree_ecology_hints(grid, tree_cells, rng)
	var flora_cells: Array[Vector2i] = _collect_flora_cells(provenance)
	hints["flora_cells"] = flora_cells
	for flora_pos: Vector2i in flora_cells:
		hints["butterfly_weights"].append({
			"anchor": flora_pos,
			"flora_center": flora_pos,
			"weight": rng.randf_range(0.78, 1.0),
			"flora": true,
		})
	hints["frog_weights"] = _build_frog_weights(grid, rng)
	hints["fish_weights"] = _build_fish_weights(grid, rng)
	return hints


static func _build_frog_weights(grid: PlayerGrid, rng: RandomNumberGenerator) -> Array:
	var weights: Array = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.GRASS:
				continue
			if not _touches_water(grid, pos):
				continue
			if rng.randf() >= 0.08:
				continue
			weights.append({
				"anchor": pos,
				"weight": rng.randf_range(0.55, 1.0),
			})
	return weights


static func _build_fish_weights(grid: PlayerGrid, rng: RandomNumberGenerator) -> Array:
	var weights: Array = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			if not WaterCellMask.is_interior_water(grid, pos):
				continue
			if rng.randf() >= 0.04:
				continue
			weights.append({
				"anchor": pos,
				"weight": rng.randf_range(0.55, 1.0),
			})
	return weights


static func _touches_water(grid: PlayerGrid, pos: Vector2i) -> bool:
	for offset: Vector2i in [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	]:
		var neighbor: Vector2i = pos + offset
		if not _in_bounds(grid, neighbor):
			continue
		if grid.get_cell(neighbor) == TileId.Type.WATER:
			return true
	return false


static func _collect_flora_cells(provenance: MapRenderProvenance) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if provenance == null:
		return cells
	for entry: Variant in provenance.overlay_anchors.values():
		var reason: String = str(entry.get("reason", ""))
		if reason != "scatter_flora" and reason != "scatter_flora_cluster":
			continue
		cells.append(entry.get("anchor", Vector2i.ZERO) as Vector2i)
	return cells


static func _build_tree_ecology_hints(
	grid: PlayerGrid,
	tree_cells: Array[Vector2i],
	rng: RandomNumberGenerator,
) -> Dictionary:
	var hints: Dictionary = {
		"butterfly_weights": [],
		"leaf_weights": [],
		"flora_cells": [],
	}
	for tree_pos: Vector2i in tree_cells:
		if rng.randf() < 0.58:
			hints["leaf_weights"].append({
				"anchor": tree_pos,
				"weight": rng.randf_range(0.45, 1.0),
			})
	return hints
