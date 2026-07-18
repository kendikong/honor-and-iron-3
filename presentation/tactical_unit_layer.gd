class_name TacticalUnitLayer
extends Node2D

## LPC unit sprites on the tactical grid (Phase 5).

const _CharacterActor = preload("res://scripts/lpc/character_actor.gd")
const _FloatingTextScene = preload("res://presentation/floating_text.tscn")

const BAR_W: float = 14.0
const BAR_H: float = 3.0
const BAR_OFFSET_Y: float = 6.0

const _COLOR_HP_BG := Color(0.08, 0.08, 0.10, 0.92)
const _COLOR_HP_FILL := Color(0.38, 0.78, 0.46)
const _COLOR_HP_PREDICTED := Color(0.95, 0.45, 0.35, 0.85)
const _COLOR_HP_LOSS := Color(0.95, 0.25, 0.22)
const _COLOR_ARMOR := Color(0.9, 0.8, 0.2)
const _COLOR_SELECT_PLAYER := Color(0.28, 0.58, 1.0, 1.0)
const _COLOR_SELECT_ENEMY := Color(1.0, 0.20, 0.16, 1.0)
const _COLOR_DRAG_TARGET := Color(1.0, 0.38, 0.22, 0.92)
const DRAG_SNAPBACK_SEC: float = 0.24
const _COLOR_HIT_BURST := Color(1.0, 0.2, 0.15, 0.9)

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState
var _catalog: LpcCatalog
var _profile: CharacterGenProfile = CharacterGenProfile.new()
var _actors: Dictionary = {}
var _selected_id: int = -1
var _glow_selected_id: int = -1
var _timeline_hover_id: int = -1
var _intent_units: Dictionary = {}
var _predicted_hp: Dictionary = {}
var _predicted_armor: Dictionary = {}
var _phase: int = CombatDirector.Phase.PLANNING
var _move_tweens: Dictionary = {}
var _active_push_tweens: int = 0
var _damage_flash: Dictionary = {}
var _hit_bursts: Array = []
var _last_attacker_pos: Dictionary = {}
var _pending_death: Dictionary = {}
var _drag_target_id: int = -1
var _drag_preview_id: int = -1
var _drag_preview_active: bool = false
var _drag_preview_failed: bool = false
var _planning_input: CombatPlanningInput

enum DragPreviewAnim { IDLE, WALK, RUN, ATTACK, SPELL }

signal push_tweens_idle


func get_active_push_tweens() -> int:
	return _active_push_tweens


func get_actor(unit_id: int) -> CharacterActor:
	return _actors.get(unit_id)


func get_actor_map() -> Dictionary:
	return _actors


func setup(map_view: TacticalMapView, director: CombatDirector, profile: CharacterGenProfile = null) -> void:
	_map_view = map_view
	_director = director
	z_as_relative = false
	z_index = 10
	if profile != null:
		_profile = profile
	else:
		_load_profile()
	_catalog = LpcCatalog.load_from_disk()
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		_phase = phase
		if not CombatDirector.is_planning_phase(phase):
			for unit_id: Variant in _move_tweens.keys():
				_kill_move_tween(int(unit_id))
		for actor: Variant in _actors.values():
			if actor is CharacterActor:
				(actor as CharacterActor).set_planning_exhausted(false)
				if not CombatDirector.is_planning_phase(phase):
					(actor as CharacterActor).set_running(false)
		_refresh_selection_glow()
		queue_redraw(),
	)
	set_process(true)
	queue_redraw()


func set_timeline_hover(unit_id: int) -> void:
	_timeline_hover_id = unit_id
	queue_redraw()


func set_intent_units(units: Dictionary) -> void:
	_intent_units = units
	queue_redraw()


func bind_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input


func set_predicted_stats(hp: Dictionary, armor: Dictionary) -> void:
	_predicted_hp = hp
	_predicted_armor = armor
	queue_redraw()


func clear_predicted_stats() -> void:
	_predicted_hp.clear()
	_predicted_armor.clear()
	queue_redraw()


func is_sprites_active() -> bool:
	return not _actors.is_empty()


func refresh_display_scale() -> void:
	var scale: float = _display_scale()
	for id: Variant in _actors.keys():
		var actor: CharacterActor = _actors[id]
		if actor != null:
			actor.set_display_scale(scale)


func _load_profile() -> void:
	_profile.load_from_user_disk()


func _display_scale() -> float:
	return UnitVisualFactory.display_scale_for_profile(_profile)


func _on_board_changed(board: BoardState) -> void:
	_board = board
	_sync_actors()
	_refresh_planning_visuals()
	queue_redraw()


func _on_preview_updated(result: SimResult) -> void:
	_preview_board = result.final_state
	queue_redraw()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	_refresh_planning_visuals()
	queue_redraw()


func _on_timeline_changed(_timeline: Timeline, _statuses: PackedStringArray) -> void:
	_refresh_planning_visuals()
	if _director != null and CombatDirector.is_planning_phase(_director.phase):
		_sync_planning_actor_positions()


func _refresh_planning_visuals() -> void:
	for unit_id: Variant in _actors:
		var actor: CharacterActor = _actors[unit_id] as CharacterActor
		if actor != null:
			actor.modulate = Color.WHITE
	if _board != null:
		for unit: UnitState in _board.units:
			if unit.is_alive() and not unit.is_enemy():
				_apply_exhaustion_state(unit)
	_refresh_selection_glow()


func _refresh_selection_glow() -> void:
	var planning: bool = CombatDirector.is_planning_phase(_phase)
	var new_glow_id: int = _selected_id if planning else -1
	if new_glow_id == _glow_selected_id:
		return
	if _glow_selected_id >= 0:
		_set_unit_selection_glow(_glow_selected_id, false)
	_glow_selected_id = new_glow_id
	if new_glow_id >= 0:
		var unit := _board.get_unit_by_id(new_glow_id) if _board != null else null
		var color: Color = _COLOR_SELECT_ENEMY if unit != null and unit.is_enemy() else _COLOR_SELECT_PLAYER
		_set_unit_selection_glow(new_glow_id, true, color)


func _set_unit_selection_glow(unit_id: int, active: bool, color: Color = _COLOR_SELECT_PLAYER) -> void:
	var actor: CharacterActor = _actors.get(unit_id) as CharacterActor
	if actor == null:
		return
	actor.set_selection_glow(active, color)


func set_drag_attack_target(unit_id: int) -> void:
	if _drag_target_id == unit_id:
		return
	_reset_drag_target_modulate()
	_drag_target_id = unit_id
	_apply_drag_target_modulate()
	queue_redraw()


func clear_drag_attack_target() -> void:
	if _drag_target_id < 0:
		return
	_reset_drag_target_modulate()
	_drag_target_id = -1
	queue_redraw()


func _reset_drag_target_modulate() -> void:
	if _drag_target_id < 0:
		return
	var unit := _board.get_unit_by_id(_drag_target_id) if _board != null else null
	if unit != null:
		_apply_exhaustion_state(unit)


func _apply_drag_target_modulate() -> void:
	if _drag_target_id < 0:
		return
	var actor: CharacterActor = _actors.get(_drag_target_id)
	if actor == null:
		return
	var pulse: float = 0.65 + 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 85.0))
	actor.modulate = Color(1.0 + 1.1 * pulse, 1.0 + 0.65 * pulse, 0.35 + 0.45 * pulse, 1.0)


func apply_sim_event(event: SimEvent) -> void:
	if _board == null:
		return
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			if _should_animate_move(event):
				_animate_move(event)
			else:
				_snap_move(event)
		GameEnums.SimEventType.UNIT_PUSHED, GameEnums.SimEventType.COLLISION:
			_animate_push(event)
		GameEnums.SimEventType.ABILITY_USED:
			if not DataLibrary.is_universal_wait(event.data.get("ability", &"")):
				_record_attack_source(event)
				_play_attack_anim(event)
		GameEnums.SimEventType.COUNTER_ATTACK:
			_record_counter_source(event)
			_play_attack_anim(event)
		GameEnums.SimEventType.UNIT_DAMAGED:
			var target_id: int = int(event.data.get("unit", -1))
			var hp: int = int(event.data.get("hp", 0))
			var target := _board.get_unit_by_id(target_id)
			if target != null:
				target.health.current_hp = hp
			var damage_taken: int = (
				int(event.data.get("hp_damaged", 0))
				+ int(event.data.get("armor_damaged", 0))
			)
			if damage_taken > 0:
				_damage_flash[target_id] = 0.85
				_spawn_hit_burst(target_id)
				var actor: CharacterActor = _actors.get(target_id)
				if actor != null and target != null and not actor.is_dying():
					var kb: Vector2 = _knockback_dir_for(target_id)
					actor.play_hurt(_facing_anim(target.facing), kb)
		GameEnums.SimEventType.UNIT_DIED:
			_begin_death(int(event.data.get("unit", -1)))
		GameEnums.SimEventType.UNIT_FACED:
			var face_id: int = int(event.data.get("unit", -1))
			var faced := _board.get_unit_by_id(face_id)
			if faced != null:
				var new_facing: int = int(event.data.get("facing", faced.facing))
				faced.facing = new_facing
				_apply_facing(face_id, new_facing)
	queue_redraw()


func _sync_actors() -> void:
	if _board == null:
		return
	var live: Dictionary = {}
	for unit in _board.units:
		if not unit.is_alive():
			continue
		live[unit.id] = true
		_ensure_actor(unit)
		if _drag_preview_active and unit.id == _drag_preview_id:
			pass
		elif _move_tweens.has(unit.id):
			pass
		elif _is_planning_phase() and not unit.is_enemy():
			_sync_planning_unit_position(unit)
		else:
			_position_actor(unit.id, unit.position)
		if not (_drag_preview_active and unit.id == _drag_preview_id):
			if not _move_tweens.has(unit.id):
				_apply_facing(unit.id, unit.facing)
			_apply_exhaustion_state(unit)
		_update_depth(unit.id)
	for id: Variant in _actors.keys():
		if not live.has(id) and not _pending_death.has(id):
			_remove_actor(int(id))
	_refresh_selection_glow()


func _record_attack_source(event: SimEvent) -> void:
	var target_id: int = int(event.data.get("target_unit", -1))
	var actor_id: int = int(event.data.get("actor", -1))
	var attacker := _board.get_unit_by_id(actor_id) if _board != null else null
	if target_id >= 0 and attacker != null:
		_last_attacker_pos[target_id] = attacker.position


func _record_counter_source(event: SimEvent) -> void:
	var target_id: int = int(event.data.get("target_unit", -1))
	var actor_id: int = int(event.data.get("actor", -1))
	var attacker := _board.get_unit_by_id(actor_id) if _board != null else null
	if target_id >= 0 and attacker != null:
		_last_attacker_pos[target_id] = attacker.position


func _knockback_dir_for(unit_id: int) -> Vector2:
	var victim := _board.get_unit_by_id(unit_id) if _board != null else null
	if victim == null:
		return Vector2.ZERO
	if _last_attacker_pos.has(unit_id):
		var from_pos: Vector2i = _last_attacker_pos[unit_id]
		var delta := victim.position - from_pos
		if delta != Vector2i.ZERO:
			return Vector2(delta).normalized()
	return -_facing_vector(victim.facing)


func _facing_vector(facing: int) -> Vector2:
	match facing:
		GameEnums.Facing.NORTH:
			return Vector2(0.0, -1.0)
		GameEnums.Facing.WEST:
			return Vector2(-1.0, 0.0)
		GameEnums.Facing.SOUTH:
			return Vector2(0.0, 1.0)
		_:
			return Vector2(1.0, 0.0)


func _spawn_hit_burst(unit_id: int) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	_hit_bursts.append({
		"pos": actor.position,
		"time": 0.38,
		"max": 0.38,
	})


func _begin_death(dead_id: int) -> void:
	if dead_id < 0 or _pending_death.has(dead_id):
		return
	var dead := _board.get_unit_by_id(dead_id) if _board != null else null
	if dead != null:
		dead.health.current_hp = 0
	_pending_death[dead_id] = true
	var kb: Vector2 = _knockback_dir_for(dead_id)
	_last_attacker_pos.erase(dead_id)
	var actor: CharacterActor = _actors.get(dead_id)
	if actor == null:
		_finish_death(dead_id)
		return
	var facing: int = dead.facing if dead != null else GameEnums.Facing.SOUTH
	actor.play_death(_facing_anim(facing), kb, func() -> void:
		_finish_death(dead_id)
	)


func _finish_death(unit_id: int) -> void:
	_pending_death.erase(unit_id)
	_remove_actor(unit_id)


func _ensure_actor(unit: UnitState) -> void:
	if _actors.has(unit.id):
		return
	var actor: CharacterActor = _CharacterActor.new()
	actor.name = "Unit_%d" % unit.id
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(actor)
	var recipe: CharacterRecipe = UnitVisualFactory.roll_recipe(
		_catalog, _profile, unit.id, int(unit.team),
	)
	actor.apply_recipe(recipe)
	actor.set_display_scale(_display_scale())
	actor.rebuild_contact_shadow(_map_view.get_effects_settings())
	_actors[unit.id] = actor


func spawn_floating_damage(unit_id: int, amount: int, dmg_type: StringName) -> void:
	if amount <= 0 or _map_view == null:
		return
	var actor: CharacterActor = _actors.get(unit_id)
	var spawn_pos: Vector2
	if actor != null:
		spawn_pos = actor.position + Vector2(0.0, -30.0)
	elif _board != null:
		var unit := _board.get_unit_by_id(unit_id)
		if unit == null:
			return
		spawn_pos = _map_view.grid_to_foot_local(unit.position) + Vector2(0.0, -30.0)
	else:
		return
	spawn_pos += Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 2.0))
	var color: Color = _damage_number_color(dmg_type)
	var ui_scale: float = _floating_text_scale()
	var label: String = ("+%d" % amount) if dmg_type == &"heal" else str(amount)
	var ft: FloatingText = _FloatingTextScene.instantiate()
	ft.z_index = 40
	add_child(ft)
	ft.setup(spawn_pos, label, color, ui_scale)


func _floating_text_scale() -> float:
	return maxf(1.5, _display_scale() * 0.9)


func _damage_number_color(dmg_type: StringName) -> Color:
	match dmg_type:
		&"physical":
			return Color(1.0, 0.95, 0.9, 1.0)
		&"magical":
			return Color(0.72, 0.52, 1.0, 1.0)
		&"burn":
			return Color(1.0, 0.55, 0.12, 1.0)
		&"poison":
			return Color(0.62, 1.0, 0.42, 1.0)
		&"bleed":
			return Color(1.0, 0.22, 0.22, 1.0)
		&"heal":
			return Color(0.35, 0.98, 0.48, 1.0)
		&"hazard", &"chasm", &"collision":
			return Color(0.85, 0.45, 0.15, 1.0)
		_:
			return Color(1.0, 0.95, 0.9, 1.0)


func _remove_actor(unit_id: int) -> void:
	var actor: Variant = _actors.get(unit_id)
	if actor is CharacterActor:
		(actor as CharacterActor).queue_free()
	_actors.erase(unit_id)


func _position_actor(unit_id: int, cell: Vector2i) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	var foot: Vector2 = _map_view.grid_to_foot_local(cell)
	if actor.is_dying():
		actor.snap_to_anchor(foot)
	else:
		actor.position = foot


func _apply_facing(unit_id: int, facing: int) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	actor.set_facing(_facing_anim(facing))
	actor.set_walking(false)


func _apply_exhaustion_state(unit: UnitState) -> void:
	var actor: CharacterActor = _actors.get(unit.id)
	if actor == null:
		return
	if (
		_director == null
		or not CombatDirector.is_planning_phase(_director.phase)
		or unit.is_enemy()
	):
		actor.set_planning_exhausted(false)
		actor.set_running(false)
		return
	var projected := _director.projected_state
	var current: UnitState = projected.get_unit_by_id(unit.id) if projected != null else unit
	if current == null:
		actor.set_planning_exhausted(false)
		actor.set_running(false)
		return
	if _director.unit_has_wait_planned(current.id):
		actor.set_planning_exhausted(true)
		actor.set_running(current.has_status(GameEnums.StatusType.RUNNING))
		return
	var can_act: bool = current.ability.points_left > 0 and not current.turn_action_used
	var can_move: bool = (
		current.movement.points_left > 0
		and not current.has_status(GameEnums.StatusType.ROOT)
		and not current.has_status(GameEnums.StatusType.STUN)
		and _director.get_planning_move_timing(current.id) >= 0
	)
	actor.set_planning_exhausted(not can_act and not can_move)
	actor.set_running(current.has_status(GameEnums.StatusType.RUNNING))


func _update_depth(unit_id: int) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null or _map_view == null:
		return
	TreeGameplay.apply_character_depth(
		actor,
		_map_view.get_player_grid(),
		_map_view.get_trees_layer(),
		_map_view.get_overlay_layer(),
		_map_view.get_effects_settings(),
	)


func _should_animate_move(event: SimEvent) -> bool:
	if event.data.get("teleport", false):
		return false
	var unit_id: int = int(event.data.get("actor", -1))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if CombatDirector.is_planning_phase(_phase):
		return unit != null and not unit.is_enemy()
	if unit != null and unit.is_enemy():
		return true
	if event.data.get("is_dash", false):
		return true
	if CombatDirector.is_executing_phase(_phase):
		var timing: int = int(event.data.get("move_timing", GameEnums.MoveTiming.PRE_ACTION))
		return timing == GameEnums.MoveTiming.POST_ACTION
	return true


func _snap_move(event: SimEvent) -> void:
	var unit_id: int = int(event.data.get("actor", -1))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit == null:
		return
	var path: Array = event.data.get("path", [])
	var to_coord: Variant = event.data.get("to", null)
	if not path.is_empty():
		var last: Variant = path[path.size() - 1]
		if last is Vector2i:
			unit.position = last
	elif to_coord is Vector2i:
		unit.position = to_coord
	var from_coord: Vector2i = event.data.get("from", unit.position)
	if not path.is_empty():
		var last_cell: Variant = path[path.size() - 1]
		if last_cell is Vector2i:
			var prev: Vector2i = from_coord
			if path.size() >= 2 and path[path.size() - 2] is Vector2i:
				prev = path[path.size() - 2]
			unit.facing = _facing_toward(prev, last_cell)
	elif event.data.has("facing"):
		unit.facing = int(event.data.get("facing", unit.facing))
	_kill_move_tween(unit_id)
	if _actor_grid_cell(unit_id) == unit.position:
		_apply_facing(unit_id, unit.facing)
		_update_depth(unit_id)
		return
	_position_actor(unit_id, unit.position)
	_apply_facing(unit_id, unit.facing)
	_update_depth(unit_id)


func _is_planning_phase() -> bool:
	if _director != null:
		return CombatDirector.is_planning_phase(_director.phase)
	return CombatDirector.is_planning_phase(_phase)


func _sync_planning_actor_positions() -> void:
	if _board == null or _map_view == null or not _is_planning_phase():
		return
	for unit: UnitState in _board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		if _drag_preview_active and unit.id == _drag_preview_id:
			continue
		if _move_tweens.has(unit.id):
			continue
		_sync_planning_unit_position(unit)


func _sync_planning_unit_position(unit: UnitState) -> void:
	var target: Vector2i = unit.position
	var current_cell: Vector2i = _actor_grid_cell(unit.id)
	if current_cell == target:
		_apply_facing(unit.id, unit.facing)
		_update_depth(unit.id)
		return
	if _should_rubberband_planning_move(unit.id, current_cell, target):
		_rubberband_actor_to_cell(unit.id, target)
		return
	_animate_planning_path(unit.id, current_cell, target, _unit_uses_run_anim(unit.id))


func _turn_start_cell(unit_id: int) -> Vector2i:
	if _director != null and _director.base_board != null:
		var start_unit: UnitState = _director.base_board.get_unit_by_id(unit_id)
		if start_unit != null:
			return start_unit.position
	if _board != null:
		var live_unit: UnitState = _board.get_unit_by_id(unit_id)
		if live_unit != null:
			return live_unit.position
	return Vector2i.ZERO


func _should_rubberband_planning_move(
	unit_id: int,
	from_cell: Vector2i,
	to_cell: Vector2i,
) -> bool:
	var start_cell: Vector2i = _turn_start_cell(unit_id)
	return GridSystem.manhattan(to_cell, start_cell) < GridSystem.manhattan(from_cell, start_cell)


func _rubberband_actor_to_cell(unit_id: int, cell: Vector2i) -> void:
	var actor: CharacterActor = _actors.get(unit_id) as CharacterActor
	if actor == null or _map_view == null:
		return
	var dest: Vector2 = _map_view.grid_to_foot_local(cell)
	if actor.position.distance_to(dest) <= 1.5:
		_position_actor(unit_id, cell)
		var unit: UnitState = _board.get_unit_by_id(unit_id) if _board != null else null
		if unit != null:
			_apply_facing(unit_id, unit.facing)
			_update_depth(unit_id)
		return
	_kill_move_tween(unit_id)
	actor.set_running(false)
	actor.set_walking(false)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(actor, "position", dest, DRAG_SNAPBACK_SEC)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_position_actor(unit_id, cell)
		var u: UnitState = _board.get_unit_by_id(unit_id) if _board != null else null
		if u != null:
			_apply_facing(unit_id, u.facing)
			_update_depth(unit_id)
	)


func _actor_grid_cell(unit_id: int) -> Vector2i:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null or _map_view == null:
		return Vector2i(-999, -999)
	return _map_view.foot_local_to_grid(actor.position)


func _unit_uses_run_anim(unit_id: int) -> bool:
	var projected := _proj_unit(unit_id)
	if projected != null and projected.has_status(GameEnums.StatusType.RUNNING):
		return true
	return false


func _find_display_path(from_cell: Vector2i, to_cell: Vector2i, unit: UnitState) -> Array[Vector2i]:
	if from_cell == to_cell or _board == null or unit == null:
		return []
	var path_board: BoardState = _board.clone()
	var path_unit: UnitState = path_board.get_unit_by_id(unit.id)
	if path_unit == null:
		return []
	GridSystem.set_occupant(path_board, path_unit.position, -1)
	path_unit.position = from_cell
	GridSystem.set_occupant(path_board, from_cell, path_unit.id)
	var move_cost: int = 2 if unit.has_status(GameEnums.StatusType.BLEED) else 1
	var mt: int = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	return MovementSystem.find_path(path_board, from_cell, to_cell, 999, mt, move_cost)


func _animate_planning_path(
	unit_id: int,
	from_cell: Vector2i,
	to_cell: Vector2i,
	use_run: bool,
) -> void:
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit == null:
		return
	var cells: Array[Vector2i] = _find_display_path(from_cell, to_cell, unit)
	if cells.is_empty():
		_position_actor(unit_id, to_cell)
		_apply_facing(unit_id, unit.facing)
		_update_depth(unit_id)
		return
	unit.position = to_cell
	if cells.size() >= 1:
		var prev: Vector2i = from_cell if cells.size() == 1 else cells[cells.size() - 2]
		unit.facing = _facing_toward(prev, cells[cells.size() - 1])
	_apply_facing(unit_id, unit.facing)
	_play_cell_path_tween(unit_id, from_cell, cells, CombatDirector.MOVE_STEP_TIME, use_run)


func _play_cell_path_tween(
	unit_id: int,
	start_cell: Vector2i,
	cells: Array[Vector2i],
	step_time: float,
	use_run: bool,
	per_step: Callable = Callable(),
) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null or _map_view == null or cells.is_empty():
		return
	_kill_move_tween(unit_id)
	actor.position = _map_view.grid_to_foot_local(start_cell)
	actor.set_running(use_run)
	actor.set_walking(true)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	for step_index: int in range(cells.size()):
		var cell: Vector2i = cells[step_index]
		tween.tween_property(actor, "position", _map_view.grid_to_foot_local(cell), step_time)
		if per_step.is_valid():
			tween.tween_callback(per_step.bind(step_index))
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		actor.set_walking(false)
		var live := _board.get_unit_by_id(unit_id) if _board != null else null
		actor.set_running(live != null and live.has_status(GameEnums.StatusType.RUNNING))
		_update_depth(unit_id)
	)


func _animate_move(event: SimEvent) -> void:
	var unit_id: int = int(event.data.get("actor", -1))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit == null:
		return
	var path: Array = event.data.get("path", [])
	if path.is_empty() and event.data.has("to"):
		path = [event.data["to"]]
	var step_time: float = CombatDirector.MOVE_STEP_TIME
	if event.data.get("is_dash", false):
		step_time = float(event.data.get("dash_step_time", CombatDirector.DASH_STEP_TIME))
	var from_coord: Vector2i = event.data.get("from", unit.position)
	var movement_points_before: int = int(
		event.data.get("movement_points_before", unit.movement.points_left)
	)
	var movement_points_left: int = int(
		event.data.get("movement_points_left", unit.movement.points_left)
	)
	var movement_cost_per_tile: int = int(event.data.get("movement_cost_per_tile", 0))
	var cells: Array[Vector2i] = []
	if path.is_empty():
		cells.append(from_coord)
	else:
		for raw: Variant in path:
			if raw is Vector2i:
				cells.append(raw)
	if cells.is_empty():
		return
	var start_cell: Vector2i = from_coord
	unit.position = cells[cells.size() - 1]
	unit.movement.points_left = movement_points_before
	var facing: int = unit.facing
	if cells.size() >= 2:
		facing = _facing_toward(cells[cells.size() - 2], cells[cells.size() - 1])
		unit.facing = facing
	_apply_facing(unit_id, facing)
	if _actors.get(unit_id) == null:
		_position_actor(unit_id, unit.position)
		_update_depth(unit_id)
		return
	var use_run: bool = (
		unit.has_status(GameEnums.StatusType.RUNNING)
		or _unit_uses_run_anim(unit_id)
	)
	var step_cb := func(step_index: int) -> void:
		var remaining: int = maxi(
			movement_points_left,
			movement_points_before - ((step_index + 1) * movement_cost_per_tile),
		)
		_set_movement_points(unit_id, remaining)
	_play_cell_path_tween(unit_id, start_cell, cells, step_time, use_run, step_cb)


func _set_movement_points(unit_id: int, points_left: int) -> void:
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit != null:
		unit.movement.points_left = points_left
	queue_redraw()


func _animate_push(event: SimEvent) -> void:
	var unit_id: int = int(event.data.get("actor", event.data.get("unit", -1)))
	var to_coord: Variant = event.data.get("to", null)
	if not to_coord is Vector2i:
		return
	var unit := _board.get_unit_by_id(unit_id)
	if unit != null:
		unit.position = to_coord
	_tween_push(unit_id, to_coord as Vector2i)


func _tween_push(unit_id: int, cell: Vector2i) -> void:
	_active_push_tweens += 1
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		_position_actor(unit_id, cell)
		_finish_push_tween()
		return
	_kill_move_tween(unit_id)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	tween.tween_property(
		actor,
		"position",
		_map_view.grid_to_foot_local(cell),
		0.22,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_update_depth(unit_id)
		_finish_push_tween()
	)


func _finish_push_tween() -> void:
	_active_push_tweens = maxi(0, _active_push_tweens - 1)
	if _active_push_tweens == 0:
		push_tweens_idle.emit()


func _tween_to_cell(unit_id: int, cell: Vector2i, step_time: float) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		_position_actor(unit_id, cell)
		return
	_kill_move_tween(unit_id)
	actor.set_walking(true)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	tween.tween_property(actor, "position", _map_view.grid_to_foot_local(cell), step_time)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		actor.set_walking(false)
		_update_depth(unit_id)
	)


func _kill_move_tween(unit_id: int) -> void:
	var existing: Variant = _move_tweens.get(unit_id)
	if existing is Tween:
		(existing as Tween).kill()
	_move_tweens.erase(unit_id)


func _play_attack_anim(event: SimEvent) -> void:
	var unit_id: int = int(event.data.get("actor", -1))
	_kill_move_tween(unit_id)
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	var facing: int = int(event.data.get("facing", GameEnums.Facing.SOUTH))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if event.data.has("target_coord"):
		var target_coord: Vector2i = event.data["target_coord"]
		if unit != null:
			facing = _facing_toward(unit.position, target_coord)
	elif event.data.has("target_unit"):
		var target := _board.get_unit_by_id(int(event.data["target_unit"])) if _board != null else null
		if target != null and unit != null:
			facing = _facing_toward(unit.position, target.position)
	var anim: StringName = _attack_anim(facing)
	var thrust_dir: Vector2 = _facing_vector(facing)
	if unit != null and event.data.has("target_coord"):
		var to_coord: Vector2i = event.data["target_coord"]
		var delta := to_coord - unit.position
		if delta != Vector2i.ZERO:
			thrust_dir = Vector2(delta).normalized()
	elif unit != null and event.data.has("target_unit"):
		var target_unit := _board.get_unit_by_id(int(event.data["target_unit"]))
		if target_unit != null:
			var delta2 := target_unit.position - unit.position
			if delta2 != Vector2i.ZERO:
				thrust_dir = Vector2(delta2).normalized()
	var ability_id: StringName = event.data.get("ability", &"")
	var ability_data: AbilityData = _ability_for_event(unit_id, ability_id)
	if ability_data != null and (ability_data.is_movement_skill or DataLibrary.is_universal_run(ability_data.id)):
		actor.play_spellcast(_spell_anim(facing))
		return
	if ability_data != null and not AbilitySystem.ability_uses_attack_animation(ability_data):
		actor.play_spellcast(_spell_anim(facing))
		return
	actor.play_attack_thrust(thrust_dir, anim)


func _ability_for_event(unit_id: int, ability_id: StringName) -> AbilityData:
	if _board == null or ability_id == &"":
		return null
	var unit := _board.get_unit_by_id(unit_id)
	if unit == null:
		return null
	for ability: AbilityData in unit.active_abilities:
		if ability.id == ability_id:
			return ability
	return null


func _attack_anim(facing: int) -> StringName:
	match facing:
		GameEnums.Facing.NORTH:
			return &"thrust_up"
		GameEnums.Facing.WEST:
			return &"thrust_left"
		GameEnums.Facing.SOUTH:
			return &"thrust_down"
		_:
			return &"thrust_right"


func _facing_toward(from: Vector2i, to: Vector2i) -> int:
	if to.x > from.x:
		return GameEnums.Facing.EAST
	if to.x < from.x:
		return GameEnums.Facing.WEST
	if to.y > from.y:
		return GameEnums.Facing.SOUTH
	if to.y < from.y:
		return GameEnums.Facing.NORTH
	return GameEnums.Facing.EAST


func begin_drag_preview(unit_id: int) -> void:
	_drag_preview_id = unit_id
	_drag_preview_active = true
	_kill_move_tween(unit_id)


func end_drag_preview(snap_back: bool = false) -> void:
	if _drag_preview_id < 0:
		return
	var unit_id: int = _drag_preview_id
	_drag_preview_active = false
	_drag_preview_id = -1
	_drag_preview_failed = false
	clear_drag_attack_target()
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	var actor: CharacterActor = _actors.get(unit_id)
	if unit == null or actor == null:
		return
	var home: Vector2 = _map_view.grid_to_foot_local(unit.position)
	if snap_back and actor.position.distance_to(home) > 1.5:
		_kill_move_tween(unit_id)
		actor.set_running(false)
		actor.set_walking(true)
		actor.modulate = Color.WHITE
		var tween: Tween = create_tween()
		_move_tweens[unit_id] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(actor, "position", home, DRAG_SNAPBACK_SEC)
		tween.finished.connect(func() -> void:
			_move_tweens.erase(unit_id)
			_finish_drag_preview_at_home(unit_id, unit)
		)
		return
	_finish_drag_preview_at_home(unit_id, unit)


func _finish_drag_preview_at_home(unit_id: int, unit: UnitState) -> void:
	_position_actor(unit_id, unit.position)
	_apply_facing(unit_id, unit.facing)
	_update_depth(unit_id)
	var actor: CharacterActor = _actors.get(unit_id)
	if actor != null:
		actor.modulate = Color.WHITE
		actor.set_running(false)
		actor.set_walking(false)
	_apply_exhaustion_state(unit)


func update_drag_preview(
	map_local: Vector2,
	anim_mode: int,
	facing: int,
	preview_cell: Vector2i,
	failed: bool = false,
	cursor_cell: Vector2i = Vector2i(-999999, -999999),
) -> void:
	if not _drag_preview_active or _drag_preview_id < 0 or _map_view == null:
		return
	_drag_preview_failed = failed
	var actor: CharacterActor = _actors.get(_drag_preview_id)
	if actor == null:
		return
	if _board != null and _board.is_in_bounds(cursor_cell):
		var cell_center: Vector2 = _map_view.grid_to_local(cursor_cell)
		var foot: Vector2 = _map_view.grid_to_foot_local(cursor_cell)
		actor.position = foot + (map_local - cell_center)
	elif _board != null and _board.is_in_bounds(preview_cell):
		var cell_center: Vector2 = _map_view.grid_to_local(preview_cell)
		var foot: Vector2 = _map_view.grid_to_foot_local(preview_cell)
		actor.position = foot + (map_local - cell_center)
	else:
		var tile_px: float = float(TacticalConstants.TILE_PX)
		actor.position = map_local + Vector2(0.0, tile_px * 0.5)
	actor.modulate = Color.WHITE
	if failed:
		actor.modulate = Color(1.0, 0.45, 0.45, 1.0)
	match anim_mode:
		DragPreviewAnim.WALK:
			actor.set_running(false)
			actor.set_facing(_facing_anim(facing))
			actor.set_walking(true)
		DragPreviewAnim.RUN:
			actor.set_facing(_facing_anim(facing))
			actor.set_running(true)
			actor.set_walking(true)
		DragPreviewAnim.ATTACK:
			actor.set_running(false)
			actor.set_facing(_attack_anim(facing))
			actor.set_walking(true)
		DragPreviewAnim.SPELL:
			actor.set_running(false)
			actor.set_facing(_spell_anim(facing))
			actor.set_walking(true)
		_:
			actor.set_running(false)
			if facing >= 0:
				actor.set_facing(_facing_anim(facing))
			actor.set_walking(false)
	_update_depth(_drag_preview_id)


func _spell_anim(facing: int) -> StringName:
	match facing:
		GameEnums.Facing.NORTH:
			return &"spellcast_up"
		GameEnums.Facing.WEST:
			return &"spellcast_left"
		GameEnums.Facing.SOUTH:
			return &"spellcast_down"
		_:
			return &"spellcast_right"


func _facing_anim(facing: int) -> StringName:
	match facing:
		GameEnums.Facing.NORTH:
			return &"walk_up"
		GameEnums.Facing.WEST:
			return &"walk_left"
		GameEnums.Facing.SOUTH:
			return &"walk_down"
		_:
			return &"walk_right"


func _draw() -> void:
	if _board == null or _map_view == null:
		return
	for unit in _board.units:
		if not unit.is_alive() or _pending_death.has(unit.id):
			continue
		if _drag_preview_active and unit.id == _drag_preview_id:
			continue
		_draw_hp_bar(unit)
	if _drag_target_id >= 0:
		_draw_drag_target_glow(_drag_target_id)
	_draw_hit_bursts()
	if _drag_preview_active and _drag_preview_id >= 0 and _drag_preview_failed:
		var drag_unit := _board.get_unit_by_id(_drag_preview_id) if _board != null else null
		if drag_unit != null:
			var actor: CharacterActor = _actors.get(_drag_preview_id)
			if actor != null:
				_draw_centered_icon(actor.position + Vector2(0.0, -18.0), "🚫", Color.WHITE, 14)


func _draw_drag_target_glow(unit_id: int) -> void:
	if _map_view == null or _board == null:
		return
	var unit := _board.get_unit_by_id(unit_id)
	if unit == null:
		return
	var actor: CharacterActor = _actors.get(unit_id)
	var center: Vector2 = actor.position if actor != null else _map_view.grid_to_foot_local(unit.position)
	var pulse: float = 0.65 + 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 85.0))
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var ring_w: float = tile_px * 0.95
	var ring_h: float = tile_px * 1.02
	var foot_y: float = 2.0
	var rect := Rect2(
		center - Vector2(ring_w * 0.5, ring_h * 0.5 + foot_y),
		Vector2(ring_w, ring_h),
	)
	var glow := Color(_COLOR_DRAG_TARGET.r, _COLOR_DRAG_TARGET.g, _COLOR_DRAG_TARGET.b, pulse * 0.62)
	draw_rect(rect.grow(8.0), glow, true)
	draw_rect(rect.grow(5.0), Color(_COLOR_DRAG_TARGET.r, _COLOR_DRAG_TARGET.g, _COLOR_DRAG_TARGET.b, pulse * 0.38), true)
	draw_rect(rect.grow(2.5), Color(_COLOR_DRAG_TARGET.r, _COLOR_DRAG_TARGET.g, _COLOR_DRAG_TARGET.b, pulse * 0.9), false, 4.0)
	draw_rect(rect, Color.WHITE, false, 1.5)


func _draw_hit_bursts() -> void:
	var stale: Array[int] = []
	for i: int in range(_hit_bursts.size()):
		var burst: Dictionary = _hit_bursts[i]
		var pos: Vector2 = burst.get("pos", Vector2.ZERO)
		var t: float = float(burst.get("time", 0.0))
		var max_t: float = float(burst.get("max", 0.38))
		if t <= 0.0:
			stale.append(i)
			continue
		var progress: float = 1.0 - (t / maxf(max_t, 0.001))
		var radius: float = lerpf(4.0, 22.0, progress)
		var alpha: float = (1.0 - progress) * 0.75
		draw_arc(pos + Vector2(0.0, -20.0), radius, 0.0, TAU, 24, Color(1.0, 0.95, 0.9, alpha * 0.5), 2.0)
		draw_arc(pos + Vector2(0.0, -20.0), radius * 0.65, 0.0, TAU, 18, Color(_COLOR_HIT_BURST.r, _COLOR_HIT_BURST.g, _COLOR_HIT_BURST.b, alpha), 2.5)
	for idx: int in range(stale.size() - 1, -1, -1):
		_hit_bursts.remove_at(stale[idx])


func _tick_hit_bursts(delta: float) -> void:
	if _hit_bursts.is_empty():
		return
	for burst: Dictionary in _hit_bursts:
		burst["time"] = float(burst.get("time", 0.0)) - delta


func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	if _director != null and _director.projected_state != null:
		var proj_u := _director.projected_state.get_unit_by_id(unit_id)
		if proj_u != null:
			return proj_u
	if _preview_board != null:
		var pv := _preview_board.get_unit_by_id(unit_id)
		if pv != null:
			return pv
	if _board != null:
		return _board.get_unit_by_id(unit_id)
	return null


func _status_icon(status_type: int) -> String:
	match status_type:
		GameEnums.StatusType.STAT_BUFF_STR:
			return "💪"
		GameEnums.StatusType.STAT_BUFF_MAG:
			return "🔮"
		GameEnums.StatusType.STAT_BUFF_MP:
			return "👟"
		GameEnums.StatusType.STAT_BUFF_ACC:
			return "🎯"
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return "💔"
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return "👁️‍🗨️"
		GameEnums.StatusType.ELECTRIFIED:
			return "⚡"
		GameEnums.StatusType.WEAK_TRAP:
			return "🪤"
		GameEnums.StatusType.BURN:
			return "🔥"
		GameEnums.StatusType.BLEED:
			return "🩸"
		GameEnums.StatusType.POISON:
			return "🧪"
		GameEnums.StatusType.WEAKEN:
			return "📉"
		GameEnums.StatusType.VULNERABLE:
			return "🎯"
		GameEnums.StatusType.STUN:
			return "💫"
		GameEnums.StatusType.ROOT:
			return "🪢"
		GameEnums.StatusType.SILENCE:
			return "🤐"
		GameEnums.StatusType.TAUNT:
			return "🤬"
		GameEnums.StatusType.BLIND:
			return "🕶️"
		GameEnums.StatusType.PACIFY:
			return "🕊️"
		GameEnums.StatusType.FEAR:
			return "😱"
		GameEnums.StatusType.CONFUSION:
			return "😵"
		GameEnums.StatusType.PIERCE:
			return "🗡️"
		GameEnums.StatusType.GHOST:
			return "👻"
		GameEnums.StatusType.TRAMPLE:
			return "🦏"
		GameEnums.StatusType.STEALTH:
			return "🥷"
		GameEnums.StatusType.INTERCEPT:
			return "🛡️"
		GameEnums.StatusType.MARK:
			return "👁️"
		GameEnums.StatusType.STURDY:
			return "🧱"
		GameEnums.StatusType.INVULNERABLE:
			return "⭐"
		GameEnums.StatusType.AIRBORNE:
			return "🦅"
		GameEnums.StatusType.CANTO:
			return "🐎"
		GameEnums.StatusType.POLYMORPH:
			return "🐸"
		_:
			return "✨"


func _draw_hp_bar(unit: UnitState) -> void:
	var foot: Vector2 = _map_view.grid_to_foot_local(unit.position)
	var origin := foot + Vector2(-BAR_W * 0.5, BAR_OFFSET_Y)
	var current_hp: int = unit.health.current_hp
	var predicted: int = int(_predicted_hp.get(unit.id, current_hp))
	var max_hp: int = unit.health.max_hp
	if max_hp <= 0:
		return
	var armor: int = maxi(0, unit.armor)
	var predicted_armor: int = int(_predicted_armor.get(unit.id, armor))
	var fortitude: int = 0
	if _board != null and _board.is_in_bounds(unit.position):
		var tile := _board.get_tile(unit.position)
		if tile != null and tile.definition != null:
			fortitude = maxi(0, tile.definition.fortitude)
	var flash: float = float(_damage_flash.get(unit.id, 0.0))
	if flash > 0.0:
		var pulse: float = 0.65 + 0.35 * sin(flash * 28.0)
		draw_rect(
			Rect2(origin - Vector2(2.0, 2.0), Vector2(BAR_W + 4.0, BAR_H + 4.0)),
			Color(1.0, 0.08, 0.08, 0.55 * pulse),
			true,
		)
	var total_max: int = maxi(max_hp, maxi(current_hp + armor, predicted + predicted_armor))
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), _COLOR_HP_BG, true)
	var survive: int = clampi(mini(current_hp, predicted), 0, max_hp)
	var loss: int = clampi(current_hp - survive, 0, max_hp)
	var heal: int = clampi(predicted - current_hp, 0, maxi(0, total_max - current_hp))
	var survive_armor: int = clampi(mini(armor, predicted_armor), 0, total_max)
	var armor_loss: int = clampi(armor - survive_armor, 0, total_max)
	var armor_gain: int = clampi(predicted_armor - armor, 0, total_max)
	var survive_w: float = BAR_W * (float(survive) / float(total_max))
	var loss_w: float = BAR_W * (float(loss) / float(total_max))
	var heal_w: float = BAR_W * (float(heal) / float(total_max))
	var survive_armor_w: float = BAR_W * (float(survive_armor) / float(total_max))
	var armor_loss_w: float = BAR_W * (float(armor_loss) / float(total_max))
	var armor_gain_w: float = BAR_W * (float(armor_gain) / float(total_max))
	if survive_w > 0.0:
		var fill_color: Color = _COLOR_HP_FILL
		if flash > 0.0:
			fill_color = fill_color.lerp(Color(1.0, 0.08, 0.08), minf(1.0, flash * 2.8))
		draw_rect(Rect2(origin, Vector2(survive_w, BAR_H)), fill_color, true)
	var blink: float = 0.35 + 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
	if loss_w > 0.0:
		var col := Color(_COLOR_HP_LOSS.r, _COLOR_HP_LOSS.g, _COLOR_HP_LOSS.b, blink)
		draw_rect(Rect2(origin + Vector2(survive_w, 0.0), Vector2(loss_w, BAR_H)), col, true)
	if heal_w > 0.0:
		var col := Color(_COLOR_HP_FILL.r, _COLOR_HP_FILL.g, _COLOR_HP_FILL.b, blink)
		draw_rect(Rect2(origin + Vector2(survive_w, 0.0), Vector2(heal_w, BAR_H)), col, true)
	var hp_end_w: float = survive_w + maxf(loss_w, heal_w)
	if survive_armor_w > 0.0:
		draw_rect(Rect2(origin + Vector2(hp_end_w, 0.0), Vector2(survive_armor_w, BAR_H)), _COLOR_ARMOR, true)
	if armor_loss_w > 0.0:
		draw_rect(
			Rect2(origin + Vector2(hp_end_w + survive_armor_w, 0.0), Vector2(armor_loss_w, BAR_H)),
			Color(_COLOR_ARMOR.r, _COLOR_ARMOR.g, _COLOR_ARMOR.b, blink),
			true,
		)
	if armor_gain_w > 0.0:
		draw_rect(
			Rect2(origin + Vector2(hp_end_w + survive_armor_w, 0.0), Vector2(armor_gain_w, BAR_H)),
			Color(_COLOR_ARMOR.r, _COLOR_ARMOR.g, _COLOR_ARMOR.b, blink),
			true,
		)
	if fortitude > 0:
		var fort_w: float = maxf(2.0, BAR_W * 0.12)
		draw_rect(Rect2(origin + Vector2(BAR_W - fort_w, 0.0), Vector2(fort_w, BAR_H)), Color(0.35, 0.65, 0.35, 0.9), true)
	if not unit.active_statuses.is_empty():
		var start_x: float = origin.x + 4.0
		var start_y: float = origin.y + BAR_H + 1.0
		var count := 0
		for status: StatusData in unit.active_statuses:
			var pos := Vector2(start_x + float(count % 4) * 7.0, start_y + float(count / 4) * 7.0)
			_draw_status_icon(pos, _status_icon(status.type))
			count += 1


func _draw_status_icon(pos: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var size_px := 5
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - Vector2(0.0, sz.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)


func _draw_centered_icon(pos: Vector2, text: String, color: Color, size_px: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - sz * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _any_predicted_change() -> bool:
	if _board == null:
		return false
	for unit: UnitState in _board.units:
		if not unit.is_alive():
			continue
		var cur_hp: int = unit.health.current_hp
		var pred_hp: int = int(_predicted_hp.get(unit.id, cur_hp))
		var cur_ar: int = maxi(0, unit.armor)
		var pred_ar: int = int(_predicted_armor.get(unit.id, cur_ar))
		if pred_hp != cur_hp or pred_ar != cur_ar:
			return true
	return false


func _process(delta: float) -> void:
	var need_redraw := false
	if not _damage_flash.is_empty():
		_tick_damage_flash(delta)
		need_redraw = true
	if not _hit_bursts.is_empty():
		_tick_hit_bursts(delta)
		need_redraw = true
	if _drag_target_id >= 0:
		_apply_drag_target_modulate()
		need_redraw = true
	if _any_predicted_change():
		need_redraw = true
	if CombatDirector.is_planning_phase(_phase):
		need_redraw = true
	if need_redraw:
		queue_redraw()


func _tick_damage_flash(delta: float = 0.0) -> void:
	if _damage_flash.is_empty():
		return
	var step: float = delta if delta > 0.0 else 0.016
	var stale: Array[int] = []
	for unit_id: Variant in _damage_flash:
		_damage_flash[unit_id] = float(_damage_flash[unit_id]) - step
		if float(_damage_flash[unit_id]) <= 0.0:
			stale.append(int(unit_id))
	for unit_id: int in stale:
		_damage_flash.erase(unit_id)
	if not stale.is_empty() or delta > 0.0:
		queue_redraw()
