class_name LpcSheetFrames
extends RefCounted

## Slice LPC walk + idle rows via Image.load — bypasses Godot res:// import pipeline.

const WALK_ANIMS: Array[StringName] = [
	&"walk_up", &"walk_left", &"walk_down", &"walk_right",
]
const IDLE_ANIMS: Array[StringName] = [
	&"idle_up", &"idle_left", &"idle_down", &"idle_right",
]

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func get_lazy_frames(
	path_prefix: String,
	recolor: String,
	variant: String,
	recolor_kind: String = "none",
	palette_base: String = "",
) -> SpriteFrames:
	var cache_key: String = "%s|%s|%s|%s|%s" % [
		path_prefix, recolor, variant, recolor_kind, palette_base,
	]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_meta("lpc_path_prefix", path_prefix)
	frames.set_meta("lpc_recolor", recolor)
	frames.set_meta("lpc_variant", variant)
	frames.set_meta("lpc_recolor_kind", recolor_kind)
	frames.set_meta("lpc_palette_base", palette_base)
	_cache[cache_key] = frames
	return frames

static func ensure_animation(frames: SpriteFrames, action: StringName) -> void:
	if frames.has_animation(action):
		return
		
	var action_str = str(action)
	var base_action = LpcConstants.get_base_action(action)
	
	if frames.has_meta("tried_" + base_action):
		return
	frames.set_meta("tried_" + base_action, true)
	
	var path_prefix = frames.get_meta("lpc_path_prefix", "")
	var recolor = frames.get_meta("lpc_recolor", "")
	var variant = frames.get_meta("lpc_variant", "")
	var recolor_kind: String = str(frames.get_meta("lpc_recolor_kind", "none"))
	var palette_base: String = str(frames.get_meta("lpc_palette_base", ""))
	if path_prefix.is_empty():
		return
		
	if base_action == "idle":
		_ensure_idle(frames, path_prefix, recolor, variant, recolor_kind, palette_base)
		return
		
	var sheet_path = LpcConstants.sheet_path(path_prefix, base_action, recolor, variant)
	if not FileAccess.file_exists(sheet_path):
		return
		
	var tex: Texture2D = _load_nearest_texture(sheet_path, recolor_kind, recolor, palette_base)
	if tex == null:
		return
		
	var config = LpcConstants.ACTIONS.get(base_action)
	if config == null:
		return
		
	var cycle_frames: Array = config[0]
	var fps: float = config[1]
	var dirs: Array = config[2]
	
	for dir_i in range(dirs.size()):
		var dir_name = dirs[dir_i]
		var anim_name = StringName(base_action + "_" + dir_name)
		frames.add_animation(anim_name)
		var y0: int = _anim_row_y0(tex, StringName(base_action), dir_i, dirs.size())
		for frame_col in cycle_frames:
			frames.add_frame(anim_name, _atlas_frame(tex, frame_col, y0), 1.0)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, _action_loops(String(base_action)))


static func _action_loops(base_action: String) -> bool:
	return base_action in ["walk", "idle", "run", "combat_idle"]

static func _ensure_idle(
	frames: SpriteFrames,
	path_prefix: String,
	recolor: String,
	variant: String,
	recolor_kind: String = "none",
	palette_base: String = "",
) -> void:
	var sheet_path = LpcConstants.sheet_path(path_prefix, "idle", recolor, variant)
	if FileAccess.file_exists(sheet_path):
		var tex: Texture2D = _load_nearest_texture(sheet_path, recolor_kind, recolor, palette_base)
		if tex != null:
			var config = LpcConstants.ACTIONS.get("idle")
			for dir_i in range(LpcConstants.DIRS.size()):
				var anim_name = StringName("idle_" + LpcConstants.DIRS[dir_i])
				frames.add_animation(anim_name)
				var y0: int = _anim_row_y0(tex, &"idle", dir_i, 4)
				for frame_col in config[0]:
					frames.add_frame(anim_name, _atlas_frame(tex, frame_col, y0), 1.0)
				frames.set_animation_speed(anim_name, config[1])
				frames.set_animation_loop(anim_name, true)
			return
			
	# Fallback to walk.png frame 0
	var walk_path = LpcConstants.sheet_path(path_prefix, "walk", recolor, variant)
	if FileAccess.file_exists(walk_path):
		var tex = _load_nearest_texture(walk_path, recolor_kind, recolor, palette_base)
		if tex != null:
			for dir_i in range(LpcConstants.DIRS.size()):
				var anim_name = StringName("idle_" + LpcConstants.DIRS[dir_i])
				frames.add_animation(anim_name)
				var y0 = _anim_row_y0(tex, &"walk", dir_i, 4)
				frames.add_frame(anim_name, _atlas_frame(tex, 0, y0), 1.0)
				frames.set_animation_speed(anim_name, 4.0)
				frames.set_animation_loop(anim_name, true)


static func get_fallback_animation(frames: SpriteFrames, facing: StringName) -> StringName:
	var base = LpcConstants.get_base_action(facing)
	var dir = str(facing).trim_prefix(str(base) + "_")
	
	var fallbacks = []
	match base:
		&"run": fallbacks = [&"walk"]
		&"combat_idle": fallbacks = [&"idle", &"walk"]
		&"sit": fallbacks = [&"idle", &"walk"]
		&"climb": fallbacks = [&"walk"]
		&"jump": fallbacks = [&"run", &"walk"]
		&"hurt": fallbacks = [&"walk"]
		&"emote": fallbacks = [&"idle", &"walk"]
		&"slash": fallbacks = [&"thrust", &"walk"]
		&"thrust": fallbacks = [&"slash", &"walk"]
		&"spellcast": fallbacks = [&"thrust", &"walk"]
		&"shoot": fallbacks = [&"spellcast", &"thrust", &"walk"]
		&"backslash": fallbacks = [&"slash", &"thrust", &"walk"]
		&"halfslash": fallbacks = [&"slash", &"thrust", &"walk"]
		
	for fb in fallbacks:
		var fb_anim = StringName(str(fb) + "_" + dir)
		ensure_animation(frames, fb_anim)
		if frames.has_animation(fb_anim):
			return fb_anim
			
	# If even walk fails, we are missing the core sprite sheet
	return &""


static func _atlas_frame(tex: Texture2D, frame_col: int, y0: int) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(
		frame_col * LpcConstants.FRAME_SIZE,
		y0,
		LpcConstants.FRAME_SIZE,
		LpcConstants.FRAME_SIZE,
	)
	return atlas


## Per-animation PNGs (e.g. walk.png) are ~832×256; full composites use global row offsets.
static func _anim_row_y0(
	tex: Texture2D,
	anim_name: StringName,
	direction_row: int,
	per_anim_rows: int,
) -> int:
	var sheet_h: int = tex.get_height()
	var per_anim_h: int = per_anim_rows * LpcConstants.FRAME_SIZE
	if sheet_h <= per_anim_h + LpcConstants.FRAME_SIZE:
		return direction_row * LpcConstants.FRAME_SIZE
	var anim_row: int = int(LpcConstants.ANIM_ROW.get(anim_name, 0))
	return (anim_row + direction_row) * LpcConstants.FRAME_SIZE


static func _load_nearest_texture(
	path: String,
	recolor_kind: String = "none",
	recolor: String = "",
	palette_base: String = "",
) -> Texture2D:
	var cache_key: String = path
	if recolor_kind != "none" and not recolor_kind.is_empty() and not recolor.is_empty():
		cache_key = "%s|%s|%s|%s" % [path, recolor_kind, recolor, palette_base]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	var img: Image = Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img = LpcPaletteStore.apply_recolor_to_image(img, recolor_kind, recolor, palette_base)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = tex
	return tex
