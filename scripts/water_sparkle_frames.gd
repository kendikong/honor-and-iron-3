class_name WaterSparkleFrames
extends RefCounted

## Builds SpriteFrames from gentle water sparkles A v01â€“v03 (3Ã—3-frame rows).

const _C = preload("res://scripts/mana_seed_constants.gd")
const FRAME_SEC: float = 0.2

static var _cache: Dictionary = {}


static func get_frames(variant: int = 1) -> SpriteFrames:
	var v: int = clampi(variant, _C.MIN_TILESET_VARIANT, _C.MAX_TILESET_VARIANT)
	if _cache.has(v):
		return _cache[v]
	var png_path: String = _C.ASSET_ROOT + "gentle animations/gentle water sparkles A %s.png" % _C.variant_suffix(v)
	var texture: Texture2D = load(png_path)
	if texture == null:
		push_error("WaterSparkleFrames: missing %s" % png_path)
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	_build_row(frames, "full", texture, 0)
	_build_row(frames, "diag", texture, 1)
	_build_row(frames, "quarter", texture, 2)
	_cache[v] = frames
	return frames


static func clear_cache() -> void:
	_cache.clear()


static func anim_for_atlas(atlas: Vector2i) -> StringName:
	if atlas.y >= 2:
		return &"quarter"
	if atlas.y == 1:
		return &"diag"
	return &"full"


static func _build_row(frames: SpriteFrames, anim: StringName, texture: Texture2D, row: int) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	for col: int in range(3):
		var atlas_tex: AtlasTexture = AtlasTexture.new()
		atlas_tex.atlas = texture
		atlas_tex.region = Rect2(col * 16, row * 16, 16, 16)
		frames.add_frame(anim, atlas_tex, FRAME_SEC)
	frames.set_animation_speed(anim, 1.0)
