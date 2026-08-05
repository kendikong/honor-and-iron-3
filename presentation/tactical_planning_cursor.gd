class_name TacticalPlanningCursor
extends CanvasLayer

## Screen-space planning cursor icons â€” outside WorldModulate so emoji stay crisp.

const BASE_ICON_SIZE: int = 36
const ICON_OFFSET: Vector2 = Vector2(12.0, 12.0)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.92)
const COMPOSITE_GAP_PX: float = 10.0
const COMPOSITE_SLASH_COLOR: Color = Color(0.82, 0.86, 0.92, 0.95)

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
	var composite: PackedStringArray = _composite_icon_parts(_icon)
	if composite.size() > 1:
		_draw_composite_row(_drawer, center, composite)
		return
	var color: Color = Color(1.0, 0.52, 0.52, 1.0) if _icon == "âˆ…" else Color(1.0, 1.0, 1.0, 1.0)
	_draw_centered(_drawer, center, _icon, color, _font_size)


func _draw_composite_row(canvas: CanvasItem, center: Vector2, parts: PackedStringArray) -> void:
	var glyph_px: int = maxi(22, int(round(float(_font_size) * 0.72)))
	var slash_px: int = maxi(14, int(round(float(_font_size) * 0.48)))
	var gap: float = COMPOSITE_GAP_PX
	var total_w: float = 0.0
	for i: int in parts.size():
		if i > 0:
			total_w += gap + _text_width("/", slash_px) + gap
		total_w += _text_width(parts[i], glyph_px)
	var x: float = center.x - total_w * 0.5
	for i: int in parts.size():
		if i > 0:
			x += gap
			var slash_w: float = _text_width("/", slash_px)
			_draw_centered_at(
				canvas,
				Vector2(x + slash_w * 0.5, center.y),
				"/",
				COMPOSITE_SLASH_COLOR,
				slash_px,
			)
			x += slash_w + gap
		var glyph_w: float = _text_width(parts[i], glyph_px)
		_draw_centered_at(
			canvas,
			Vector2(x + glyph_w * 0.5, center.y),
			parts[i],
			Color.WHITE,
			glyph_px,
		)
		x += glyph_w


static func _composite_icon_parts(icon: String) -> PackedStringArray:
	for sep: String in ["/", "+"]:
		if icon.contains(sep):
			var parts: PackedStringArray = []
			for segment: String in icon.split(sep, false):
				var trimmed: String = segment.strip_edges()
				if not trimmed.is_empty():
					parts.append(trimmed)
			return parts
	if icon == "ðŸ‘Ÿâš”ï¸":
		return PackedStringArray(["ðŸ‘Ÿ", "âš”ï¸"])
	if icon == "ðŸƒâš”ï¸":
		return PackedStringArray(["ðŸƒ", "âš”ï¸"])
	return PackedStringArray()


static func _text_width(text: String, size_px: int) -> float:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return float(size_px)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x


static func _draw_centered_at(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	color: Color,
	size_px: int,
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
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


static func _draw_centered(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	color: Color,
	size_px: int,
) -> void:
	_draw_centered_at(canvas, center, text, color, size_px)
