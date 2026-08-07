class_name SmartReplayCurator
extends RefCounted

## Purpose: Evaluates a batch of telemetry results and extracts the 5 key replays
## for the dashboard: Best, Worst, Median, Upset, and Most Chaotic.

var best_performance_id: int = -1
var worst_performance_id: int = -1
var median_match_id: int = -1
var biggest_upset_id: int = -1
var most_chaotic_id: int = -1

func curate(telemetry_list: Array) -> void:
	if telemetry_list.is_empty():
		return
		
	var sorted_by_efficiency = []
	var sorted_by_chaos = []
	
	for t in telemetry_list:
		var tid: int
		var t_winner: int
		var t_turns: int
		var chaos: int
		
		if t is SimulationTelemetry:
			tid = t.run_id
			t_winner = t.winner
			t_turns = t.turns_taken
			chaos = t.wall_collisions + t.chain_collisions + t.hazard_landings
		else:
			tid = t.get("run_id", -1)
			t_winner = t.get("winner", GameEnums.Team.NEUTRAL)
			t_turns = t.get("turns_taken", 0)
			chaos = t.get("wall_collisions", 0) + t.get("chain_collisions", 0) + t.get("hazard_landings", 0)
			
		# Efficiency heuristic: Player wins faster -> higher score.
		# Enemy wins faster -> lower score.
		var efficiency = 0.0
		if t_winner == GameEnums.Team.PLAYER:
			efficiency = 1000.0 - float(t_turns)
		elif t_winner == GameEnums.Team.ENEMY:
			efficiency = -1000.0 + float(t_turns)
			
		sorted_by_efficiency.append({"id": tid, "eff": efficiency})
		sorted_by_chaos.append({"id": tid, "chaos": chaos})
		
	if sorted_by_efficiency.is_empty():
		return
		
	sorted_by_efficiency.sort_custom(func(a, b): return a["eff"] > b["eff"])
	best_performance_id = sorted_by_efficiency.front()["id"]
	worst_performance_id = sorted_by_efficiency.back()["id"]
	
	var mid_index = sorted_by_efficiency.size() / 2
	median_match_id = sorted_by_efficiency[mid_index]["id"]
	
	sorted_by_chaos.sort_custom(func(a, b): return a["chaos"] > b["chaos"])
	most_chaotic_id = sorted_by_chaos.front()["id"]
	
	# Biggest upset heuristic: Player win that took the absolute longest / lowest efficiency
	var upset_candidates = sorted_by_efficiency.filter(func(a): return a["eff"] > 0)
	if not upset_candidates.is_empty():
		biggest_upset_id = upset_candidates.back()["id"]
	else:
		biggest_upset_id = median_match_id

func to_dict() -> Dictionary:
	return {
		"best_performance_id": best_performance_id,
		"worst_performance_id": worst_performance_id,
		"median_match_id": median_match_id,
		"biggest_upset_id": biggest_upset_id,
		"most_chaotic_id": most_chaotic_id
	}
