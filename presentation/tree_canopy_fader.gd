class_name TreeCanopyFader
extends Node2D

## Swaps opaque tree tiles for semi-transparent sprites when units stand behind them.

const FADE_ALPHA: float = 0.38
const FADE_EXIT_MARGIN_PX: float = 20.0
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
		var sort_y: float = TreeGameplay.character_fade_sort_y(actor)
		for anchor: Vector2i in _all_check_anchors():
			if _anchor_needs_fade(anchor, char_x, sort_y):
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


## Faded trees are erased from TileMapLayer — must keep checking their anchors until restore.
func _all_check_anchors() -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for anchor: Vector2i in TreeGameplay.tree_anchors(_trees):
		var key: String = "%d,%d" % [anchor.x, anchor.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(anchor)
	for anchor: Variant in _fade_sprites.keys():
		var faded: Vector2i = anchor as Vector2i
		var key: String = "%d,%d" % [faded.x, faded.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(faded)
	return out


func _anchor_needs_fade(anchor: Vector2i, char_x: float, sort_y: float) -> bool:
	var margin: float = FADE_EXIT_MARGIN_PX if _fade_sprites.has(anchor) else 0.0
	var stored: Dictionary = _stored_cells.get(anchor, {})
	if stored.has("canopy_rect"):
		return _fade_test_cached(stored, char_x, sort_y, margin)
	return TreeGameplay.tree_should_fade_canopy(
		char_x, sort_y, anchor, _grid, _trees, _settings, margin,
	)


func _fade_test_cached(stored: Dictionary, char_x: float, sort_y: float, margin_px: float) -> bool:
	var trunk_y: float = float(stored.get("trunk_y", INF))
	if sort_y >= trunk_y:
		return false
	var canopy_rect: Rect2 = stored["canopy_rect"]
	if margin_px > 0.0:
		canopy_rect = canopy_rect.grow(margin_px)
	return canopy_rect.has_point(Vector2(char_x, sort_y))


func _fade_tree(anchor: Vector2i) -> void:
	if _trees.get_cell_source_id(anchor) < 0:
		return
	var canopy_rect: Rect2 = TreeGameplay.canopy_fade_rect(_trees, anchor)
	var trunk_y: float = TreeGameplay.trunk_sort_line_y(anchor, _grid, _trees, _settings)
	_stored_cells[anchor] = {
		"source": _trees.get_cell_source_id(anchor),
		"atlas": _trees.get_cell_atlas_coords(anchor),
		"alt": _trees.get_cell_alternative_tile(anchor),
		"canopy_rect": canopy_rect,
		"trunk_y": trunk_y,
	}
	var td: TileData = _trees.get_cell_tile_data(anchor)
	var atlas_tex: AtlasTexture = _atlas_texture_for_cell(anchor)
	if atlas_tex == null:
		_stored_cells.erase(anchor)
		return
	var spr := Sprite2D.new()
	spr.texture = atlas_tex
	spr.centered = false
	var origin := Vector2(td.texture_origin) if td != null else Vector2.ZERO
	var top_left: Vector2 = (
		_trees.map_to_local(anchor)
		- origin
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


func _atlas_texture_for_cell(cell: Vector2i) -> AtlasTexture:
	var source_id: int = _trees.get_cell_source_id(cell)
	if source_id < 0:
		return null
	var atlas_coords: Vector2i = _trees.get_cell_atlas_coords(cell)
	var tile_set: TileSet = _trees.tile_set
	if tile_set == null:
		return null
	var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return null
	var region_size: Vector2i = source.texture_region_size
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = source.texture
	tex.region = Rect2(Vector2(atlas_coords) * Vector2(region_size), Vector2(region_size))
	tex.filter_clip = true
	return tex


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
