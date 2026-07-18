class_name CharacterContactShadow
extends Node2D

## Oblique contact shadow bake for LPC actors — ground display is unified in GroundShadows only.

const _LPC = preload("res://scripts/lpc/lpc_constants.gd")
const FOOT_LOCAL_Y: float = 0.0

var _caster: Image
var _foot_center_tex: Vector2 = Vector2.ZERO
var _silhouette_version: int = 0


func _ready() -> void:
	visible = false
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = true
	z_index = -1
	_purge_legacy_shadow_sprite()


func rebuild_silhouette(layers: Array[AnimatedSprite2D], anim: StringName) -> void:
	_caster = _composite_layers(layers, anim)
	if _caster == null:
		_foot_center_tex = Vector2.ZERO
		return
	_foot_center_tex = ShadowPlacer.foot_center_from_image(_caster)
	_silhouette_version += 1
	ShadowPlacer.reset_actor_bake_key()


func sync(settings: EffectsSettings = null) -> void:
	var actor: Node2D = get_parent() as Node2D
	if actor == null:
		return
	if settings == null or not settings.oblique_contact_shadows or _caster == null:
		ShadowPlacer.clear_actor_foot_bake(actor)
		return
	ShadowPlacer.sync_actor_contact_shadow(
		actor,
		_caster,
		_foot_center_tex,
		Vector2(0.0, FOOT_LOCAL_Y),
		_silhouette_version,
		settings,
	)


func get_shadow_sprite() -> Sprite2D:
	return null


func _purge_legacy_shadow_sprite() -> void:
	for child: Node in get_children():
		if child is Sprite2D and str(child.name) == "ShadowSprite":
			var spr: Sprite2D = child as Sprite2D
			spr.visible = false
			spr.material = null
			spr.texture = null
			spr.queue_free()


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
