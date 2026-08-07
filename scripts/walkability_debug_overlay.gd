class_name WalkabilityDebugOverlay
extends CanvasLayer

## Dev overlay â€” blocked tiles + prop visual vs block spill. Toggle **K**.

const TILE_PX: int = 16
const _C = preload("res://scripts/mana_seed_constants.gd")

const COLOR_LOGICAL: Color = Color(0.25, 0.45, 1.0, 0.42)
const COLOR_TRUNK: Color = Color(1.0, 0.12, 0.12, 0.52)
const COLOR_PROP_VISUAL: Color = Color(0.35, 0.88, 0.42, 0.3)
const COLOR_PROP_BLOCK: Color = Color(0.92, 0.2, 0.85, 0.58)
const COLOR_PROP_BORDER: Color = Color(0.2, 0.75, 0.35, 0.85)

var _grid: PlayerGrid
var _map_root: Node2D
var _trees: TileMapLayer
var _overlay: TileMapLayer
var _settings: EffectsSettings
var _container: Control


func _ready() -> void:
	layer = 11
	visible = false
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func sync(
	grid: PlayerGrid,
	map_root: Node2D,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
) -> void:
	_grid = grid
	_map_root = map_root
	_trees = trees
	_overlay = overlay
	_settings = settings
	if visible:
		_rebuild()


func toggle() -> bool:
	visible = not visible
	if visible:
		_rebuild()
	else:
		_clear()
	return visible


func _rebuild() -> void:
	_clear()
	if _grid == null or _map_root == null:
		return
	var zoom: float = _map_root.scale.x
	var tile_px: float = TILE_PX * zoom
	var blocked_count: int = 0
	var painted_props: Dictionary = {}
	_paint_tree_debug(tile_px)
	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var kind: int = TreeGameplay.movement_block_kind(
				pos, _grid, _trees, _overlay, _settings,
			)
			if kind == TreeGameplay.BlockKind.PROP_FOOTPRINT:
				continue
			if kind == TreeGameplay.BlockKind.NONE:
				continue
			blocked_count += 1
			_add_cell_rect(pos, tile_px, _color_for_kind(kind))
	blocked_count += _paint_prop_debug(tile_px, painted_props)
	_build_legend(blocked_count)


func _paint_prop_debug(tile_px: float, painted_props: Dictionary) -> int:
	if _overlay == null:
		return 0
	var extra_blocks: int = 0
	for anchor: Vector2i in _overlay.get_used_cells():
		if _overlay.get_cell_source_id(anchor) != _C.SOURCE_PROPS_32:
			continue
		var prop_key: String = "%d,%d" % [anchor.x, anchor.y]
		if painted_props.has(prop_key):
			continue
		painted_props[prop_key] = true
		var atlas_x: int = _overlay.get_cell_atlas_coords(anchor).x
		var block_set: Dictionary = TileCatalog.prop_movement_block_cell_set(anchor, atlas_x)
		var render_cells: Array[Vector2i] = TileCatalog.prop_render_footprint_cells(anchor)
		for cell: Vector2i in render_cells:
			if not _cell_in_grid(cell):
				continue
			var key: String = TileCatalog.cell_key(cell)
			if block_set.has(key):
				_add_cell_rect(cell, tile_px, COLOR_PROP_BLOCK)
				extra_blocks += 1
			else:
				_add_cell_rect(cell, tile_px, COLOR_PROP_VISUAL)
				_add_cell_border(cell, tile_px)
	return extra_blocks


func _paint_tree_debug(tile_px: float) -> void:
	if _trees == null:
		return
	var painted_cells: Dictionary = {}
	for anchor: Vector2i in _trees.get_used_cells():
		var footprint_anchor: Vector2i = TreeGameplay.visual_footprint_anchor(anchor, _settings)
		for dy: int in range(TreeGameplay.TREE_FOOTPRINT.y):
			for dx: int in range(TreeGameplay.TREE_FOOTPRINT.x):
				var cell: Vector2i = footprint_anchor + Vector2i(dx, dy)
				if not _cell_in_grid(cell):
					continue
				var key: String = "%d,%d" % [cell.x, cell.y]
				if painted_cells.has(key):
					continue
				painted_cells[key] = true
				
				var kind: int = TreeGameplay.movement_block_kind(
					cell, _grid, _trees, _overlay, _settings,
				)
				if kind == TreeGameplay.BlockKind.TREE_TRUNK:
					continue
					
				_add_cell_rect(cell, tile_px, COLOR_PROP_VISUAL)
				_add_cell_border(cell, tile_px)


func _add_cell_rect(cell: Vector2i, tile_px: float, color: Color) -> void:
	var rect: ColorRect = ColorRect.new()
	var top_left: Vector2 = _map_root.to_global(Vector2(cell) * float(TILE_PX))
	rect.position = top_left
	rect.size = Vector2(tile_px, tile_px)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(rect)


func _add_cell_border(cell: Vector2i, tile_px: float) -> void:
	var top_left: Vector2 = _map_root.to_global(Vector2(cell) * float(TILE_PX))
	var inset: float = maxf(1.0, tile_px * 0.08)
	for edge: Dictionary in _border_edges(top_left, tile_px, inset):
		var strip: ColorRect = ColorRect.new()
		strip.position = edge["pos"]
		strip.size = edge["size"]
		strip.color = COLOR_PROP_BORDER
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.add_child(strip)


func _border_edges(top_left: Vector2, tile_px: float, inset: float) -> Array[Dictionary]:
	var inner: float = tile_px - inset * 2.0
	return [
		{"pos": top_left + Vector2(inset, inset), "size": Vector2(inner, inset)},
		{"pos": top_left + Vector2(inset, tile_px - inset * 2.0), "size": Vector2(inner, inset)},
		{"pos": top_left + Vector2(inset, inset), "size": Vector2(inset, inner)},
		{"pos": top_left + Vector2(tile_px - inset * 2.0, inset), "size": Vector2(inset, inner)},
	]


func _cell_in_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < _grid.width
		and cell.y < _grid.height
	)


func _color_for_kind(kind: int) -> Color:
	match kind:
		TreeGameplay.BlockKind.LOGICAL_TILE:
			return COLOR_LOGICAL
		TreeGameplay.BlockKind.TREE_TRUNK:
			return COLOR_TRUNK
		_:
			return COLOR_TRUNK


func _build_legend(blocked_count: int) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Walkability (K) â€” %d blocked cells" % blocked_count
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	for line: String in [
		"Blue â€” logical tile (water/rock/ruin)",
		"Red â€” big tree trunk foot (1 cell)",
		"Green fill â€” prop 2Ã—2 visual, walkable",
		"Green border â€” walkable prop spill edge",
		"Magenta â€” prop movement block only",
	]:
		var row: Label = Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 10)
		box.add_child(row)
	_container.add_child(panel)


func _clear() -> void:
	for child: Node in _container.get_children():
		child.queue_free()
