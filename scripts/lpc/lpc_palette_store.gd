class_name LpcPaletteStore
extends RefCounted

## Runtime ULPC palette JSON + shared recolor ShaderMaterials (matches chargen.js mapping).

const ULPC_DIR: String = (
	"Universal-LPC-Spritesheet-Character-Generator-master"
	+ "/Universal-LPC-Spritesheet-Character-Generator-master"
)
const MAX_PAIRS: int = 8
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
	if recolor_kind.is_empty() or target_name.is_empty() or recolor_kind == "none":
		return null
	var resolved_target: String = _resolve_target_name(recolor_kind, target_name)
	var cache_key: String = "%s:%s:%s" % [
		recolor_kind,
		palette_base if not palette_base.is_empty() else "_",
		resolved_target,
	]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var built: Dictionary = _build_pair_arrays(recolor_kind, resolved_target, palette_base)
	if built.is_empty():
		if not _is_identity_recolor(recolor_kind, resolved_target, palette_base):
			_warn_missing_target(recolor_kind, target_name, resolved_target, palette_base)
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("pair_count", int(built["count"]))
	mat.set_shader_parameter("source_colors", built["source"] as PackedColorArray)
	mat.set_shader_parameter("target_colors", built["target"] as PackedColorArray)
	mat.set_shader_parameter("selection_active", 0.0)
	_material_cache[cache_key] = mat
	return mat


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
	var version: String = str(meta.get("default", "ulpc"))
	var base_name: String = (
		palette_base_override
		if not palette_base_override.is_empty()
		else str(meta.get("base", ""))
	)
	if base_name.is_empty() or target_name == base_name:
		return {}
	var palette: Dictionary = _load_palette_json(material, version)
	if not palette.has(base_name) or not palette.has(target_name):
		return {}
	var source_hex: Array = palette[base_name]
	var target_hex: Array = palette[target_name]
	var count: int = mini(source_hex.size(), target_hex.size())
	count = mini(count, MAX_PAIRS)
	if count < 1:
		return {}
	var source: PackedColorArray = PackedColorArray()
	var target: PackedColorArray = PackedColorArray()
	source.resize(MAX_PAIRS)
	target.resize(MAX_PAIRS)
	for i: int in count:
		source[i] = _hex_to_color(str(source_hex[i]))
		target[i] = _hex_to_color(str(target_hex[i]))
	for i: int in range(count, MAX_PAIRS):
		source[i] = Color.BLACK
		target[i] = Color.BLACK
	return {"count": count, "source": source, "target": target}


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
	var base_name: String = (
		palette_base_override
		if not palette_base_override.is_empty()
		else str(meta.get("base", ""))
	)
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

