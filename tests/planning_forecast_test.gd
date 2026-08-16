class_name PlanningForecastTest
extends RefCounted

## Planning health bars must render one immutable simulator-derived forecast.


static func run_all(failures: Array[String]) -> void:
	_test_damage_and_healing_are_derived_once(failures)
	_test_empty_plan_has_no_change(failures)


static func _test_damage_and_healing_are_derived_once(failures: Array[String]) -> void:
	var baseline: BoardState = _board_with_units([
		_unit(1, 20, 2),
		_unit(2, 12, 0),
	])
	var predicted: BoardState = _board_with_units([
		_unit(1, 13, 2),
		_unit(2, 17, 0),
	])
	var forecast := CombatPlanningForecast.from_boards(baseline, predicted, 17)
	if forecast.revision != 17:
		failures.append("PlanningForecast revision was not preserved")
	if forecast.damage_hp(1) != 7 or forecast.healing_hp(1) != 0:
		failures.append("PlanningForecast damage unit 1 was not derived from board states")
	if forecast.damage_hp(2) != 0 or forecast.healing_hp(2) != 5:
		failures.append("PlanningForecast healing unit 2 was not derived from board states")
	if not forecast.has_stat_change():
		failures.append("PlanningForecast did not report a stat change")


static func _test_empty_plan_has_no_change(failures: Array[String]) -> void:
	var baseline: BoardState = _board_with_units([_unit(1, 20, 2)])
	var forecast := CombatPlanningForecast.from_boards(baseline, baseline, 18)
	if forecast.has_stat_change():
		failures.append("PlanningForecast identical boards reported a change")
	if forecast.damage_hp(1) != 0 or forecast.healing_hp(1) != 0:
		failures.append("PlanningForecast identical boards reported HP movement")


static func _board_with_units(units: Array[UnitState]) -> BoardState:
	var board := BoardState.new()
	board.grid_size = Vector2i(4, 4)
	board.units = units
	return board


static func _unit(unit_id: int, hp: int, armor: int) -> UnitState:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.health = HealthComponent.new(hp)
	unit.armor = armor
	return unit
