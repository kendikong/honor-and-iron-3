class_name CharacterSelectionGlow
extends Node2D

## Pulsing rect outline drawn on top of LPC layers for unit selection.

var enabled: bool = false
var glow_color: Color = Color(0.36, 0.62, 0.92, 1.0)
var sprite_bounds: Rect2 = Rect2(Vector2(-30.0, -58.0), Vector2(60.0, 62.0))


func _ready() -> void:
	z_as_relative = true
	z_index = 250
	visible = false


func set_active(active: bool, color: Color = glow_color) -> void:
	enabled = active
	glow_color = color
	visible = active
	if active:
		queue_redraw()


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var pulse: float = 0.62 + 0.38 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 100.0))
	var core := Color(glow_color.r, glow_color.g, glow_color.b, pulse)
	var mid := Color(core.r, core.g, core.b, core.a * 0.55)
	var outer := Color(core.r, core.g, core.b, core.a * 0.22)
	draw_rect(sprite_bounds.grow(7.0), outer, false, 6.0)
	draw_rect(sprite_bounds.grow(4.0), mid, false, 4.0)
	draw_rect(sprite_bounds.grow(1.5), core, false, 2.5)
