class_name FloatingText
extends Label

## Screen-space combat floater — crisp HD-2D UI text (not map-scaled world art).

const ACCUMULATION_DURATION: float = 0.45
## Target cap height ~= LPC head height on screen at scale 1.0 (before map zoom).
const HEAD_FONT_REF: float = 22.0
const BASE_OUTLINE: int = 3
const RISE_HEAD_FRACTION: float = 1.35

var _current_tween: Tween
var _base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08, 1.0))
	modulate.a = 1.0


func setup(canvas_pos: Vector2, text_val: String, color: Color, world_scale: float = 1.0) -> void:
	var scale_factor: float = maxf(world_scale, 1.0)
	_base_pos = Vector2(roundf(canvas_pos.x), roundf(canvas_pos.y))
	global_position = _base_pos
	text = text_val
	var font_size: int = maxi(24, roundi(HEAD_FONT_REF * scale_factor))
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override(
		"outline_size",
		maxi(3, roundi(float(BASE_OUTLINE) * scale_factor * 0.65)),
	)
	add_theme_color_override("font_color", color)
	_animate(scale_factor)


func _animate(text_scale: float) -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
	modulate.a = 1.0
	var rise: float = HEAD_FONT_REF * text_scale * RISE_HEAD_FRACTION
	var end_pos: Vector2 = _base_pos + Vector2(0.0, -rise)
	_current_tween = create_tween()
	_current_tween.tween_method(
		_set_canvas_position,
		_base_pos,
		end_pos,
		ACCUMULATION_DURATION + 0.25,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_interval(0.08)
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
	_current_tween.tween_callback(queue_free)


func _set_canvas_position(pos: Vector2) -> void:
	global_position = Vector2(roundf(pos.x), roundf(pos.y))
