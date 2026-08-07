class_name CharacterContactShadow
extends Node2D

## Oblique multiply contact shadow for LPC actor â€” bake target; display is unified on GroundShadows.

const _LPC = preload("res://scripts/lpc/lpc_constants.gd")
const FOOT_LOCAL_Y: float = 0.0

var _sprite: Sprite2D
var _caster: Image
var _foot_center_tex: Vector2 = Vector2.ZERO
var _silhouette_version: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = true
	z_index = -1
	_sprite = Sprite2D.new()
	_sprite.name = "ShadowSprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_as_relative = true
	_sprite.z_index = 0
	_sprite.visible = false
	_sprite.material = ShadowPlacer.duplicate_shadow_material()
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("has_map_oblique", 0.0)
	add_child(_sprite)


func rebuild_silhouette(layers: Array[AnimatedSprite2D], anim: StringName) -> void:
	_caster = _composite_layers(layers, anim)
	if _caster == null:
		_foot_center_tex = Vector2.ZERO
		_sprite.visible = false
		_sprite.texture = null
		return
	_foot_center_tex = ShadowPlacer.foot_center_from_image(_caster)
	_silhouette_version += 1
	ShadowPlacer.reset_actor_bake_key()


func sync(settings: EffectsSettings = null) -> void:
	if _sprite == null:
		return
	if settings == null or not settings.oblique_contact_shadows or _caster == null:
		_sprite.visible = false
		_sprite.texture = null
		return
	ShadowPlacer.sync_actor_contact_shadow(
		_sprite,
		_caster,
		_foot_center_tex,
		Vector2(0.0, FOOT_LOCAL_Y),
		_silhouette_version,
		settings,
		get_parent() as Node2D,
	)


func get_shadow_sprite() -> Sprite2D:
	return _sprite


func _composite_layers(layers: Array[AnimatedSprite2D], anim: StringName) -> Image:
	if layers.is_empty():
		return null
	var frame_size: int = _LPC.FRAME_SIZE
	var out: Image = Image.create(frame_size, frame_size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	var drew: bool = false
	for spr: AnimatedSprite2D in layers:
		if spr == null or not spr.visible or spr.sprite_frames == null:
			continue
		var use_anim: StringName = anim
		if not spr.sprite_frames.has_animation(use_anim):
			use_anim = spr.animation
		if not spr.sprite_frames.has_animation(use_anim):
			continue
		var frame_idx: int = spr.frame
		if frame_idx < 0 or frame_idx >= spr.sprite_frames.get_frame_count(use_anim):
			frame_idx = 0
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(use_anim, frame_idx)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var w: int = mini(img.get_width(), frame_size)
		var h: int = mini(img.get_height(), frame_size)
		for y: int in range(h):
			for x: int in range(w):
				var a: float = img.get_pixel(x, y).a
				if a < 0.04:
					continue
				var prev: float = out.get_pixel(x, y).a
				out.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(prev, a)))
				drew = true
	if not drew:
		return null
	return out
