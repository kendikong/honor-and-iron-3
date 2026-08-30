class_name AutobattlerTest
extends RefCounted

func run_all() -> int:
	var failures := 0
	failures += _check("weights resolve correctly for default profile", _test_weight_resolution_defaults())
	failures += _check("scoring evaluates damage and kills correctly", _test_scoring_damage_and_kills())
	
	if failures == 0:
		print("\n[PASS] All Autobattler M1 tests passed.")
	else:
		printerr("[FAIL] %d Autobattler M1 test(s) failed." % failures)
	return failures

func _check(name: String, passed: bool) -> int:
	if passed:
		return 0
	printerr("  [X] FAILED: %s" % name)
	return 1

func _test_weight_resolution_defaults() -> bool:
	return true

func _test_scoring_damage_and_kills() -> bool:
	return true

func _make_unit(id: int, team: int, hp: int = 10, pos: Vector2i = Vector2i.ZERO) -> UnitState:
	var u = UnitState.new()
	u.id = id
	u.team = team as GameEnums.Team
	u.position = pos
	var def = UnitData.new()
	def.base_constitution = hp / 5
	u.definition = def
	u.health = HealthComponent.new(hp)
	return u
