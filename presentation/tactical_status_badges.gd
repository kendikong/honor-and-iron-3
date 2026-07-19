class_name TacticalStatusBadges
extends CanvasLayer

## Screen-space unit status badges — outside WorldModulate for crisp text at any zoom.

const BADGE_BASE_SIZE: int = 14
const BADGE_GAP: int = 2
const BADGE_COLS: int = 4
const FONT_BASE: int = 9
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.92)

var _unit_layer: TacticalUnitLayer
var _map_view: Node
var _text_scale: float = 1.0
var _drawer: Control


func _ready() -> void:
	layer = 24
	_drawer = Control.new()
	_drawer.name = "Drawer"
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.draw.connect(_on_draw)
	add_child(_drawer)
	set_process(true)


func bind(unit_layer: TacticalUnitLayer, map_view: Node) -> void:
	_unit_layer = unit_layer
	_map_view = map_view


func apply_text_scale(scale: float) -> void:
	_text_scale = maxf(0.75, scale)


func _process(_delta: float) -> void:
	if _drawer != null and _unit_layer != null:
		_drawer.queue_redraw()


func _on_draw() -> void:
	if _unit_layer == null or _map_view == null or not _map_view.has_method("map_local_to_screen"):
		return
	var badge_sz: int = maxi(12, int(round(float(BADGE_BASE_SIZE) * _text_scale)))
	var gap: int = maxi(1, int(round(float(BADGE_GAP) * _text_scale)))
	var font_px: int = maxi(8, int(round(float(FONT_BASE) * _text_scale)))
	var step: float = float(badge_sz + gap)
	for unit: UnitState in _unit_layer.get_units_for_status_display():
		var anchor_map: Vector2 = _unit_layer.status_badge_anchor_map_local(unit)
		var start: Vector2 = _map_view.map_local_to_screen(anchor_map)
		start = Vector2(roundf(start.x), roundf(start.y))
		var count := 0
		for status: StatusData in unit.active_statuses:
			var col: int = count % BADGE_COLS
			var row: int = count / BADGE_COLS
			var top_left := Vector2(
				roundf(start.x + float(col) * step),
				roundf(start.y + float(row) * step),
			)
			_draw_badge(_drawer, top_left, badge_sz, font_px, status.type)
			count += 1


func _draw_badge(canvas: CanvasItem, top_left: Vector2, badge_sz: int, font_px: int, status_type: int) -> void:
	if _unit_layer == null:
		return
	var badge: Dictionary = _unit_layer.status_badge_style(status_type)
	var abbr: String = String(badge.get("abbr", "??"))
	var bg: Color = badge.get("bg", Color(0.3, 0.3, 0.35))
	var fg: Color = badge.get("fg", Color.WHITE)
	var rect := Rect2(top_left, Vector2(float(badge_sz), float(badge_sz)))
	canvas.draw_rect(rect, bg, true)
	canvas.draw_rect(rect, bg.lightened(0.35), false, 1.0)
	_draw_outlined_abbr(canvas, top_left, badge_sz, font_px, abbr, fg)


static func _draw_outlined_abbr(
	canvas: CanvasItem,
	top_left: Vector2,
	badge_sz: int,
	font_px: int,
	text: String,
	color: Color,
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
	var pos := Vector2(
		roundf(top_left.x + (float(badge_sz) - sz.x) * 0.5),
		roundf(top_left.y + (float(badge_sz) + sz.y) * 0.5 - 1.0),
	)
	for ox: int in [-1, 0, 1]:
		for oy: int in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			canvas.draw_string(
				font,
				pos + Vector2(float(ox), float(oy)),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_px,
				OUTLINE_COLOR,
			)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
