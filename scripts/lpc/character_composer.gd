class_name CharacterComposer
extends RefCounted

## Build layered LPC sprites on a CharacterActor from a CharacterRecipe.

const WALK_ANIM: StringName = &"walk_down"
const META_VIEW_PLANE: StringName = &"lpc_view_plane"


static func apply(actor: CharacterActor, recipe: CharacterRecipe) -> Dictionary:
	actor.clear_layers()
	
	var hidden_slots: Dictionary = {}
	if recipe.selections.has("hat"):
		var hat_id = str(recipe.selections["hat"].get("id", ""))
		if "bandana" in hat_id:
			hidden_slots["hair"] = true
			hidden_slots["hairextl"] = true
			hidden_slots["hairextr"] = true
			hidden_slots["ponytail"] = true

	var layers: Array = []
	var parts: Array[Dictionary] = []
	var skipped: int = 0
	for type_name: String in recipe.selections.keys():
		if hidden_slots.has(type_name):
			continue
			
		var sel: Dictionary = recipe.selections[type_name]
		var slot_layers: Array[Dictionary] = _layers_for_selection(sel)
		if slot_layers.is_empty():
			skipped += 1
			var fail_path: String = LpcPath.sheet_png(
				str(sel.get("path_prefix", "")), &"walk",
				str(sel.get("recolor", "")), str(sel.get("variant", "")),
			)
			parts.append({
				"slot": type_name,
				"id": str(sel.get("id", "")),
				"z": int(sel.get("z_pos", 0)),
				"recolor_kind": str(sel.get("recolor_kind", "none")),
				"recolor": str(sel.get("recolor", "")),
				"variant": str(sel.get("variant", "")),
				"path": fail_path,
				"status": "missing_png" if not FileAccess.file_exists(fail_path) else "bad_frames",
			})
			continue
		for layer: Dictionary in slot_layers:
			var entry: Dictionary = layer.get("part", {}) as Dictionary
			entry["slot"] = type_name
			parts.append(entry)
			layer["slot"] = type_name
			layers.append(layer)
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["z"]) < int(b["z"])
	)
	for layer: Dictionary in layers:
		actor.add_layer(
			layer["frames"] as SpriteFrames,
			int(layer["z"]),
			str(layer.get("recolor_kind", "none")),
			str(layer.get("recolor", "")),
			str(layer.get("palette_base", "")),
			str(layer.get("view_plane", "unified")),
			str(layer.get("item_id", "")),
			str(layer.get("slot", ""))
		)
	if skipped > 0 and layers.is_empty():
		push_warning("LPC character: all %d layers failed to load." % skipped)
	return {
		"body_type": recipe.body_type,
		"drawn": layers.size(),
		"skipped": skipped,
		"recipe_count": recipe.selections.size(),
		"parts": parts,
	}


static func _layers_for_selection(sel: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path_prefix: String = str(sel.get("path_prefix", ""))
	var recolor: String = str(sel.get("recolor", ""))
	var variant: String = str(sel.get("variant", ""))
	var z_pos: int = int(sel.get("z_pos", 0))
	var recolor_kind: String = str(sel.get("recolor_kind", "none"))
	var palette_base: String = str(sel.get("palette_base", ""))
	var part_id: String = str(sel.get("id", ""))
	var bg_prefix: String = str(sel.get("bg_path_prefix", ""))
	if bg_prefix == "":
		bg_prefix = LpcPath.bg_path_for_fg(path_prefix)
	var split: bool = bg_prefix != ""
	var fg_layer: Dictionary = _load_plane_layer(
		path_prefix, recolor, variant, z_pos, recolor_kind, palette_base, part_id,
		"fg" if split else "unified",
	)
	if fg_layer.is_empty():
		return out
	out.append(fg_layer)
	if split:
		var bg_layer: Dictionary = _load_plane_layer(
			bg_prefix, recolor, variant, z_pos - 1000, recolor_kind, palette_base, part_id, "bg",
		)
		if not bg_layer.is_empty():
			out.append(bg_layer)
	return out


static func _load_plane_layer(
	path_prefix: String,
	recolor: String,
	variant: String,
	z_pos: int,
	recolor_kind: String,
	palette_base: String,
	part_id: String,
	view_plane: String,
) -> Dictionary:
	var walk_path = LpcPath.sheet_png(path_prefix, "walk", recolor, variant)
	var missing_anims: Array[String] = []
	var any_exists = false
	for action in LpcConstants.ACTIONS.keys():
		var p = LpcPath.sheet_png(path_prefix, action, recolor, variant)
		if not FileAccess.file_exists(p):
			missing_anims.append(str(action))
		else:
			any_exists = true
			
	var part: Dictionary = {
		"id": part_id,
		"z": z_pos,
		"recolor_kind": recolor_kind,
		"recolor": recolor,
		"variant": variant,
		"path": walk_path,
		"status": "drawn",
		"plane": view_plane,
		"missing_anims": missing_anims,
	}
	if not any_exists:
		part["status"] = "missing_png"
		return {}
	
	# The actual texture file loaded depends on the active animation.
	# We just supply the path_prefix, recolor, and variant to the lazy loader.
	part["path"] = walk_path
	
	var frames: SpriteFrames = LpcSheetFrames.get_lazy_frames(
		path_prefix, recolor, variant, recolor_kind, palette_base,
	)
	return {
		"z": z_pos,
		"frames": frames,
		"recolor_kind": recolor_kind,
		"recolor": recolor,
		"palette_base": palette_base,
		"view_plane": view_plane,
		"item_id": part_id,
		"part": part,
	}


static func format_report(report: Dictionary, multiline: bool = true) -> String:
	var sep: String = "\n" if multiline else " | "
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"LPC seed=%d body=%s recipe=%d drawn=%d skipped=%d"
		% [
			int(report.get("seed", -1)),
			str(report.get("body_type", "?")),
			int(report.get("recipe_count", 0)),
			int(report.get("drawn", 0)),
			int(report.get("skipped", 0)),
		]
	)
	var parts: Variant = report.get("parts", [])
	if typeof(parts) != TYPE_ARRAY:
		return "\n".join(lines)
	var sorted_parts: Array = parts.duplicate()
	sorted_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("z", 0)) == int(b.get("z", 0)):
			return str(a.get("slot", "")) < str(b.get("slot", ""))
		return int(a.get("z", 0)) < int(b.get("z", 0))
	)
	for raw: Variant in sorted_parts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw
		var tint: String = ""
		if str(p.get("recolor_kind", "none")) != "none":
			tint = " [%s:%s]" % [p.get("recolor_kind", ""), p.get("recolor", "")]
		elif str(p.get("variant", "")) != "":
			tint = " [var:%s]" % p.get("variant", "")
		var status: String = str(p.get("status", "?"))
		var mark: String = "OK" if status == "drawn" else status.to_upper()
		var plane: String = str(p.get("plane", ""))
		var plane_tag: String = (" %s" % plane) if plane != "" and plane != "unified" else ""
		lines.append(
			"  z%3d %-14s %-28s %s%s%s"
			% [
				int(p.get("z", 0)),
				str(p.get("slot", "")),
				str(p.get("id", "")),
				mark,
				plane_tag,
				tint,
			]
		)
		if status != "drawn" and multiline:
			lines.append("       -> %s" % str(p.get("path", "")))
	return sep.join(lines)
