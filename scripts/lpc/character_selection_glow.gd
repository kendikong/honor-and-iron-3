class_name CharacterSelectionGlow
extends Node

## Selection glow — one outline child per LPC layer (dual ring via pixel_sprite_outline.gdshader).
## Main sprite materials are untouched so character colors stay correct.

const _OUTLINE_SHADER: Shader = preload("res://shaders/pixel_sprite_outline.gdshader")
const _OUTLINE_OUTER_ALPHA: float = 0.42

enum GlowStrength {
	HOVER,
	SELECTED,
}

var enabled: bool = false
var glow_color: Color = Color(0.36, 0.62, 0.92, 1.0)
var _strength: GlowStrength = GlowStrength.SELECTED
var _muted: bool = false
var _actor: CharacterActor
var _outline_sprites: Array[AnimatedSprite2D] = []
var _layer_to_outline: Dictionary = {}
var _layer_frame_handlers: Dictionary = {}
var _layer_anim_handlers: Dictionary = {}
var _outline_material: ShaderMaterial


func bind_actor(actor: CharacterActor) -> void:
	_actor = actor
	_ensure_material()
	set_process(false)


func is_active() -> bool:
	return enabled


func is_outline_empty() -> bool:
	return _outline_sprites.is_empty()


func set_glow(
	active: bool,
	color: Color = glow_color,
	strength: GlowStrength = GlowStrength.SELECTED,
) -> void:
	var color_changed: bool = glow_color != color
	var strength_changed: bool = _strength != strength
	glow_color = color
	_strength = strength
	if active:
		enabled = true
		_apply_strength_params()
		if _outline_sprites.is_empty() or not _outlines_match_layers():
			rebuild_from_layers()
		else:
			_reconnect_layer_signals()
			for spr: AnimatedSprite2D in _actor.get_sprite_layers():
				_sync_outline_for_layer(spr)
			_set_outlines_visible(true)
			if color_changed or strength_changed:
				_update_outline_alpha()
		set_process(_strength == GlowStrength.SELECTED)
	else:
		if not enabled:
			return
		enabled = false
		set_process(false)
		_disconnect_layer_signals()
		_set_outlines_visible(false)


func set_active(active: bool, color: Color = glow_color) -> void:
	set_glow(active, color, GlowStrength.SELECTED)


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_update_outline_alpha()


func _process(_delta: float) -> void:
	if not enabled or _strength != GlowStrength.SELECTED or _muted:
		return
	var pulse: float = 0.82 + 0.18 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0))
	_apply_strength_params(pulse)


func rebuild_from_layers() -> void:
	_ensure_material()
	_clear_outlines()
	if _actor == null or not enabled:
		return
	for spr: AnimatedSprite2D in _actor.get_sprite_layers():
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		var outline := _make_outline_sprite(spr)
		spr.add_child(outline)
		spr.move_child(outline, 0)
		_outline_sprites.append(outline)
		_layer_to_outline[spr] = outline
		_connect_layer_signals(spr)
		_sync_outline_for_layer(spr)
	_update_outline_alpha()


func on_layer_added(layer: AnimatedSprite2D) -> void:
	if not enabled or layer == null:
		return
	if _layer_to_outline.has(layer):
		return
	var outline := _make_outline_sprite(layer)
	layer.add_child(outline)
	layer.move_child(outline, 0)
	_outline_sprites.append(outline)
	_layer_to_outline[layer] = outline
	_connect_layer_signals(layer)
	_sync_outline_for_layer(layer)
	_update_outline_alpha()


func on_layers_cleared() -> void:
	_clear_outlines()


func _connect_layer_signals(layer: AnimatedSprite2D) -> void:
	if layer == null or _layer_frame_handlers.has(layer):
		return
	var frame_handler := _on_layer_frame_changed.bind(layer)
	var anim_handler := _on_layer_animation_changed.bind(layer)
	_layer_frame_handlers[layer] = frame_handler
	_layer_anim_handlers[layer] = anim_handler
	layer.frame_changed.connect(frame_handler)
	layer.animation_changed.connect(anim_handler)


func _make_outline_sprite(layer: AnimatedSprite2D) -> AnimatedSprite2D:
	var outline := AnimatedSprite2D.new()
	outline.name = "SelOutline"
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.centered = layer.centered
	outline.position = Vector2.ZERO
	outline.sprite_frames = layer.sprite_frames
	outline.animation = layer.animation
	outline.frame = layer.frame
	outline.z_as_relative = true
	outline.z_index = -1
	outline.self_modulate = Color.WHITE
	outline.material = _outline_material
	return outline


func _ensure_material() -> void:
	if _outline_material != null:
		return
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = _OUTLINE_SHADER
	_outline_material.set_shader_parameter("inner_px", 2)
	_outline_material.set_shader_parameter("outer_px", 4)
	_update_outline_alpha()


func _draw_color() -> Color:
	if _muted:
		return Color(0.55, 0.55, 0.60, 1.0)
	return glow_color


func _clear_outlines() -> void:
	_disconnect_layer_signals()
	for spr: AnimatedSprite2D in _outline_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	_outline_sprites.clear()
	_layer_to_outline.clear()


func _disconnect_layer_signals() -> void:
	for layer: Variant in _layer_frame_handlers.keys():
		var spr: AnimatedSprite2D = layer as AnimatedSprite2D
		if spr == null or not is_instance_valid(spr):
			continue
		var frame_handler: Callable = _layer_frame_handlers[layer]
		var anim_handler: Callable = _layer_anim_handlers.get(layer)
		if spr.frame_changed.is_connected(frame_handler):
			spr.frame_changed.disconnect(frame_handler)
		if anim_handler != null and spr.animation_changed.is_connected(anim_handler):
			spr.animation_changed.disconnect(anim_handler)
	_layer_frame_handlers.clear()
	_layer_anim_handlers.clear()


func _reconnect_layer_signals() -> void:
	if _actor == null:
		return
	for spr: AnimatedSprite2D in _actor.get_sprite_layers():
		if spr != null and spr.visible and spr.sprite_frames != null:
			_connect_layer_signals(spr)


func _set_outlines_visible(visible: bool) -> void:
	for spr: AnimatedSprite2D in _outline_sprites:
		if is_instance_valid(spr):
			spr.visible = visible


func _outlines_match_layers() -> bool:
	if _actor == null:
		return false
	var expected: int = 0
	for spr: AnimatedSprite2D in _actor.get_sprite_layers():
		if spr != null and spr.visible and spr.sprite_frames != null:
			expected += 1
	return expected > 0 and expected == _outline_sprites.size()


func _on_layer_frame_changed(layer: AnimatedSprite2D) -> void:
	_sync_outline_for_layer(layer)


func _on_layer_animation_changed(layer: AnimatedSprite2D) -> void:
	_sync_outline_for_layer(layer)


func _sync_outline_for_layer(layer: AnimatedSprite2D) -> void:
	if layer == null:
		return
	var outline: AnimatedSprite2D = _layer_to_outline.get(layer) as AnimatedSprite2D
	if outline == null or not is_instance_valid(outline):
		return
	outline.animation = layer.animation
	outline.frame = layer.frame
	outline.visible = layer.visible


func _update_outline_alpha() -> void:
	if _outline_material == null:
		return
	_apply_strength_params(1.0)


func _apply_strength_params(pulse_scale: float = 1.0) -> void:
	if _outline_material == null:
		return
	var inner_px: int = 2
	var outer_px: int = 3
	var inner_a: float = 0.72
	var outer_a: float = 0.28
	match _strength:
		GlowStrength.HOVER:
			inner_px = 2
			outer_px = 3
			inner_a = 0.72 if not _muted else 0.62
			outer_a = 0.28 if not _muted else 0.20
		GlowStrength.SELECTED:
			inner_px = 2
			outer_px = 5
			inner_a = 1.0 if not _muted else 0.85
			outer_a = 0.62 if not _muted else 0.48
	_outline_material.set_shader_parameter("inner_px", inner_px)
	_outline_material.set_shader_parameter("outer_px", outer_px)
	var draw_color: Color = _draw_color()
	_outline_material.set_shader_parameter("outline_color", draw_color)
	_outline_material.set_shader_parameter("inner_alpha", inner_a)
	_outline_material.set_shader_parameter("outer_alpha", outer_a * pulse_scale)
