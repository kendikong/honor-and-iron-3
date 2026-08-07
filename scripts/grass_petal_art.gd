class_name GrassPetalArt
extends RefCounted

## Pixel Pete 3-line blades â€” graduated bend: bottom 3 rows still, then +1 / +2 px.

enum Variant { THREE_LINE, V_SHAPE }

const TILE_PX: int = 16
const ANIM_FPS: float = 1.5
const SWAY_PAD_PX: int = 2
const _SWAY_DIRECTIONS: Array[int] = [0, 1, 0, -1]
## rows_from_bottom (0 = bottom) â†’ px at full sway. 6-row blades after +1 height.
const _SWAY_PX_FROM_BOTTOM: Array[int] = [0, 0, 0, 1, 2, 2]

static var _cache: Dictionary = {}

const _PALETTES: Array[Dictionary] = [
	{
		"base": Color(0.30, 0.48, 0.18, 1.0),
		"d": Color(0.22, 0.36, 0.12, 1.0),
		"m": Color(0.40, 0.60, 0.24, 1.0),
		"g": Color(0.44, 0.64, 0.28, 1.0),
		"h": Color(0.54, 0.76, 0.34, 1.0),
	},
	{
		"base": Color(0.28, 0.46, 0.16, 1.0),
		"d": Color(0.20, 0.34, 0.10, 1.0),
		"m": Color(0.38, 0.58, 0.22, 1.0),
		"g": Color(0.42, 0.62, 0.26, 1.0),
		"h": Color(0.52, 0.74, 0.32, 1.0),
	},
]


static func cluster_frames(variant_idx: int) -> SpriteFrames:
	var variant: Variant = variant_idx as Variant
	var key: String = "pete_v2_%d" % variant
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	var palette: Dictionary = _palette_for_variant(variant_idx)
	var built: SpriteFrames = _build_blade(variant, palette)
	_cache[key] = built
	return built


static func base_fill_texture(variant_idx: int) -> Texture2D:
	var palette: Dictionary = _palette_for_variant(variant_idx)
	var img: Image = Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
	img.fill(palette["base"] as Color)
	return ImageTexture.create_from_image(img)


static func cluster_placements(variant_idx: int) -> Array[Vector2]:
	if variant_idx == Variant.V_SHAPE:
		return [
			Vector2(-5.0, -2.0),
			Vector2(0.0, -4.0),
			Vector2(4.0, -1.0),
			Vector2(-3.0, 2.0),
			Vector2(2.0, 3.0),
			Vector2(5.0, 2.0),
			Vector2(-1.0, 0.0),
		]
	return [
		Vector2(-5.0, -1.0),
		Vector2(-2.0, -4.0),
		Vector2(2.0, -3.0),
		Vector2(4.0, 1.0),
		Vector2(-4.0, 3.0),
		Vector2(0.0, 2.0),
		Vector2(3.0, 4.0),
	]


static func _palette_for_variant(variant_idx: int) -> Dictionary:
	return _PALETTES[clampi(variant_idx, 0, _PALETTES.size() - 1)]


static func _build_blade(variant: Variant, palette: Dictionary) -> SpriteFrames:
	match variant:
		Variant.THREE_LINE:
			return _sway_frames_graduated(
				PackedStringArray([".h.", ".m.", ".m.", "m.m", "d.d", "..."]),
				palette,
				&"sway",
			)
		Variant.V_SHAPE:
			return _sway_frames_graduated(
				PackedStringArray(["..h..", "..m..", "m . m", ".g.g.", ".d.d.", "....."]),
				palette,
				&"sway",
			)
	return SpriteFrames.new()


static func _sway_frames_graduated(
	rows: PackedStringArray,
	palette: Dictionary,
	anim: StringName,
) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	frames.set_animation_speed(anim, ANIM_FPS)
	for direction: int in _SWAY_DIRECTIONS:
		frames.add_frame(anim, _composite_graduated(rows, palette, direction))
	return frames


## Sway table (rows from bottom on 6-row blade):
## 1stâ€“3rd still | 4th +1 px | 5th +2 px | 6th tip +2 px
static func _composite_graduated(
	rows: PackedStringArray,
	palette: Dictionary,
	direction: int,
) -> Texture2D:
	var row_count: int = rows.size()
	var content_w: int = _row_block_width(rows)
	var img_w: int = content_w + SWAY_PAD_PX * 2
	var img_h: int = row_count
	var img: Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var x_center: int = SWAY_PAD_PX + _center_offset(content_w, content_w)
	for y: int in range(row_count):
		var rows_from_bottom: int = (row_count - 1) - y
		var row_shift: int = _row_sway_px(rows_from_bottom) * direction
		_stamp_row(img, rows[y], palette, x_center + row_shift, y)

	return ImageTexture.create_from_image(img)


static func _row_sway_px(rows_from_bottom: int) -> int:
	if rows_from_bottom < 0:
		return 0
	if rows_from_bottom >= _SWAY_PX_FROM_BOTTOM.size():
		return _SWAY_PX_FROM_BOTTOM[_SWAY_PX_FROM_BOTTOM.size() - 1]
	return _SWAY_PX_FROM_BOTTOM[rows_from_bottom]


static func _row_block_width(rows: PackedStringArray) -> int:
	var w: int = 0
	for row: String in rows:
		w = maxi(w, row.length())
	return w


static func _center_offset(content_w: int, block_w: int) -> int:
	return int((content_w - block_w) * 0.5)


static func _stamp_row(
	img: Image,
	row: String,
	palette: Dictionary,
	x0: int,
	y0: int,
) -> void:
	for x: int in range(row.length()):
		var ch: String = row.substr(x, 1)
		if ch == "." or ch == " ":
			continue
		var px: int = x0 + x
		var py: int = y0
		if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
			continue
		var tint: Color = palette.get(ch, Color.WHITE) as Color
		img.set_pixel(px, py, tint)
