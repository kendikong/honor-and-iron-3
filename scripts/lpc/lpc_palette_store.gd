class_name LpcPaletteStore
extends RefCounted

## Runtime ULPC palette JSON + shared recolor ShaderMaterials (matches chargen.js mapping).

const ULPC_DIR: String = (
	"Universal-LPC-Spritesheet-Character-Generator-master"
	+ "/Universal-LPC-Spritesheet-Character-Generator-master"
)
const MAX_PAIRS: int = 12
## Hair sheets ship with either ULPC or LPCR orange bases; include both when unknown.
const HAIR_FALLBACK_VERSIONS: Array = ["ulpc", "lpcr"]
const SHADER: Shader = preload("res://shaders/lpc_palette_recolor.gdshader")

const KIND_TO_MATERIAL: Dictionary = {
	"skin": "body",
	"hair": "hair",
	"cloth": "cloth",
}

## Catalog roll names that differ from ULPC palette_definitions keys.
const TARGET_ALIASES: Dictionary = {
	"hair": {"brown": "light_brown"},
}

static var _ulpc_root: String = ""
static var _meta_cache: Dictionary = {}
static var _palette_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _warned_missing_target: Dictionary = {}


static func ulpc_root() -> String:
	if _ulpc_root.is_empty():
		_ulpc_root = ProjectSettings.globalize_path("res://").path_join(ULPC_DIR)
	return _ulpc_root


static func palettes_available() -> bool:
	var probe: String = (
		ulpc_root()
		.path_join("palette_definitions/body/meta_body.json")
	)
	return FileAccess.file_exists(probe)


static func get_recolor_material(
	recolor_kind: String,
	target_name: String,
	palette_base: String = "",
) -> ShaderMaterial:
	# Palette swap is baked into textures at load (see apply_recolor_to_image).
	return null


## CPU palette swap — matches chargen.js tolerance (1/255 per channel).
static func apply_recolor_to_image(
	img: Image,
	recolor_kind: String,
	target_name: String,
	palette_base: String = "",
) -> Image:
	if img == null or img.is_empty():
		return img
	if recolor_kind.is_empty() or target_name.is_empty() or recolor_kind == "none":
		return img
	if not palettes_available():
		return img
	var resolved_target: String = _resolve_target_name(recolor_kind, target_name)
	var built: Dictionary = _build_pair_arrays(recolor_kind, resolved_target, palette_base)
	if built.is_empty():
		if not _is_identity_recolor(recolor_kind, resolved_target, palette_base):
			_warn_missing_target(recolor_kind, target_name, resolved_target, palette_base)
		return img
	return _recolor_image_pairs(img, built)


static func _recolor_image_pairs(img: Image, built: Dictionary) -> Image:
	var count: int = int(built.get("count", 0))
	if count < 1:
		return img
	var source: PackedColorArray = built["source"] as PackedColorArray
	var target: PackedColorArray = built["target"] as PackedColorArray
	var out: Image = img.duplicate()
	if out.is_compressed():
		out.decompress()
	var width: int = out.get_width()
	var height: int = out.get_height()
	for y: int in range(height):
		for x: int in range(width):
			var pixel: Color = out.get_pixel(x, y)
			if pixel.a < 0.01:
				continue
			var rgb8: Vector3i = _color_to_rgb8(pixel)
			for i: int in count:
				if _rgb8_near(rgb8, _color_to_rgb8(source[i])):
					var mapped: Color = target[i]
					out.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, pixel.a))
					break
	return out


static func _color_to_rgb8(color: Color) -> Vector3i:
	return Vector3i(
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
	)


static func _rgb8_near(a: Vector3i, b: Vector3i, tolerance: int = 1) -> bool:
	return (
		absi(a.x - b.x) <= tolerance
		and absi(a.y - b.y) <= tolerance
		and absi(a.z - b.z) <= tolerance
	)


static func _build_pair_arrays(
	kind: String,
	target_name: String,
	palette_base_override: String = "",
) -> Dictionary:
	var material: String = str(KIND_TO_MATERIAL.get(kind, ""))
	if material.is_empty():
		return {}
	var meta: Dictionary = _load_meta(material)
	if meta.is_empty():
		return {}
	var default_version: String = str(meta.get("default", "ulpc"))
	var default_base: String = str(meta.get("base", ""))
	var parsed: Dictionary = _parse_palette_ref(
		palette_base_override,
		default_version,
		default_base,
	)
	var base_name: String = str(parsed.get("base", ""))
	if base_name.is_empty() or target_name == base_name:
		return {}
	var versions: Array[String] = _palette_versions_for(kind, str(parsed.get("version", "")), base_name, palette_base_override)
	var source: PackedColorArray = PackedColorArray()
	var target: PackedColorArray = PackedColorArray()
	source.resize(MAX_PAIRS)
	target.resize(MAX_PAIRS)
	var count: int = 0
	for version: String in versions:
		var palette: Dictionary = _load_palette_json(material, version)
		if not palette.has(base_name) or not palette.has(target_name):
			continue
		var source_hex: Array = palette[base_name]
		var target_hex: Array = palette[target_name]
		var pair_count: int = mini(source_hex.size(), target_hex.size())
		for i: int in pair_count:
			if count >= MAX_PAIRS:
				break
			source[count] = _hex_to_color(str(source_hex[i]))
			target[count] = _hex_to_color(str(target_hex[i]))
			count += 1
		if count >= MAX_PAIRS:
			break
	if count < 1:
		return {}
	for i: int in range(count, MAX_PAIRS):
		source[i] = Color.BLACK
		target[i] = Color.BLACK
	return {"count": count, "source": source, "target": target}


static func _parse_palette_ref(
	token: String,
	default_version: String,
	default_base: String,
) -> Dictionary:
	var trimmed: String = token.strip_edges()
	if trimmed.is_empty():
		return {"version": default_version, "base": default_base}
	var parts: PackedStringArray = PackedStringArray(trimmed.split("."))
	if parts.size() >= 2:
		return {"version": parts[0], "base": parts[1]}
	return {"version": default_version, "base": parts[0]}


static func _palette_versions_for(
	kind: String,
	version: String,
	base_name: String,
	palette_base_override: String,
) -> Array[String]:
	if not palette_base_override.is_empty():
		return [version]
	if kind == "hair" and base_name == "orange":
		var out: Array[String] = []
		if not out.has(version):
			out.append(version)
		for ver: String in HAIR_FALLBACK_VERSIONS:
			if not out.has(ver):
				out.append(ver)
		return out
	return [version]


static func _load_meta(material: String) -> Dictionary:
	if _meta_cache.has(material):
		return _meta_cache[material]
	var path: String = (
		ulpc_root()
		.path_join("palette_definitions")
		.path_join(material)
		.path_join("meta_%s.json" % material)
	)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_meta_cache[material] = parsed
	return parsed


static func _load_palette_json(material: String, version: String) -> Dictionary:
	var cache_key: String = "%s:%s" % [material, version]
	if _palette_cache.has(cache_key):
		return _palette_cache[cache_key]
	var path: String = (
		ulpc_root()
		.path_join("palette_definitions")
		.path_join(material)
		.path_join("%s_%s.json" % [material, version])
	)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_palette_cache[cache_key] = parsed
	return parsed


static func _hex_to_color(hex: String) -> Color:
	var h: String = hex.strip_edges().trim_prefix("#")
	if h.length() >= 8:
		h = h.substr(0, 6)
	if h.length() != 6:
		return Color.MAGENTA
	return Color(
		_hex_byte(h, 0),
		_hex_byte(h, 2),
		_hex_byte(h, 4),
		1.0,
	)


static func _hex_byte(h: String, start: int) -> float:
	return float(h.substr(start, 2).hex_to_int()) / 255.0


static func _is_identity_recolor(
	kind: String,
	target_name: String,
	palette_base_override: String,
) -> bool:
	var material: String = str(KIND_TO_MATERIAL.get(kind, ""))
	if material.is_empty():
		return false
	var meta: Dictionary = _load_meta(material)
	if meta.is_empty():
		return false
	var parsed: Dictionary = _parse_palette_ref(
		palette_base_override,
		str(meta.get("default", "ulpc")),
		str(meta.get("base", "")),
	)
	var base_name: String = str(parsed.get("base", ""))
	return not base_name.is_empty() and target_name == base_name


static func _resolve_target_name(kind: String, target_name: String) -> String:
	var aliases: Variant = TARGET_ALIASES.get(kind, {})
	if typeof(aliases) == TYPE_DICTIONARY and aliases.has(target_name):
		return str(aliases[target_name])
	return target_name


static func _warn_missing_target(
	kind: String,
	rolled: String,
	resolved: String,
	palette_base: String,
) -> void:
	var warn_key: String = "%s:%s:%s" % [kind, palette_base, resolved]
	if _warned_missing_target.has(warn_key):
		return
	_warned_missing_target[warn_key] = true
	push_warning(
		"LPC palette: no mapping for %s roll '%s' (resolved '%s', base '%s')"
		% [kind, rolled, resolved, palette_base if not palette_base.is_empty() else "default"]
	)
