extends SceneTree

## Headless audit: factory abilities whose formatter output is a lone number or raw enum name.

const _Helpers := preload("res://tests/factory_test_helpers.gd")

const _CLASS_IDS: Array[StringName] = [
	&"knight", &"bruiser", &"archer", &"lancer", &"cleric", &"mage",
]


func _init() -> void:
	var issues: PackedStringArray = run_all()
	var exit_code: int = 0 if issues.is_empty() else 1
	if issues.is_empty():
		print("--- Ability formatter audit: PASS ---")
	else:
		print("--- Ability formatter audit: FAIL ---")
		for line: String in issues:
			print("[FAIL] %s" % line)
	quit(exit_code)


static func run_all() -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for class_id: StringName in _CLASS_IDS:
		var unit_data: UnitData = _Helpers.build_unit(class_id)
		if unit_data == null:
			continue
		for ability: AbilityData in unit_data.abilities:
			if ability == null:
				continue
			_check_ability(issues, ability)
	return issues


static func _check_ability(issues: PackedStringArray, ability: AbilityData) -> void:
	var plain: String = CombatUiFormatters.ability_effect_string(ability)
	var bbcode: String = CombatUiFormatters.ability_effect_bbcode(ability)
	var bbcode_stripped: String = bbcode.strip_edges()
	for tag: String in ["[color=#FBBF24]", "[/color]", "[hint=\"", "\"]", "[/hint]"]:
		while tag in bbcode_stripped:
			bbcode_stripped = bbcode_stripped.replace(tag, "")
	# crude strip of hint payloads
	var hint_start: int = bbcode_stripped.find("[hint=")
	while hint_start >= 0:
		var hint_end: int = bbcode_stripped.find("]", hint_start)
		if hint_end < 0:
			break
		bbcode_stripped = bbcode_stripped.substr(0, hint_start) + bbcode_stripped.substr(hint_end + 1)
		hint_start = bbcode_stripped.find("[hint=")
	if plain == "No effect":
		issues.append("%s plain=No effect" % ability.id)
	if _is_bad_token(plain):
		issues.append("%s plain='%s'" % [ability.id, plain])
	if _is_bad_token(bbcode_stripped):
		issues.append("%s bbcode='%s'" % [ability.id, bbcode_stripped])


static func _is_bad_token(text: String) -> bool:
	var t: String = text.strip_edges()
	if t.is_empty():
		return false
	if t.is_valid_int():
		return true
	if t.ends_with("_On_Collision") or t.ends_with("_On_Adjacent"):
		return true
	if "_" in t and t == t.capitalize().replace(" ", "_"):
		return true
	if t.begins_with("Move_Into_And_Push") or t == "Throw_Behind" or t == "Create_Hazard":
		return true
	return false
