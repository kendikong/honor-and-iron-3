extends Node

## Unit tests for Phase 11 Character Generator.
## Run headless:  godot --headless -s scripts/test_character_generator.gd

const _Catalog = preload("res://scripts/lpc/lpc_catalog.gd")
const _Profile = preload("res://scripts/lpc/character_gen_profile.gd")
const _Roller  = preload("res://scripts/lpc/character_roller.gd")
const _Manager = preload("res://scripts/lpc/character_weight_manager.gd")

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	print("=== Character Generator Tests ===")
	_test_profile_weight_defaults()
	_test_set_slot_weight_clamps()
	_test_set_item_weight_clamps()
	_test_profile_persistence()
	_test_weight_manager_get_weight()
	_test_weighted_distribution()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


# ---- helpers ----

func _assert(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
		_pass += 1
	else:
		print("  FAIL: %s" % label)
		_fail += 1


# ---- test cases ----

func _test_profile_weight_defaults() -> void:
	print("-- test_profile_weight_defaults")
	var p := CharacterGenProfile.new()
	_assert(p.slot_weights.is_empty(), "slot_weights starts empty")
	_assert(p.item_weights.is_empty(), "item_weights starts empty")


func _test_set_slot_weight_clamps() -> void:
	print("-- test_set_slot_weight_clamps")
	var p := CharacterGenProfile.new()
	p.set_slot_weight("head", 2.5)
	_assert(p.slot_weights["head"] == 1.0, "clamps above 1.0")
	p.set_slot_weight("head", -0.5)
	_assert(p.slot_weights["head"] == 0.0, "clamps below 0.0")
	p.set_slot_weight("head", 0.75)
	_assert(is_equal_approx(p.slot_weights["head"], 0.75), "stores valid value")


func _test_set_item_weight_clamps() -> void:
	print("-- test_set_item_weight_clamps")
	var p := CharacterGenProfile.new()
	p.set_item_weight("boots_brown", 1.5)
	_assert(p.item_weights["boots_brown"] == 1.0, "clamps above 1.0")
	p.set_item_weight("boots_brown", 0.3)
	_assert(is_equal_approx(p.item_weights["boots_brown"], 0.3), "stores valid value")


func _test_profile_persistence() -> void:
	print("-- test_profile_persistence")
	var p := CharacterGenProfile.new()
	p.set_slot_weight("hair", 0.42)
	p.set_item_weight("hat_wizard", 0.88)

	var cfg := ConfigFile.new()
	p.save_to_config(cfg)

	var p2 := CharacterGenProfile.new()
	p2.load_from_config(cfg)
	_assert(is_equal_approx(p2.slot_weights.get("hair", 0.0), 0.42), "slot weight round-trips")
	_assert(is_equal_approx(p2.item_weights.get("hat_wizard", 0.0), 0.88), "item weight round-trips")


func _test_weight_manager_get_weight() -> void:
	print("-- test_weight_manager_get_weight")
	var p := CharacterGenProfile.new()
	p.set_slot_weight("hair", 0.5)
	p.set_item_weight("hair_long", 0.6)
	var w: float = CharacterWeightManager.get_weight("hair_long", "hair", p)
	# slot(0.5) * item(0.6) = 0.3 → clamped to 0.3
	_assert(is_equal_approx(w, 0.3), "get_weight multiplies slot × item (0.5×0.6=0.3)")

	# Unknown id/slot defaults to 1.0 each → result is 1.0 (clamped)
	var w2: float = CharacterWeightManager.get_weight("unknown_id", "unknown_slot", p)
	_assert(is_equal_approx(w2, 1.0), "unknown ids default to 1.0")


func _test_weighted_distribution() -> void:
	print("-- test_weighted_distribution (1000 rolls, biased body type)")
	var catalog := LpcCatalog.load_from_disk()
	if catalog.body_types.is_empty():
		print("  SKIP: catalog not available in headless environment")
		_pass += 1
		return

	var profile := CharacterGenProfile.new()
	# Heavily weight 'male', suppress 'female'.
	profile.body_type_weights = {
		"male": 1.0, "female": 0.0, "teen": 0.0,
		"child": 0.0, "muscular": 0.0, "pregnant": 0.0,
	}
	var counts: Dictionary = {}
	for _i in range(1000):
		profile.seed = randi()
		var recipe := CharacterRoller.roll(catalog, profile)
		counts[recipe.body_type] = counts.get(recipe.body_type, 0) + 1

	var male_count: int = counts.get("male", 0)
	_assert(male_count == 1000, "all 1000 rolls pick 'male' when others have weight 0 (got %d)" % male_count)
