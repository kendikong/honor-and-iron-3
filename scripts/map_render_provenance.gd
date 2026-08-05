class_name MapRenderProvenance
extends RefCounted

## Records every visual TileMapLayer placement during AutoDecorator / EcologySeeder.

const FOREST_COLUMNS: int = 16

var ground: Dictionary = {}
var phantoms: Dictionary = {}
var overlay_anchors: Dictionary = {}
var vfx: Dictionary = {}
var _overlay_by_cell: Dictionary = {}


func clear() -> void:
	ground.clear()
	phantoms.clear()
	overlay_anchors.clear()
	vfx.clear()
	_overlay_by_cell.clear()


func finalize_overlay_index() -> void:
	_overlay_by_cell.clear()
	for key: String in overlay_anchors.keys():
		var entry: Dictionary = overlay_anchors[key]
		var anchor: Vector2i = entry["anchor"]
		var footprint: Vector2i = entry["footprint_cells"]
		for dy: int in range(footprint.y):
			for dx: int in range(footprint.x):
				var cell: Vector2i = anchor + Vector2i(dx, dy)
				var cell_key: String = _key(cell)
				if not _overlay_by_cell.has(cell_key):
					_overlay_by_cell[cell_key] = [] as Array
				(_overlay_by_cell[cell_key] as Array).append(entry)


func record_ground(
	pos: Vector2i,
	source_id: int,
	atlas: Vector2i,
	reason: String,
	detail: String,
) -> void:
	var key: String = _key(pos)
	var local_id: int = _forest_local_id(source_id, atlas)
	var entry: Dictionary = ground.get(key, {
		"steps": [] as Array[Dictionary],
	})
	var steps: Array = entry["steps"]
	steps.append({
		"source_id": source_id,
		"atlas": atlas,
		"local_id": local_id,
		"reason": reason,
		"detail": detail,
	})
	entry["source_id"] = source_id
	entry["atlas"] = atlas
	entry["local_id"] = local_id
	entry["reason"] = reason
	entry["detail"] = detail
	entry["steps"] = steps
	ground[key] = entry


func record_overlay_anchor(
	pos: Vector2i,
	source_id: int,
	atlas: Vector2i,
	footprint_cells: Vector2i,
	reason: String,
	detail: String,
) -> void:
	var key: String = _key(pos)
	overlay_anchors[key] = {
		"anchor": pos,
		"source_id": source_id,
		"atlas": atlas,
		"footprint_cells": footprint_cells,
		"reason": reason,
		"detail": detail,
	}


func erase_overlay_anchor(pos: Vector2i) -> void:
	overlay_anchors.erase(_key(pos))


func record_vfx(
	pos: Vector2i,
	source_id: int,
	atlas: Vector2i,
	reason: String,
	detail: String,
) -> void:
	vfx[_key(pos)] = {
		"source_id": source_id,
		"atlas": atlas,
		"reason": reason,
		"detail": detail,
	}


func ground_at(pos: Vector2i) -> Dictionary:
	return ground.get(_key(pos), {})


func record_phantom(
	pos: Vector2i,
	source_id: int,
	atlas: Vector2i,
	logical_type: int,
	extends_from: Vector2i,
	reason: String,
	detail: String,
) -> void:
	var local_id: int = _forest_local_id(source_id, atlas)
	phantoms[_key(pos)] = {
		"source_id": source_id,
		"atlas": atlas,
		"local_id": local_id,
		"logical_type": logical_type,
		"extends_from": extends_from,
		"reason": reason,
		"detail": detail,
	}


func phantom_at(pos: Vector2i) -> Dictionary:
	return phantoms.get(_key(pos), {})


func overlay_entries_affecting(pos: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var indexed: Array = _overlay_by_cell.get(_key(pos), []) as Array
	if indexed.is_empty():
		return results
	for entry: Dictionary in indexed:
		var anchor: Vector2i = entry["anchor"]
		var copy: Dictionary = entry.duplicate()
		copy["is_anchor"] = pos == anchor
		copy["is_spillover"] = pos != anchor
		results.append(copy)
	return results


func vfx_at(pos: Vector2i) -> Dictionary:
	return vfx.get(_key(pos), {})


static func footprint_for_source(source_id: int) -> Vector2i:
	match source_id:
		TileSetFactory.SOURCE_PROPS_32:
			return Vector2i(2, 2)
		TileSetFactory.SOURCE_TREES:
			return Vector2i(5, 6)
		_:
			return Vector2i(1, 1)


static func blocked_cells_for_anchors(
	anchors: Array[Vector2i],
	source_id: int,
	margin: int = 0,
) -> Dictionary:
	var blocked: Dictionary = {}
	var footprint: Vector2i = footprint_for_source(source_id)
	for anchor: Vector2i in anchors:
		for dy: int in range(-margin, footprint.y + margin):
			for dx: int in range(-margin, footprint.x + margin):
				blocked[anchor + Vector2i(dx, dy)] = true
	return blocked


static func mark_footprint_blocked(
	blocked: Dictionary,
	anchor: Vector2i,
	source_id: int,
	margin: int = 0,
) -> void:
	var footprint: Vector2i = footprint_for_source(source_id)
	for dy: int in range(-margin, footprint.y + margin):
		for dx: int in range(-margin, footprint.x + margin):
			blocked[anchor + Vector2i(dx, dy)] = true


static func _cell_in_footprint(pos: Vector2i, anchor: Vector2i, footprint: Vector2i) -> bool:
	return (
		pos.x >= anchor.x
		and pos.y >= anchor.y
		and pos.x < anchor.x + footprint.x
		and pos.y < anchor.y + footprint.y
	)


## 16Ã—16 forest scatter that y-sorts over the 80Ã—96 canopy â€” must not draw here.
static func forest_occluded_by_tree_canopy(tree_anchor: Vector2i, cell: Vector2i) -> bool:
	if cell == tree_anchor:
		return false
	var footprint: Vector2i = footprint_for_source(TileSetFactory.SOURCE_TREES)
	var rel: Vector2i = cell - tree_anchor
	if rel.x >= 0 and rel.x < footprint.x and rel.y >= 0 and rel.y < footprint.y:
		return true
	# Left column beside canopy rows (organic west spill; ground foot row kept clear).
	if rel.x == -1 and rel.y >= 0 and rel.y < footprint.y - 1:
		return true
	return false


static func _forest_local_id(source_id: int, atlas: Vector2i) -> int:
	if source_id != TileSetFactory.SOURCE_FOREST:
		return -1
	return atlas.x + atlas.y * FOREST_COLUMNS


static func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
