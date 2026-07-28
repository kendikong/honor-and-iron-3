class_name MassSimCombatStatsCollector
extends RefCounted

## Per-battle combat + skill + Commander-AI telemetry for mass sim meta / balance / AI tuning.

var _unit_meta: Dictionary = {}  # unit_id -> {class_id, team, ability_ids}
var _unit_lifecycle: Dictionary = {}  # unit_id -> {class_id, team, turns_alive, max_hp, lifespan_recorded}
var _skill: Dictionary = {}      # ability_key -> counters
var _class: Dictionary = {}      # class_id -> combat counters
var _turn: int = 0
var _total_turns: int = 0
var _pending_ability: Dictionary = {}  # actor_id -> ability_id
var _last_ability_actor: int = -1
var _ai_samples: Array[Dictionary] = []
var _turn_rollups: Array[Dictionary] = []

var _turn_damage_player: int = 0
var _turn_damage_enemy: int = 0
var _turn_heal_player: int = 0
var _turn_heal_enemy: int = 0
var _turn_skill_uses_player: int = 0
var _turn_skill_uses_enemy: int = 0
var _turn_holds_player: int = 0


func register_board(board: BoardState) -> void:
	_unit_meta.clear()
	_unit_lifecycle.clear()
	_skill.clear()
	_class.clear()
	for unit: UnitState in board.units:
		if unit.definition == null:
			continue
		var class_id: String = str(unit.definition.id)
		var ability_ids: PackedStringArray = PackedStringArray()
		for ab: AbilityData in unit.active_abilities:
			if ab == null:
				continue
			ability_ids.append(str(ab.id))
			_ensure_skill(class_id, str(ab.id), ab.display_name, unit.team)
		_unit_meta[unit.id] = {
			"class_id": class_id,
			"team": unit.team,
			"ability_ids": ability_ids,
		}
		_unit_lifecycle[unit.id] = {
			"class_id": class_id,
			"team": unit.team,
			"turns_alive": 0,
			"max_hp": maxi(unit.health.max_hp, 1),
			"lifespan_recorded": false,
		}
		_ensure_class(class_id, unit.team)


func begin_turn(turn_index: int) -> void:
	_turn = turn_index
	_turn_damage_player = 0
	_turn_damage_enemy = 0
	_turn_heal_player = 0
	_turn_heal_enemy = 0
	_turn_skill_uses_player = 0
	_turn_skill_uses_enemy = 0
	_turn_holds_player = 0
	_pending_ability.clear()
	_last_ability_actor = -1


func record_ai_decision(board: BoardState, team_vector: TeamVector, ai: AutobattlerAI) -> void:
	if team_vector == null:
		return
	var skill_commits: int = 0
	var move_only_units: int = 0
	for unit: UnitState in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var legal_skills_this_unit: Dictionary = {}
		for action: Variant in ai.get_legal_actions(board, unit):
			if not action is Dictionary:
				continue
			var ab_idx: Variant = (action as Dictionary).get("ability_index")
			if ab_idx == null:
				continue
			var meta: Dictionary = _unit_meta.get(unit.id, {})
			var class_id: String = String(meta.get("class_id", ""))
			var ab_list: Array = unit.active_abilities
			var idx: int = int(ab_idx)
			if idx < 0 or idx >= ab_list.size():
				continue
			var ab: AbilityData = ab_list[idx] as AbilityData
			if ab == null:
				continue
			var sk_key: String = _skill_key(int(meta.get("team", GameEnums.Team.PLAYER)), class_id, str(ab.id))
			legal_skills_this_unit[sk_key] = true
		for sk_key: Variant in legal_skills_this_unit.keys():
			if _skill.has(sk_key):
				(_skill[sk_key] as Dictionary)["turns_legal"] = int((_skill[sk_key] as Dictionary).get("turns_legal", 0)) + 1
	for act: TimelineAction in team_vector.actions:
		if act.type == GameEnums.ActionType.ABILITY and act.ability != null:
			skill_commits += 1
	for unit: UnitState in board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		var legal_skills: int = ai.count_legal_skill_options(board, unit)
		var used: bool = _timeline_has_skill_for_unit(team_vector.actions, unit.id)
		if legal_skills > 0 and not used:
			_turn_holds_player += 1
			var meta: Dictionary = _unit_meta.get(unit.id, {})
			var class_id: String = String(meta.get("class_id", ""))
			if _class.has(_class_key(class_id, GameEnums.Team.PLAYER)):
				var cr: Dictionary = _class[_class_key(class_id, GameEnums.Team.PLAYER)] as Dictionary
				cr["ai_holds"] = int(cr.get("ai_holds", 0)) + 1
				cr["ai_skill_opportunity_turns"] = int(cr.get("ai_skill_opportunity_turns", 0)) + 1
		elif legal_skills > 0:
			var meta2: Dictionary = _unit_meta.get(unit.id, {})
			var class_id2: String = String(meta2.get("class_id", ""))
			if _class.has(_class_key(class_id2, GameEnums.Team.PLAYER)):
				(_class[_class_key(class_id2, GameEnums.Team.PLAYER)] as Dictionary)["ai_skill_opportunity_turns"] = int((_class[_class_key(class_id2, GameEnums.Team.PLAYER)] as Dictionary).get("ai_skill_opportunity_turns", 0)) + 1
		var had_move: bool = false
		for act2: TimelineAction in team_vector.actions:
			if act2.actor_id == unit.id and act2.type == GameEnums.ActionType.MOVE:
				had_move = true
				break
		if had_move and not used:
			var meta3: Dictionary = _unit_meta.get(unit.id, {})
			var class_id3: String = String(meta3.get("class_id", ""))
			if _class.has(_class_key(class_id3, GameEnums.Team.PLAYER)):
				(_class[_class_key(class_id3, GameEnums.Team.PLAYER)] as Dictionary)["movement_only_turns"] = int((_class[_class_key(class_id3, GameEnums.Team.PLAYER)] as Dictionary).get("movement_only_turns", 0)) + 1
			move_only_units += 1
	_ai_samples.append({
		"turn": _turn,
		"utility_score": team_vector.utility_score,
		"fast_score": team_vector.fast_score,
		"passed_pruning": team_vector.passed_pruning,
		"skill_actions_committed": skill_commits,
		"holds": _turn_holds_player,
		"move_only_units": move_only_units,
		"telemetry": team_vector.telemetry.duplicate(true),
	})


func apply_events(events: Array, board: BoardState) -> void:
	for e: Variant in events:
		if not e is SimEvent:
			continue
		var event: SimEvent = e as SimEvent
		match event.type:
			GameEnums.SimEventType.ABILITY_USED:
				_on_ability_used(event, board)
			GameEnums.SimEventType.UNIT_DAMAGED:
				_on_damaged(event, board)
			GameEnums.SimEventType.UNIT_HEALED:
				_on_healed(event, board)
			GameEnums.SimEventType.UNIT_ARMORED:
				_on_armored(event, board)
			GameEnums.SimEventType.UNIT_DIED:
				_on_died(event, board)
			GameEnums.SimEventType.ACTION_FAILED:
				_on_action_failed(event)
			GameEnums.SimEventType.TURN_ENDED:
				_on_turn_ended(event, board)


func finalize_battle(board: BoardState) -> void:
	for unit: UnitState in board.units:
		var life: Dictionary = _unit_lifecycle.get(unit.id, {}) as Dictionary
		if life.is_empty() or bool(life.get("lifespan_recorded", false)):
			continue
		var class_id: String = String(life.get("class_id", ""))
		var team: int = int(life.get("team", GameEnums.Team.NEUTRAL))
		if class_id.is_empty() or not _class.has(_class_key(class_id, team)):
			continue
		_record_lifespan(class_id, team, int(life.get("turns_alive", 0)))
		var end_hp_pct: float = 0.0
		if unit.is_alive():
			end_hp_pct = float(unit.health.current_hp) / float(maxi(unit.health.max_hp, 1)) * 100.0
		_record_end_hp_pct(class_id, team, end_hp_pct)
		life["lifespan_recorded"] = true


func end_turn() -> void:
	_total_turns += 1
	_turn_rollups.append({
		"turn": _turn,
		"damage_player": _turn_damage_player,
		"damage_enemy": _turn_damage_enemy,
		"heal_player": _turn_heal_player,
		"heal_enemy": _turn_heal_enemy,
		"skill_uses_player": _turn_skill_uses_player,
		"skill_uses_enemy": _turn_skill_uses_enemy,
		"ai_holds": _turn_holds_player,
	})


func to_dict() -> Dictionary:
	var skill_rows: Array[Dictionary] = []
	for key: Variant in _skill.keys():
		var row: Dictionary = (_skill[key] as Dictionary).duplicate(true)
		var unit_turns: int = int(row.get("class_unit_turns", 1))
		row["uses_per_turn"] = float(row.get("uses", 0)) / float(maxi(unit_turns, 1))
		row["damage_per_turn"] = float(row.get("damage_dealt", 0)) / float(maxi(unit_turns, 1))
		row["heal_per_turn"] = float(row.get("healing_done", 0)) / float(maxi(unit_turns, 1))
		row["pick_rate_when_legal"] = (
			float(row.get("uses", 0)) / float(maxi(int(row.get("turns_legal", 0)), 1)) * 100.0
		)
		if int(row.get("team", GameEnums.Team.PLAYER)) != GameEnums.Team.PLAYER:
			row["pick_rate_when_legal"] = -1.0
		elif int(row.get("turns_legal", 0)) <= 0:
			row["pick_rate_when_legal"] = -1.0
		row["kills_per_turn"] = float(row.get("kills", 0)) / float(maxi(unit_turns, 1))
		skill_rows.append(row)
	skill_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("uses_per_turn", 0)) > float(b.get("uses_per_turn", 0))
	)
	var class_rows: Array[Dictionary] = []
	for ck: Variant in _class.keys():
		var cr: Dictionary = (_class[ck] as Dictionary).duplicate(true)
		var ut: int = int(cr.get("unit_turns", 1))
		cr["class_id"] = str(cr.get("class_id", ""))
		cr["team"] = int(cr.get("team", GameEnums.Team.NEUTRAL))
		cr["damage_dealt_per_turn"] = float(cr.get("damage_dealt", 0)) / float(maxi(ut, 1))
		cr["damage_taken_per_turn"] = float(cr.get("damage_taken", 0)) / float(maxi(ut, 1))
		cr["hp_damage_taken_per_turn"] = float(cr.get("hp_damage_taken", 0)) / float(maxi(ut, 1))
		cr["damage_mitigated_per_turn"] = float(cr.get("damage_mitigated", 0)) / float(maxi(ut, 1))
		cr["healing_per_turn"] = float(cr.get("healing_done", 0)) / float(maxi(ut, 1))
		cr["kills_per_turn"] = float(cr.get("kills", 0)) / float(maxi(ut, 1))
		cr["deaths_per_turn"] = float(cr.get("deaths", 0)) / float(maxi(ut, 1))
		var lifespan_samples: int = int(cr.get("lifespan_samples", 0))
		cr["avg_survival_turns"] = float(cr.get("lifespan_turns_sum", 0)) / float(maxi(lifespan_samples, 1))
		var end_hp_samples: int = int(cr.get("end_hp_pct_samples", 0))
		cr["avg_end_hp_pct"] = float(cr.get("end_hp_pct_sum", 0.0)) / float(maxi(end_hp_samples, 1))
		cr["has_survival_sample"] = lifespan_samples > 0
		var opp: int = int(cr.get("ai_skill_opportunity_turns", 0))
		cr["ai_hold_rate_pct"] = float(cr.get("ai_holds", 0)) / float(maxi(opp, 1)) * 100.0
		class_rows.append(cr)
	class_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("damage_dealt_per_turn", 0)) > float(b.get("damage_dealt_per_turn", 0))
	)
	var ai_summary: Dictionary = _summarize_ai()
	return {
		"total_turns": _total_turns,
		"skill_rows": skill_rows,
		"class_combat_rows": class_rows,
		"ai_commander": ai_summary,
		"ai_turn_samples": _ai_samples,
		"per_turn_rollups": _turn_rollups,
	}


func _summarize_ai() -> Dictionary:
	if _ai_samples.is_empty():
		return {}
	var util_sum: float = 0.0
	var holds: int = 0
	var commits: int = 0
	var pruned: int = 0
	for sample: Dictionary in _ai_samples:
		util_sum += float(sample.get("utility_score", 0.0))
		holds += int(sample.get("holds", 0))
		commits += int(sample.get("skill_actions_committed", 0))
		if not bool(sample.get("passed_pruning", true)):
			pruned += 1
	var n: int = _ai_samples.size()
	return {
		"avg_utility_per_turn": util_sum / float(maxi(n, 1)),
		"total_holds": holds,
		"total_skill_commits": commits,
		"holds_per_turn": float(holds) / float(maxi(_total_turns, 1)),
		"skill_commits_per_turn": float(commits) / float(maxi(_total_turns, 1)),
		"pruned_turns": pruned,
		"sample_turns": n,
	}


func _on_ability_used(event: SimEvent, board: BoardState) -> void:
	var actor_id: int = int(event.data.get("actor", -1))
	var ability_id: String = str(event.data.get("ability", ""))
	_pending_ability[actor_id] = ability_id
	_last_ability_actor = actor_id
	var meta: Dictionary = _unit_meta.get(actor_id, {})
	var class_id: String = String(meta.get("class_id", ""))
	var team: int = int(meta.get("team", GameEnums.Team.NEUTRAL))
	if class_id.is_empty():
		return
	var sk: Dictionary = _ensure_skill(class_id, ability_id, String(event.data.get("ability_name", ability_id)), team)
	sk["uses"] = int(sk.get("uses", 0)) + 1
	if team == GameEnums.Team.PLAYER:
		_turn_skill_uses_player += 1
	else:
		_turn_skill_uses_enemy += 1


func _on_damaged(event: SimEvent, _board: BoardState) -> void:
	var unit_id: int = int(event.data.get("unit", -1))
	var hp_dmg: int = int(event.data.get("hp_damaged", 0))
	var armor_dmg: int = int(event.data.get("armor_damaged", 0))
	var amount: int = hp_dmg + armor_dmg
	if amount <= 0:
		return
	var victim_meta: Dictionary = _unit_meta.get(unit_id, {})
	var victim_class: String = String(victim_meta.get("class_id", ""))
	var victim_team: int = int(victim_meta.get("team", GameEnums.Team.NEUTRAL))
	if not victim_class.is_empty() and _class.has(_class_key(victim_class, victim_team)):
		var vcr: Dictionary = _class[_class_key(victim_class, victim_team)] as Dictionary
		vcr["damage_taken"] = int(vcr.get("damage_taken", 0)) + amount
		vcr["hp_damage_taken"] = int(vcr.get("hp_damage_taken", 0)) + hp_dmg
		vcr["damage_mitigated"] = int(vcr.get("damage_mitigated", 0)) + armor_dmg
	if victim_team == GameEnums.Team.PLAYER:
		_turn_damage_player += amount
	else:
		_turn_damage_enemy += amount
	if _last_ability_actor < 0:
		return
	var attacker_meta: Dictionary = _unit_meta.get(_last_ability_actor, {})
	var attacker_class: String = String(attacker_meta.get("class_id", ""))
	var ability_id: String = str(_pending_ability.get(_last_ability_actor, ""))
	var attacker_team: int = int(attacker_meta.get("team", GameEnums.Team.NEUTRAL))
	if not attacker_class.is_empty() and _class.has(_class_key(attacker_class, attacker_team)):
		(_class[_class_key(attacker_class, attacker_team)] as Dictionary)["damage_dealt"] = int((_class[_class_key(attacker_class, attacker_team)] as Dictionary).get("damage_dealt", 0)) + amount
	if not ability_id.is_empty():
		var sk_key: String = _skill_key(attacker_team, attacker_class, ability_id)
		if _skill.has(sk_key):
			(_skill[sk_key] as Dictionary)["damage_dealt"] = int((_skill[sk_key] as Dictionary).get("damage_dealt", 0)) + amount


func _on_healed(event: SimEvent, board: BoardState) -> void:
	var unit_id: int = int(event.data.get("unit", -1))
	var amount: int = int(event.data.get("amount", 0))
	var meta: Dictionary = _unit_meta.get(unit_id, {})
	var class_id: String = String(meta.get("class_id", ""))
	var team: int = int(meta.get("team", GameEnums.Team.NEUTRAL))
	if class_id.is_empty():
		return
	if _class.has(_class_key(class_id, team)):
		(_class[_class_key(class_id, team)] as Dictionary)["healing_done"] = int((_class[_class_key(class_id, team)] as Dictionary).get("healing_done", 0)) + amount
	if team == GameEnums.Team.PLAYER:
		_turn_heal_player += amount
	else:
		_turn_heal_enemy += amount
	for pid: Variant in _pending_ability.keys():
		var ability_id: String = str(_pending_ability[pid])
		var attacker_class: String = String((_unit_meta.get(int(pid), {}) as Dictionary).get("class_id", ""))
		var attacker_team: int = int((_unit_meta.get(int(pid), {}) as Dictionary).get("team", GameEnums.Team.NEUTRAL))
		var sk_key: String = _skill_key(attacker_team, attacker_class, ability_id)
		if _skill.has(sk_key):
			(_skill[sk_key] as Dictionary)["healing_done"] = int((_skill[sk_key] as Dictionary).get("healing_done", 0)) + amount
		break


func _on_armored(event: SimEvent, board: BoardState) -> void:
	var unit_id: int = int(event.data.get("unit", -1))
	var amount: int = int(event.data.get("amount", 0))
	for pid: Variant in _pending_ability.keys():
		var ability_id: String = str(_pending_ability[pid])
		var attacker_class: String = String((_unit_meta.get(int(pid), {}) as Dictionary).get("class_id", ""))
		var attacker_team: int = int((_unit_meta.get(int(pid), {}) as Dictionary).get("team", GameEnums.Team.NEUTRAL))
		var sk_key: String = _skill_key(attacker_team, attacker_class, ability_id)
		if _skill.has(sk_key):
			(_skill[sk_key] as Dictionary)["armor_given"] = int((_skill[sk_key] as Dictionary).get("armor_given", 0)) + amount
		break


func _on_died(event: SimEvent, _board: BoardState) -> void:
	var unit_id: int = int(event.data.get("unit", -1))
	var meta: Dictionary = _unit_meta.get(unit_id, {})
	var class_id: String = String(meta.get("class_id", ""))
	var victim_team: int = int(meta.get("team", GameEnums.Team.NEUTRAL))
	if not class_id.is_empty() and _class.has(_class_key(class_id, victim_team)):
		(_class[_class_key(class_id, victim_team)] as Dictionary)["deaths"] = int((_class[_class_key(class_id, victim_team)] as Dictionary).get("deaths", 0)) + 1
	var life: Dictionary = _unit_lifecycle.get(unit_id, {}) as Dictionary
	if not life.is_empty() and not bool(life.get("lifespan_recorded", false)) and not class_id.is_empty():
		_record_lifespan(class_id, victim_team, int(life.get("turns_alive", 0)) + 1)
		_record_end_hp_pct(class_id, victim_team, 0.0)
		life["lifespan_recorded"] = true
	if _last_ability_actor < 0:
		return
	var attacker_meta: Dictionary = _unit_meta.get(_last_ability_actor, {})
	var attacker_class: String = String(attacker_meta.get("class_id", ""))
	var attacker_team: int = int(attacker_meta.get("team", GameEnums.Team.NEUTRAL))
	var ability_id: String = str(_pending_ability.get(_last_ability_actor, ""))
	if _class.has(_class_key(attacker_class, attacker_team)):
		(_class[_class_key(attacker_class, attacker_team)] as Dictionary)["kills"] = int((_class[_class_key(attacker_class, attacker_team)] as Dictionary).get("kills", 0)) + 1
	if not ability_id.is_empty():
		var sk_key: String = _skill_key(attacker_team, attacker_class, ability_id)
		if _skill.has(sk_key):
			(_skill[sk_key] as Dictionary)["kills"] = int((_skill[sk_key] as Dictionary).get("kills", 0)) + 1


func _on_action_failed(event: SimEvent) -> void:
	var reason: String = String(event.data.get("reason", ""))
	var actor_id: int = int(event.data.get("actor", -1))
	if reason.find("cannot_use") >= 0 or reason.find("whiff") >= 0:
		var ability_id: String = str(_pending_ability.get(actor_id, ""))
		var class_id: String = String((_unit_meta.get(actor_id, {}) as Dictionary).get("class_id", ""))
		var fail_team: int = int((_unit_meta.get(actor_id, {}) as Dictionary).get("team", GameEnums.Team.NEUTRAL))
		if not ability_id.is_empty():
			var sk_key: String = _skill_key(fail_team, class_id, ability_id)
			if _skill.has(sk_key):
				(_skill[sk_key] as Dictionary)["action_failed"] = int((_skill[sk_key] as Dictionary).get("action_failed", 0)) + 1


func _on_turn_ended(_event: SimEvent, board: BoardState) -> void:
	_last_ability_actor = -1
	_pending_ability.clear()
	for unit: UnitState in board.units:
		if not unit.is_alive():
			continue
		var meta: Dictionary = _unit_meta.get(unit.id, {})
		var class_id: String = String(meta.get("class_id", ""))
		var unit_team: int = int(meta.get("team", GameEnums.Team.NEUTRAL))
		if class_id.is_empty() or not _class.has(_class_key(class_id, unit_team)):
			continue
		var cr: Dictionary = _class[_class_key(class_id, unit_team)] as Dictionary
		cr["unit_turns"] = int(cr.get("unit_turns", 0)) + 1
		for ab_id: Variant in meta.get("ability_ids", []):
			var sk_key: String = _skill_key(unit_team, class_id, str(ab_id))
			if _skill.has(sk_key):
				(_skill[sk_key] as Dictionary)["class_unit_turns"] = int(cr.get("unit_turns", 0))
		var floated_ap: int = unit.ability.points_left if unit.ability != null else 0
		if floated_ap > 0:
			cr["floated_ap_turns"] = int(cr.get("floated_ap_turns", 0)) + 1
		var life: Dictionary = _unit_lifecycle.get(unit.id, {}) as Dictionary
		if not life.is_empty():
			life["turns_alive"] = int(life.get("turns_alive", 0)) + 1


func _ensure_skill(class_id: String, ability_id: String, display_name: String, team: int) -> Dictionary:
	var key: String = _skill_key(team, class_id, ability_id)
	if not _skill.has(key):
		_skill[key] = {
			"class_id": class_id,
			"ability_id": ability_id,
			"display_name": display_name,
			"team": team,
			"uses": 0,
			"turns_legal": 0,
			"damage_dealt": 0,
			"healing_done": 0,
			"armor_given": 0,
			"kills": 0,
			"action_failed": 0,
			"class_unit_turns": 0,
		}
	return _skill[key] as Dictionary


func _ensure_class(class_id: String, team: int) -> Dictionary:
	var key: String = _class_key(class_id, team)
	if not _class.has(key):
		_class[key] = {
			"class_id": class_id,
			"team": team,
			"unit_turns": 0,
			"damage_dealt": 0,
			"damage_taken": 0,
			"hp_damage_taken": 0,
			"damage_mitigated": 0,
			"healing_done": 0,
			"kills": 0,
			"deaths": 0,
			"lifespan_turns_sum": 0,
			"lifespan_samples": 0,
			"end_hp_pct_sum": 0.0,
			"end_hp_pct_samples": 0,
			"ai_holds": 0,
			"ai_skill_opportunity_turns": 0,
			"movement_only_turns": 0,
			"floated_ap_turns": 0,
		}
	return _class[key] as Dictionary


func _class_key(class_id: String, team: int) -> String:
	return "%d:%s" % [team, class_id]


func _skill_key(team: int, class_id: String, ability_id: String) -> String:
	return "%d:%s/%s" % [team, class_id, ability_id]


func _timeline_has_skill_for_unit(actions: Array, unit_id: int) -> bool:
	for act: Variant in actions:
		if act is TimelineAction:
			var ta: TimelineAction = act as TimelineAction
			if ta.actor_id == unit_id and ta.type == GameEnums.ActionType.ABILITY and ta.ability != null:
				return true
	return false


func _record_lifespan(class_id: String, team: int, turns: int) -> void:
	if not _class.has(_class_key(class_id, team)):
		return
	var cr: Dictionary = _class[_class_key(class_id, team)] as Dictionary
	cr["lifespan_turns_sum"] = int(cr.get("lifespan_turns_sum", 0)) + maxi(turns, 0)
	cr["lifespan_samples"] = int(cr.get("lifespan_samples", 0)) + 1


func _record_end_hp_pct(class_id: String, team: int, hp_pct: float) -> void:
	if not _class.has(_class_key(class_id, team)):
		return
	var cr: Dictionary = _class[_class_key(class_id, team)] as Dictionary
	cr["end_hp_pct_sum"] = float(cr.get("end_hp_pct_sum", 0.0)) + clampf(hp_pct, 0.0, 100.0)
	cr["end_hp_pct_samples"] = int(cr.get("end_hp_pct_samples", 0)) + 1
