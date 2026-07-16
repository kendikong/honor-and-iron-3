class_name AutobattlerAI
extends RefCounted

## Purpose: Commander AI Pipeline for the Autobattler.
## Responsibilities: Generates Fast-Pass candidate actions, bundles them into 
##   Team Vectors, simulates outcomes, applies Alpha-Beta pruning, and returns 
##   the highest utility TeamVector.

var aggressiveness: float = 0.5
var current_profile: AIProfile

func _init(profile: AIProfile = null, aggro: float = 0.5) -> void:
	current_profile = profile
	aggressiveness = aggro

func decide_team_vector(board: BoardState) -> TeamVector:
	var ctx = AutobattlerMetrics.compute_context(board, current_profile, aggressiveness)
	
	var player_units: Array[UnitState] = []
	for u in board.units:
		if u.is_alive() and not u.is_enemy():
			player_units.append(u)
			
	if player_units.is_empty():
		return null
		
	# ── 1. Fast-Pass (Candidate Generation) ──────────────────────────────
	var unit_candidates := {}
	var K := 2
	if current_profile != null:
		K = current_profile.search_depth_slider + 1
		
	for u in player_units:
		var legal_actions = _generate_legal_actions(board, u)
		
		# Generate diverse options by perturbing Aggressiveness (A)
		var perturbed_a1 = clampf(ctx.aggression + 0.25, 0.0, 1.0)
		var perturbed_a2 = clampf(ctx.aggression - 0.25, 0.0, 1.0)
		
		var candidates_1 = []
		var candidates_2 = []
		for act in legal_actions:
			var s1 = AutobattlerMetrics.score_fast_pass(board, u, act, current_profile, perturbed_a1)
			var s2 = AutobattlerMetrics.score_fast_pass(board, u, act, current_profile, perturbed_a2)
			candidates_1.append({"action": act, "score": s1})
			candidates_2.append({"action": act, "score": s2})
			
		candidates_1.sort_custom(func(a, b): return a.score > b.score)
		candidates_2.sort_custom(func(a, b): return a.score > b.score)
		
		var merged = []
		var hashes = {}
		
		for arr in [candidates_1, candidates_2]:
			for i in range(mini(K, arr.size())):
				var c = arr[i]
				var h = _hash_action(c.action)
				if not hashes.has(h):
					hashes[h] = true
					merged.append(c)
					
		merged.sort_custom(func(a, b): return a.score > b.score)
		var final_candidates = []
		for i in range(mini(K, merged.size())):
			final_candidates.append(merged[i])
			
		if final_candidates.is_empty():
			final_candidates.append({"action": {"dest": u.position, "ability_index": null, "target_id": null, "timeline_actions": []}, "score": 0.0})
			
		unit_candidates[u.id] = final_candidates

	# ── 2. Vector Bundling (Combinatorial) ────────────────────────────────
	var projected_hp = {}
	for u in board.units:
		if u.is_alive() and u.is_enemy():
			projected_hp[u.id] = float(u.health.current_hp + u.armor)
			
	var all_vectors = _build_vectors(board, player_units, unit_candidates, 0, [], 0.0, projected_hp)
	
	var best_vector: TeamVector = null
	var best_util = -INF
	var max_hp = 0.0
	for u in player_units:
		max_hp += float(u.health.max_hp)
		
	var prune_threshold = 0.4
	if current_profile != null:
		prune_threshold = current_profile.pruning_survivability_threshold
		
	var rejection_limit = -(max_hp * prune_threshold)
	
	var all_rejected = true
	var fallback_vector: TeamVector = null
	var fallback_fast_score = -INF
	
	var hash_cache = {}
	
	# ── 3. Simulation & Final Grading ─────────────────────────────────────
	for v in all_vectors:
		var sim_board = board.clone()
		var timeline = Timeline.new()
		for act in v.actions:
			timeline.add(act)
			
		var res = Simulator.simulate(sim_board, timeline)
		var state_hash = _hash_board_state(res.final_state)
		
		if hash_cache.has(state_hash):
			var cached = hash_cache[state_hash]
			v.utility_score = cached.utility_score
			v.telemetry = cached.telemetry
			v.passed_pruning = cached.passed_pruning
			continue
			
		# Alpha-Beta Pruning Lite
		var surv_dict = AutobattlerMetrics._calc_survivability(board, res.final_state, current_profile)
		if surv_dict.total < rejection_limit:
			v.passed_pruning = false
			if v.fast_score > fallback_fast_score:
				fallback_fast_score = v.fast_score
				fallback_vector = v
			continue
			
		all_rejected = false
		AutobattlerMetrics.evaluate_vector(board, res.final_state, v, ctx, current_profile)
		
		hash_cache[state_hash] = v
		
		if v.utility_score > best_util:
			best_util = v.utility_score
			best_vector = v
			
	if all_rejected and fallback_vector != null:
		print("[Commander AI] Doomsday Scenario! All vectors pruned. Falling back to best Fast-Pass vector.")
		var sim_board = board.clone()
		var timeline = Timeline.new()
		for act in fallback_vector.actions:
			timeline.add(act)
		var res = Simulator.simulate(sim_board, timeline)
		AutobattlerMetrics.evaluate_vector(board, res.final_state, fallback_vector, ctx, current_profile)
		best_vector = fallback_vector
		
	return best_vector

func _build_vectors(board: BoardState, units: Array[UnitState], unit_candidates: Dictionary, index: int, current_actions: Array[TimelineAction], current_fast_score: float, projected_hp: Dictionary) -> Array[TeamVector]:
	if index == units.size():
		var tv = TeamVector.new()
		tv.actions = current_actions.duplicate()
		tv.fast_score = current_fast_score
		return [tv]
		
	var u = units[index]
	var cands = unit_candidates[u.id]
	var res: Array[TeamVector] = []
	for c in cands:
		var target_id = c.action.get("target_id")
		if target_id != null and projected_hp.has(target_id):
			if projected_hp[target_id] <= 0.0:
				continue
				
		var n_actions = current_actions.duplicate()
		for ta in c.action.timeline_actions:
			n_actions.append(ta)
			
		var next_hp = projected_hp
		var ab_idx = c.action.get("ability_index")
		if ab_idx != null and target_id != null and projected_hp.has(target_id):
			var ab = u.active_abilities[ab_idx]
			var dmg = 0.0
			for ef in ab.effects:
				if ef.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]:
					dmg += float(ef.amount)
			if dmg > 0.0:
				next_hp = projected_hp.duplicate()
				next_hp[target_id] -= dmg
				
		res.append_array(_build_vectors(board, units, unit_candidates, index + 1, n_actions, current_fast_score + c.score, next_hp))
	return res

func _hash_action(action: Dictionary) -> String:
	return "%s_%s_%s" % [action.dest, action.ability_index, action.target_id]
	
func _hash_board_state(board: BoardState) -> String:
	var s = ""
	for u in board.units:
		if u.is_alive():
			s += "%d:%d,%d:%d:%d|" % [u.id, u.position.x, u.position.y, u.health.current_hp, u.armor]
	return s

func _generate_legal_actions(board: BoardState, unit: UnitState) -> Array:
	var actions = []
	var budget = unit.movement.points_left if unit.movement != null else 0
	var dests = [unit.position]
	
	for dx in range(-budget, budget + 1):
		for dy in range(-budget, budget + 1):
			var dist = abs(dx) + abs(dy)
			if dist > 0 and dist <= budget:
				var candidate = unit.position + Vector2i(dx, dy)
				if GridSystem.is_passable(board, candidate):
					if MovementSystem.find_path(board, unit.position, candidate, budget).size() > 0:
						dests.append(candidate)
						
	for dest in dests:
		var timeline_actions: Array[TimelineAction] = []
		if dest != unit.position:
			timeline_actions.append(TimelineAction.make_move(unit.id, dest))
			
		actions.append({
			"dest": dest,
			"ability_index": null,
			"target_id": null,
			"timeline_actions": timeline_actions.duplicate()
		})
		
		if unit.definition != null and not unit.active_abilities.is_empty():
			for i in range(unit.active_abilities.size()):
				var ability = unit.active_abilities[i]
				var rng = ability.range_tiles
				
				var is_harmful = false
				var is_helpful = false
				for ef in ability.effects:
					if ef.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]:
						is_harmful = true
					elif ef.type in [GameEnums.EffectType.HEAL, GameEnums.EffectType.ARMOR_UP]:
						is_helpful = true
						
				for target in board.units:
					if target.is_alive():
						# Core logic fix: Pre-filter valid targets so we never even generate suicidal actions
						var target_is_enemy = target.is_enemy() != unit.is_enemy()
						if is_harmful and not is_helpful and not target_is_enemy:
							continue
						if is_helpful and not is_harmful and target_is_enemy:
							continue
							
						if GridSystem.manhattan(dest, target.position) <= rng:
							var attack_actions = timeline_actions.duplicate()
							attack_actions.append(TimelineAction.make_ability(unit.id, ability, target.position, target.id))
							actions.append({
								"dest": dest,
								"ability_index": i,
								"target_id": target.id,
								"timeline_actions": attack_actions
							})
	return actions

