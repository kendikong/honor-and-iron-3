extends Control

## Visual catalog of gentle forest v01 tiles. Open `scenes/tile_library.tscn` and press F6.

const BASE_PREVIEW_PX: int = 48
const BASE_ROW_HEIGHT: int = 56
const BASE_SEPARATION: int = 16

@onready var _list: VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer

var _ui_scale: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_rebuild_all()


func _on_viewport_resized() -> void:
	var next_scale: float = CatalogUiScale.factor(get_viewport_rect().size)
	if is_equal_approx(next_scale, _ui_scale):
		return
	_ui_scale = next_scale
	_rebuild_all()


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


func _rebuild_all() -> void:
	_ui_scale = CatalogUiScale.factor(_viewport_size())
	for child: Node in _list.get_children():
		child.queue_free()
	_build_header()
	_build_seasonal_samples_section()
	var grouped: Dictionary = TileCatalog.entries_grouped()
	for category_key: String in TileCatalog.CATEGORY_ORDER:
		var bucket: Array = grouped.get(category_key, [])
		if bucket.is_empty():
			continue
		_add_section_header(str(TileCatalog.CATEGORY_TITLES.get(category_key, category_key)), bucket.size())
		for entry: Dictionary in bucket:
			_add_row(entry)


func _build_header() -> void:
	var featured_count: int = SeasonalSampleCatalog.featured_forest_local_ids().size()
	var title: Label = Label.new()
	title.text = "Gentle Forest v01 â€” Tile Library (%d tiles)" % TileCatalog.TILE_COUNT
	title.add_theme_font_size_override("font_size", _font(17, true))
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_list.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = (
		"Atlas: gentle forest v01.png Â· 16Ã—16 cells Â· "
		+ "%d tiles featured in seasonal samples (spring/summer/autumn/winter) Â· "
		+ "Orientations from terrain_peering_map.tres overrides when saved (else .tsx)"
		% featured_count
	)
	subtitle.add_theme_font_size_override("font_size", _font(10))
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_list.add_child(subtitle)
	_list.add_child(_make_separator())

	_list.add_child(_make_column_header())
	_list.add_child(_make_separator())


func _build_seasonal_samples_section() -> void:
	_list.add_child(_make_separator())
	var section_title: Label = Label.new()
	section_title.text = "Seasonal sample reference maps (tilesets/)"
	section_title.add_theme_font_size_override("font_size", _font(13, true))
	section_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_list.add_child(section_title)

	var section_note: Label = Label.new()
	section_note.text = (
		"256Ã—256 composed previews â€” same layout as the gentle forest sample map. "
		+ "Palette targets gentle forest v07â€“v10 (PNGs not on disk; reference only)."
	)
	section_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_note.add_theme_font_size_override("font_size", _font(10))
	section_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_list.add_child(section_note)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", _separation())
	grid.add_theme_constant_override("v_separation", _separation())
	_list.add_child(grid)

	var sample_px: int = CatalogUiScale.px(120, _viewport_size())
	for season: Dictionary in SeasonalSampleCatalog.SEASONS:
		grid.add_child(_make_seasonal_sample_card(season, sample_px))

	_add_overlay_featured_section()


func _make_seasonal_sample_card(season: Dictionary, sample_px: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(6, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(6, _viewport_size()))
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", CatalogUiScale.px(4, _viewport_size()))
	margin.add_child(vbox)

	var label: Label = Label.new()
	label.text = "%s â€” %s" % [season["label"], season["palette"]]
	label.add_theme_font_size_override("font_size", _font(11, true))
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	vbox.add_child(label)

	var preview_wrap: CenterContainer = CenterContainer.new()
	vbox.add_child(preview_wrap)

	var preview_bg: PanelContainer = PanelContainer.new()
	preview_bg.add_theme_stylebox_override("panel", _preview_bg_style())
	preview_wrap.add_child(preview_bg)

	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(sample_px, sample_px)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = load(str(season["path"]))
	preview_bg.add_child(preview)

	return card


func _add_overlay_featured_section() -> void:
	var overlay_entries: Array[Dictionary] = SeasonalSampleCatalog.featured_overlay_entries()
	if overlay_entries.is_empty():
		return

	_list.add_child(_make_separator())
	var overlay_title: Label = Label.new()
	overlay_title.text = "Seasonal sample â€” overlay / composite tiles (%d)" % overlay_entries.size()
	overlay_title.add_theme_font_size_override("font_size", _font(13, true))
	overlay_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_list.add_child(overlay_title)

	_list.add_child(_make_separator())
	_list.add_child(_make_column_header())
	_list.add_child(_make_separator())

	for entry: Dictionary in overlay_entries:
		_add_overlay_row(entry)


func _add_overlay_row(entry: Dictionary) -> void:
	var preview_px: int = _preview_px()
	var source_id: int = int(entry["source_id"])
	var atlas: Vector2i = entry["atlas_coords"]
	var tile_size: Vector2i = Vector2i(16, 16)
	match source_id:
		TileSetFactory.SOURCE_PROPS_32:
			tile_size = Vector2i(32, 32)
		TileSetFactory.SOURCE_TREES:
			tile_size = Vector2i(80, 96)
	var display_px: int = mini(preview_px * 2, maxi(tile_size.x, tile_size.y))

	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, _row_height())
	row.add_theme_stylebox_override("panel", _row_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(4, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(4, _viewport_size()))
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	margin.add_child(hbox)

	var preview_wrap: CenterContainer = CenterContainer.new()
	preview_wrap.custom_minimum_size = Vector2(display_px + CatalogUiScale.px(8, _viewport_size()), display_px)
	hbox.add_child(preview_wrap)

	var preview_bg: PanelContainer = PanelContainer.new()
	preview_bg.add_theme_stylebox_override("panel", _preview_bg_style())
	preview_wrap.add_child(preview_bg)

	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(display_px, display_px)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = SeasonalSampleCatalog.make_overlay_preview_texture(source_id, atlas)
	preview_bg.add_child(preview)

	hbox.add_child(_cell_label("src %d" % source_id, _col(64.0), true))
	hbox.add_child(_cell_label("(%d, %d)" % [atlas.x, atlas.y], _col(140.0)))
	hbox.add_child(_cell_label(str(entry["label"]), _col(520.0)))
	hbox.add_child(_cell_label(str(entry["use_case"]), _col(280.0)))

	_list.add_child(row)


func _add_section_header(title: String, count: int) -> void:
	_list.add_child(_make_separator())
	var label: Label = Label.new()
	label.text = "%s (%d)" % [title, count]
	label.add_theme_font_size_override("font_size", _font(13, true))
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_list.add_child(label)


func _add_row(entry: Dictionary) -> void:
	var preview_px: int = _preview_px()
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, _row_height())
	row.add_theme_stylebox_override("panel", _row_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_right", CatalogUiScale.px(8, _viewport_size()))
	margin.add_theme_constant_override("margin_top", CatalogUiScale.px(4, _viewport_size()))
	margin.add_theme_constant_override("margin_bottom", CatalogUiScale.px(4, _viewport_size()))
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	margin.add_child(hbox)

	var preview_wrap: CenterContainer = CenterContainer.new()
	preview_wrap.custom_minimum_size = Vector2(preview_px + CatalogUiScale.px(8, _viewport_size()), preview_px)
	hbox.add_child(preview_wrap)

	var preview_bg: PanelContainer = PanelContainer.new()
	preview_bg.add_theme_stylebox_override("panel", _preview_bg_style())
	preview_wrap.add_child(preview_bg)

	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(preview_px, preview_px)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = TileCatalog.make_atlas_texture(int(entry["id"]))
	preview_bg.add_child(preview)

	hbox.add_child(_cell_label(_tile_id_label(entry), _col(64.0), true))
	hbox.add_child(_cell_label(str(entry["category"]), _col(140.0)))
	hbox.add_child(_cell_label(str(entry["use_case"]), _col(520.0)))
	hbox.add_child(_cell_label(str(entry["orientation"]), _col(280.0)))

	_list.add_child(row)


func _make_column_header() -> HBoxContainer:
	var preview_px: int = _preview_px()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", _separation())
	hbox.add_child(_header_label("Preview", preview_px + CatalogUiScale.px(8, _viewport_size())))
	hbox.add_child(_header_label("ID", _col(64.0)))
	hbox.add_child(_header_label("Category", _col(140.0)))
	hbox.add_child(_header_label("Use case", _col(520.0)))
	hbox.add_child(_header_label("Orientation (Wang TL,T,TR,L,R,BL,B,BR)", _col(280.0)))
	return hbox


func _header_label(text: String, min_width: float) -> Label:
	var label: Label = _cell_label(text, min_width, true)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	return label


func _cell_label(text: String, min_width: float, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _font(11, bold))
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	return label


func _tile_id_label(entry: Dictionary) -> String:
	var local_id: int = int(entry["id"])
	var text: String = "#%d" % local_id
	if SeasonalSampleCatalog.is_featured_forest_tile(local_id):
		text += " â˜…"
	return text


func _make_separator() -> Control:
	var sep: HSeparator = HSeparator.new()
	sep.modulate = Color(1.0, 1.0, 1.0, 0.25)
	return sep


func _row_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.65)
	style.set_corner_radius_all(CatalogUiScale.px(4, _viewport_size()))
	return style


func _preview_bg_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.24, 0.28, 1.0)
	style.set_corner_radius_all(CatalogUiScale.px(2, _viewport_size()))
	style.set_border_width_all(CatalogUiScale.px(1, _viewport_size()))
	style.border_color = Color(0.35, 0.38, 0.45, 1.0)
	return style
