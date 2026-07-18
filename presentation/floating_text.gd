class_name FloatingText
extends Label

## Pixel-art friendly combat floater — snaps to whole pixels, minimal bounce.

const ACCUMULATION_DURATION: float = 0.45
const BASE_FONT_SIZE: int = 8
const BASE_OUTLINE: int = 2

var _accumulated_damage: int = 0
var _current_tween: Tween
var _base_pos: Vector2 = Vector2.ZERO
var _ui_scale: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set("theme_override_colors/font_outline_color", Color(0.05, 0.02, 0.08, 1.0))
	modulate.a = 1.0
	scale = Vector2.ZERO


func setup(pos: Vector2, text_val: String, color: Color, ui_scale: float = 1.0) -> void:
	_ui_scale = maxf(ui_scale, 0.5)
	_base_pos = Vector2(roundf(pos.x), roundf(pos.y))
	position = _base_pos
	text = text_val
	var font_size: int = maxi(6, roundi(float(BASE_FONT_SIZE) * _ui_scale))
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("outline_size", maxi(1, roundi(float(BASE_OUTLINE) * _ui_scale)))
	add_theme_color_override("font_color", color)
	_accumulated_damage = text_val.to_int()
	_animate()


func _animate() -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
	scale = Vector2(0.75, 0.75)
	modulate.a = 1.0
	position = _base_pos
	var rise: float = 14.0 * _ui_scale
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	_current_tween.tween_property(
		self,
		"position",
		_base_pos + Vector2(0.0, -rise),
		ACCUMULATION_DURATION + 0.25,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	_current_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_LINEAR)
	_current_tween.set_parallel(false)
	_current_tween.tween_interval(ACCUMULATION_DURATION)
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	_current_tween.tween_callback(queue_free)
