class_name CombatPlanningForecast
extends RefCounted

## Immutable, simulator-derived planning forecast for unit health bars.
## The baseline is the board currently shown during planning; the predicted
## values are copied from the simulator's final state for the same plan revision.

var revision: int = -1
var _baseline_hp: Dictionary = {}
var _predicted_hp: Dictionary = {}
var _baseline_armor: Dictionary = {}
var _predicted_armor: Dictionary = {}
var _damage_hp: Dictionary = {}
var _healing_hp: Dictionary = {}
var _has_stat_change: bool = false


static func from_boards(
	baseline: BoardState,
	predicted: BoardState,
	plan_revision: int = -1,
) -> CombatPlanningForecast:
	var forecast := CombatPlanningForecast.new()
	forecast.revision = plan_revision
	if baseline == null or predicted == null:
		return forecast
	for unit: UnitState in baseline.units:
		if unit == null:
			continue
		var future: UnitState = predicted.get_unit_by_id(unit.id)
		var current_hp: int = unit.health.current_hp
		var current_armor: int = maxi(0, unit.armor)
		var future_hp: int = 0
		var future_armor: int = 0
		if future != null and future.is_alive():
			future_hp = future.health.current_hp
			future_armor = maxi(0, future.armor)
		forecast._baseline_hp[unit.id] = current_hp
		forecast._predicted_hp[unit.id] = future_hp
		forecast._baseline_armor[unit.id] = current_armor
		forecast._predicted_armor[unit.id] = future_armor
		forecast._damage_hp[unit.id] = maxi(0, current_hp - future_hp)
		forecast._healing_hp[unit.id] = maxi(0, future_hp - current_hp)
		if (
			current_hp != future_hp
			or current_armor != future_armor
		):
			forecast._has_stat_change = true
	return forecast


func baseline_hp(unit_id: int, fallback: int) -> int:
	return int(_baseline_hp.get(unit_id, fallback))


func predicted_hp(unit_id: int, fallback: int) -> int:
	return int(_predicted_hp.get(unit_id, fallback))


func baseline_armor(unit_id: int, fallback: int) -> int:
	return int(_baseline_armor.get(unit_id, fallback))


func predicted_armor(unit_id: int, fallback: int) -> int:
	return int(_predicted_armor.get(unit_id, fallback))


func damage_hp(unit_id: int) -> int:
	return int(_damage_hp.get(unit_id, 0))


func healing_hp(unit_id: int) -> int:
	return int(_healing_hp.get(unit_id, 0))


func has_unit(unit_id: int) -> bool:
	return _baseline_hp.has(unit_id)


func has_stat_change() -> bool:
	return _has_stat_change
