class_name EcologyActorArt
extends RefCounted

## Procedural 8â€“12 px ecology actor silhouettes + 2-frame flap loops (nearest).

static var _cache: Dictionary = {}


static func butterfly_frames(variant: int = 0) -> SpriteFrames:
	var idx: int = clampi(variant, 0, _BUTTERFLY_PALETTES.size() - 1)
	return _get_frames("butterfly_front_v5_%d" % idx, func() -> SpriteFrames:
		return _build_butterfly(idx)
	)


static func butterfly_variant_count() -> int:
	return _BUTTERFLY_PALETTES.size()


const _BUTTERFLY_PALETTES: Array = [
	{
		"wing": Color(0.88, 0.42, 0.72, 1.0),
		"hi": Color(0.96, 0.58, 0.82, 1.0),
		"tip": Color(0.98, 0.66, 0.86, 1.0),
		"body": Color(0.88, 0.42, 0.72, 0.28),
	},
	{
		"wing": Color(0.94, 0.70, 0.24, 1.0),
		"hi": Color(0.98, 0.82, 0.42, 1.0),
		"tip": Color(1.0, 0.88, 0.52, 1.0),
		"body": Color(0.94, 0.70, 0.24, 0.28),
	},
	{
		"wing": Color(0.46, 0.72, 0.94, 1.0),
		"hi": Color(0.62, 0.84, 0.98, 1.0),
		"tip": Color(0.74, 0.90, 1.0, 1.0),
		"body": Color(0.46, 0.72, 0.94, 0.28),
	},
]


static func bird_frames() -> SpriteFrames:
	return _get_frames("bird", _build_bird)


static func leaf_frames() -> SpriteFrames:
	return _get_frames("leaf", _build_leaf)


static func frog_frames() -> SpriteFrames:
	return _get_frames("frog_v2", _build_frog)


static func fish_frames() -> SpriteFrames:
	return _get_frames("fish_v10", _build_fish)


static func _build_fish() -> SpriteFrames:
	# Deep interior water (#180) â€” dark blue silhouette.
	var silhouette: Color = Color(0.06, 0.13, 0.24, 0.90)
	var palette: Dictionary = {"b": silhouette}
	const BODY_W: int = 12
	const BODY_H: int = 4
	const FRAME_COUNT: int = 6
	const WAVE_FPS: float = 5.0
	var h_patterns: Array = []
	for i: int in range(FRAME_COUNT):
		var phase: float = (float(i) / float(FRAME_COUNT)) * TAU
		h_patterns.append(_fish_swim_pattern(BODY_W, BODY_H, phase))
	var frames: SpriteFrames = SpriteFrames.new()
	_populate_wave_anim(frames, &"swim_h", WAVE_FPS, h_patterns, palette)
	var v_patterns: Array = []
	for pat: Variant in h_patterns:
		v_patterns.append(_transpose_pattern(pat as PackedStringArray))
	_populate_wave_anim(frames, &"swim_v", WAVE_FPS, v_patterns, palette)
	return frames


## Single gentle arch â€” chunky top-down fish body, not a worm line.
static func _fish_swim_pattern(w: int, h: int, phase: float) -> PackedStringArray:
	var rows: Array[String] = []
	for _y: int in range(h):
		rows.append(".".repeat(w))
	var mid: float = (float(h) - 1.0) * 0.5
	const AMP: float = 0.65
	for x: int in range(w):
		var t: float = float(x) / float(maxi(w - 1, 1))
		var cy: int = clampi(int(round(mid + sin(t * PI + phase) * AMP)), 1, h - 2)
		var half: int = 1
		if t < 0.10 or t > 0.90:
			half = 0
		elif t < 0.18 or t > 0.82:
			half = 0 if absf(sin(t * PI + phase)) > 0.55 else 1
		for dy: int in range(-half, half + 1):
			var py: int = cy + dy
			if py < 0 or py >= h:
				continue
			var row: String = rows[py]
			rows[py] = row.substr(0, x) + "b" + row.substr(x + 1)
	return PackedStringArray(rows)


static func _populate_wave_anim(
	frames: SpriteFrames,
	anim: StringName,
	fps: float,
	patterns: Array,
	palette: Dictionary,
) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	frames.set_animation_speed(anim, fps)
	for pat: Variant in patterns:
		frames.add_frame(anim, _pattern(pat as PackedStringArray, palette))


static func _transpose_pattern(rows: PackedStringArray) -> PackedStringArray:
	var h: int = rows.size()
	var w: int = rows[0].length()
	var out: PackedStringArray = PackedStringArray()
	for x: int in range(w):
		var row: String = ""
		for y: int in range(h):
			var src: String = rows[y]
			row += src.substr(x, 1) if x < src.length() else "."
		out.append(row)
	return out


static func _build_frog() -> SpriteFrames:
	var body: Color = Color(0.34, 0.68, 0.30, 1.0)
	var belly: Color = Color(0.52, 0.82, 0.38, 1.0)
	var leg: Color = Color(0.24, 0.52, 0.22, 1.0)
	var eye: Color = Color(0.12, 0.14, 0.10, 1.0)
	var idle: PackedStringArray = PackedStringArray([
		"..e.e.",
		".gggg.",
		"ggbbgg",
		".gggg.",
		"..gg..",
		"......",
	])
	var hop: PackedStringArray = PackedStringArray([
		"..e.e.",
		".g..g.",
		".bbbb.",
		"gg..gg",
		"ll..ll",
		".llll.",
	])
	var palette: Dictionary = {"g": body, "b": belly, "l": leg, "e": eye}
	return _two_anim(
		&"idle",
		&"hop",
		_pattern(idle, palette),
		_pattern(hop, palette),
	)


static func _two_anim(anim_a: StringName, anim_b: StringName, a: Texture2D, b: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(anim_a):
		frames.add_animation(anim_a)
	frames.set_animation_loop(anim_a, true)
	frames.add_frame(anim_a, a)
	if not frames.has_animation(anim_b):
		frames.add_animation(anim_b)
	frames.set_animation_loop(anim_b, false)
	frames.add_frame(anim_b, b)
	return frames


static func _get_frames(key: String, builder: Callable) -> SpriteFrames:
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	var frames: SpriteFrames = builder.call()
	_cache[key] = frames
	return frames


static func _build_butterfly(variant: int) -> SpriteFrames:
	var pack: Dictionary = _BUTTERFLY_PALETTES[variant]
	var body: Color = pack["body"] as Color
	var wing: Color = pack["wing"] as Color
	var wing_hi: Color = pack["hi"] as Color
	var wing_tip: Color = pack["tip"] as Color
	# 6Ã—5 front view â€” same lobe/tip read, one column tighter than v3.
	var open: PackedStringArray = PackedStringArray([
		".T..T.",
		"wAw.wA",
		".wwbww",
		".wAwA.",
		".T..T.",
	])
	var flap_up: PackedStringArray = PackedStringArray([
		"..T.T.",
		".wAw..",
		".wb.w.",
		".wAw..",
		"..T.T.",
	])
	var palette: Dictionary = {"w": wing, "A": wing_hi, "T": wing_tip, "b": body}
	return _two_frame_loop("flap", 9.0, _pattern(open, palette), _pattern(flap_up, palette))


static func _build_bird() -> SpriteFrames:
	var body: Color = Color(0.28, 0.24, 0.32, 1.0)
	var wing: Color = Color(0.42, 0.38, 0.48, 1.0)
	var beak: Color = Color(0.62, 0.48, 0.28, 1.0)
	var up: PackedStringArray = PackedStringArray([
		"...bbb>>...",
		"..bbWWbb...",
		".bbbWWbbb..",
		"..bbWWbb...",
		"...bbb.....",
	])
	var down: PackedStringArray = PackedStringArray([
		"...bbb.....",
		"...bbbb....",
		"..bbbbbb...",
		"...bbbb....",
		"...bbb.....",
	])
	var palette: Dictionary = {"b": body, "W": wing, ">": beak}
	return _two_frame_loop("flap", 8.0, _pattern(up, palette), _pattern(down, palette))


static func _build_leaf() -> SpriteFrames:
	var leaf: Color = Color(0.38, 0.66, 0.28, 1.0)
	var vein: Color = Color(0.28, 0.52, 0.18, 1.0)
	var tilt_a: PackedStringArray = PackedStringArray([
		"...gg.....",
		"..gggg....",
		".gggggg...",
		"..gggg....",
		"...ggg....",
		"....g.....",
	])
	var tilt_b: PackedStringArray = PackedStringArray([
		".....gg...",
		"....gggg..",
		"...gggggg.",
		"....gggg..",
		".....ggg..",
		"......g...",
	])
	var palette: Dictionary = {"g": leaf, "G": vein}
	return _two_frame_loop("tumble", 5.0, _pattern(tilt_a, palette), _pattern(tilt_b, palette))


static func _two_frame_loop(anim: StringName, fps: float, a: Texture2D, b: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	frames.set_animation_speed(anim, fps)
	frames.add_frame(anim, a)
	frames.add_frame(anim, b)
	return frames


static func _multi_frame_loop(anim: StringName, fps: float, textures: Array) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	frames.set_animation_speed(anim, fps)
	for tex: Variant in textures:
		frames.add_frame(anim, tex as Texture2D)
	return frames


static func _pattern(rows: PackedStringArray, palette: Dictionary) -> Texture2D:
	var h: int = rows.size()
	var w: int = rows[0].length()
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(h):
		var row: String = rows[y]
		for x: int in range(w):
			if x >= row.length():
				continue
			var ch: String = row.substr(x, 1)
			if ch == ".":
				continue
			var tint: Color = palette.get(ch, Color.WHITE) as Color
			img.set_pixel(x, y, tint)
	return ImageTexture.create_from_image(img)
