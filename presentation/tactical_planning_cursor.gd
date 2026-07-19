class_name TacticalPlanningCursor
extends CanvasLayer

## Screen-space planning cursor icons — outside WorldModulate so emoji stay crisp.

const BASE_ICON_SIZE: int = 36
const ICON_OFFSET: Vector2 = Vector2(12.0, 12.0)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.92)

var _icon: String = ""
var _font_size: int = BASE_ICON_SIZE
var _drawer: Control


func _ready() -> void:
	layer = 25
	_drawer = Control.new()
	_drawer.name = "Drawer"
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.draw.connect(_on_draw)
	add_child(_drawer)
	set_process(true)


func apply_text_scale(scale: float) -> void:
	_font_size = maxi(28, int(round(float(BASE_ICON_SIZE) * maxf(scale, 0.75))))


func set_icon(icon: String) -> void:
	if _icon == icon:
		return
	_icon = icon
	if _drawer != null:
		_drawer.queue_redraw()


func _process(_delta: float) -> void:
	if _icon != "" and _drawer != null:
		_drawer.queue_redraw()


func _on_draw() -> void:
	if _icon == "":
		return
	var center: Vector2 = get_viewport().get_mouse_position() + ICON_OFFSET
	if _icon == "👟⚔️" or _icon == "🏃⚔️":
		var move_glyph: String = "👟" if _icon == "👟⚔️" else "🏃"
		var half: int = maxi(22, int(round(float(_font_size) * 0.72)))
		_draw_centered(_drawer, center + Vector2(-10.0, 0.0), move_glyph, Color.WHITE, half)
		_draw_centered(_drawer, center + Vector2(10.0, 0.0), "⚔️", Color.WHITE, half)
		return
	var color: Color = Color(1.0, 0.52, 0.52, 1.0) if _icon == "∅" else Color(1.0, 1.0, 1.0, 1.0)
	_draw_centered(_drawer, center, _icon, color, _font_size)


static func _draw_centered(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	color: Color,
	size_px: int,
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px).x
	var pos: Vector2 = center - Vector2(width * 0.5, -float(size_px) * 0.35)
	for ox: int in [-2, -1, 0, 1, 2]:
		for oy: int in [-2, -1, 0, 1, 2]:
			if ox == 0 and oy == 0:
				continue
			if absi(ox) + absi(oy) > 2:
				continue
			canvas.draw_string(
				font,
				pos + Vector2(float(ox), float(oy)),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				size_px,
				OUTLINE_COLOR,
			)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
