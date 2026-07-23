class_name SimulationTelemetry
extends RefCounted

## Purpose: Aggregates the 7 levels of telemetry for a single simulated battle.
## Represents a serializable payload outputted by the MassBattleRunner.

var run_id: int = 0
var map_seed: int = 0
var map_tags: Array = []

var winner: int = GameEnums.Team.NEUTRAL
var turns_taken: int = 0
var completion_reason: String = "timeout"

var player_classes: Array = []
var enemy_classes: Array = []
var surviving_units: Array = []

var class_stats: Dictionary = {}
var skill_stats: Dictionary = {}
var floated_ap_turns: int = 0

var wall_collisions: int = 0
var chain_collisions: int = 0
var hazard_landings: int = 0
var friendly_fire_incidents: int = 0

var assisted_damage: int = 0
var assisted_shields: int = 0
var execution_whiffs: int = 0
var overkill_damage: int = 0

var ai_telemetry: Array = []

func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"map_seed": map_seed,
		"map_tags": map_tags,
		"winner": winner,
		"turns_taken": turns_taken,
		"completion_reason": completion_reason,
		"player_classes": player_classes,
		"enemy_classes": enemy_classes,
		"surviving_units": surviving_units,
		"class_stats": class_stats,
		"skill_stats": skill_stats,
		"floated_ap_turns": floated_ap_turns,
		"wall_collisions": wall_collisions,
		"chain_collisions": chain_collisions,
		"hazard_landings": hazard_landings,
		"friendly_fire_incidents": friendly_fire_incidents,
		"assisted_damage": assisted_damage,
		"assisted_shields": assisted_shields,
		"execution_whiffs": execution_whiffs,
		"overkill_damage": overkill_damage,
		"ai_telemetry": ai_telemetry
	}

static func from_dict(data: Dictionary) -> SimulationTelemetry:
	var t = SimulationTelemetry.new()
	t.run_id = data.get("run_id", 0)
	t.map_seed = data.get("map_seed", 0)
	t.map_tags = data.get("map_tags", [])
	t.winner = data.get("winner", GameEnums.Team.NEUTRAL)
	t.turns_taken = data.get("turns_taken", 0)
	t.completion_reason = data.get("completion_reason", "timeout")
	t.player_classes = data.get("player_classes", [])
	t.enemy_classes = data.get("enemy_classes", [])
	t.surviving_units = data.get("surviving_units", [])
	t.class_stats = data.get("class_stats", {})
	t.skill_stats = data.get("skill_stats", {})
	t.floated_ap_turns = data.get("floated_ap_turns", 0)
	t.wall_collisions = data.get("wall_collisions", 0)
	t.chain_collisions = data.get("chain_collisions", 0)
	t.hazard_landings = data.get("hazard_landings", 0)
	t.friendly_fire_incidents = data.get("friendly_fire_incidents", 0)
	t.assisted_damage = data.get("assisted_damage", 0)
	t.assisted_shields = data.get("assisted_shields", 0)
	t.execution_whiffs = data.get("execution_whiffs", 0)
	t.overkill_damage = data.get("overkill_damage", 0)
	t.ai_telemetry = data.get("ai_telemetry", [])
	return t
