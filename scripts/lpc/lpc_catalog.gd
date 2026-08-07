class_name LpcCatalog
extends RefCounted

## Curated LPC item metadata for Godot runtime rolling.

var body_types: PackedStringArray = PackedStringArray()
var skin_recolors: PackedStringArray = PackedStringArray()
var hair_recolors: PackedStringArray = PackedStringArray()
var cloth_recolors: PackedStringArray = PackedStringArray()
var slots: Dictionary = {}


static func load_from_disk(path: String = LpcConstants.CATALOG_PATH) -> LpcCatalog:
	var catalog: LpcCatalog = LpcCatalog.new()
	if not FileAccess.file_exists(path):
		push_error("LPC catalog missing: %s â€” run tools/build_lpc_catalog.py" % path)
		return catalog
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("LPC catalog parse failed: %s" % path)
		return catalog
	catalog.body_types = _to_str_array(data.get("body_types", []))
	catalog.skin_recolors = _to_str_array(data.get("skin_recolors", []))
	catalog.hair_recolors = _to_str_array(data.get("hair_recolors", []))
	catalog.cloth_recolors = _to_str_array(data.get("cloth_recolors", []))
	catalog.slots = data.get("slots", {})
	return catalog


static func _to_str_array(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v: Variant in raw:
		out.append(str(v))
	return out


func slot_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for key: Variant in slots.keys():
		names.append(str(key))
	names.sort()
	return names


func items_for_slot(type_name: String) -> Array:
	var slot: Variant = slots.get(type_name, {})
	if typeof(slot) != TYPE_DICTIONARY:
		return []
	return slot.get("items", [])


func is_required_slot(type_name: String) -> bool:
	var slot: Variant = slots.get(type_name, {})
	if typeof(slot) != TYPE_DICTIONARY:
		return false
	return bool(slot.get("required", false))


func default_fill_chance(type_name: String) -> float:
	var slot: Variant = slots.get(type_name, {})
	if typeof(slot) != TYPE_DICTIONARY:
		return 0.0
	return float(slot.get("fill_chance", 0.0))


func find_item(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	for slot_name: String in slot_names():
		for raw: Variant in items_for_slot(slot_name):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			if str(raw.get("id", "")) == item_id:
				return {"slot": slot_name, "item": raw}
	return {}


func recolor_pool(kind: String) -> PackedStringArray:
	match kind:
		"skin":
			return skin_recolors
		"hair":
			return hair_recolors
		"cloth":
			return cloth_recolors
		_:
			return PackedStringArray()
