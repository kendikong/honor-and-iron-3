class_name TileDebugOverlay
extends CanvasLayer

## Dev overlay: logical TileId (colored text) + ground atlas id on dark badge. Toggle with **L**.

const TILE_PX: int = 16
const FOREST_COLUMNS: int = 16

# Bright text colors for readability on the dark badge background.
const TYPE_TEXT_COLORS: Dictionary = {
	TileId.Type.GRASS: Color(0.45, 0.92, 0.50),
	TileId.Type.WATER: Color(0.55, 0.78, 1.0),
	TileId.Type.DIRT: Color(0.95, 0.72, 0.38),
	TileId.Type.TREE: Color(0.38, 0.88, 0.52),
	TileId.Type.RUIN: Color(0.82, 0.72, 0.95),
	TileId.Type.ROCK: Color(0.72, 0.78, 0.88),
}

const LEGEND_ROWS: Array[Array] = [
	[TileId.Type.GRASS, "GRS", "Grass"],
	[TileId.Type.WATER, "WAT", "Water"],
	[TileId.Type.DIRT, "DRT", "Dirt"],
	[TileId.Type.TREE, "TRE", "Tree"],
	[TileId.Type.RUIN, "RUI", "Ruin"],
	[TileId.Type.ROCK, "ROK", "Rock"],
]

var _grid: PlayerGrid
var _map_root: Node2D
var _ground: TileMapLayer
var _phantom: TileMapLayer
var _render: MapRenderProvenance
var _container: Control


func _ready() -> void:
	layer = 10
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func sync(
	grid: PlayerGrid,
	map_root: Node2D,
	ground: TileMapLayer = null,
	phantom: TileMapLayer = null,
	render: MapRenderProvenance = null,
) -> void:
	_grid = grid
	_map_root = map_root
	_ground = ground
	_phantom = phantom
	_render = render
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
	var font_size: int = int(clampf(round(tile_px / 5.0), 7.0, 12.0))
	var badge_h: float = font_size * 2.0 + 8.0
	var badge_w: float = tile_px * 0.95
	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var tile_id: int = _grid.get_cell(pos)
			var top_left: Vector2 = _map_root.to_global(Vector2(pos) * float(TILE_PX))
			var label: Label = Label.new()
			label.text = _cell_text(pos, tile_id)
			label.position = top_left + Vector2(
				(tile_px - badge_w) * 0.5,
				tile_px - badge_h - 2.0,
			)
			label.custom_minimum_size = Vector2(badge_w, badge_h)
			label.size = Vector2(badge_w, badge_h)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", _type_text_color(tile_id))
			label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
			label.add_theme_constant_override("outline_size", 1)
			label.add_theme_stylebox_override("normal", _make_label_bg())
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_container.add_child(label)
	_build_phantom_labels(tile_px, font_size, badge_h, badge_w)
	_build_legend()


func _build_phantom_labels(
	tile_px: float,
	font_size: int,
	badge_h: float,
	badge_w: float,
) -> void:
	if _phantom == null or _render == null:
		return
	for key: String in _render.phantoms.keys():
		var pos: Vector2i = _parse_cell_key(key)
		if _phantom.get_cell_source_id(pos) == -1:
			continue
		var entry: Dictionary = _render.phantoms[key]
		var tile_id: int = int(entry.get("logical_type", TileId.Type.GRASS))
		var top_left: Vector2 = _map_root.to_global(Vector2(pos) * float(TILE_PX))
		var label: Label = Label.new()
		label.text = _phantom_cell_text(pos, tile_id)
		label.position = top_left + Vector2(
			(tile_px - badge_w) * 0.5,
			tile_px - badge_h - 2.0,
		)
		label.custom_minimum_size = Vector2(badge_w, badge_h)
		label.size = Vector2(badge_w, badge_h)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", _type_text_color(tile_id).lerp(Color(0.7, 0.85, 1.0), 0.35))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_stylebox_override("normal", _make_phantom_label_bg())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.add_child(label)


func _phantom_cell_text(pos: Vector2i, tile_id: int) -> String:
	var abbrev: String = "~%s" % TileId.type_abbrev(tile_id)
	var atlas_id: String = _phantom_atlas_local_id(pos)
	if atlas_id.is_empty():
		return abbrev
	return "%s\n#%s" % [abbrev, atlas_id]


func _phantom_atlas_local_id(pos: Vector2i) -> String:
	if _phantom == null:
		return ""
	if _phantom.get_cell_source_id(pos) != TileSetFactory.SOURCE_FOREST:
		return ""
	var atlas: Vector2i = _phantom.get_cell_atlas_coords(pos)
	return str(atlas.x + atlas.y * FOREST_COLUMNS)


static func _parse_cell_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _make_phantom_label_bg() -> StyleBoxFlat:
	var bg: StyleBoxFlat = _make_label_bg()
	bg.bg_color = Color(0.05, 0.12, 0.22, 0.55)
	return bg


func _cell_text(pos: Vector2i, tile_id: int) -> String:
	var abbrev: String = TileId.type_abbrev(tile_id)
	var atlas_id: String = _ground_atlas_local_id(pos)
	if atlas_id.is_empty():
		return abbrev
	return "%s\n#%s" % [abbrev, atlas_id]


func _ground_atlas_local_id(pos: Vector2i) -> String:
	if _ground == null:
		return ""
	if _ground.get_cell_source_id(pos) != TileSetFactory.SOURCE_FOREST:
		return ""
	var atlas: Vector2i = _ground.get_cell_atlas_coords(pos)
	return str(atlas.x + atlas.y * FOREST_COLUMNS)


func _type_text_color(tile_id: int) -> Color:
	return TYPE_TEXT_COLORS.get(tile_id, Color(0.9, 0.9, 0.9))


func _make_label_bg() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(1)
	return bg


func _build_legend() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -168.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.offset_bottom = 8.0
	panel.add_theme_stylebox_override("panel", _make_legend_panel_bg())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Tile legend (L)"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)

	for row: Array in LEGEND_ROWS:
		vbox.add_child(_make_legend_row(int(row[0]), str(row[1]), str(row[2])))

	var footnote: Label = Label.new()
	footnote.text = "# = ground atlas · ~ = phantom · use side panel"
	footnote.add_theme_font_size_override("font_size", 9)
	footnote.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	vbox.add_child(footnote)

	_container.add_child(panel)


func _make_legend_row(tile_id: int, abbrev: String, full_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var abbrev_label: Label = Label.new()
	abbrev_label.text = abbrev
	abbrev_label.custom_minimum_size = Vector2(28.0, 0.0)
	abbrev_label.add_theme_font_size_override("font_size", 10)
	abbrev_label.add_theme_color_override("font_color", _type_text_color(tile_id))
	abbrev_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	abbrev_label.add_theme_constant_override("outline_size", 1)
	row.add_child(abbrev_label)

	var label: Label = Label.new()
	label.text = full_name
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	return row


func _make_legend_panel_bg() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(4)
	return bg


func _clear() -> void:
	if _container == null:
		return
	for child: Node in _container.get_children():
		child.queue_free()
