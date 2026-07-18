class_name CharacterSelectionGlow
extends Node

## Selection glow — dual outline behind each LPC layer (soft outer + crisp inner).

const _OUTLINE_SHADER: Shader = preload("res://shaders/pixel_sprite_outline.gdshader")
const _OUTLINE_INNER_PX: int = 2
const _OUTLINE_OUTER_PX: int = 4
const _OUTLINE_OUTER_ALPHA: float = 0.42

var enabled: bool = false
var glow_color: Color = Color(0.36, 0.62, 0.92, 1.0)
var _muted: bool = false
var _actor: CharacterActor
var _outline_sprites: Array[AnimatedSprite2D] = []
var _outline_material: ShaderMaterial


func bind_actor(actor: CharacterActor) -> void:
	_actor = actor
	_ensure_material()


func is_active() -> bool:
	return enabled


func set_active(active: bool, color: Color = glow_color) -> void:
	enabled = active
	glow_color = color
	if active:
		rebuild_from_layers()
	else:
		_clear_outlines()
	set_process(active)


func set_muted(muted: bool) -> void:
	_muted = muted
	_update_outline_alpha()


func rebuild_from_layers() -> void:
	_ensure_material()
	_clear_outlines()
	if _actor == null or not enabled:
		return
	var layers: Array[AnimatedSprite2D] = _actor.get_sprite_layers()
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		var outer := _make_outline_sprite(spr, _OUTLINE_OUTER_PX, _OUTLINE_OUTER_ALPHA)
		var inner := _make_outline_sprite(spr, _OUTLINE_INNER_PX, 1.0)
		spr.add_child(outer)
		spr.add_child(inner)
		spr.move_child(outer, 0)
		spr.move_child(inner, 1)
		_outline_sprites.append(outer)
		_outline_sprites.append(inner)
	_sync_outline_frames()
	_update_outline_alpha()


func _make_outline_sprite(layer: AnimatedSprite2D, outline_px: int, alpha: float) -> AnimatedSprite2D:
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
	var mat: ShaderMaterial = _outline_material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("outline_color", _draw_color())
	mat.set_shader_parameter("outline_alpha", alpha)
	mat.set_shader_parameter("outline_px", outline_px)
	outline.material = mat
	return outline


func _ensure_material() -> void:
	if _outline_material != null:
		return
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = _OUTLINE_SHADER


func _draw_color() -> Color:
	if _muted:
		return Color(0.55, 0.55, 0.60, 1.0)
	return glow_color


func _clear_outlines() -> void:
	for spr: AnimatedSprite2D in _outline_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	_outline_sprites.clear()


func _process(_delta: float) -> void:
	if not enabled:
		return
	_sync_outline_frames()


func _sync_outline_frames() -> void:
	if _actor == null:
		return
	var layers: Array[AnimatedSprite2D] = _actor.get_sprite_layers()
	var outline_idx: int = 0
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		for _pass: int in 2:
			if outline_idx >= _outline_sprites.size():
				return
			var outline: AnimatedSprite2D = _outline_sprites[outline_idx]
			if outline.get_parent() == spr:
				if outline.animation == spr.animation and outline.frame == spr.frame and outline.visible == spr.visible:
					outline_idx += 1
					continue
				outline.animation = spr.animation
				outline.frame = spr.frame
				outline.visible = spr.visible
			outline_idx += 1


func _update_outline_alpha() -> void:
	var draw_color: Color = _draw_color()
	var inner_alpha: float = 1.0 if not _muted else 0.85
	var outer_alpha: float = _OUTLINE_OUTER_ALPHA if not _muted else _OUTLINE_OUTER_ALPHA * 0.75
	var outline_idx: int = 0
	while outline_idx < _outline_sprites.size():
		var outer: AnimatedSprite2D = _outline_sprites[outline_idx]
		var inner: AnimatedSprite2D = _outline_sprites[outline_idx + 1] if outline_idx + 1 < _outline_sprites.size() else null
		var outer_mat: ShaderMaterial = outer.material as ShaderMaterial
		if outer_mat != null:
			outer_mat.set_shader_parameter("outline_color", draw_color)
			outer_mat.set_shader_parameter("outline_alpha", outer_alpha)
		if inner != null:
			var inner_mat: ShaderMaterial = inner.material as ShaderMaterial
			if inner_mat != null:
				inner_mat.set_shader_parameter("outline_color", draw_color)
				inner_mat.set_shader_parameter("outline_alpha", inner_alpha)
		outline_idx += 2
