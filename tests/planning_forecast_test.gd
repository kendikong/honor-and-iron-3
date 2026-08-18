class_name PlanningForecastTest
extends RefCounted

## Planning health bars must render one immutable simulator-derived forecast.


static func run_all(failures: Array[String]) -> void:
	_test_damage_and_healing_are_derived_once(failures)
	_test_empty_plan_has_no_change(failures)
	_test_merge_keeps_committed_damage_during_hover_on_other_unit(failures)
	_test_merge_adds_extra_hover_damage(failures)
	_test_merge_hover_only_damage_without_committed(failures)
	_test_merge_live_only_forecast_must_not_erase_committed(failures)
	_test_committed_forecast_cannot_be_cleared_during_planning(failures)
	_test_promoted_forecast_rebases_to_committed_plan_revision(failures)
	_test_unit_layer_bar_display_source_contract(failures)


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


static func _test_merge_keeps_committed_damage_during_hover_on_other_unit(
	failures: Array[String],
) -> void:
	var baseline: BoardState = _board_with_units([
		_unit(1, 20, 0),
		_unit(2, 30, 0),
	])
	var committed_predicted: BoardState = _board_with_units([
		_unit(1, 15, 0),
		_unit(2, 30, 0),
	])
	var live_predicted: BoardState = _board_with_units([
		_unit(1, 20, 0),
		_unit(2, 22, 0),
	])
	var committed := CombatPlanningForecast.from_boards(baseline, committed_predicted, 42)
	var live := CombatPlanningForecast.from_boards(baseline, live_predicted, 42)
	var merged := CombatPlanningForecast.merge_for_bar_display(
		committed, live, baseline, 42,
	)
	if merged.damage_hp(1) != 5:
		failures.append(
			"PlanningForecast merge must keep committed damage on unit 1 during hover on unit 2",
		)
	if merged.damage_hp(2) != 8:
		failures.append(
			"PlanningForecast merge must include hover damage on unit 2 while unit 1 stays committed",
		)


static func _test_merge_adds_extra_hover_damage(failures: Array[String]) -> void:
	var baseline: BoardState = _board_with_units([_unit(1, 20, 0)])
	var committed_predicted: BoardState = _board_with_units([_unit(1, 15, 0)])
	var live_predicted: BoardState = _board_with_units([_unit(1, 10, 0)])
	var committed := CombatPlanningForecast.from_boards(baseline, committed_predicted, 43)
	var live := CombatPlanningForecast.from_boards(baseline, live_predicted, 43)
	var merged := CombatPlanningForecast.merge_for_bar_display(
		committed, live, baseline, 43,
	)
	if merged.damage_hp(1) != 10:
		failures.append(
			"PlanningForecast merge must show deeper hover damage (10) not only committed (5)",
		)


static func _test_merge_hover_only_damage_without_committed(failures: Array[String]) -> void:
	var baseline: BoardState = _board_with_units([_unit(1, 20, 0)])
	var live_predicted: BoardState = _board_with_units([_unit(1, 12, 0)])
	var live := CombatPlanningForecast.from_boards(baseline, live_predicted, 44)
	var merged := CombatPlanningForecast.merge_for_bar_display(
		null, live, baseline, 44,
	)
	if merged.damage_hp(1) != 8:
		failures.append(
			"PlanningForecast merge must show uncommitted hover damage when no committed forecast exists",
		)


static func _test_merge_live_only_forecast_must_not_erase_committed(
	failures: Array[String],
) -> void:
	var baseline: BoardState = _board_with_units([
		_unit(1, 20, 0),
		_unit(2, 25, 0),
	])
	var committed_predicted: BoardState = _board_with_units([
		_unit(1, 12, 0),
		_unit(2, 25, 0),
	])
	var live_predicted: BoardState = _board_with_units([
		_unit(1, 20, 0),
		_unit(2, 25, 0),
	])
	var committed := CombatPlanningForecast.from_boards(baseline, committed_predicted, 45)
	var live := CombatPlanningForecast.from_boards(baseline, live_predicted, 45)
	var live_only := CombatPlanningForecast.merge_for_bar_display(
		null, live, baseline, 45,
	)
	if live_only.damage_hp(1) != 0:
		failures.append(
			"PlanningForecast live-only merge must not invent committed damage on unit 1",
		)
	var merged := CombatPlanningForecast.merge_for_bar_display(
		committed, live, baseline, 45,
	)
	if merged.damage_hp(1) != 8:
		failures.append(
			"PlanningForecast merge must preserve committed unit 1 damage (8) when live hover is elsewhere",
		)
	if live.damage_hp(1) != 0 and merged.damage_hp(1) == live.damage_hp(1):
		failures.append(
			"PlanningForecast merge must not replace committed damage with live-only zeros",
		)


static func _test_committed_forecast_cannot_be_cleared_during_planning(
	failures: Array[String],
) -> void:
	var baseline: BoardState = _board_with_units([_unit(1, 20, 0)])
	var predicted: BoardState = _board_with_units([_unit(1, 12, 0)])
	var director := CombatDirector.new()
	director.board = baseline
	director.plan_revision = 7
	var layer := TacticalUnitLayer.new()
	layer._director = director
	layer._board = baseline
	layer._phase = CombatDirector.Phase.PLANNING
	layer.set_committed_forecast(
		CombatPlanningForecast.from_boards(baseline, predicted, director.plan_revision),
	)
	layer.set_committed_forecast(null)
	var display: CombatPlanningForecast = layer._bar_display_forecast()
	if display == null or display.damage_hp(1) != 8:
		failures.append(
			"PlanningForecast committed damage must survive planner clears until phase end",
		)


static func _test_promoted_forecast_rebases_to_committed_plan_revision(
	failures: Array[String],
) -> void:
	var baseline: BoardState = _board_with_units([_unit(1, 20, 0)])
	var predicted: BoardState = _board_with_units([_unit(1, 12, 0)])
	var director := CombatDirector.new()
	director.plan_revision = 11
	var overlay := TacticalPlanningOverlay.new()
	overlay._director = director
	overlay._live_preview.forecast = CombatPlanningForecast.from_boards(
		baseline, predicted, 10,
	)
	overlay._live_preview.preview_board = predicted
	overlay.promote_live_preview_to_committed()
	if (
		overlay._committed_preview.forecast == null
		or overlay._committed_preview.forecast.revision != director.plan_revision
	):
		failures.append(
			"PlanningForecast promoted commit must use the current plan revision",
		)


static func _test_unit_layer_bar_display_source_contract(failures: Array[String]) -> void:
	var path := "res://presentation/tactical_unit_layer.gd"
	if not FileAccess.file_exists(path):
		failures.append("PlanningForecast unit layer contract: missing tactical_unit_layer.gd")
		return
	var text := FileAccess.get_file_as_string(path)
	if "_active_forecast" in text:
		failures.append(
			"PlanningForecast unit layer must not use live-only _active_forecast (use _bar_display_forecast)",
		)
	if "return _committed_forecast" in text or "return _live_forecast" in text:
		failures.append(
			"PlanningForecast unit layer must not return raw committed/live forecast in draw paths",
		)
	var draw_start := text.find("func _draw_hp_bar")
	if draw_start < 0:
		failures.append("PlanningForecast unit layer contract: missing _draw_hp_bar")
		return
	var draw_end := text.find("func ", draw_start + 1)
	var draw_body := text.substr(draw_start, draw_end - draw_start if draw_end > draw_start else -1)
	if "_committed_forecast" in draw_body or "_live_forecast" in draw_body:
		failures.append(
			"PlanningForecast _draw_hp_bar must use _bar_display_forecast only, not raw forecast fields",
		)
	if "_bar_display_forecast" not in draw_body:
		failures.append(
			"PlanningForecast _draw_hp_bar must call _bar_display_forecast for simulator merge",
		)


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
