extends Control

## Side-by-side grass comparison — F6 this scene. Not wired into test_map.

const _PetalPatch = preload("res://scripts/grass_petal_patch.gd")

const ZOOM: int = 8
const TILE_PX: int = 16
const CELL_PX: int = TILE_PX * ZOOM

const _ROWS: Array[Dictionary] = [
	{
		"tile_id": 97,
		"static_label": "Grass #97 — Mana Seed reference (static)",
		"anim_label": "3-line blades — top half sways, base planted",
		"variant": 0,
		"seed": 9701,
	},
	{
		"tile_id": 98,
		"static_label": "Grass #98 — Mana Seed reference (static)",
		"anim_label": "V-shape blades — top half sways, base planted",
		"variant": 1,
		"seed": 9801,
	},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.07, 0.09, 1.0)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 28)
	scroll.add_child(vbox)

	vbox.add_child(_title_label())
	vbox.add_child(_hint_label())

	for row: Dictionary in _ROWS:
		vbox.add_child(_build_row(row))


func _title_label() -> Label:
	var label: Label = Label.new()
	label.text = "Grass cluster animation lab (Pixel Pete 101)"
	label.add_theme_font_size_override("font_size", 28)
	return label


func _hint_label() -> Label:
	var label: Label = Label.new()
	label.text = (
		"Blade sway: bottom 3 still, 4th +1 px, 5th +2 px, tip +2 px (synced). "
		+ "Left = Mana Seed reference. Right = procedural only. F6 this scene."
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 1.0))
	return label


func _build_row(row: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.14, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 32)
	panel.add_child(row_box)

	var tile_id: int = int(row["tile_id"])
	var variant_idx: int = int(row["variant"])
	var seed: int = int(row["seed"])
	row_box.add_child(_column(str(row["static_label"]), _make_static_tile(tile_id)))
	row_box.add_child(_column(str(row["anim_label"]), _make_petal_patch(variant_idx, seed)))

	return panel


func _column(title: String, tile_node: Node2D) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)

	var label: Label = Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 400.0
	col.add_child(label)

	var wrap: CenterContainer = CenterContainer.new()
	wrap.custom_minimum_size = Vector2(CELL_PX + 16, CELL_PX + 16)
	col.add_child(wrap)

	var checker: PanelContainer = PanelContainer.new()
	checker.add_theme_stylebox_override("panel", _checker_style())
	wrap.add_child(checker)

	var inner: CenterContainer = CenterContainer.new()
	inner.custom_minimum_size = Vector2(CELL_PX, CELL_PX)
	checker.add_child(inner)
	inner.add_child(tile_node)

	return col


func _checker_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.20, 1.0)
	style.border_color = Color(0.28, 0.30, 0.36, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _make_static_tile(tile_id: int) -> Sprite2D:
	var atlas_tex: AtlasTexture = TileCatalog.make_atlas_texture(tile_id)
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = atlas_tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.scale = Vector2(float(ZOOM), float(ZOOM))
	return spr


func _make_petal_patch(variant_idx: int, seed: int) -> Node2D:
	var patch: GrassPetalPatch = _PetalPatch.new()
	patch.setup(variant_idx, seed)
	patch.scale = Vector2(float(ZOOM), float(ZOOM))
	return patch
