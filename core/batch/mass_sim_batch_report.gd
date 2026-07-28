class_name MassSimBatchReport
extends RefCounted

const MIN_SAMPLE_FULL_CONFIDENCE := 500

## Aggregated analytics payload for all dashboard levels (single source of truth).

var source_path: String = ""
var total_battles: int = 0

var player_wins: int = 0
var enemy_wins: int = 0
var draws: int = 0
var timeouts: int = 0

var player_win_pct: float = 0.0
var enemy_win_pct: float = 0.0
var draw_pct: float = 0.0
var timeout_pct: float = 0.0

var avg_turns: float = 0.0
var median_turns: int = 0
var turn_values: Array[int] = []

var integrity_score: float = 0.0
var integrity_notes: PackedStringArray = PackedStringArray()
var unique_classes_seen: int = 0
var total_player_classes: int = 0

var total_wall_collisions: int = 0
var total_chain_collisions: int = 0
var total_hazard_landings: int = 0
var total_friendly_fire: int = 0
var total_assisted_damage: int = 0
var total_assisted_shields: int = 0
var total_execution_whiffs: int = 0
var total_overkill: int = 0
var total_floated_ap: int = 0
var battles_with_whiffs: int = 0

var class_records: Dictionary = {}
var map_tag_records: Dictionary = {}
var tier_rows: Array[Dictionary] = []
var matchup_snippets: Array[Dictionary] = []

var curator: Dictionary = {}
var raw_rows: Array[Dictionary] = []
var ai_samples: Array[Dictionary] = []

var collision_heatmap: Dictionary = {}
var spawn_quadrant_records: Dictionary = {}
var turn_histogram: Dictionary = {}
var meta_diversity_pct: float = 0.0
var timeline_entries: Array[Dictionary] = []
var missing_classes: PackedStringArray = PackedStringArray()
var parse_errors: int = 0

var skill_meta_rows: Array[Dictionary] = []
var class_combat_rows: Array[Dictionary] = []
var ai_commander_meta: Dictionary = {}
var total_sim_turns: int = 0
var passive_meta_rows: Array[Dictionary] = []
var economy_per_turn: Dictionary = {}

var previous_player_win_pct: float = -1.0
var previous_avg_turns: float = -1.0
var previous_integrity: float = -1.0


func is_empty() -> bool:
	return total_battles <= 0


func has_full_confidence() -> bool:
	return total_battles >= MIN_SAMPLE_FULL_CONFIDENCE


func sample_gate_label(metric_name: String) -> String:
	if has_full_confidence():
		return ""
	return (
		"Not enough data for %s. Requires %d matches. (Current: %d)"
		% [metric_name, MIN_SAMPLE_FULL_CONFIDENCE, total_battles]
	)


func format_pct_delta(current: float, previous: float, suffix: String = "%") -> String:
	if previous < 0.0:
		return "— (no prior snapshot)"
	var delta: float = current - previous
	var sign: String = "+" if delta >= 0.0 else ""
	return "%s%.1f%s vs last batch" % [sign, delta, suffix]


func class_display_name(class_id: Variant) -> String:
	var key: String = str(class_id)
	if key.is_empty():
		return "Unknown"
	var def: UnitData = DataLibrary.get_unit(StringName(key))
	if def != null and def.display_name != "":
		return def.display_name
	return key.substr(0, 1).to_upper() + key.substr(1)


func row_for_run_id(run_id: int) -> Dictionary:
	for row: Dictionary in raw_rows:
		if int(row.get("run_id", -1)) == run_id:
			return row
	return {}


func wilson_margin(wins: int, total: int, z: float = 1.96) -> float:
	if total <= 0:
		return 100.0
	var p: float = float(wins) / float(total)
	var z2: float = z * z
	var denom: float = 1.0 + z2 / float(total)
	var center: float = p + z2 / (2.0 * float(total))
	var spread: float = z * sqrt((p * (1.0 - p) + z2 / (4.0 * float(total))) / float(total))
	return (spread / denom) * 100.0
