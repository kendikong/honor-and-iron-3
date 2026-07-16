class_name AutobattlerMetrics
extends RefCounted

## Context weights and context checking
static func compute_context(board: BoardState, profile: AIProfile, A: float) -> CommanderContext:
	var ctx = CommanderContext.new()
	ctx.aggression = A
	
	if profile != null:
		ctx.w_lethality = profile.base_lethality_weight + (profile.weight_lethality_aggro_scale * A)
		ctx.w_survivability = (profile.base_survivability_weight * profile.weight_surv_base_scale) * (1.0 - A)
		ctx.w_position = profile.base_position_weight + (1.0 - A)
		
		var healer_count = 0
		var player_count = 0
		var enemy_count = 0
		
		for u in board.units:
			if u.is_alive():
				if u.is_enemy():
					enemy_count += 1
				else:
					player_count += 1
					if _is_support(u):
						healer_count += 1
						
		if player_count > 0:
			if healer_count == 0:
				ctx.w_survivability *= profile.weight_healer_absence_scale
				ctx.healer_absence_bonus_applied = true
				
			var density := float(enemy_count) / float(player_count)
			if density >= 1.5:
				ctx.w_survivability *= profile.weight_density_swarm_scale
				ctx.w_lethality *= profile.weight_density_swarm_scale
				ctx.density_bonus_applied = true
				
	return ctx

static func _is_support(unit: UnitState) -> bool:
	if unit.definition == null or unit.active_abilities.is_empty(): return false
	var has_dmg = false
	for ab in unit.active_abilities:
		for ef in ab.effects:
			if ef.type == GameEnums.EffectType.HEAL or ef.type == GameEnums.EffectType.ARMOR_UP: return true
			if ef.type == GameEnums.EffectType.DAMAGE: has_dmg = true
	return not has_dmg

static func _has_damage_ability(unit: UnitState) -> bool:
	if unit.definition == null or unit.active_abilities.is_empty(): return false
	for ab in unit.active_abilities:
		for ef in ab.effects:
			if ef.type == GameEnums.EffectType.DAMAGE or ef.type == GameEnums.EffectType.EXPLODE or ef.type == GameEnums.EffectType.RANGED_EXPLODE:
				return true
	return false

static func _max_ability_damage(unit: UnitState) -> int:
	var max_dmg = 0
	if unit.definition != null and not unit.active_abilities.is_empty():
		for ab in unit.active_abilities:
			for ef in ab.effects:
				if ef.type == GameEnums.EffectType.DAMAGE or ef.type == GameEnums.EffectType.EXPLODE or ef.type == GameEnums.EffectType.RANGED_EXPLODE:
					if ef.amount > max_dmg:
						max_dmg = ef.amount
	if max_dmg == 0:
		max_dmg = maxi(unit.current_strength, unit.current_magic)
	return max_dmg

static func evaluate_vector(base_state: BoardState, final_state: BoardState, vector: TeamVector, ctx: CommanderContext, profile: AIProfile) -> void:
	if profile == null:
		profile = AIProfile.new()
		
	# To gather events for Level 5 Attribution, we run a headless simulation of the vector's actions.
	var plan = Timeline.new()
	plan.entries = vector.actions
	var sim_res = Simulator.simulate(base_state, plan)
	var events = sim_res.events
	
	var leth_dict = _calc_lethality(base_state, final_state, profile)
	var surv_dict = _calc_survivability(base_state, final_state, profile)
	var pos_dict = _calc_positioning(base_state, final_state, profile)
	var pot_dict = _calc_potential(base_state, final_state, profile)
	var pen_dict = _calc_penalties(base_state, final_state, vector, ctx.aggression, pos_dict.total, profile)
	
	var score_leth = leth_dict.total
	var score_surv = surv_dict.total
	var score_pos = pos_dict.total
	var score_pot = pot_dict.total
	var pens = pen_dict.total
	
	var final_util = (score_leth * ctx.w_lethality) + (score_surv * ctx.w_survivability) + (score_pos * ctx.w_position) + (score_pot * 1.0) - pens
	
	var attribution = _calc_attribution(events)
	
	vector.utility_score = final_util
	vector.telemetry = {
		"actions": vector.actions,
		"lethality": leth_dict,
		"survivability": surv_dict,
		"position": pos_dict,
		"potential": pot_dict,
		"penalties": pen_dict,
		"attribution": attribution,
		"context": {
			"aggression": ctx.aggression,
			"w_lethality": ctx.w_lethality,
			"w_survivability": ctx.w_survivability,
			"w_position": ctx.w_position
		},
		"total": final_util
	}

static func _calc_attribution(events: Array[SimEvent]) -> Dictionary:
	var attr = {}
	for ev in events:
		if not ev.data.has("actor_id"): continue
		var a_id = ev.data["actor_id"]
		if not attr.has(a_id):
			attr[a_id] = {"dmg_dealt": 0.0, "heal_shield": 0.0, "hazards": 0, "spawns": 0, "moved": 0}
			
		if ev.type == GameEnums.SimEventType.UNIT_DAMAGED:
			attr[a_id].dmg_dealt += ev.data.get("amount", 0.0)
		elif ev.type == GameEnums.SimEventType.UNIT_HEALED or ev.type == GameEnums.SimEventType.UNIT_ARMORED:
			attr[a_id].heal_shield += ev.data.get("amount", 0.0)
		elif ev.type == GameEnums.SimEventType.STATUS_APPLIED:
			attr[a_id].hazards += 1
		elif ev.type == GameEnums.SimEventType.UNIT_SPAWNED:
			attr[a_id].spawns += 1
		elif ev.type == GameEnums.SimEventType.UNIT_MOVED:
			attr[a_id].moved += 1
	return attr

static func _calc_lethality(base: BoardState, final: BoardState, profile: AIProfile) -> Dictionary:
	var b_leth = 0.0
	var f_leth = 0.0
	var enemies_data = []
	for u in base.units:
		if u.is_enemy():
			var u_f = final.get_unit_by_id(u.id)
			if u_f == null: continue
			var b_eff = 0.0; var b_threat = 0.0; var b_exec = 0.0
			var f_eff = 0.0; var f_threat = 0.0; var f_exec = 0.0
			var b_tot = 0.0; var f_tot = 0.0
			if u.is_alive():
				b_eff = float(u.health.current_hp) + float(u.armor)
				b_threat = 1.0 + (float(_max_ability_damage(u)) * profile.lethality_threat_scale)
				b_exec = 2.0 - (float(u.health.current_hp) / float(u.health.max_hp))
				b_tot = b_eff * b_threat * b_exec
				b_leth += b_tot
			if u_f.is_alive():
				f_eff = float(u_f.health.current_hp) + float(u_f.armor)
				f_threat = 1.0 + (float(_max_ability_damage(u_f)) * profile.lethality_threat_scale)
				f_exec = 2.0 - (float(u_f.health.current_hp) / float(u_f.health.max_hp))
				f_tot = f_eff * f_threat * f_exec
				f_leth += f_tot
			
			enemies_data.append({
				"id": u.id,
				"class": u.definition.display_name if u.definition else "Unknown",
				"b_eff": b_eff, "b_threat": b_threat, "b_exec": b_exec, "b_tot": b_tot,
				"f_eff": f_eff, "f_threat": f_threat, "f_exec": f_exec, "f_tot": f_tot,
				"delta": b_tot - f_tot
			})
	return {
		"total": b_leth - f_leth,
		"b_sum": b_leth,
		"f_sum": f_leth,
		"enemies": enemies_data
	}

static func _calc_survivability(base: BoardState, final: BoardState, profile: AIProfile) -> Dictionary:
	if profile == null:
		profile = AIProfile.new()
	var b_surv = 0.0
	var f_surv = 0.0
	var allies_data = []
	for u in base.units:
		if not u.is_enemy():
			var u_f = final.get_unit_by_id(u.id)
			if u_f == null: continue
			var b_dict = _ally_surv_dict(base, u, profile)
			var f_dict = _ally_surv_dict(final, u_f, profile)
			if u.is_alive(): b_surv += b_dict.post
			if u_f.is_alive(): f_surv += f_dict.post
			allies_data.append({
				"id": u.id,
				"class": u.definition.display_name if u.definition else "Unknown",
				"b_val": b_dict.val, "b_inc": b_dict.inc, "b_post": b_dict.post, "b_death_pen": b_dict.death_pen,
				"f_val": f_dict.val, "f_inc": f_dict.inc, "f_post": f_dict.post, "f_death_pen": f_dict.death_pen,
				"delta": f_dict.post - b_dict.post
			})
	return {
		"total": f_surv - b_surv,
		"b_sum": b_surv,
		"f_sum": f_surv,
		"allies": allies_data
	}

static func _ally_surv_dict(state: BoardState, u: UnitState, profile: AIProfile) -> Dictionary:
	if not u.is_alive(): return {"val": 0.0, "inc": 0.0, "post": 0.0, "death_pen": false}
	var max_hp = float(u.health.max_hp)
	var squishy = profile.surv_squishy_numerator / max_hp
	var val = (float(u.health.current_hp) + float(u.armor)) * squishy
	var inc = 0.0
	for intent in state.intents:
		for act in intent.actions:
			if act.type == GameEnums.ActionType.ABILITY and act.target_unit_id == u.id:
				var e = state.get_unit_by_id(intent.enemy_id)
				if e and e.definition:
					for ab in e.active_abilities:
						for ef in ab.effects:
							if ef.type == GameEnums.EffectType.DAMAGE: inc += float(ef.amount)
	var post = maxf(0.0, val - inc)
	var death_pen = false
	if post <= 0: 
		post -= (max_hp * squishy * 2.0)
		death_pen = true
	return {"val": val, "inc": inc, "post": post, "death_pen": death_pen}

static func _nearest_of_team(board: BoardState, pos: Vector2i, find_enemy: bool, ignore_id: int) -> UnitState:
	var best_dist = 9999
	var best_u = null
	for u in board.units:
		if not u.is_alive() or u.id == ignore_id: continue
		if u.is_enemy() == find_enemy:
			var d = GridSystem.manhattan(pos, u.position)
			if d < best_dist:
				best_dist = d
				best_u = u
	return best_u

static func _calc_positioning(base: BoardState, final: BoardState, profile: AIProfile) -> Dictionary:
	var pos = 0.0
	var center = Vector2.ZERO
	var count = 0
	var cohesion_tot = 0.0
	var terrain_tot = 0.0
	var sweet_tot = 0.0
	var cohesion_data = []
	var isolation_list = []
	
	for u in final.units:
		if u.is_alive() and not u.is_enemy():
			center += Vector2(u.position)
			count += 1
	if count > 0: center /= float(count)
	
	for u in final.units:
		if not u.is_alive() or u.is_enemy(): continue
		var n = _nearest_of_team(final, u.position, false, u.id)
		var d_n = float(GridSystem.manhattan(u.position, n.position)) if n else 0.0
		var d_c = absf(float(u.position.x) - center.x) + absf(float(u.position.y) - center.y)
		var blend = (d_n * profile.cohesion_nearest_ally_weight) + (d_c * profile.cohesion_team_center_weight)
		var is_iso = false
		if blend > profile.cohesion_safe_distance: 
			var pen = (blend - profile.cohesion_safe_distance) * profile.cohesion_excess_dist_penalty
			pos -= pen
			cohesion_tot -= pen
			is_iso = true
			isolation_list.append(u.id)
		cohesion_data.append({"id": u.id, "blend": blend, "is_iso": is_iso})
		
		var t = final.get_tile(u.position)
		if t and t.definition: 
			pos += float(t.definition.fortitude)
			terrain_tot += float(t.definition.fortitude)
			
		if GridSystem.is_hazard(final, u.position): 
			pos -= profile.position_hazard_penalty
			terrain_tot -= profile.position_hazard_penalty
		
		var en = _nearest_of_team(final, u.position, true, u.id)
		var d_en = float(GridSystem.manhattan(u.position, en.position)) if en else 999.0
		if u.definition:
			var nm = u.definition.display_name
			if nm == "Lancer" and d_en == 2.0: 
				pos += profile.position_sweet_spot_bonus
				sweet_tot += profile.position_sweet_spot_bonus
			elif (nm == "Mage" or nm == "Archer") and d_en <= 1.0: 
				pos -= profile.position_sweet_spot_bonus
				sweet_tot -= profile.position_sweet_spot_bonus
				
	return {
		"total": pos,
		"cohesion_tot": cohesion_tot,
		"terrain_tot": terrain_tot,
		"sweet_tot": sweet_tot,
		"cohesion_data": cohesion_data,
		"isolation_list": isolation_list
	}

static func _calc_potential(base: BoardState, final: BoardState, profile: AIProfile) -> Dictionary:
	var pot = 0.0
	var spec = profile.potential_stat_specialization_scale if profile else 1.0
	var stat_tot = 0.0
	var hazard_tot = 0.0
	
	for u in final.units:
		if u.is_alive() and u.is_enemy():
			for s in u.active_statuses:
				if s.type in [GameEnums.StatusType.BURN, GameEnums.StatusType.POISON, GameEnums.StatusType.BLEED]:
					pot += profile.potential_dot_weight
					stat_tot += profile.potential_dot_weight
				else:
					var sv = float(max(1.0, float(abs(s.value))))
					pot += profile.potential_stat_point_weight * spec * sv
					stat_tot += profile.potential_stat_point_weight * spec * sv
				
				
	return {
		"total": pot,
		"stat_tot": stat_tot,
		"hazard_tot": hazard_tot
	}

static func _calc_penalties(base: BoardState, final: BoardState, vector: TeamVector, A: float, pos_score: float, profile: AIProfile) -> Dictionary:
	var pen = 0.0
	var ap_tax = 0.0
	var mov_tax = 0.0
	var disp_pen = 0.0
	
	for act in vector.actions:
		if act.type == GameEnums.ActionType.ABILITY and act.ability:
			ap_tax += float(act.ability.action_point_cost) * profile.penalty_ap_tax
			
			var is_disp = false
			var is_dmg = false
			for ef in act.ability.effects:
				if ef.type in [GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL, GameEnums.EffectType.SWAP]: is_disp = true
				if ef.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]: is_dmg = true
			if is_disp and not is_dmg and pos_score < 2.0:
				disp_pen += profile.penalty_displacement_loop
				
				
		elif act.type == GameEnums.ActionType.MOVE:
			if act.waypoints.size() > 0:
				mov_tax += float(act.waypoints.size()) * profile.penalty_mov_tax
				
	pen = ap_tax + mov_tax + disp_pen
	return {
		"total": pen,
		"ap_tax": ap_tax,
		"mov_tax": mov_tax,
		"disp_pen": disp_pen
	}

static func score_fast_pass(board: BoardState, unit: UnitState, action: Dictionary, profile: AIProfile, A: float) -> float:
	if profile == null:
		profile = AIProfile.new()
		
	var score = 0.0
	var target_dist = 0.0
	var center_dist = 0.0
	var dest: Vector2i = action.dest
	
	if dest != unit.position:
		var n = _nearest_of_team(board, dest, true, unit.id)
		if n:
			var d_b = GridSystem.manhattan(unit.position, n.position)
			var d_f = GridSystem.manhattan(dest, n.position)
			target_dist = float(d_b - d_f)
			
		var team_center = Vector2.ZERO
		var alive_count = 0
		for u in board.units:
			if u.is_alive() and not u.is_enemy():
				team_center += Vector2(u.position)
				alive_count += 1
		if alive_count > 0:
			team_center /= float(alive_count)
			var dc_b = float(GridSystem.manhattan(unit.position, Vector2i(roundi(team_center.x), roundi(team_center.y))))
			var dc_f = float(GridSystem.manhattan(dest, Vector2i(roundi(team_center.x), roundi(team_center.y))))
			center_dist = float(dc_b - dc_f)
			
		var t = board.get_tile(dest)
		if t and t.definition:
			score += float(t.definition.fortitude) * profile.search_fortitude_weight * (1.25 - A)
			
		score += target_dist * profile.search_distance_weight * (A + 0.25)
		score += center_dist * profile.search_cohesion_weight * (1.25 - A)
		
	if action.has("ability_index") and action.ability_index != null:
		var ab = unit.active_abilities[action.ability_index]
		var hp = 0.0
		var dmg = 0.0
		for ef in ab.effects:
			if ef.type == GameEnums.EffectType.DAMAGE: dmg += float(ef.amount)
			if ef.type == GameEnums.EffectType.HEAL: hp += float(ef.amount)
			
		score += dmg * profile.search_damage_weight * (A + 0.5)
		score += hp * profile.search_healing_weight * (1.5 - A)
		score -= float(ab.action_point_cost) * profile.search_ap_tax
		
	return score

