class_name ClassLibraryBibleText
extends RefCounted

## Verbatim Master Bible blocks from class_abilities.txt, keyed by class + skill name.

const BIBLE_PATH: String = "res://class_abilities.txt"

const _CLASS_HEADERS: PackedStringArray = [
	"knight", "bruiser", "mercenary", "rogue", "monk", "beast rider",
	"mage", "archer", "cleric", "shaman", "lancer", "engineer",
]

static var _by_class_name: Dictionary = {}
static var _by_name: Dictionary = {}
static var _loaded: bool = false


static func lookup(display_name: String, class_display_name: String = "", item_id: String = "") -> String:
	_ensure_loaded()
	var name_key: String = _normalize(display_name)
	var class_key: String = _normalize(class_display_name)
	var from_class: String = _lookup_in_class(class_key, name_key)
	if not from_class.is_empty():
		return from_class
	var id_key: String = _name_from_id(item_id, class_key)
	if not id_key.is_empty():
		from_class = _lookup_in_class(class_key, id_key)
		if not from_class.is_empty():
			return from_class
		if _by_name.has(id_key):
			return str(_by_name[id_key])
	if _by_name.has(name_key):
		return str(_by_name[name_key])
	if display_name.is_empty():
		return "No Master Bible entry found."
	return "No Master Bible entry found for \"%s\"." % display_name


static func _lookup_in_class(class_key: String, name_key: String) -> String:
	if class_key.is_empty() or name_key.is_empty() or not _by_class_name.has(class_key):
		return ""
	var class_map: Dictionary = _by_class_name[class_key]
	if class_map.has(name_key):
		return str(class_map[name_key])
	return ""


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(BIBLE_PATH):
		push_warning("Class library Bible missing: %s" % BIBLE_PATH)
		return
	var text: String = FileAccess.get_file_as_string(BIBLE_PATH)
	if text.is_empty():
		push_warning("Class library Bible empty: %s" % BIBLE_PATH)
		return
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	var current_class: String = ""
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i]
		var header: String = _parse_class_header(line)
		if not header.is_empty():
			current_class = header
			i += 1
			continue
		if current_class.is_empty():
			i += 1
			continue
		if line.begins_with("Innate Trait:"):
			var trait_name: String = line.substr("Innate Trait:".length()).strip_edges()
			var block: PackedStringArray = PackedStringArray()
			block.append(line)
			i += 1
			while i < lines.size():
				var nxt: String = lines[i]
				if nxt.begins_with("Base Mechanic:") or nxt.begins_with("Upgrade:"):
					block.append(nxt)
					i += 1
					continue
				break
			_store(current_class, trait_name, "\n".join(block))
			continue
		if line.begins_with("Reposition Skill:"):
			var rest: String = line.substr("Reposition Skill:".length()).strip_edges()
			var skill_name: String = rest
			var paren: int = rest.find(" (")
			if paren >= 0:
				skill_name = rest.substr(0, paren).strip_edges()
			var block: PackedStringArray = PackedStringArray()
			block.append(line)
			i += 1
			if i < lines.size() and str(lines[i]).begins_with("Upgrade:"):
				block.append(lines[i])
				i += 1
			_store(current_class, skill_name, "\n".join(block))
			continue
		if line.begins_with("Basic Attack ("):
			var inner_start: int = line.find("(")
			var inner_end: int = line.find("):")
			if inner_start >= 0 and inner_end > inner_start:
				var inner: String = line.substr(inner_start + 1, inner_end - inner_start - 1).strip_edges()
				_store(current_class, inner, line)
				_store(current_class, "Basic Attack", line)
			i += 1
			continue
		if line.begins_with("(The "):
			var close: int = line.find(") ")
			if close >= 0:
				var after: String = line.substr(close + 2)
				var colon: int = after.find(":")
				if colon >= 0:
					_store(current_class, after.substr(0, colon).strip_edges(), line)
			i += 1
			continue
		i += 1


static func _parse_class_header(line: String) -> String:
	var stripped: String = line.strip_edges()
	var dot: int = stripped.find(". ")
	if dot < 1:
		return ""
	if not stripped.substr(0, dot).is_valid_int():
		return ""
	var header_name: String = _normalize(stripped.substr(dot + 2))
	if header_name in _CLASS_HEADERS:
		return stripped.substr(dot + 2).strip_edges()
	return ""


static func _store(class_display: String, skill_name: String, body: String) -> void:
	var class_key: String = _normalize(class_display)
	var name_key: String = _normalize(skill_name)
	if class_key.is_empty() or name_key.is_empty() or body.is_empty():
		return
	if not _by_class_name.has(class_key):
		_by_class_name[class_key] = {}
	var class_map: Dictionary = _by_class_name[class_key]
	class_map[name_key] = body
	_by_class_name[class_key] = class_map
	_by_name[name_key] = body


static func _name_from_id(item_id: String, class_key: String) -> String:
	var raw: String = item_id.strip_edges().to_lower().replace("-", "_")
	if raw.is_empty():
		return ""
	var class_snake: String = class_key.replace(" ", "_")
	if not class_snake.is_empty() and raw.begins_with(class_snake + "_"):
		raw = raw.substr(class_snake.length() + 1)
	return _normalize(raw.replace("_", " "))


static func _normalize(value: String) -> String:
	var out: String = value.strip_edges().to_lower()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out
