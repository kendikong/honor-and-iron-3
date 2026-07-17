class_name TacticalUnitLayer
extends Node2D

## LPC unit sprites on the tactical grid (Phase 5).

const _CharacterActor = preload("res://scripts/lpc/character_actor.gd")

const BAR_W: float = 14.0
const BAR_H: float = 3.0
const BAR_OFFSET_Y: float = 6.0

const _COLOR_HP_BG := Color(0.08, 0.08, 0.10, 0.92)
const _COLOR_HP_FILL := Color(0.38, 0.78, 0.46)
const _COLOR_INTENT := Color(0.95, 0.35, 0.35, 0.7)
const _COLOR_TIMELINE_HOVER := Color(1.0, 1.0, 1.0, 0.8)
const _COLOR_HP_PREDICTED := Color(0.95, 0.45, 0.35, 0.85)
const _COLOR_HP_LOSS := Color(0.95, 0.25, 0.22)
const _COLOR_ARMOR := Color(0.9, 0.8, 0.2)
const _COLOR_SELECT := Color(0.98, 0.86, 0.32, 0.95)
const _COLOR_SELECT_GLOW := Color(0.98, 0.86, 0.32, 0.25)

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState
var _catalog: LpcCatalog
var _profile: CharacterGenProfile = CharacterGenProfile.new()
var _actors: Dictionary = {}
var _selected_id: int = -1
var _timeline_hover_id: int = -1
var _intent_units: Dictionary = {}
var _predicted_hp: Dictionary = {}
var _predicted_armor: Dictionary = {}
var _phase: int = CombatDirector.Phase.PLANNING_PHASE_1
var _move_tweens: Dictionary = {}
var _active_push_tweens: int = 0
var _damage_flash: Dictionary = {}
var _drag_preview_id: int = -1
var _drag_preview_active: bool = false
var _drag_preview_failed: bool = false
var _planning_input: CombatPlanningInput

enum DragPreviewAnim { IDLE, WALK, ATTACK, SPELL }

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
	z_index = 6
	if profile != null:
		_profile = profile
	else:
		_load_profile()
	_catalog = LpcCatalog.load_from_disk()
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		_phase = phase
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
	queue_redraw()


func _on_preview_updated(result: SimResult) -> void:
	_preview_board = result.final_state
	queue_redraw()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	queue_redraw()


func apply_sim_event(event: SimEvent) -> void:
	if _board == null:
		return
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED:
			_animate_move(event)
		GameEnums.SimEventType.UNIT_PUSHED, GameEnums.SimEventType.COLLISION:
			_animate_push(event)
		GameEnums.SimEventType.ABILITY_USED:
			_play_attack_anim(event)
		GameEnums.SimEventType.UNIT_DAMAGED:
			var target_id: int = int(event.data.get("unit", -1))
			var hp: int = int(event.data.get("hp", 0))
			var target := _board.get_unit_by_id(target_id)
			if target != null:
				target.health.current_hp = hp
			_damage_flash[target_id] = 0.45
		GameEnums.SimEventType.UNIT_DIED:
			var dead_id: int = int(event.data.get("unit", -1))
			var dead := _board.get_unit_by_id(dead_id)
			if dead != null:
				dead.health.current_hp = 0
				_remove_actor(dead_id)
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
		if not _move_tweens.has(unit.id) and not (_drag_preview_active and unit.id == _drag_preview_id):
			_position_actor(unit.id, unit.position)
		if not (_drag_preview_active and unit.id == _drag_preview_id):
			_apply_facing(unit.id, unit.facing)
		_update_depth(unit.id)
	for id: Variant in _actors.keys():
		if not live.has(id):
			_remove_actor(int(id))


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


func _remove_actor(unit_id: int) -> void:
	var actor: Variant = _actors.get(unit_id)
	if actor is CharacterActor:
		(actor as CharacterActor).queue_free()
	_actors.erase(unit_id)


func _position_actor(unit_id: int, cell: Vector2i) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	actor.position = _map_view.grid_to_foot_local(cell)


func _apply_facing(unit_id: int, facing: int) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	actor.set_facing(_facing_anim(facing))
	actor.set_walking(false)


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
	if cells.size() >= 2:
		start_cell = cells[0]
	elif cells.size() == 1:
		start_cell = cells[0]
	unit.position = cells[cells.size() - 1]
	var facing: int = unit.facing
	if cells.size() >= 2:
		facing = _facing_toward(cells[cells.size() - 2], cells[cells.size() - 1])
		unit.facing = facing
	_apply_facing(unit_id, facing)
	_kill_move_tween(unit_id)
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		_position_actor(unit_id, unit.position)
		_update_depth(unit_id)
		return
	actor.position = _map_view.grid_to_foot_local(start_cell)
	actor.set_walking(true)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	for cell: Vector2i in cells:
		tween.tween_property(actor, "position", _map_view.grid_to_foot_local(cell), step_time)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		actor.set_walking(false)
		_update_depth(unit_id)
	)


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
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	var facing: int = int(event.data.get("facing", GameEnums.Facing.SOUTH))
	if event.data.has("target_coord"):
		var target_coord: Vector2i = event.data["target_coord"]
		var unit := _board.get_unit_by_id(unit_id) if _board != null else null
		if unit != null:
			facing = _facing_toward(unit.position, target_coord)
	elif event.data.has("target_unit"):
		var target := _board.get_unit_by_id(int(event.data["target_unit"])) if _board != null else null
		var unit := _board.get_unit_by_id(unit_id) if _board != null else null
		if target != null and unit != null:
			facing = _facing_toward(unit.position, target.position)
	var anim: StringName = _attack_anim(facing)
	actor.set_facing(anim)
	actor.set_walking(true)
	get_tree().create_timer(CombatDirector.ATTACK_ANIM_TIME).timeout.connect(func() -> void:
		if is_instance_valid(actor):
			actor.set_walking(false)
			_apply_facing(unit_id, facing)
	)


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


func end_drag_preview() -> void:
	if _drag_preview_id < 0:
		return
	var unit_id: int = _drag_preview_id
	_drag_preview_active = false
	_drag_preview_id = -1
	_drag_preview_failed = false
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit != null:
		_position_actor(unit_id, unit.position)
		_apply_facing(unit_id, unit.facing)
		_update_depth(unit_id)
	var actor: CharacterActor = _actors.get(unit_id)
	if actor != null:
		actor.modulate = Color.WHITE
		actor.set_walking(false)


func update_drag_preview(
	map_local: Vector2,
	anim_mode: int,
	facing: int,
	preview_cell: Vector2i,
	failed: bool = false,
) -> void:
	if not _drag_preview_active or _drag_preview_id < 0 or _map_view == null:
		return
	_drag_preview_failed = failed
	var actor: CharacterActor = _actors.get(_drag_preview_id)
	if actor == null:
		return
	var foot: Vector2 = _map_view.grid_to_foot_local(preview_cell)
	var offset: Vector2 = map_local - _map_view.grid_to_local(preview_cell)
	actor.position = foot + Vector2(offset.x, offset.y * 0.35)
	actor.modulate = Color(1.0, 0.35, 0.35, 0.58) if failed else Color(1.0, 1.0, 1.0, 0.58)
	match anim_mode:
		DragPreviewAnim.WALK:
			actor.set_facing(_facing_anim(facing))
			actor.set_walking(true)
		DragPreviewAnim.ATTACK:
			actor.set_facing(_attack_anim(facing))
			actor.set_walking(true)
		DragPreviewAnim.SPELL:
			actor.set_facing(_spell_anim(facing))
			actor.set_walking(true)
		_:
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
		if not unit.is_alive():
			continue
		if _drag_preview_active and unit.id == _drag_preview_id:
			continue
		_draw_hp_bar(unit)
		var foot: Vector2 = _map_view.grid_to_foot_local(unit.position)
		var ring_center: Vector2 = foot + Vector2(0.0, -10.0)
		if _phase in [
			CombatDirector.Phase.PLANNING_PHASE_1,
			CombatDirector.Phase.PLANNING_PHASE_2,
		]:
			_draw_movement_pips(ring_center, unit)
		if unit.id == _selected_id and _phase in [
			CombatDirector.Phase.PLANNING_PHASE_1,
			CombatDirector.Phase.PLANNING_PHASE_2,
		]:
			draw_arc(ring_center, 15.0, 0.0, TAU, 48, _COLOR_SELECT_GLOW, 5.0)
			draw_arc(ring_center, 11.0, 0.0, TAU, 40, _COLOR_SELECT, 3.5)
		if unit.id == _timeline_hover_id:
			draw_arc(ring_center, 12.0, 0.0, TAU, 32, _COLOR_TIMELINE_HOVER, 2.5)
		if unit.is_enemy() and _intent_units.has(unit.id):
			draw_arc(ring_center, 8.0, 0.0, TAU, 24, Color(_COLOR_INTENT, 0.25), 4.0)
			draw_arc(ring_center, 5.0, 0.0, TAU, 20, _COLOR_INTENT, 2.0)
		_draw_facing_wedge(ring_center, unit.facing, Color(1.0, 1.0, 1.0, 0.75))
	if _drag_preview_active and _drag_preview_id >= 0 and _drag_preview_failed:
		var drag_unit := _board.get_unit_by_id(_drag_preview_id) if _board != null else null
		if drag_unit != null:
			var actor: CharacterActor = _actors.get(_drag_preview_id)
			if actor != null:
				_draw_centered_icon(actor.position + Vector2(0.0, -18.0), "🚫", Color.WHITE, 14)


func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	if _planning_input != null and _planning_input.preview_state.preview_board != null:
		var live_active: bool = (
			_planning_input.dragging
			or _planning_input.aiming
			or _planning_input.skill_interaction_active()
		)
		if live_active:
			var live_u := _planning_input.preview_state.preview_board.get_unit_by_id(unit_id)
			if live_u != null:
				return live_u
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


func _enemy_targets_player(unit: UnitState) -> bool:
	var intent_list: Array = _board.intents if _board != null else []
	if (
		_planning_input != null
		and _planning_input.is_live_preview_active()
		and not _planning_input.preview_state.live_intents.is_empty()
	):
		intent_list = _planning_input.preview_state.live_intents
	for intent_v: Variant in intent_list:
		if not intent_v is Intent:
			continue
		var intent: Intent = intent_v as Intent
		if intent.enemy_id != unit.id:
			continue
		for action: TimelineAction in intent.actions:
			if action.type != GameEnums.ActionType.ABILITY:
				continue
			var tgt := _board.get_unit_by_id(action.target_unit_id) if _board != null else null
			if tgt != null and not tgt.is_enemy():
				return true
	return false


func _draw_movement_pips(center: Vector2, unit: UnitState) -> void:
	if unit.definition == null or _director == null:
		return
	var p_unit := _proj_unit(unit.id)
	if p_unit == null:
		return
	var max_move: int = maxi(1, p_unit.definition.move_points)
	var points_left: int = p_unit.movement.points_left
	var is_drag: bool = (
		_planning_input != null
		and _planning_input.dragging
		and _planning_input.get_drag_unit_id() == unit.id
	)
	if is_drag:
		points_left = maxi(0, points_left - maxi(0, _planning_input.get_drag_route().size() - 1))
	var is_attack_queued := false
	var is_skill_queued := false
	if not unit.is_enemy():
		var plan_to_use: Timeline = (
			_director.plan_phase_1
			if _phase == CombatDirector.Phase.PLANNING_PHASE_1
			else _director.plan_phase_2
		)
		if plan_to_use != null:
			for action: TimelineAction in plan_to_use.entries:
				if action.actor_id == unit.id and action.type == GameEnums.ActionType.ABILITY:
					is_skill_queued = true
					if action.ability != null:
						for effect: EffectData in action.ability.effects:
							if effect.type == GameEnums.EffectType.DAMAGE:
								is_attack_queued = true
								break
	elif unit.is_enemy() and (_intent_units.has(unit.id) or _enemy_targets_player(unit)):
		var intent_list: Array = _board.intents if _board != null else []
		if (
			_planning_input != null
			and _planning_input.is_live_preview_active()
			and not _planning_input.preview_state.live_intents.is_empty()
		):
			intent_list = _planning_input.preview_state.live_intents
		for intent_v: Variant in intent_list:
			if not intent_v is Intent:
				continue
			var intent: Intent = intent_v as Intent
			if intent.enemy_id != unit.id:
				continue
			for action: TimelineAction in intent.actions:
				if action.type == GameEnums.ActionType.ABILITY:
					var tgt := _board.get_unit_by_id(action.target_unit_id) if _board != null else null
					if tgt != null and not tgt.is_enemy():
						is_skill_queued = true
						if action.ability != null:
							for effect: EffectData in action.ability.effects:
								if effect.type == GameEnums.EffectType.DAMAGE:
									is_attack_queued = true
									break
						break
	var accent: Color = _COLOR_SELECT if not unit.is_enemy() else _COLOR_INTENT
	var ring_radius := 11.0
	var segments := maxi(1, max_move)
	var gap := 0.2
	var arc_len := (TAU - gap * float(segments)) / float(segments)
	draw_arc(center, ring_radius, 0.0, TAU, 48, Color(0.1, 0.1, 0.1, 0.6), 6.0)
	for i: int in range(segments):
		var start_ang: float = -PI / 2.0 + float(i) * (arc_len + gap)
		var end_ang: float = start_ang + arc_len
		var segment_color: Color = accent
		if i >= points_left:
			segment_color = Color(0.0, 0.0, 0.0, 0.3)
		var flash_color: Color = segment_color
		if is_attack_queued and i < points_left:
			var atk_blink: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			flash_color = Color(1.0, 0.0, 0.0, atk_blink)
		elif is_skill_queued and i < points_left:
			var sk_blink: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			flash_color = Color(1.0, 1.0, 1.0, sk_blink)
		draw_arc(center, ring_radius, start_ang, end_ang, 12, flash_color, 4.0)


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
		var pulse: float = 0.5 + 0.5 * sin(flash * 40.0)
		draw_rect(
			Rect2(origin - Vector2(1.0, 1.0), Vector2(BAR_W + 2.0, BAR_H + 2.0)),
			Color(1.0, 0.1, 0.1, 0.35 * pulse),
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
			fill_color = fill_color.lerp(Color(1.0, 0.15, 0.15), minf(1.0, flash * 2.0))
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
		var start_y: float = origin.y + BAR_H + 2.0
		var count := 0
		for status: StatusData in unit.active_statuses:
			var pos := Vector2(start_x + float(count % 3) * 12.0, start_y + float(count / 3) * 12.0)
			_draw_status_icon(pos, _status_icon(status.type))
			count += 1


func _draw_status_icon(pos: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var size_px := 8
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - Vector2(0.0, sz.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)


func _draw_centered_icon(pos: Vector2, text: String, color: Color, size_px: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - sz * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _facing_vector(facing: int) -> Vector2:
	match facing:
		GameEnums.Facing.NORTH:
			return Vector2(0.0, -1.0)
		GameEnums.Facing.SOUTH:
			return Vector2(0.0, 1.0)
		GameEnums.Facing.WEST:
			return Vector2(-1.0, 0.0)
		_:
			return Vector2(1.0, 0.0)


func _draw_facing_wedge(center: Vector2, facing: int, color: Color) -> void:
	var dir: Vector2 = _facing_vector(facing)
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var tip: Vector2 = center + dir * 14.0
	var base: Vector2 = center + dir * 8.0
	var pts := PackedVector2Array([tip, base + perp * 5.0, base - perp * 5.0])
	draw_colored_polygon(pts, color)


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
	if _any_predicted_change():
		need_redraw = true
	if _phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
	]:
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
