extends Control

## Wang-pattern terrain editor with peering diagram + live Godot preview. F6 on this scene.

enum ViewMode { PATTERNS, NON_TERRAIN }

const BASE_PREVIEW_PX: int = 40
const BASE_ROW_HEIGHT: int = 50
const BASE_CELL_PX: int = 52
const BASE_NEIGHBORHOOD_CELL_PX: int = 44
const BASE_SEPARATION: int = 10
const BIG_PREVIEW_PX: int = 96
const PREVIEW_MAP_CELLS: int = 7
const PREVIEW_TILE_PX: int = 16

@onready var _pattern_list: VBoxContainer = $HSplit/PatternPanel/Scroll/PatternVBox
@onready var _tile_list: VBoxContainer = $HSplit/RightSplit/TilePanel/Scroll/TileVBox
@onready var _status: Label = $Footer/Status
@onready var _hint: Label = $HSplit/RightSplit/TilePanel/Hint
@onready var _pattern_header: Label = $HSplit/PatternPanel/PatternHeader
@onready var _search: LineEdit = $HSplit/RightSplit/TilePanel/SearchRow/Search
@onready var _header: HBoxContainer = $Header
@onready var _main_split: HSplitContainer = $HSplit
@onready var _right_split: HSplitContainer = $HSplit/RightSplit
@onready var _pattern_panel: VBoxContainer = $HSplit/PatternPanel
@onready var _center_panel: VBoxContainer = $HSplit/RightSplit/CenterPanel
@onready var _big_preview: TextureRect = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/BigPreview
@onready var _meta_label: Label = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/MetaLabel
@onready var _peering_grid: GridContainer = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PeeringGrid
@onready var _neighborhood_grid: GridContainer = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/NeighborhoodGrid
@onready var _match_label: Label = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/MatchLabel
@onready var _preview_frame: PanelContainer = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PreviewFrame
)
@onready var _preview_viewport: SubViewport = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PreviewFrame/Margin/SubViewportContainer/SubViewport
)
@onready var _preview_host: TerrainPreviewMap = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PreviewFrame/Margin/SubViewportContainer/SubViewport/PreviewHost
)

@onready var _center_header: Label = $HSplit/RightSplit/CenterPanel/CenterHeader
@onready var _peering_title: Label = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PeeringTitle
)
@onready var _neighborhood_title: Label = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/NeighborhoodTitle
)
@onready var _preview_title: Label = (
	$HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox/PreviewTitle
)
@onready var _center_vbox: VBoxContainer = $HSplit/RightSplit/CenterPanel/CenterScroll/CenterVBox

var _map: TerrainPeeringMap
var _last_picked_id: int = -1
var _last_region_ids: Array[int] = []
var _selected_pattern_key: String = ""
var _selected_non_terrain_id: int = -1
var _filter_terrain: int = TerrainPeeringPatterns.TERRAIN_DIRT
var _view_mode: ViewMode = ViewMode.PATTERNS
var _ui_scale: float = 1.0
var _search_text: String = ""
var _neighborhood: Array[int] = []
var _category_row: HBoxContainer
var _category_option: OptionButton
var _syncing_category_option: bool = false
var _entry_by_id: Dictionary = {}
var _non_terrain_row_panels: Dictionary = {}
var _checker_tex: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_search.text_changed.connect(_on_search_changed)
	_map = TerrainPeeringMap.load_or_create()
	if _map.pattern_to_tile.is_empty():
		_map.reset_from_tsx()
	_build_category_assignment_ui()
	_apply_layout_scale()
	_refresh_ui()
	_update_status(_coverage_line())


func _unhandled_input(event: InputEvent) -> void:
	if _view_mode != ViewMode.PATTERNS:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N:
				_on_next_pattern()
			KEY_P:
				_on_prev_pattern()
			KEY_S:
				if event.ctrl_pressed or event.meta_pressed:
					_on_save_pressed()
					get_viewport().set_input_as_handled()


func _on_viewport_resized() -> void:
	var next_scale: float = CatalogUiScale.factor(get_viewport_rect().size)
	if is_equal_approx(next_scale, _ui_scale):
		_apply_split_ratio()
		return
	_ui_scale = next_scale
	_apply_layout_scale()
	_refresh_ui()


func _on_search_changed(text: String) -> void:
	_search_text = text.strip_edges().to_lower()
	_rebuild_tile_list()


func _refresh_ui() -> void:
	_pattern_panel.visible = _view_mode == ViewMode.PATTERNS
	_center_panel.visible = true
	_set_pattern_inspector_visible(_view_mode == ViewMode.PATTERNS)
	if _category_row:
		_category_row.visible = _view_mode == ViewMode.NON_TERRAIN
	var variant_btn: Button = _header.get_node("ToggleVariants") as Button
	if variant_btn:
		variant_btn.text = "Variants: OFF" if _map.suppress_variants else "Variants: ON"
	_rebuild_pattern_list()
	_rebuild_tile_list()
	_refresh_center_panel()
	_update_status(_coverage_line())


func _coverage_line() -> String:
	var stats: Dictionary = TerrainPeeringPatterns.coverage_stats(_map)
	var assigned: int = _map.tile_category_by_id.size()
	return (
		"%d patterns · %d customized · %d non-wang · %d assigned · P/N · %s"
		% [
			int(stats["pattern_count"]),
			int(stats["customized"]),
			int(stats["non_terrain"]),
			assigned,
			"variants suppressed" if _map.suppress_variants else "variants on",
		]
	)


func _filtered_patterns() -> Array[Dictionary]:
	return TerrainPeeringPatterns.patterns_for_terrain(_filter_terrain)


func _on_prev_pattern() -> void:
	_navigate_pattern(-1)


func _on_next_pattern() -> void:
	_navigate_pattern(1)


func _navigate_pattern(delta: int) -> void:
	if _view_mode != ViewMode.PATTERNS:
		return
	var patterns: Array[Dictionary] = _filtered_patterns()
	if patterns.is_empty():
		return
	var index: int = 0
	for i: int in range(patterns.size()):
		if str(patterns[i]["key"]) == _selected_pattern_key:
			index = i
			break
	index = posmod(index + delta, patterns.size())
	_select_pattern(str(patterns[index]["key"]))


func _select_pattern(pattern_key: String) -> void:
	_selected_pattern_key = pattern_key
	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(pattern_key)
	if pattern.is_empty():
		return
	var wang: Array[int] = _map.get_effective_wang(pattern_key)
	_neighborhood = TerrainPeeringBridge.neighborhood_from_wang(wang)
	_rebuild_pattern_list()
	_rebuild_tile_list()
	_refresh_center_panel()
	_hint.text = "Pick canonical tile, or edit peering / test layout in the center panel."


func _get_preview_tile_set() -> TileSet:
	var built: Dictionary = ManaSeedTilesetBuilder.build_forest_tileset_from_tsx()
	var ts: TileSet = built["tile_set"] as TileSet
	var source: TileSetSource = ts.get_source(0)
	if source is TileSetAtlasSource:
		var columns: int = maxi(int(built["parsed"].get("columns", 16)), 1)
		ManaSeedTerrainPeering.apply_peering_map_to_source(source, _map, columns)
	return ts


func _refresh_center_panel() -> void:
	_clear_grid(_peering_grid)
	_clear_grid(_neighborhood_grid)
	if _view_mode == ViewMode.NON_TERRAIN:
		_refresh_non_terrain_center()
		return
	if _selected_pattern_key.is_empty():
		_big_preview.texture = null
		_meta_label.text = "Select a pattern from the left list."
		_match_label.text = "—"
		return

	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(_selected_pattern_key)
	var canonical: int = _map.get_canonical(_selected_pattern_key)
	var wang: Array[int] = _map.get_effective_wang(_selected_pattern_key)

	_big_preview.custom_minimum_size = Vector2(
		CatalogUiScale.px(BIG_PREVIEW_PX, _viewport_size()),
		CatalogUiScale.px(BIG_PREVIEW_PX, _viewport_size()),
	)
	_big_preview.texture = TileCatalog.make_atlas_texture(canonical)
	_meta_label.text = (
		"Canonical #%d · %s · %s"
		% [canonical, str(pattern.get("shape", "")), TerrainPeeringBridge.orientation_label(wang)]
	)

	_build_peering_grid(wang)
	_run_live_preview(pattern, canonical)
	_build_neighborhood_grid()


func _build_peering_grid(wang: Array[int]) -> void:
	var canonical: int = _map.get_canonical(_selected_pattern_key)
	for grid_i: int in range(9):
		if grid_i == 4:
			_peering_grid.add_child(_mini_preview_cell(canonical))
			continue
		var peer_i: int = TerrainPeeringBridge.GRID3_TO_PEER[grid_i]
		var digit: int = int(wang[peer_i]) if peer_i < wang.size() else 0
		var terrain: int = TerrainPeeringBridge.wang_digit_to_terrain(digit)
		var cell: PanelContainer = _make_grid_cell(
			TerrainPeeringBridge.PEER_FULL[peer_i],
			terrain,
			true,
		)
		cell.gui_input.connect(_on_peering_cell_input.bind(peer_i))
		_peering_grid.add_child(cell)


func _build_neighborhood_grid() -> void:
	if _neighborhood.is_empty():
		return
	for grid_i: int in range(9):
		var terrain: int = int(_neighborhood[grid_i])
		var short: String = "·" if grid_i == 4 else TerrainPeeringBridge.PEER_SHORT[
			TerrainPeeringBridge.GRID3_TO_PEER[grid_i]
		]
		var cell: PanelContainer = _make_neighborhood_cell(
			grid_i,
			short,
			terrain,
			_region_tile_id(grid_i),
		)
		cell.gui_input.connect(_on_neighborhood_cell_input.bind(grid_i))
		_neighborhood_grid.add_child(cell)


func _region_tile_id(grid_i: int) -> int:
	if grid_i < 0 or grid_i >= _last_region_ids.size():
		return -1
	return int(_last_region_ids[grid_i])


func _make_neighborhood_cell(
	grid_i: int,
	short_label: String,
	terrain: int,
	tile_id: int,
) -> PanelContainer:
	var cell_px: int = CatalogUiScale.px(BASE_NEIGHBORHOOD_CELL_PX, _viewport_size())
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(cell_px, cell_px)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TerrainPeeringBridge.terrain_color(terrain).darkened(0.2)
	style.set_corner_radius_all(4)
	if grid_i == 4:
		style.set_border_width_all(2)
		style.border_color = Color(0.95, 0.85, 0.35)
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	if tile_id >= 0:
		var tex: TextureRect = TextureRect.new()
		tex.custom_minimum_size = Vector2(cell_px - 6, cell_px - 14)
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.texture = TileCatalog.make_atlas_texture(tile_id)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex)
	else:
		var empty: Label = Label.new()
		empty.text = "—"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.add_theme_font_size_override("font_size", CatalogUiScale.font_size(9, _viewport_size()))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(empty)

	var badge: Label = Label.new()
	badge.text = "%s %s" % [short_label, TerrainPeeringBridge.terrain_label(terrain)]
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", CatalogUiScale.font_size(8, _viewport_size()))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)
	return panel


func _make_grid_cell(title: String, terrain: int, bold: bool) -> PanelContainer:
	var cell_px: int = CatalogUiScale.px(BASE_CELL_PX, _viewport_size())
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(cell_px, cell_px)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TerrainPeeringBridge.terrain_color(terrain).darkened(0.15)
	style.set_corner_radius_all(4)
	if bold:
		style.set_border_width_all(2)
		style.border_color = Color(0.9, 0.9, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "%s\n%s" % [title, TerrainPeeringBridge.terrain_label(terrain)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", CatalogUiScale.font_size(9, _viewport_size()))
	panel.add_child(label)
	return panel


func _mini_preview_cell(tile_id: int) -> Control:
	var cell_px: int = CatalogUiScale.px(BASE_CELL_PX, _viewport_size())
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(cell_px, cell_px)
	panel.add_theme_stylebox_override("panel", _preview_bg_style())
	var tex: TextureRect = TextureRect.new()
	tex.custom_minimum_size = Vector2(cell_px - 8, cell_px - 8)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.texture = TileCatalog.make_atlas_texture(tile_id)
	panel.add_child(tex)
	return panel


func _on_peering_cell_input(event: InputEvent, peer_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _selected_pattern_key.is_empty():
		return
	var wang: Array[int] = _map.get_effective_wang(_selected_pattern_key)
	var updated: Array[int] = TerrainPeeringBridge.cycle_wang_peer(wang, peer_index)
	_map.set_custom_wang(_selected_pattern_key, updated)
	_neighborhood = TerrainPeeringBridge.neighborhood_from_wang(updated)
	_refresh_center_panel()
	_rebuild_pattern_list()


func _on_neighborhood_cell_input(event: InputEvent, grid_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_neighborhood = TerrainPeeringBridge.cycle_neighborhood_cell(_neighborhood, grid_index)
	_refresh_preview_and_neighborhood()


func _refresh_preview_and_neighborhood() -> void:
	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(_selected_pattern_key)
	if pattern.is_empty():
		return
	_run_live_preview(pattern, _map.get_canonical(_selected_pattern_key))
	_clear_grid(_neighborhood_grid)
	_build_neighborhood_grid()


func _run_live_preview(pattern: Dictionary, expected_id: int) -> void:
	if pattern.is_empty():
		return
	var preview_scale: float = _preview_host.scale.x
	_update_preview_viewport(preview_scale)
	var result: Dictionary = _preview_host.run_preview(
		_get_preview_tile_set(),
		pattern,
		_neighborhood,
		expected_id,
	)
	_last_picked_id = int(result.get("picked_id", -1))
	_last_region_ids = []
	for id: Variant in result.get("region_ids", []):
		_last_region_ids.append(int(id))
	if bool(result.get("match", false)):
		_match_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
		_match_label.text = "Match — Godot picked #%d as expected." % int(result["picked_id"])
	else:
		_match_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.4))
		_match_label.text = (
			"Mismatch — Godot picked #%d, expected #%d. Try another canonical or edit peering."
			% [int(result["picked_id"]), int(result["expected_id"])]
		)


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		child.queue_free()


func _viewport_size() -> Vector2:
	return get_viewport_rect().size


func _preview_px() -> int:
	return CatalogUiScale.px(BASE_PREVIEW_PX, _viewport_size())


func _row_height() -> int:
	return CatalogUiScale.px(BASE_ROW_HEIGHT, _viewport_size())


func _separation() -> int:
	return CatalogUiScale.px(BASE_SEPARATION, _viewport_size())


func _col(base: float) -> float:
	return CatalogUiScale.dim(base, _viewport_size())


func _font(base: int, bold: bool = false) -> int:
	return CatalogUiScale.font_size(base + (1 if bold else 0), _viewport_size())


func _apply_layout_scale() -> void:
	_ui_scale = CatalogUiScale.factor(_viewport_size())
	_apply_split_ratio()
	_apply_header_fonts()
	var preview_scale: float = clampf(_ui_scale * 1.2, 2.0, 4.0)
	_preview_host.scale = Vector2(preview_scale, preview_scale)
	_update_preview_viewport(preview_scale)


func _update_preview_viewport(preview_scale: float) -> void:
	var map_px: int = PREVIEW_MAP_CELLS * PREVIEW_TILE_PX
	var scaled: int = int(ceil(float(map_px) * preview_scale)) + 8
	_preview_viewport.size = Vector2i(scaled, scaled)
	_preview_frame.custom_minimum_size = Vector2(0.0, float(scaled) + 12.0)


func _apply_split_ratio() -> void:
	var viewport_width: float = _viewport_size().x
	if _view_mode == ViewMode.NON_TERRAIN:
		_main_split.split_offset = 0
	else:
		_main_split.split_offset = int(clampf(viewport_width * 0.24, _col(260.0), _col(420.0)))
		_right_split.split_offset = int(clampf(viewport_width * 0.38, _col(320.0), _col(520.0)))


func _apply_header_fonts() -> void:
	var title: Label = _header.get_node("Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", _font(15, true))
	for button: Node in _header.get_children():
		if button is Button:
			(button as Button).add_theme_font_size_override("font_size", _font(12))
	_hint.add_theme_font_size_override("font_size", _font(11))
	_status.add_theme_font_size_override("font_size", _font(10))
	_search.add_theme_font_size_override("font_size", _font(11))
	_meta_label.add_theme_font_size_override("font_size", _font(11))


func _on_save_pressed() -> void:
	var err: Error = _map.save_to_disk()
	if err != OK:
		_update_status("Save failed (error %d)" % err)
		return
	_update_status("Saved. F5 test_map to apply. %s" % _coverage_line())


func _on_reset_pressed() -> void:
	_map.reset_from_tsx()
	_invalidate_entry_cache()
	_refresh_ui()
	_update_status("Reset to TSX defaults.")


func _on_toggle_variants_pressed() -> void:
	_map.suppress_variants = not _map.suppress_variants
	_refresh_ui()


func _on_view_patterns() -> void:
	_view_mode = ViewMode.PATTERNS
	_selected_pattern_key = ""
	_selected_non_terrain_id = -1
	_apply_split_ratio()
	_hint.text = "Pick canonical tile, or edit peering / test layout in the center panel."
	_refresh_ui()


func _on_view_non_terrain() -> void:
	_view_mode = ViewMode.NON_TERRAIN
	_selected_pattern_key = ""
	_selected_non_terrain_id = -1
	_apply_split_ratio()
	_hint.text = "Click a tile → choose category in center → Save."
	_refresh_ui()


func _build_category_assignment_ui() -> void:
	_category_row = HBoxContainer.new()
	_category_row.name = "CategoryRow"
	_category_row.visible = false
	_category_row.add_theme_constant_override("separation", CatalogUiScale.px(8, _viewport_size()))
	var cat_label: Label = Label.new()
	cat_label.text = "Assign category:"
	cat_label.add_theme_font_size_override("font_size", _font(12, true))
	_category_option = OptionButton.new()
	_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key: String in TileCatalog.ASSIGNABLE_CATEGORY_KEYS:
		_category_option.add_item(TileCatalog.category_title(key))
	_category_option.item_selected.connect(_on_category_option_selected)
	_category_row.add_child(cat_label)
	_category_row.add_child(_category_option)
	_center_vbox.add_child(_category_row)
	_center_vbox.move_child(_category_row, 2)


func _set_pattern_inspector_visible(visible: bool) -> void:
	_center_header.text = "Inspector + live preview" if visible else "Tile assignment"
	_peering_title.visible = visible
	_peering_grid.visible = visible
	_neighborhood_title.visible = visible
	_neighborhood_grid.visible = visible
	_match_label.visible = visible
	_preview_title.visible = visible
	_preview_frame.visible = visible


func _refresh_non_terrain_center() -> void:
	_match_label.text = "—"
	if _selected_non_terrain_id < 0:
		_big_preview.texture = null
		_meta_label.text = "Select a non-wang tile from the list on the right."
		return
	var entry: Dictionary = _catalog_entry(_selected_non_terrain_id)
	var tile_id: int = int(entry.get("id", _selected_non_terrain_id))
	_big_preview.custom_minimum_size = Vector2(
		CatalogUiScale.px(BIG_PREVIEW_PX, _viewport_size()),
		CatalogUiScale.px(BIG_PREVIEW_PX, _viewport_size()),
	)
	_big_preview.texture = TileCatalog.make_atlas_texture(tile_id)
	var override_note: String = " (saved override)" if _map.is_tile_category_overridden(tile_id) else ""
	_meta_label.text = (
		"Tile #%d · %s%s\n%s"
		% [
			tile_id,
			str(entry.get("category", "misc")),
			override_note,
			str(entry.get("use_case", "")),
		]
	)
	_sync_category_option(tile_id)


func _sync_category_option(tile_id: int) -> void:
	if _category_option == null:
		return
	var current: String = _map.get_tile_category_override(tile_id)
	var select_idx: int = 0
	for i: int in range(TileCatalog.ASSIGNABLE_CATEGORY_KEYS.size()):
		if TileCatalog.ASSIGNABLE_CATEGORY_KEYS[i] == current:
			select_idx = i
			break
	_syncing_category_option = true
	_category_option.select(select_idx)
	_syncing_category_option = false


func _on_category_option_selected(_index: int) -> void:
	if _syncing_category_option or _selected_non_terrain_id < 0:
		return
	var category_key: String = TileCatalog.ASSIGNABLE_CATEGORY_KEYS[_category_option.selected]
	_map.set_tile_category(_selected_non_terrain_id, category_key)
	_invalidate_entry_cache()
	_update_non_terrain_row_meta(_selected_non_terrain_id)
	_refresh_non_terrain_center()
	_update_status(_coverage_line())


func _select_non_terrain_tile(tile_id: int) -> void:
	if tile_id == _selected_non_terrain_id:
		return
	_set_non_terrain_row_selected(_selected_non_terrain_id, false)
	_selected_non_terrain_id = tile_id
	_set_non_terrain_row_selected(tile_id, true)
	_refresh_non_terrain_center()


func _on_filter_dirt() -> void:
	_filter_terrain = TerrainPeeringPatterns.TERRAIN_DIRT
	_selected_pattern_key = ""
	_view_mode = ViewMode.PATTERNS
	_refresh_ui()


func _on_filter_water() -> void:
	_filter_terrain = TerrainPeeringPatterns.TERRAIN_WATER
	_selected_pattern_key = ""
	_view_mode = ViewMode.PATTERNS
	_refresh_ui()


func _on_filter_elevation() -> void:
	_filter_terrain = TerrainPeeringPatterns.TERRAIN_ELEVATION
	_selected_pattern_key = ""
	_view_mode = ViewMode.PATTERNS
	_refresh_ui()


func _rebuild_pattern_list() -> void:
	for child: Node in _pattern_list.get_children():
		child.queue_free()
	if _view_mode != ViewMode.PATTERNS:
		return

	_pattern_header.text = TerrainPeeringPatterns.terrain_title(_filter_terrain)
	_add_section_label("Click a pattern · P / N to step · center panel = live Godot preview")

	var last_shape: String = ""
	for pattern: Dictionary in _filtered_patterns():
		var shape: String = str(pattern["shape"])
		if shape != last_shape:
			last_shape = shape
			_add_section_label(shape.capitalize())
		_pattern_list.add_child(_make_pattern_row(pattern))


func _add_section_label(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font(11, not text.contains("·")))
	label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.72, 0.85) if text.contains("·") else Color(0.8, 0.86, 0.95),
	)
	_pattern_list.add_child(label)


func _make_pattern_row(pattern: Dictionary) -> PanelContainer:
	var pattern_key: String = str(pattern["key"])
	var canonical: int = _map.get_canonical(pattern_key)
	var selected: bool = pattern_key == _selected_pattern_key
	var customized: bool = _map.is_customized(pattern_key)
	var variant_count: int = int(pattern["variant_count"])

	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, _row_height())
	var base: Color = Color(0.18, 0.14, 0.14) if customized else Color(0.14, 0.16, 0.22)
	row.add_theme_stylebox_override("panel", _panel_style(selected, base))
	row.gui_input.connect(_on_pattern_gui_input.bind(pattern_key))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(4, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(4, _viewport_size()))
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	margin.add_child(hbox)

	hbox.add_child(_preview(canonical))
	hbox.add_child(_label(str(pattern["label"]), _col(200.0), selected))
	hbox.add_child(_label("#%d" % canonical, _col(48.0), true))
	var meta: String = "edited" if customized else "tsx"
	if variant_count > 1:
		meta += " · ×%d" % variant_count
	hbox.add_child(_label(meta, _col(72.0)))

	return row


func _on_pattern_gui_input(event: InputEvent, pattern_key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_pattern(pattern_key)


func _rebuild_tile_list() -> void:
	_non_terrain_row_panels.clear()
	for child: Node in _tile_list.get_children():
		child.queue_free()

	if _view_mode == ViewMode.NON_TERRAIN:
		_build_non_terrain_list()
		return

	if _selected_pattern_key.is_empty():
		_add_tile_header("Select a pattern.")
		return

	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(_selected_pattern_key)
	var canonical: int = _map.get_canonical(_selected_pattern_key)
	_add_tile_header("Candidates — canonical #%d" % canonical)

	for tile_id: Variant in pattern["candidates"]:
		var id: int = int(tile_id)
		if not _matches_search(id, pattern):
			continue
		_tile_list.add_child(_make_candidate_row(id, pattern, id == canonical))


func _build_non_terrain_list() -> void:
	_ensure_entry_cache()
	_add_tile_header("Non-wang tiles — click to assign category")
	_add_info_row(
		"Wang/terrain tiles use the Patterns tab. Here: grass fill, decor, tree bases, ruins, etc."
	)
	var last_category: String = ""
	for entry: Dictionary in TerrainPeeringPatterns.non_terrain_entries(_map):
		var category: String = str(entry["category"])
		if category != last_category:
			last_category = category
			_add_tile_header(str(TerrainPeeringPatterns.CATEGORY_TITLES.get(category, category)))
		var tile_id: int = int(entry["id"])
		if not _matches_search(tile_id, entry):
			continue
		_tile_list.add_child(_make_info_tile_row(entry))


func _matches_search(tile_id: int, context: Dictionary) -> bool:
	if _search_text.is_empty():
		return true
	if ("#%d" % tile_id).contains(_search_text) or str(tile_id).contains(_search_text):
		return true
	for key: String in ["label", "orientation", "use_case", "category"]:
		if str(context.get(key, "")).to_lower().contains(_search_text):
			return true
	return false


func _make_candidate_row(tile_id: int, pattern: Dictionary, is_canonical: bool) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, _row_height())
	var base: Color = Color(0.16, 0.2, 0.14) if is_canonical else Color(0.11, 0.12, 0.14, 0.85)
	row.add_theme_stylebox_override("panel", _panel_style(is_canonical, base))
	row.gui_input.connect(_on_candidate_gui_input.bind(str(pattern["key"]), tile_id))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(6, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(6, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(3, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(3, _viewport_size()))
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	margin.add_child(hbox)

	hbox.add_child(_preview(tile_id))
	hbox.add_child(_label("#%d" % tile_id, _col(56.0), true))
	hbox.add_child(_label("CANONICAL" if is_canonical else "variant", _col(90.0), is_canonical))
	hbox.add_child(_label(str(_catalog_entry(tile_id).get("use_case", "")), _col(380.0)))

	return row


func _make_info_tile_row(entry: Dictionary) -> PanelContainer:
	var tile_id: int = int(entry["id"])
	var selected: bool = tile_id == _selected_non_terrain_id
	var overridden: bool = _map.is_tile_category_overridden(tile_id)
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, _row_height())
	var base: Color = Color(0.16, 0.2, 0.14) if selected else Color(0.1, 0.11, 0.13, 0.75)
	if overridden and not selected:
		base = Color(0.14, 0.16, 0.12, 0.85)
	row.add_theme_stylebox_override("panel", _panel_style(selected, base))
	row.gui_input.connect(_on_non_terrain_tile_gui_input.bind(tile_id))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(6, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(6, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(3, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(3, _viewport_size()))
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	margin.add_child(hbox)

	hbox.add_child(_preview(tile_id))
	hbox.add_child(_label("#%d" % tile_id, _col(56.0), true))
	hbox.add_child(_label(str(entry.get("category", "misc")), _col(140.0), overridden))
	hbox.add_child(_label(str(entry.get("use_case", "")), _col(360.0)))

	_non_terrain_row_panels[tile_id] = row
	return row


func _on_non_terrain_tile_gui_input(event: InputEvent, tile_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_non_terrain_tile(tile_id)


func _on_candidate_gui_input(event: InputEvent, pattern_key: String, tile_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_map.set_canonical(pattern_key, tile_id)
		_select_pattern(pattern_key)


func _catalog_entry(tile_id: int) -> Dictionary:
	_ensure_entry_cache()
	return _entry_by_id.get(tile_id, {}) as Dictionary


func _ensure_entry_cache() -> void:
	if not _entry_by_id.is_empty():
		return
	for entry: Dictionary in TileCatalog.build_forest_entries(_map):
		_entry_by_id[int(entry["id"])] = entry


func _invalidate_entry_cache() -> void:
	_entry_by_id.clear()
	TileCatalog.invalidate_runtime_cache()


func _set_non_terrain_row_selected(tile_id: int, selected: bool) -> void:
	var row: PanelContainer = _non_terrain_row_panels.get(tile_id) as PanelContainer
	if row == null:
		return
	var overridden: bool = _map.is_tile_category_overridden(tile_id)
	var base: Color = Color(0.16, 0.2, 0.14) if selected else Color(0.1, 0.11, 0.13, 0.75)
	if overridden and not selected:
		base = Color(0.14, 0.16, 0.12, 0.85)
	row.add_theme_stylebox_override("panel", _panel_style(selected, base))


func _update_non_terrain_row_meta(tile_id: int) -> void:
	var row: PanelContainer = _non_terrain_row_panels.get(tile_id) as PanelContainer
	if row == null:
		return
	var entry: Dictionary = _catalog_entry(tile_id)
	var hbox: HBoxContainer = row.get_child(0).get_child(0) as HBoxContainer
	if hbox == null or hbox.get_child_count() < 4:
		return
	var use_label: Label = hbox.get_child(3) as Label
	if use_label != null:
		use_label.text = str(entry.get("use_case", ""))
	var cat_label: Label = hbox.get_child(2) as Label
	if cat_label != null:
		cat_label.text = str(entry.get("category", "misc"))
	_set_non_terrain_row_selected(tile_id, tile_id == _selected_non_terrain_id)


func _add_tile_header(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font(12, true))
	label.add_theme_color_override("font_color", Color(0.82, 0.87, 0.96))
	_tile_list.add_child(label)


func _add_info_row(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font(10))
	label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8))
	_tile_list.add_child(label)


func _preview(tile_id: int) -> Control:
	var preview_px: int = _preview_px()
	var pad: int = CatalogUiScale.px(6, _viewport_size())
	var wrap: CenterContainer = CenterContainer.new()
	wrap.custom_minimum_size = Vector2(preview_px + pad, preview_px + CatalogUiScale.px(4, _viewport_size()))
	if tile_id < 0:
		return wrap
	var bg: PanelContainer = PanelContainer.new()
	bg.add_theme_stylebox_override("panel", _preview_bg_style())
	wrap.add_child(bg)
	var checker: TextureRect = TextureRect.new()
	checker.custom_minimum_size = Vector2(preview_px, preview_px)
	checker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checker.stretch_mode = TextureRect.STRETCH_TILE
	checker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	checker.texture = _checkerboard_texture()
	checker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(checker)
	if TileCatalog.is_atlas_empty_slot(tile_id):
		var empty: Label = Label.new()
		empty.text = "∅"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(preview_px, preview_px)
		empty.add_theme_font_size_override("font_size", CatalogUiScale.font_size(14, _viewport_size()))
		empty.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(empty)
	else:
		var tex: TextureRect = TextureRect.new()
		tex.custom_minimum_size = Vector2(preview_px, preview_px)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.texture = TileCatalog.make_atlas_texture(tile_id)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(tex)
	return wrap


func _checkerboard_texture() -> Texture2D:
	if _checker_tex != null:
		return _checker_tex
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y: int in range(8):
		for x: int in range(8):
			var light: bool = ((x + y) % 2) == 0
			img.set_pixel(x, y, Color(0.36, 0.38, 0.44) if light else Color(0.50, 0.52, 0.58))
	_checker_tex = ImageTexture.create_from_image(img)
	return _checker_tex


func _label(text: String, min_width: float, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font(11, bold))
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	return label


func _panel_style(selected: bool, base: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = base.lightened(0.1) if selected else base
	style.set_corner_radius_all(CatalogUiScale.px(4, _viewport_size()))
	if selected:
		style.set_border_width_all(CatalogUiScale.px(1, _viewport_size()))
		style.border_color = Color(0.45, 0.65, 1.0, 0.9)
	return style


func _preview_bg_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.24, 0.28, 1.0)
	style.set_corner_radius_all(CatalogUiScale.px(2, _viewport_size()))
	style.set_border_width_all(CatalogUiScale.px(1, _viewport_size()))
	style.border_color = Color(0.35, 0.38, 0.45, 1.0)
	return style


func _update_status(text: String) -> void:
	_status.text = text
