class_name CharacterSelectionGlow
extends Node2D

## Pixel-accurate selection outline — duplicates each LPC layer with an outline shader behind it.

const _OUTLINE_SHADER: Shader = preload("res://shaders/pixel_sprite_outline.gdshader")

var enabled: bool = false
var glow_color: Color = Color(0.36, 0.62, 0.92, 1.0)
var _muted: bool = false
var _actor: CharacterActor
var _outline_root: Node2D
var _outline_sprites: Array[AnimatedSprite2D] = []
var _outline_material: ShaderMaterial


func _ready() -> void:
	z_as_relative = true
	z_index = -2
	visible = false
	_outline_root = Node2D.new()
	_outline_root.name = "OutlineSprites"
	add_child(_outline_root)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = _OUTLINE_SHADER


func bind_actor(actor: CharacterActor) -> void:
	_actor = actor


func is_active() -> bool:
	return enabled


func set_active(active: bool, color: Color = glow_color) -> void:
	enabled = active
	glow_color = color
	visible = active
	if active:
		rebuild_from_layers()
	else:
		_clear_outlines()
	set_process(active)


func set_muted(muted: bool) -> void:
	_muted = muted
	_update_outline_alpha()


func rebuild_from_layers() -> void:
	_clear_outlines()
	if _actor == null:
		return
	var layers: Array[AnimatedSprite2D] = _actor.get_sprite_layers()
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		var outline := AnimatedSprite2D.new()
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		outline.centered = spr.centered
		outline.position = spr.position
		outline.sprite_frames = spr.sprite_frames
		outline.animation = spr.animation
		outline.frame = spr.frame
		outline.z_as_relative = true
		outline.z_index = spr.z_index - 1
		var mat: ShaderMaterial = _outline_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("outline_color", glow_color)
		mat.set_shader_parameter("outline_alpha", 1.0)
		outline.material = mat
		_outline_root.add_child(outline)
		_outline_sprites.append(outline)
	_sync_outline_frames()
	_update_outline_alpha()


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
	var pulse: float = 0.62 + 0.38 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 100.0))
	var draw_color: Color = (
		Color(0.58, 0.58, 0.62, 1.0) if _muted else glow_color
	)
	for spr: AnimatedSprite2D in _outline_sprites:
		var mat: ShaderMaterial = spr.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("outline_color", draw_color)
			mat.set_shader_parameter("outline_alpha", pulse if not _muted else 0.85)
