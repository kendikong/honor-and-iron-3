class_name CombatPlanningForecast
extends RefCounted

## Immutable, simulator-derived planning forecast for unit health bars.
## The baseline is the board currently shown during planning; the predicted
## values are copied from the simulator's final state for the same plan revision.
##
## Health bar display contract (regression-critical):
## - Committed forecast = full player timeline sim (global, always-on segment).
## - Live forecast = hover/drag preview sim (uncommitted aim).
## - Bars call merge_for_bar_display() only — never pick live OR committed alone.

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


## Health bars: one display truth from committed full-turn sim plus live hover sim.
## Per unit, show the most damage and any healing from either source (never hide global
## committed damage when hover only updates other units).
static func merge_for_bar_display(
	committed: CombatPlanningForecast,
	live: CombatPlanningForecast,
	baseline: BoardState,
	plan_revision: int = -1,
) -> CombatPlanningForecast:
	var forecast := CombatPlanningForecast.new()
	forecast.revision = plan_revision
	if baseline == null:
		return forecast
	for unit: UnitState in baseline.units:
		if unit == null:
			continue
		var unit_id: int = unit.id
		var current_hp: int = unit.health.current_hp
		var current_armor: int = maxi(0, unit.armor)
		var committed_hp: int = current_hp
		var committed_armor: int = current_armor
		if committed != null and committed.has_unit(unit_id):
			committed_hp = committed.predicted_hp(unit_id, current_hp)
			committed_armor = committed.predicted_armor(unit_id, current_armor)
		var live_hp: int = committed_hp
		var live_armor: int = committed_armor
		if live != null and live.has_unit(unit_id):
			live_hp = live.predicted_hp(unit_id, current_hp)
			live_armor = live.predicted_armor(unit_id, current_armor)
		var predicted_hp: int = mini(committed_hp, live_hp)
		if committed_hp > current_hp or live_hp > current_hp:
			predicted_hp = maxi(committed_hp, live_hp)
		var predicted_armor: int = mini(committed_armor, live_armor)
		if committed_armor > current_armor or live_armor > current_armor:
			predicted_armor = maxi(committed_armor, live_armor)
		forecast._baseline_hp[unit_id] = current_hp
		forecast._predicted_hp[unit_id] = predicted_hp
		forecast._baseline_armor[unit_id] = current_armor
		forecast._predicted_armor[unit_id] = predicted_armor
		forecast._damage_hp[unit_id] = maxi(0, current_hp - predicted_hp)
		forecast._healing_hp[unit_id] = maxi(0, predicted_hp - current_hp)
		if current_hp != predicted_hp or current_armor != predicted_armor:
			forecast._has_stat_change = true
	return forecast
