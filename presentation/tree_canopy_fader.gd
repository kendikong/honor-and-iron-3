class_name TreeCanopyFader
extends Node2D

## Swaps opaque tree tiles for semi-transparent sprites when units stand behind them.

const FADE_ALPHA: float = 0.38
const _C = preload("res://scripts/mana_seed_constants.gd")

var _trees: TileMapLayer
var _grid: PlayerGrid
var _settings: EffectsSettings
var _fade_sprites: Dictionary = {}
var _stored_cells: Dictionary = {}


func setup(
	trees: TileMapLayer,
	grid: PlayerGrid,
	settings: EffectsSettings,
) -> void:
	_trees = trees
	_grid = grid
	_settings = settings
	z_as_relative = false
	z_index = _C.Z_TREE


func clear_all() -> void:
	var anchors: Array = _fade_sprites.keys()
	for anchor: Variant in anchors:
		_restore_tree(anchor)


func sync_actors(actors: Dictionary) -> void:
	if _trees == null or _grid == null:
		return
	var need_fade: Dictionary = {}
	for unit_id: Variant in actors:
		var actor: Node2D = actors[unit_id] as Node2D
		if actor == null:
			continue
		var char_x: float = actor.position.x
		var sort_y: float = TreeGameplay.character_sort_y(actor)
		var char_cell: Vector2i = TreeGameplay.cell_from_world(actor.position)
		for anchor: Vector2i in TreeGameplay.tree_anchors(_trees):
			if TreeGameplay.tree_occludes_character(
				char_x, sort_y, char_cell, anchor, _grid, _trees, _settings,
			):
				need_fade[anchor] = true

	var stale: Array[Vector2i] = []
	for anchor: Variant in _fade_sprites:
		if not need_fade.has(anchor):
			stale.append(anchor as Vector2i)
	for anchor: Vector2i in stale:
		_restore_tree(anchor)

	for anchor: Variant in need_fade:
		if not _fade_sprites.has(anchor):
			_fade_tree(anchor as Vector2i)


func _fade_tree(anchor: Vector2i) -> void:
	if _trees.get_cell_source_id(anchor) < 0:
		return
	_stored_cells[anchor] = {
		"source": _trees.get_cell_source_id(anchor),
		"atlas": _trees.get_cell_atlas_coords(anchor),
		"alt": _trees.get_cell_alternative_tile(anchor),
	}
	var td: TileData = _trees.get_cell_tile_data(anchor)
	if td == null:
		_stored_cells.erase(anchor)
		return
	var spr := Sprite2D.new()
	spr.texture = td.texture
	spr.region_enabled = true
	spr.region_rect = td.texture_region
	spr.centered = false
	var top_left: Vector2 = (
		_trees.map_to_local(anchor)
		- Vector2(td.texture_origin)
		- Vector2(TreeGameplay.TREE_SPRITE_SIZE) * 0.5
	)
	spr.position = top_left
	spr.modulate = Color(1.0, 1.0, 1.0, FADE_ALPHA)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_as_relative = false
	spr.z_index = 0
	_trees.erase_cell(anchor)
	add_child(spr)
	_fade_sprites[anchor] = spr


func _restore_tree(anchor: Vector2i) -> void:
	var spr: Sprite2D = _fade_sprites.get(anchor)
	if spr != null:
		spr.queue_free()
	_fade_sprites.erase(anchor)
	var stored: Dictionary = _stored_cells.get(anchor, {})
	if stored.is_empty():
		return
	_trees.set_cell(
		anchor,
		int(stored["source"]),
		Vector2i(stored["atlas"]),
		int(stored["alt"]),
	)
	_stored_cells.erase(anchor)
