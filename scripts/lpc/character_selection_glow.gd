class_name CharacterSelectionGlow
extends Node

## Pixel-accurate selection outline — duplicate layers drawn ON TOP so the ring is visible.

const _OUTLINE_SHADER: Shader = preload("res://shaders/pixel_sprite_outline.gdshader")

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
	var layer_idx: int = 0
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		var outline := AnimatedSprite2D.new()
		outline.name = "SelOutline_%d" % layer_idx
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		outline.centered = spr.centered
		outline.position = spr.position
		outline.sprite_frames = spr.sprite_frames
		outline.animation = spr.animation
		outline.frame = spr.frame
		outline.z_as_relative = false
		outline.z_index = 120 + layer_idx
		outline.show_behind_parent = false
		var mat: ShaderMaterial = _outline_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("outline_color", _draw_color())
		mat.set_shader_parameter("outline_alpha", 1.0)
		mat.set_shader_parameter("outline_px", 3)
		outline.material = mat
		_actor.add_child(outline)
		_actor.move_child(outline, -1)
		_outline_sprites.append(outline)
		layer_idx += 1
	_sync_outline_frames()
	_update_outline_alpha()


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
	_update_outline_alpha()


func _sync_outline_frames() -> void:
	if _actor == null:
		return
	var layers: Array[AnimatedSprite2D] = _actor.get_sprite_layers()
	var outline_idx: int = 0
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		if outline_idx >= _outline_sprites.size():
			break
		var outline: AnimatedSprite2D = _outline_sprites[outline_idx]
		outline.animation = spr.animation
		outline.frame = spr.frame
		outline.position = spr.position
		outline.visible = spr.visible
		outline_idx += 1


func _update_outline_alpha() -> void:
	var draw_color: Color = _draw_color()
	var alpha: float = 0.92 if not _muted else 0.80
	for spr: AnimatedSprite2D in _outline_sprites:
		var mat: ShaderMaterial = spr.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("outline_color", draw_color)
			mat.set_shader_parameter("outline_alpha", alpha)
