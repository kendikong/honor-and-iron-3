class_name FloatingText
extends Label

const ACCUMULATION_DURATION: float = 0.4

var _accumulated_damage: int = 0
var _current_tween: Tween
var _base_pos: Vector2

func _ready() -> void:
	# Base styling for a punchy look
	set("theme_override_colors/font_outline_color", Color.BLACK)
	set("theme_override_constants/outline_size", 4)
	
	# Initial settings
	scale = Vector2.ZERO
	modulate.a = 1.0

func setup(pos: Vector2, text_val: String, color: Color) -> void:
	_base_pos = pos
	position = pos
	text = text_val
	set("theme_override_colors/font_color", color)
	
	_accumulated_damage = text_val.to_int()
	_animate()

func _animate() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		
	# Reset scale and position slightly for the pop
	scale = Vector2(0.5, 0.5)
	modulate.a = 1.0
	position = _base_pos
		
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	# Pop effect
	_current_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Drift upwards
	_current_tween.tween_property(self, "position", _base_pos + Vector2(0, -30), ACCUMULATION_DURATION + 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Shrink back to normal
	_current_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	
	# Fade out
	_current_tween.set_parallel(false)
	_current_tween.tween_interval(ACCUMULATION_DURATION)
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	
	_current_tween.tween_callback(queue_free)
