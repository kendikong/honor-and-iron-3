class_name TileInspectorPanel
extends CanvasLayer

## Side panel: full provenance for the hovered / clicked map cell.

const TILE_PX: int = 16

var _panel_width: int = 520
var _title_label: Label
var _screen_root: Control

var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: RichTextLabel
var _hint: Label
var _selected: Vector2i = Vector2i(-1, -1)
var _hover: Vector2i = Vector2i(-1, -1)
var _displayed_cell: Vector2i = Vector2i(-9999, -9999)
var _displayed_locked: bool = false

var _grid: PlayerGrid
var _logical_provenance: PlayerGridProvenance
var _render_provenance: MapRenderProvenance
var _ground: TileMapLayer
var _phantom: TileMapLayer
var _overlay: TileMapLayer
var _vfx: TileMapLayer
var _map_root: Node2D


func _ready() -> void:
	layer = 20
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)


func setup(
	grid: PlayerGrid,
	logical: PlayerGridProvenance,
	render: MapRenderProvenance,
	map_root: Node2D,
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
	phantom: TileMapLayer = null,
) -> void:
	_grid = grid
	_logical_provenance = logical
	_render_provenance = render
	_map_root = map_root
	_ground = ground
	_phantom = phantom
	_overlay = overlay
	_vfx = vfx
	_displayed_cell = Vector2i(-9999, -9999)
	_refresh_if_active()


func invalidate_display_cache() -> void:
	_displayed_cell = Vector2i(-9999, -9999)


func set_hover_cell(pos: Vector2i) -> void:
	if pos == _hover:
		return
	_hover = pos
	if _selected.x >= 0:
		return
	if not _can_inspect(pos):
		_displayed_cell = Vector2i(-9999, -9999)
		_body.text = "[i]Hover or click a map cell.[/i]"
		return
	_show_cell(pos)


func set_selected_cell(pos: Vector2i) -> void:
	_selected = pos
	_show_cell(pos)


func clear_selection() -> void:
	_selected = Vector2i(-1, -1)
	if _can_inspect(_hover):
		_show_cell(_hover)
	else:
		_body.text = "[i]Hover or click a map cell.[/i]"


func panel_width() -> int:
	return _panel_width


func apply_display_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_panel_width = settings.inspector_panel_width
	_apply_panel_width()
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", settings.inspector_title_font())
	if _hint != null:
		_hint.add_theme_font_size_override("font_size", settings.inspector_hint_font())
	if _body != null:
		_body.add_theme_font_size_override("normal_font_size", settings.inspector_body_font())
		_body.custom_minimum_size.x = float(_panel_width - 40)
	invalidate_display_cache()
	_refresh_if_active()


func get_active_cell() -> Vector2i:
	if _selected.x >= 0:
		return _selected
	return _hover


func _on_viewport_resized() -> void:
	if _screen_root != null:
		_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	_screen_root = Control.new()
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_apply_panel_width()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_screen_root.add_child(_panel)

	var outer: MarginContainer = MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left", 10)
	outer.add_theme_constant_override("margin_right", 10)
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(outer)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	outer.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Tile Inspector"
	_title_label = title
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vbox.add_child(title)

	_hint = Label.new()
	_hint.text = "Hover a cell Â· click to lock Â· Esc or Clear to unlock"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
	vbox.add_child(_hint)

	var clear_row: HBoxContainer = HBoxContainer.new()
	clear_row.add_theme_constant_override("separation", 8)
	vbox.add_child(clear_row)

	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear selection"
	clear_btn.add_theme_font_size_override("font_size", 16)
	clear_btn.pressed.connect(clear_selection)
	clear_row.add_child(clear_btn)

	vbox.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_scroll)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(_panel_width - 40, 0)
	_body.add_theme_font_size_override("normal_font_size", 20)
	_scroll.add_child(_body)

	_body.text = "[i]Hover or click a map cell.[/i]"


func _apply_panel_width() -> void:
	if _panel == null:
		return
	_panel.offset_left = -float(_panel_width)


func _refresh_if_active() -> void:
	var cell: Vector2i = get_active_cell()
	if _can_inspect(cell):
		_show_cell(cell)


func _show_cell(pos: Vector2i) -> void:
	if _grid == null:
		return
	if not _can_inspect(pos):
		return
	var locked: bool = _selected == pos
	if pos == _displayed_cell and locked == _displayed_locked:
		return
	_displayed_cell = pos
	_displayed_locked = locked
	if _is_phantom_cell(pos):
		_body.text = TileInspectorReport.build_phantom_bbcode(
			pos, _render_provenance, _phantom, locked,
		)
	else:
		_body.text = TileInspectorReport.build_bbcode(
			pos,
			_grid,
			_logical_provenance,
			_render_provenance,
			_ground,
			_overlay,
			_vfx,
			locked,
		)
	call_deferred("_refresh_scroll_extent")


func _refresh_scroll_extent() -> void:
	if _body == null or _scroll == null:
		return
	_body.custom_minimum_size.y = _body.get_content_height() + 8.0


func _in_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _grid.width and pos.y < _grid.height


func _is_phantom_cell(pos: Vector2i) -> bool:
	return not _in_grid(pos) and _phantom != null and _phantom.get_cell_source_id(pos) != -1


func _can_inspect(pos: Vector2i) -> bool:
	if _in_grid(pos):
		return true
	return _is_phantom_cell(pos)


func _panel_style() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.11, 0.94)
	bg.set_corner_radius_all(0)
	bg.border_width_left = 2
	bg.border_color = Color(0.28, 0.32, 0.42)
	return bg
