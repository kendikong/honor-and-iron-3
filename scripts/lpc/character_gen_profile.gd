class_name CharacterGenProfile
extends RefCounted

## Tunable weights for procedural LPC character generation.

signal changed

const CONFIG_SECTION: String = "character_gen"
## Shared with mana-seed-test — Godot user:// is per project name; weights live here instead.
const SHARED_USERDATA_PROJECT: String = "mana-seed-test"
const CFG_FILE_NAME: String = "character_gen.cfg"

var seed: int = 42
var display_scale: float = 2.0

# New weight maps for slots and individual items
var slot_weights: Dictionary = {}
var item_weights: Dictionary = {}
var item_gender_tags: Dictionary = {}
var required_animations: Array[String] = []

var allow_non_human_parts: bool = true

var body_type_weights: Dictionary = {
	"male": 1.0,
	"female": 1.0,
	"teen": 0.35,
	"child": 0.15,
	"muscular": 0.4,
	"pregnant": 0.1,
	"skeleton": 0.0,
	"zombie": 0.0,
}


func load_from_config(cfg: ConfigFile) -> void:
	seed = int(cfg.get_value(CONFIG_SECTION, "seed", seed))
	allow_non_human_parts = bool(cfg.get_value(CONFIG_SECTION, "allow_non_human_parts", allow_non_human_parts))
	display_scale = float(cfg.get_value(CONFIG_SECTION, "display_scale", display_scale))
	
	var req_anims: Variant = cfg.get_value(CONFIG_SECTION, "required_animations", [])
	if typeof(req_anims) == TYPE_ARRAY:
		required_animations.clear()
		for a in req_anims:
			required_animations.append(str(a))

	# Load weight maps (stored as JSON strings)
	var slot_json: String = str(cfg.get_value(CONFIG_SECTION, "slot_weights", "{}"))
	var item_json: String = str(cfg.get_value(CONFIG_SECTION, "item_weights", "{}"))
	var tags_json: String = str(cfg.get_value(CONFIG_SECTION, "item_gender_tags", "{}"))
	var body_json: String = str(cfg.get_value(CONFIG_SECTION, "body_type_weights", "{}"))
	var slot_parsed: Variant = JSON.parse_string(slot_json)
	var item_parsed: Variant = JSON.parse_string(item_json)
	var tags_parsed: Variant = JSON.parse_string(tags_json)
	var body_parsed: Variant = JSON.parse_string(body_json)
	slot_weights = slot_parsed if typeof(slot_parsed) == TYPE_DICTIONARY else {}
	item_weights = item_parsed if typeof(item_parsed) == TYPE_DICTIONARY else {}
	item_gender_tags = tags_parsed if typeof(tags_parsed) == TYPE_DICTIONARY else {}
	# Merge loaded body type weights over defaults so new body types stay at 1.0
	if typeof(body_parsed) == TYPE_DICTIONARY:
		for bt: Variant in body_parsed.keys():
			body_type_weights[str(bt)] = float(body_parsed[bt])


func save_to_config(cfg: ConfigFile) -> void:
	cfg.set_value(CONFIG_SECTION, "seed", seed)
	cfg.set_value(CONFIG_SECTION, "allow_non_human_parts", allow_non_human_parts)
	cfg.set_value(CONFIG_SECTION, "display_scale", display_scale)

	var slot_json: String = JSON.stringify(slot_weights)
	var item_json: String = JSON.stringify(item_weights)
	var tags_json: String = JSON.stringify(item_gender_tags)
	var body_json: String = JSON.stringify(body_type_weights)
	cfg.set_value(CONFIG_SECTION, "slot_weights", slot_json)
	cfg.set_value(CONFIG_SECTION, "item_weights", item_json)
	cfg.set_value(CONFIG_SECTION, "item_gender_tags", tags_json)
	cfg.set_value(CONFIG_SECTION, "body_type_weights", body_json)
	cfg.set_value(CONFIG_SECTION, "required_animations", required_animations)


func slot_fill_chance(type_name: String, catalog_default: float) -> float:
	return slot_weights.get(type_name, catalog_default)


func emit_changed() -> void:
	changed.emit()

# New helper methods for setting weights
func set_slot_weight(slot: String, w: float) -> void:
	slot_weights[slot] = clamp(w, 0.0, 1.0)
	emit_changed()

func set_item_weight(item_id: String, w: float) -> void:
	item_weights[item_id] = clamp(w, 0.0, 1.0)
	emit_changed()

func set_item_gender_tag(item_id: String, tag: String) -> void:
	if tag == "" or tag == "neutral":
		item_gender_tags.erase(item_id)
	else:
		item_gender_tags[item_id] = tag
	emit_changed()


static func user_config_path() -> String:
	return (
		OS.get_data_dir()
		.path_join("Godot")
		.path_join("app_userdata")
		.path_join(SHARED_USERDATA_PROJECT)
		.path_join(CFG_FILE_NAME)
	)


static func ensure_user_config_dir() -> void:
	DirAccess.make_dir_recursive_absolute(user_config_path().get_base_dir())


static func load_user_config(cfg: ConfigFile) -> Error:
	var shared: String = user_config_path()
	if FileAccess.file_exists(shared):
		return cfg.load(shared)
	var local: String = "user://character_gen.cfg"
	if FileAccess.file_exists(local):
		var err: Error = cfg.load(local)
		if err == OK:
			save_user_config(cfg)
		return err
	return ERR_FILE_NOT_FOUND


static func save_user_config(cfg: ConfigFile) -> Error:
	ensure_user_config_dir()
	return cfg.save(user_config_path())


func load_from_user_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if load_user_config(cfg) == OK:
		load_from_config(cfg)


func save_to_user_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	save_to_config(cfg)
	save_user_config(cfg)
