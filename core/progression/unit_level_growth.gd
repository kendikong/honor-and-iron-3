class_name UnitLevelGrowth
extends RefCounted

## Canonical level-up stat distribution for UnitState._recalculate_stats.
## 2 points per level above 1: 75% preferred, remainder split across two secondary stats.

const POINTS_PER_LEVEL: int = 2
const PREFERRED_SHARE: float = 0.75


static func compute(def: UnitData, level: int) -> Dictionary:
	var levels_above_base: int = maxi(0, level - 1)
	var total_points: int = levels_above_base * POINTS_PER_LEVEL
	var preferred_points: int = int(floor(float(total_points) * PREFERRED_SHARE))
	var remainder: int = total_points - preferred_points
	var spread_primary: int = remainder / 2
	var spread_secondary: int = remainder - spread_primary
	var bonuses: Dictionary = {
		"str": 0,
		"mag": 0,
		"def": 0,
		"con": 0,
	}
	match def.preferred_stat:
		GameEnums.StatType.PHYSICAL:
			bonuses.str = preferred_points
			bonuses.def = spread_primary
			bonuses.con = spread_secondary
		GameEnums.StatType.MAGICAL:
			bonuses.mag = preferred_points
			bonuses.def = spread_primary
			bonuses.con = spread_secondary
		GameEnums.StatType.DEFENSE:
			bonuses.def = preferred_points
			_apply_offensive_spread(bonuses, def, spread_primary)
			bonuses.con = spread_secondary
		GameEnums.StatType.MAX_HP:
			bonuses.con = preferred_points
			_apply_offensive_spread(bonuses, def, spread_primary)
			bonuses.def = spread_secondary
		_:
			bonuses.str = preferred_points
			bonuses.def = spread_primary
			bonuses.con = spread_secondary
	return bonuses


static func bonus_for_stat(def: UnitData, level: int, stat_type: GameEnums.StatType) -> int:
	var bonuses: Dictionary = compute(def, level)
	match stat_type:
		GameEnums.StatType.PHYSICAL:
			return int(bonuses.str)
		GameEnums.StatType.MAGICAL:
			return int(bonuses.mag)
		GameEnums.StatType.DEFENSE:
			return int(bonuses.def)
		GameEnums.StatType.MAX_HP:
			return int(bonuses.con)
		_:
			return 0


static func constitution_bonus(def: UnitData, level: int) -> int:
	return int(compute(def, level).con)


static func _apply_offensive_spread(bonuses: Dictionary, def: UnitData, amount: int) -> void:
	if _offensive_stat(def) == GameEnums.StatType.MAGICAL:
		bonuses.mag = amount
	else:
		bonuses.str = amount


static func _offensive_stat(def: UnitData) -> GameEnums.StatType:
	if def.base_magic > def.base_strength:
		return GameEnums.StatType.MAGICAL
	return GameEnums.StatType.PHYSICAL
