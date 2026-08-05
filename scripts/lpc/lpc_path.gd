class_name LpcPath
extends RefCounted

## Resolve on-disk LPC sprite paths (palette-recolor PNGs where present).


static func sheet_png(path_prefix: String, animation: StringName, recolor: String, variant: String) -> String:
	return LpcConstants.sheet_path(path_prefix, str(animation), recolor, variant)


static func path_prefix_for_item(item: Dictionary, body_type: String) -> String:
	var paths: Variant = item.get("paths", {})
	if typeof(paths) != TYPE_DICTIONARY:
		return ""
	if not paths.has(body_type):
		return ""
	return str(paths[body_type])


## ULPC split sheets: layer_1 fg (front/down), layer_2 bg (back/sides).
static func bg_path_for_fg(path_prefix: String) -> String:
	if path_prefix.is_empty() or not path_prefix.contains("/fg/"):
		return ""
	return path_prefix.replace("/fg/", "/bg/")


static func path_prefix_for_bg_item(item: Dictionary, body_type: String) -> String:
	var bg_paths: Variant = item.get("bg_paths", {})
	if typeof(bg_paths) == TYPE_DICTIONARY and bg_paths.has(body_type):
		return str(bg_paths[body_type])
	return bg_path_for_fg(path_prefix_for_item(item, body_type))


static func is_fg_split_path(path_prefix: String) -> bool:
	return path_prefix.contains("/fg/")


static func item_supports_body(item: Dictionary, body_type: String) -> bool:
	var paths: Variant = item.get("paths", {})
	if typeof(paths) != TYPE_DICTIONARY or not paths.has(body_type):
		return false
	var required: Variant = item.get("required_body_types", [])
	if typeof(required) != TYPE_ARRAY or required.is_empty():
		return true
	var id: String = str(item.get("id", ""))
	
	# Strict gender matching (override catalog fallbacks)
	if body_type == "female" and "_male" in id:
		return false
	if body_type == "male" and "_female" in id:
		return false
		
	for bt: Variant in required:
		var s_bt = str(bt)
		if s_bt == body_type:
			return true
		if s_bt == "human" and body_type in ["male", "female", "teen", "child", "muscular", "pregnant"]:
			return true
		if s_bt == "non-human" and body_type in ["skeleton", "zombie"]:
			return true
	return false
