class_name TsxTilesetParser
extends RefCounted

## Parses Tiled .tsx tileset XML into Godot-friendly metadata.

const WANG_CORNER_LABELS: PackedStringArray = ["TL", "T", "TR", "L", "R", "BL", "B", "BR"]


static func parse_file(tsx_path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(tsx_path)
	if text.is_empty():
		push_error("TsxTilesetParser: empty or missing file: %s" % tsx_path)
		return {}
	return parse_text(text, tsx_path)


static func parse_text(text: String, tsx_path: String = "") -> Dictionary:
	var header: Dictionary = _parse_tileset_header(text)
	if header.is_empty():
		push_error("TsxTilesetParser: could not parse <tileset> header")
		return {}

	var image_match: RegExMatch = _match(
		text,
		"<image\\s+source=\"([^\"]*)\"\\s+width=\"(\\d+)\"\\s+height=\"(\\d+)\"",
	)
	var image_source: String = image_match.get_string(1) if image_match else ""

	return {
		"tsx_path": tsx_path,
		"name": str(header.get("name", "")),
		"tile_width": int(header.get("tile_width", 16)),
		"tile_height": int(header.get("tile_height", 16)),
		"tile_count": int(header.get("tile_count", 0)),
		"columns": int(header.get("columns", 16)),
		"image_source": image_source,
		"image_res_path": _resolve_image_path(tsx_path, image_source),
		"image_size": Vector2i(
			int(image_match.get_string(2)) if image_match else 0,
			int(image_match.get_string(3)) if image_match else 0,
		),
		"wangsets": _parse_wangsets(text),
		"tile_animations": _parse_tile_animations(text),
	}


static func _parse_tile_animations(text: String) -> Dictionary:
	## tile_id → { "frames": Array[{ "tile_id": int, "duration_ms": int }] }
	var result: Dictionary = {}
	var tile_regex: RegEx = RegEx.new()
	tile_regex.compile("<tile\\s+id=\"(\\d+)\">\\s*<animation>([\\s\\S]*?)</animation>")
	for tile_match: RegExMatch in tile_regex.search_all(text):
		var tile_id: int = int(tile_match.get_string(1))
		var body: String = tile_match.get_string(2)
		var frames: Array = []
		var frame_regex: RegEx = RegEx.new()
		frame_regex.compile("<frame\\s+tileid=\"(\\d+)\"\\s+duration=\"(\\d+)\"")
		for frame_match: RegExMatch in frame_regex.search_all(body):
			frames.append({
				"tile_id": int(frame_match.get_string(1)),
				"duration_ms": int(frame_match.get_string(2)),
			})
		if not frames.is_empty():
			result[tile_id] = {"frames": frames}
	return result


static func wang_tiles_by_id(parsed: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var wangsets: Array = parsed.get("wangsets", [])
	for wangset_variant: Variant in wangsets:
		var wangset: Dictionary = wangset_variant
		var tiles: Array = wangset.get("tiles", [])
		for tile_variant: Variant in tiles:
			var tile: Dictionary = tile_variant
			result[int(tile["tile_id"])] = tile
	return result


static func wang_map_by_id(parsed: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tile_id: int in wang_tiles_by_id(parsed).keys():
		result[tile_id] = _as_int_array(wang_tiles_by_id(parsed)[tile_id]["wangid"])
	return result


static func format_report(parsed: Dictionary) -> String:
	if parsed.is_empty():
		return "TsxTilesetParser: no data"
	var lines: PackedStringArray = []
	lines.append("TSX: %s" % parsed.get("name", "?"))
	lines.append("  path: %s" % parsed.get("tsx_path", ""))
	lines.append(
		"  grid: %dx%d px, %d tiles, %d columns" % [
			int(parsed.get("tile_width", 0)),
			int(parsed.get("tile_height", 0)),
			int(parsed.get("tile_count", 0)),
			int(parsed.get("columns", 0)),
		]
	)
	lines.append("  image: %s" % parsed.get("image_res_path", ""))
	var wangsets: Array = parsed.get("wangsets", [])
	for wangset_variant: Variant in wangsets:
		var wangset: Dictionary = wangset_variant
		lines.append("  wangset: %s (%s)" % [wangset.get("name", "?"), wangset.get("type", "?")])
		var colors: Array = wangset.get("colors", [])
		for color_variant: Variant in colors:
			var color: Dictionary = color_variant
			lines.append(
				"    color %d: %s (%s)" % [
					int(color.get("index", 0)),
					str(color.get("name", "")),
					str(color.get("color", "")),
				]
			)
		var tiles: Array = wangset.get("tiles", [])
		lines.append("    wang tiles: %d" % tiles.size())
	return "\n".join(lines)


static func _parse_tileset_header(text: String) -> Dictionary:
	var open_match: RegExMatch = _match(text, "<tileset\\s+([^>]+)/?>")
	if open_match == null:
		return {}
	var attrs: String = open_match.get_string(1)
	return {
		"name": _read_attr(attrs, "name"),
		"tile_width": int(_read_attr(attrs, "tilewidth")),
		"tile_height": int(_read_attr(attrs, "tileheight")),
		"tile_count": int(_read_attr(attrs, "tilecount")),
		"columns": int(_read_attr(attrs, "columns")),
	}


static func _read_attr(attrs: String, key: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("%s=\"([^\"]*)\"" % key)
	var found: RegExMatch = regex.search(attrs)
	if found == null:
		return ""
	return found.get_string(1)


static func _parse_wangsets(text: String) -> Array:
	var wangsets: Array = []
	var wangset_regex: RegEx = RegEx.new()
	wangset_regex.compile(
		"<wangset\\s+name=\"([^\"]*)\"\\s+type=\"([^\"]*)\"[^>]*>([\\s\\S]*?)</wangset>",
	)
	for wangset_match: RegExMatch in wangset_regex.search_all(text):
		var body: String = wangset_match.get_string(3)
		wangsets.append({
			"name": wangset_match.get_string(1),
			"type": wangset_match.get_string(2),
			"colors": _parse_wang_colors(body),
			"tiles": _parse_wang_tiles(body),
		})
	return wangsets


static func _parse_wang_colors(body: String) -> Array:
	var colors: Array = []
	var color_regex: RegEx = RegEx.new()
	color_regex.compile("<wangcolor\\s+name=\"([^\"]*)\"\\s+color=\"([^\"]*)\"")
	var index: int = 1
	for color_match: RegExMatch in color_regex.search_all(body):
		colors.append({
			"index": index,
			"name": color_match.get_string(1),
			"color": color_match.get_string(2),
		})
		index += 1
	return colors


static func _parse_wang_tiles(body: String) -> Array:
	var tiles: Array = []
	var tile_regex: RegEx = RegEx.new()
	tile_regex.compile("<wangtile\\s+tileid=\"(\\d+)\"\\s+wangid=\"([0-9,]+)\"")
	for tile_match: RegExMatch in tile_regex.search_all(body):
		var parts: PackedStringArray = tile_match.get_string(2).split(",")
		var wangid: Array[int] = []
		for part: String in parts:
			wangid.append(int(part))
		tiles.append({
			"tile_id": int(tile_match.get_string(1)),
			"wangid": wangid,
		})
	return tiles


static func _as_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item: Variant in value:
			result.append(int(item))
	return result


static func _resolve_image_path(tsx_path: String, image_source: String) -> String:
	if image_source.is_empty():
		return ""
	if image_source.begins_with("res://"):
		return image_source
	if tsx_path.is_empty():
		return image_source

	var base_dir: String = tsx_path.get_base_dir()
	var normalized: String = image_source.replace("\\", "/")
	var candidates: PackedStringArray = PackedStringArray()

	# Standard Tiled relative path (original pack layout).
	candidates.append((base_dir + "/" + normalized).simplify_path())

	# Mana Seed Godot layout: PNGs sit in gentle sheets/ or gentle animations/ beside the .tsx,
	# not one folder up (../gentle sheets/ would wrongly resolve to Assets/gentle sheets/).
	if normalized.begins_with("../"):
		candidates.append((base_dir + "/" + normalized.trim_prefix("../")).simplify_path())

	var filename: String = normalized.get_file()
	if not filename.is_empty():
		for subdir: String in ["gentle sheets", "gentle animations"]:
			candidates.append((base_dir + "/" + subdir + "/" + filename).simplify_path())

	for candidate: String in candidates:
		if FileAccess.file_exists(candidate):
			return candidate

	return candidates[0]


static func _match(text: String, pattern: String) -> RegExMatch:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return regex.search(text)
