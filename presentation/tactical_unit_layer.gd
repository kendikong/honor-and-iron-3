class_name TacticalUnitLayer
extends Node2D

## LPC unit sprites on the tactical grid (Phase 5).

const _CharacterActor = preload("res://scripts/lpc/character_actor.gd")
const _FloatingTextScene = preload("res://presentation/floating_text.tscn")

const BAR_W: float = 14.0
const BAR_H: float = 3.0
const BAR_OFFSET_Y: float = 6.0
const BAR_OFFSET_ABOVE_Y: float = -22.0

const _COLOR_HP_BG := Color(0.08, 0.08, 0.10, 0.92)
const _COLOR_HP_FILL := Color(0.38, 0.78, 0.46)
const _COLOR_HP_PREDICTED := Color(0.95, 0.45, 0.35, 0.85)
const _COLOR_HP_LOSS := Color(0.95, 0.25, 0.22)
const _COLOR_ARMOR := Color(0.9, 0.8, 0.2)
const _COLOR_SELECT_PLAYER := Color(0.28, 0.58, 1.0, 1.0)
const _COLOR_SELECT_ENEMY := Color(1.0, 0.20, 0.16, 1.0)
const _COLOR_PLAN_TARGET := Color(0.98, 0.72, 0.38, 1.0)
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
var _hover_unit_id: int = -1
var _glow_applied: Dictionary = {}
var _timeline_hover_id: int = -1
var _intent_units: Dictionary = {}
var _predicted_hp: Dictionary = {}
var _predicted_armor: Dictionary = {}
var _phase: int = CombatDirector.Phase.PLANNING
var _move_tweens: Dictionary = {}
var _move_tween_destinations: Dictionary = {}
var _active_push_tweens: int = 0
var _downed_actors: Array[CharacterActor] = []
var _damage_flash: Dictionary = {}
var _hit_bursts: Array = []
var _sfx: SfxPlayer
var _spellcast_target_ids: Dictionary = {}
var _pending_spellcast_damage: Dictionary = {}
var _pending_spellcast_deaths: Dictionary = {}
var _spellcast_released: bool = false
var _last_attacker_pos: Dictionary = {}
var _suppress_hurt_knockback: bool = false
var _pending_death: Dictionary = {}
var _drag_preview_id: int = -1
var _drag_preview_active: bool = false
var _drag_preview_failed: bool = false
var _drag_attack_target_id: int = -1
var _drag_preview_last_anim: int = -1
var _drag_preview_last_facing: int = -1
var _drag_preview_last_failed: bool = false
var _planning_input: CombatPlanningInput
var _planning_overlay: TacticalPlanningOverlay
var _show_team_outlines: bool = false
var _autobattler_hook: AutobattlerHookRegistry
var _planning_anim_units: Dictionary = {}

enum DragPreviewAnim { IDLE, WALK, RUN, ATTACK, SPELL }

signal push_tweens_idle


func is_spellcast_damage_deferred(unit_id: int) -> bool:
	return _spellcast_target_ids.has(unit_id)


func get_active_push_tweens() -> int:
	return _active_push_tweens


func has_active_move_tweens() -> bool:
	return not _move_tweens.is_empty()


func await_move_tweens_idle() -> void:
	while not _move_tweens.is_empty():
		await get_tree().process_frame


func set_autobattler_hook(hook: AutobattlerHookRegistry) -> void:
	_autobattler_hook = hook
	if not EventBus.planning_commit_events.is_connected(_on_planning_commit_events):
		EventBus.planning_commit_events.connect(_on_planning_commit_events)


func get_actor(unit_id: int) -> CharacterActor:
	return _actors.get(unit_id)


func get_actor_map() -> Dictionary:
	return _actors


func sync_all_contact_shadows(settings: EffectsSettings) -> void:
	var shadow_root: Node2D = null
	if _map_view != null:
		shadow_root = _map_view.get_shadow_sprites()
	EffectsController.sync_contact_shadow_on_actors(_actors, settings, shadow_root)


func bind_sfx(sfx: SfxPlayer) -> void:
	_sfx = sfx


func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_show_team_outlines = settings.show_team_outlines
	_refresh_unit_glows()


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
		for downed: CharacterActor in _downed_actors:
			downed.finish_combat_reaction()
		_downed_actors.clear()
		for actor: Variant in _actors.values():
			if actor is CharacterActor:
				(actor as CharacterActor).set_planning_exhausted(false)
				if not CombatDirector.is_planning_phase(phase):
					(actor as CharacterActor).set_running(false)
		_refresh_unit_glows()
		queue_redraw(),
	)
	set_process(true)
	queue_redraw()


func set_timeline_hover(unit_id: int) -> void:
	if _timeline_hover_id == unit_id:
		return
	_timeline_hover_id = unit_id
	_refresh_unit_glows()
	queue_redraw()


func set_hover_cell(coord: Vector2i) -> void:
	var unit := _unit_at_cell(coord)
	var new_hover_id: int = unit.id if unit != null else -1
	if new_hover_id == _hover_unit_id:
		return
	_hover_unit_id = new_hover_id
	_refresh_unit_glows()


func set_intent_units(units: Dictionary) -> void:
	_intent_units = units
	queue_redraw()


func bind_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input


func bind_planning_overlay(overlay: TacticalPlanningOverlay) -> void:
	_planning_overlay = overlay


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
	if _director != null and _director.peek_movement_only_refresh():
		_refresh_player_exhaustion()
		queue_redraw()
		return
	_sync_actors()
	_refresh_planning_visuals()
	queue_redraw()


func _on_preview_updated(result: SimResult) -> void:
	_preview_board = result.final_state
	if _director != null and CombatDirector.is_planning_phase(_director.phase):
		_sync_planning_actor_positions()
	queue_redraw()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	_refresh_unit_glows()
	if _board != null and unit_id >= 0:
		var unit: UnitState = _board.get_unit_by_id(unit_id)
		if unit != null and unit.is_alive() and not unit.is_enemy():
			_apply_exhaustion_state(unit)
	queue_redraw()


func _on_timeline_changed(_timeline: Timeline, _statuses: PackedStringArray) -> void:
	if _director != null and CombatDirector.is_planning_phase(_director.phase):
		_sync_planning_facings_for_queued_actions()
		_refresh_player_exhaustion()
		_refresh_unit_glows()


func _refresh_planning_visuals() -> void:
	for unit_id: Variant in _actors:
		var actor: CharacterActor = _actors[unit_id] as CharacterActor
		if actor != null:
			actor.modulate = Color.WHITE
	_refresh_player_exhaustion()
	_refresh_unit_glows()


func _refresh_player_exhaustion() -> void:
	if _board == null:
		return
	for unit: UnitState in _board.units:
		if unit.is_alive() and not unit.is_enemy():
			_apply_exhaustion_state(unit)


func _unit_at_cell(coord: Vector2i) -> UnitState:
	if _board == null or not _board.is_in_bounds(coord):
		return null
	if _director != null and _director.projected_state != null:
		var projected := _director.projected_state.get_unit_at(coord)
		if projected != null:
			return projected
	return _board.get_unit_at(coord)


func _effective_hover_id() -> int:
	if _hover_unit_id >= 0:
		return _hover_unit_id
	return _timeline_hover_id


func _outline_color_for(unit: UnitState, strength: CharacterSelectionGlow.GlowStrength) -> Color:
	if strength == CharacterSelectionGlow.GlowStrength.TARGET:
		return _COLOR_PLAN_TARGET
	return _COLOR_SELECT_ENEMY if unit.is_enemy() else _COLOR_SELECT_PLAYER


func _refresh_unit_glows() -> void:
	var want: Dictionary = {}
	if _show_team_outlines and _board != null:
		for unit: UnitState in _board.units:
			if unit.is_alive():
				want[unit.id] = CharacterSelectionGlow.GlowStrength.TEAM
	if not CombatDirector.is_planning_phase(_phase):
		if want.is_empty():
			_clear_all_unit_glows()
			return
		_apply_glow_want(want)
		return
	var selected_id: int = _selected_id
	var hover_id: int = _effective_hover_id()
	if selected_id >= 0:
		var selected_unit := _board.get_unit_by_id(selected_id) if _board != null else null
		if selected_unit != null and not selected_unit.is_enemy():
			for target_id: int in _planned_enemy_target_ids(selected_id):
				if target_id >= 0 and target_id != selected_id:
					want[target_id] = CharacterSelectionGlow.GlowStrength.TARGET
			if _drag_attack_target_id >= 0 and _drag_attack_target_id != selected_id:
				want[_drag_attack_target_id] = CharacterSelectionGlow.GlowStrength.TARGET
	if hover_id >= 0 and hover_id != selected_id:
		if not want.has(hover_id) or want[hover_id] != CharacterSelectionGlow.GlowStrength.TARGET:
			want[hover_id] = CharacterSelectionGlow.GlowStrength.HOVER
	if selected_id >= 0:
		want[selected_id] = CharacterSelectionGlow.GlowStrength.SELECTED
	_apply_glow_want(want)


func _apply_glow_want(want: Dictionary) -> void:
	var stale: Array[int] = []
	for unit_id: Variant in _glow_applied.keys():
		stale.append(int(unit_id))
	for unit_id: int in stale:
		if not want.has(unit_id):
			_apply_unit_glow(unit_id, false)
			_glow_applied.erase(unit_id)
	for unit_id: Variant in want.keys():
		var id: int = int(unit_id)
		var unit := _board.get_unit_by_id(id) if _board != null else null
		if unit == null or not unit.is_alive():
			_apply_unit_glow(id, false)
			_glow_applied.erase(id)
			continue
		var strength: CharacterSelectionGlow.GlowStrength = want[id]
		if _glow_applied.get(id) == strength:
			continue
		_apply_unit_glow(id, true, _outline_color_for(unit, strength), strength)
		_glow_applied[id] = strength


func _clear_all_unit_glows() -> void:
	for unit_id: Variant in _glow_applied.keys():
		_apply_unit_glow(int(unit_id), false)
	_glow_applied.clear()


func _apply_unit_glow(
	unit_id: int,
	active: bool,
	color: Color = _COLOR_SELECT_PLAYER,
	strength: CharacterSelectionGlow.GlowStrength = CharacterSelectionGlow.GlowStrength.HOVER,
) -> void:
	var actor: CharacterActor = _actors.get(unit_id) as CharacterActor
	if actor == null:
		return
	actor.set_selection_glow(active, color, strength)


func set_drag_attack_target(unit_id: int) -> void:
	if _drag_attack_target_id == unit_id:
		return
	_drag_attack_target_id = unit_id
	_refresh_unit_glows()


func clear_drag_attack_target() -> void:
	if _drag_attack_target_id < 0:
		return
	_drag_attack_target_id = -1
	_refresh_unit_glows()


func _planned_enemy_target_ids(caster_id: int) -> Array[int]:
	var out: Array[int] = []
	if _director == null or caster_id < 0 or _board == null:
		return out
	var caster := _proj_unit(caster_id)
	if caster == null:
		caster = _board.get_unit_by_id(caster_id)
	if caster == null or caster.is_enemy():
		return out
	var board: BoardState = _director.projected_state if _director.projected_state != null else _board
	var origin: Vector2i = caster.position
	var seen: Dictionary = {}
	for action: TimelineAction in _director.get_unit_plan_steps(caster_id):
		if action.type == GameEnums.ActionType.MOVE:
			origin = _move_action_destination(action, origin)
			continue
		if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
			continue
		if action.ability.is_movement_kind():
			origin = action.target_coord
			continue
		if action.ability.is_movement_kind() or action.ability.is_universal_run() or action.ability.is_universal_wait():
			continue
		_collect_planned_ability_enemy_targets(action, origin, board, out, seen)
	return out


func _move_action_destination(action: TimelineAction, fallback: Vector2i) -> Vector2i:
	if not action.waypoints.is_empty():
		var last: Variant = action.waypoints[action.waypoints.size() - 1]
		if last is Vector2i:
			return last
	return action.target_coord if action.target_coord != Vector2i.ZERO else fallback


func _collect_planned_ability_enemy_targets(
	action: TimelineAction,
	origin: Vector2i,
	board: BoardState,
	out: Array[int],
	seen: Dictionary,
) -> void:
	var ability: AbilityData = action.ability
	if ability == null:
		return
	ability.ensure_targeting_flags_from_mode()
	if not ability.has_targeting(GameEnums.TargetingFlags.ENEMY):
		return
	if action.target_unit_id >= 0:
		var tgt := board.get_unit_by_id(action.target_unit_id)
		if tgt == null:
			tgt = _board.get_unit_by_id(action.target_unit_id) if _board != null else null
		if tgt != null and tgt.is_enemy() and tgt.is_alive():
			_append_target_id(out, seen, tgt.id)
		return
	var target_coord: Vector2i = action.target_coord
	var shape: int = ability.target_shape
	var shape_size: int = ability.target_shape_size
	var affected: Array[Vector2i] = GridSystem.get_affected_tiles(
		board, origin, target_coord, shape, shape_size,
	)
	if affected.is_empty():
		var occ := board.get_unit_at(target_coord)
		if occ == null and _board != null:
			occ = _board.get_unit_at(target_coord)
		if occ != null and occ.is_enemy() and occ.is_alive():
			_append_target_id(out, seen, occ.id)
		return
	for cell: Vector2i in affected:
		var occ := board.get_unit_at(cell)
		if occ == null and _board != null:
			occ = _board.get_unit_at(cell)
		if occ != null and occ.is_enemy() and occ.is_alive():
			_append_target_id(out, seen, occ.id)


func _append_target_id(out: Array[int], seen: Dictionary, unit_id: int) -> void:
	if seen.has(unit_id):
		return
	seen[unit_id] = true
	out.append(unit_id)


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
			_suppress_hurt_knockback = false
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
				if _spellcast_target_ids.has(target_id):
					_pending_spellcast_damage[target_id] = {
						"hp_damaged": int(event.data.get("hp_damaged", 0)),
						"armor_damaged": int(event.data.get("armor_damaged", 0)),
						"amount": int(event.data.get("amount", 0)),
						"damage_type": event.data.get("damage_type", &"physical"),
					}
					if _spellcast_released:
						_apply_spellcast_hit_presentation(target_id)
				else:
					_apply_unit_damaged_vfx(target_id, target, damage_taken)
		GameEnums.SimEventType.UNIT_DIED:
			var dead_id: int = int(event.data.get("unit", -1))
			var dead := _board.get_unit_by_id(dead_id) if _board != null else null
			if dead != null:
				dead.health.current_hp = 0
			if _spellcast_target_ids.has(dead_id):
				_pending_spellcast_deaths[dead_id] = true
				if _spellcast_released:
					_apply_spellcast_death_presentation(dead_id)
			else:
				_begin_death(dead_id)
		GameEnums.SimEventType.UNIT_FACED:
			var face_id: int = int(event.data.get("unit", -1))
			var faced := _board.get_unit_by_id(face_id)
			if faced != null:
				var new_facing: int = int(event.data.get("facing", faced.facing))
				faced.facing = new_facing
				_apply_facing(face_id, new_facing)
	queue_redraw()


func rebuild_all_actor_visuals() -> void:
	if _board == null:
		return
	var ids: Array = _actors.keys()
	for id: Variant in ids:
		_remove_actor(int(id))
	_sync_actors()


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
			# Planning walk/snap: committed preview_updated (+ planning_commit_events).
			pass
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
	_refresh_unit_glows()
	if _map_view != null:
		var shadow_settings: EffectsSettings = _map_view.get_effects_settings()
		if shadow_settings != null and (
			shadow_settings.oblique_contact_shadows or shadow_settings.cloud_shadows
		):
			sync_all_contact_shadows(shadow_settings)


func _record_attack_source(event: SimEvent) -> void:
	var target_id: int = int(event.data.get("target_unit", -1))
	var actor_id: int = int(event.data.get("actor", -1))
	var attacker := _board.get_unit_by_id(actor_id) if _board != null else null
	if target_id >= 0 and attacker != null:
		_last_attacker_pos[target_id] = attacker.position
	_suppress_hurt_knockback = _event_ability_has_pull(event)


func _record_counter_source(event: SimEvent) -> void:
	var target_id: int = int(event.data.get("target_unit", -1))
	var actor_id: int = int(event.data.get("actor", -1))
	var attacker := _board.get_unit_by_id(actor_id) if _board != null else null
	if target_id >= 0 and attacker != null:
		_last_attacker_pos[target_id] = attacker.position
	_suppress_hurt_knockback = false


func _event_ability_has_pull(event: SimEvent) -> bool:
	var ability_id: StringName = event.data.get("ability", &"")
	if ability_id == &"" or _board == null:
		return false
	var actor_id: int = int(event.data.get("actor", -1))
	var actor: UnitState = _board.get_unit_by_id(actor_id)
	if actor == null:
		return false
	for ability: AbilityData in actor.active_abilities:
		if ability.id != ability_id:
			continue
		var effects: Array[EffectData] = ability.effects
		if actor.is_ability_upgraded(ability_id) and ability.upgraded_effects.size() > 0:
			effects = ability.upgraded_effects
		for effect: EffectData in effects:
			if effect.type == GameEnums.EffectType.PULL:
				return true
		return false
	return false


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
	var kb: Vector2 = Vector2.ZERO
	if not _suppress_hurt_knockback:
		kb = _knockback_dir_for(dead_id)
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
	var recipe: CharacterRecipe = UnitVisualFactory.roll_recipe_for_unit(
		_catalog, _profile, unit,
	)
	actor.apply_recipe(recipe)
	actor.set_display_scale(_display_scale())
	_actors[unit.id] = actor
	_position_actor(unit.id, unit.position)
	_apply_facing(unit.id, unit.facing)
	actor.rebuild_contact_shadow(_map_view.get_effects_settings())
	_update_depth(unit.id)


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


func _apply_facing(unit_id: int, facing: int, keep_walking: bool = false) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null:
		return
	actor.set_facing(_facing_anim(facing))
	if not keep_walking:
		actor.set_walking(false)


func _defer_exhaustion_grey(unit_id: int) -> bool:
	return _move_tweens.has(unit_id)


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
		actor.set_planning_exhausted(not _defer_exhaustion_grey(unit.id))
		actor.set_running(current.has_run_boost())
		return
	var exhausted: bool = AbilitySystem.is_planning_fully_exhausted(
		current, _director.get_planning_move_timing(current.id) >= 0,
	)
	actor.set_planning_exhausted(exhausted and not _defer_exhaustion_grey(unit.id))
	actor.set_running(current.has_run_boost())


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


func _is_full_autobattle_active() -> bool:
	return (
		_autobattler_hook != null
		and _autobattler_hook._active
		and _autobattler_hook._auto_commit
	)


func _on_planning_commit_events(events: Array) -> void:
	for raw: Variant in events:
		if raw is SimEvent and (raw as SimEvent).type == GameEnums.SimEventType.UNIT_MOVED:
			var actor_id: int = int((raw as SimEvent).data.get("actor", -1))
			if actor_id >= 0:
				_planning_anim_units[actor_id] = true


func _clear_planning_anim_unit(unit_id: int) -> void:
	_planning_anim_units.erase(unit_id)


func _should_animate_move(event: SimEvent) -> bool:
	if event.data.get("teleport", false):
		return false
	var unit_id: int = int(event.data.get("actor", -1))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if _is_full_autobattle_active():
		return true
	if CombatDirector.is_planning_phase(_phase):
		return unit != null and not unit.is_enemy()
	if unit != null and unit.is_enemy():
		return true
	if event.data.get("presentation_anim", GameEnums.PresentationAnim.WALK) == GameEnums.PresentationAnim.SUPER_RUN:
		return true
	var pres_anim: int = int(event.data.get("presentation_anim", GameEnums.PresentationAnim.AUTO))
	if pres_anim != GameEnums.PresentationAnim.AUTO and pres_anim != GameEnums.PresentationAnim.NONE:
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
	var force_sync: Dictionary = {}
	if _director != null:
		for unit_id: int in _director.plan_affected_unit_ids:
			force_sync[unit_id] = true
	for unit: UnitState in _board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		if _drag_preview_active and unit.id == _drag_preview_id:
			continue
		if _planning_anim_units.has(unit.id) and _move_tweens.has(unit.id):
			continue
		var target: Vector2i = unit.position
		var current_cell: Vector2i = _actor_grid_cell(unit.id)
		if current_cell == target and not force_sync.has(unit.id):
			if not _move_tweens.has(unit.id):
				_sync_planning_final_facing(unit.id)
			continue
		if force_sync.has(unit.id):
			if _move_tweens.has(unit.id) and _move_tween_destinations.get(unit.id, Vector2i(-999, -999)) == target:
				continue
			_kill_move_tween(unit.id)
		elif _move_tweens.has(unit.id):
			continue
		_sync_planning_unit_position(unit)


func _sync_planning_unit_position(unit: UnitState) -> void:
	var target: Vector2i = unit.position
	var current_cell: Vector2i = _actor_grid_cell(unit.id)
	if current_cell == target:
		_sync_planning_final_facing(unit.id)
		_update_depth(unit.id)
		return
	if _director != null and _director.take_planning_move_instant(unit.id):
		_position_actor(unit.id, target)
		_sync_planning_final_facing(unit.id)
		_update_depth(unit.id)
		return
	if _should_rubberband_planning_move(unit.id, current_cell, target):
		_snap_actor_rubberband(unit.id, target)
		return
	_animate_planning_path(unit.id, current_cell, target, _unit_uses_run_anim(unit.id))


func _turn_start_cell(unit_id: int) -> Vector2i:
	if _director != null and _director.turn_start_board != null:
		var start_unit: UnitState = _director.turn_start_board.get_unit_by_id(unit_id)
		if start_unit != null:
			return start_unit.position
	if _director != null and _director.base_board != null:
		var base_unit: UnitState = _director.base_board.get_unit_by_id(unit_id)
		if base_unit != null:
			return base_unit.position
	if _board != null:
		var live_unit: UnitState = _board.get_unit_by_id(unit_id)
		if live_unit != null:
			return live_unit.position
	return Vector2i.ZERO


func _turn_start_facing(unit_id: int) -> int:
	if _director != null and _director.turn_start_board != null:
		var start_unit: UnitState = _director.turn_start_board.get_unit_by_id(unit_id)
		if start_unit != null:
			return start_unit.facing
	if _director != null and _director.base_board != null:
		var base_unit: UnitState = _director.base_board.get_unit_by_id(unit_id)
		if base_unit != null:
			return base_unit.facing
	if _board != null:
		var live_unit: UnitState = _board.get_unit_by_id(unit_id)
		if live_unit != null:
			return live_unit.facing
	return GameEnums.Facing.SOUTH


func _should_rubberband_planning_move(
	unit_id: int,
	from_cell: Vector2i,
	to_cell: Vector2i,
) -> bool:
	var start_cell: Vector2i = _turn_start_cell(unit_id)
	return GridSystem.manhattan(to_cell, start_cell) < GridSystem.manhattan(from_cell, start_cell)


func _snap_actor_rubberband(unit_id: int, grid_cell: Vector2i) -> void:
	var actor: CharacterActor = _actors.get(unit_id) as CharacterActor
	if actor == null or _map_view == null:
		return
	var home: Vector2 = _map_view.grid_to_foot_local(grid_cell)
	var unit: UnitState = _board.get_unit_by_id(unit_id) if _board != null else null
	if unit != null:
		if grid_cell == _turn_start_cell(unit_id):
			unit.facing = _turn_start_facing(unit_id)
		_apply_facing(unit_id, unit.facing, true)
	if actor.position.distance_to(home) <= 1.5:
		_finish_snap_at_cell(unit_id, grid_cell)
		return
	_kill_move_tween(unit_id)
	actor.set_running(false)
	actor.set_walking(true)
	actor.modulate = Color.WHITE
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	_move_tween_destinations[unit_id] = grid_cell
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(actor, "position", home, DRAG_SNAPBACK_SEC)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_move_tween_destinations.erase(unit_id)
		_finish_snap_at_cell(unit_id, grid_cell)
	)


func _finish_snap_at_cell(unit_id: int, grid_cell: Vector2i) -> void:
	_position_actor(unit_id, grid_cell)
	_sync_planning_final_facing(unit_id)
	_update_depth(unit_id)
	var actor: CharacterActor = _actors.get(unit_id) as CharacterActor
	if actor != null:
		actor.modulate = Color.WHITE
		actor.set_running(false)
		actor.set_walking(false)


func _actor_grid_cell(unit_id: int) -> Vector2i:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null or _map_view == null:
		return Vector2i(-999, -999)
	return _map_view.foot_local_to_grid(actor.position)


func _unit_uses_run_anim(unit_id: int) -> bool:
	if _director != null:
		for action: TimelineAction in _director.plan_pre_move.entries:
			if action.actor_id == unit_id and action.is_run_boosted_pre_move():
				return true
		for action: TimelineAction in _director.plan_post_move.entries:
			if action.actor_id == unit_id and action.is_run_boosted_pre_move():
				return true
	var projected := _proj_unit(unit_id)
	if projected != null and projected.has_run_boost():
		return true
	return false


func _resolve_planning_path_cells(from_cell: Vector2i, to_cell: Vector2i, unit: UnitState) -> Array[Vector2i]:
	if unit == null:
		return []
	if _director != null:
		var skill_wps: Array[Vector2i] = _director.get_planned_skill_walk_waypoints(unit.id, to_cell)
		if not skill_wps.is_empty():
			return skill_wps.duplicate()
		var move_wps: Array[Vector2i] = _director.get_planned_move_waypoints(unit.id)
		if not move_wps.is_empty() and move_wps.back() == to_cell:
			return move_wps.duplicate()
	var preview: CombatPlanningPreview = _committed_planning_preview()
	return CombatPlanningPreview.planning_animation_cells(
		unit.id, preview, from_cell, to_cell, _director, _board,
	)


func _committed_planning_preview() -> CombatPlanningPreview:
	if _planning_overlay != null:
		return _planning_overlay.get_committed_preview()
	return null


func _animate_planning_path(
	unit_id: int,
	from_cell: Vector2i,
	to_cell: Vector2i,
	use_run: bool,
) -> void:
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit == null:
		return
	var cells: Array[Vector2i] = _resolve_planning_path_cells(from_cell, to_cell, unit)
	if cells.is_empty():
		_position_actor(unit_id, to_cell)
		if _actor_grid_cell(unit_id) == to_cell:
			_sync_planning_final_facing(unit_id)
		_update_depth(unit_id)
		return
	unit.position = to_cell
	_play_cell_path_tween(unit_id, from_cell, cells, CombatDirector.MOVE_STEP_TIME, use_run)


func _play_cell_path_tween(
	unit_id: int,
	start_cell: Vector2i,
	cells: Array[Vector2i],
	step_time: float,
	use_run: bool,
	per_step: Variant = null,
	is_dash: bool = false,
) -> void:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor == null or _map_view == null or cells.is_empty():
		return
	_kill_move_tween(unit_id)
	if is_dash:
		actor.cancel_dash_windup()
	else:
		actor.position = _map_view.grid_to_foot_local(start_cell)
	if is_dash:
		actor.set_dash_running(true)
	else:
		actor.set_running(use_run)
	actor.set_walking(true)
	_apply_path_step_facing(unit_id, _facing_toward(start_cell, cells[0]))
	var tile_time: float = CombatDirector.RUN_STEP_TIME if use_run else step_time
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	if not cells.is_empty():
		_move_tween_destinations[unit_id] = cells.back()
	for step_index: int in range(cells.size()):
		var cell: Vector2i = cells[step_index]
		tween.tween_property(actor, "position", _map_view.grid_to_foot_local(cell), tile_time)
		if per_step is Callable and (per_step as Callable).is_valid():
			tween.tween_callback((per_step as Callable).bind(step_index))
		if step_index + 1 < cells.size():
			var next_cell: Vector2i = cells[step_index + 1]
			var next_facing: int = _facing_toward(cell, next_cell)
			tween.tween_callback(func() -> void:
				_apply_path_step_facing(unit_id, next_facing)
			)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_move_tween_destinations.erase(unit_id)
		_clear_planning_anim_unit(unit_id)
		actor.set_walking(false)
		var live := _board.get_unit_by_id(unit_id) if _board != null else null
		actor.set_running(live != null and live.has_run_boost())
		if live != null:
			if _actor_grid_cell(unit_id) == live.position:
				_sync_planning_final_facing(unit_id)
			else:
				_sync_planning_unit_position(live)
		_update_depth(unit_id)
	)


func _resolve_planning_facing(unit_id: int) -> int:
	var board_unit: UnitState = _board.get_unit_by_id(unit_id) if _board != null else null
	var queued: int = _facing_toward_queued_action(unit_id)
	if queued >= 0:
		return queued
	var from_plan: int = _facing_from_last_planned_movement(unit_id)
	if from_plan >= 0:
		return from_plan
	var projected := _proj_unit(unit_id)
	if projected != null:
		return projected.facing
	if board_unit != null:
		return board_unit.facing
	return GameEnums.Facing.SOUTH


func _sync_planning_final_facing(unit_id: int) -> void:
	if _move_tweens.has(unit_id):
		return
	var board_unit: UnitState = _board.get_unit_by_id(unit_id) if _board != null else null
	if board_unit != null and _actor_grid_cell(unit_id) != board_unit.position:
		return
	var facing: int = _resolve_planning_facing(unit_id)
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit != null:
		unit.facing = facing
	_apply_facing(unit_id, facing)
	if unit != null:
		_apply_exhaustion_state(unit)


func _apply_path_step_facing(unit_id: int, facing: int) -> void:
	_apply_facing(unit_id, facing, true)


func _animate_move(event: SimEvent) -> void:
	var unit_id: int = int(event.data.get("actor", -1))
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	if unit == null:
		return
	var path: Array = event.data.get("path", [])
	if path.is_empty() and event.data.has("to"):
		path = [event.data["to"]]
	var step_time: float = CombatDirector.MOVE_STEP_TIME
	if event.data.get("presentation_anim", GameEnums.PresentationAnim.WALK) == GameEnums.PresentationAnim.SUPER_RUN:
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
	if _actors.get(unit_id) == null:
		_position_actor(unit_id, unit.position)
		_update_depth(unit_id)
		return
	var pres_anim: int = int(event.data.get("presentation_anim", GameEnums.PresentationAnim.AUTO))
	var is_dash: bool = pres_anim == GameEnums.PresentationAnim.SUPER_RUN
	var use_run: bool = (
		unit.has_run_boost()
		or _unit_uses_run_anim(unit_id)
		or is_dash
		or pres_anim == GameEnums.PresentationAnim.RUN
	)
	if use_run and not is_dash:
		step_time = CombatDirector.RUN_STEP_TIME
	var step_cb := func(step_index: int) -> void:
		var remaining: int = maxi(
			movement_points_left,
			movement_points_before - ((step_index + 1) * movement_cost_per_tile),
		)
		_set_movement_points(unit_id, remaining)
	_play_cell_path_tween(unit_id, start_cell, cells, step_time, use_run, step_cb, is_dash)


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
	var from_coord: Vector2i = Vector2i(-999, -999)
	var from_data: Variant = event.data.get("from", null)
	if from_data is Vector2i:
		from_coord = from_data
	var unit := _board.get_unit_by_id(unit_id)
	if unit != null:
		if from_coord.x <= -900:
			from_coord = unit.position
		unit.position = to_coord as Vector2i
	_tween_push(unit_id, to_coord as Vector2i, from_coord)


func _tween_push(unit_id: int, cell: Vector2i, from_cell: Vector2i) -> void:
	_active_push_tweens += 1
	var actor: CharacterActor = _actors.get(unit_id)
	var dest_foot: Vector2 = _map_view.grid_to_foot_local(cell)
	if actor == null:
		_position_actor(unit_id, cell)
		_finish_push_tween()
		return
	_kill_move_tween(unit_id)
	actor.cancel_combat_reaction()
	var start_foot: Vector2 = dest_foot
	if from_cell.x > -900 and _map_view != null:
		start_foot = _map_view.grid_to_foot_local(from_cell)
	actor.snap_to_anchor(start_foot)
	var tween: Tween = create_tween()
	_move_tweens[unit_id] = tween
	_move_tween_destinations[unit_id] = cell
	tween.tween_property(
		actor,
		"position",
		dest_foot,
		0.22,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_downed_actors.append(actor)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_move_tween_destinations.erase(unit_id)
		actor.snap_to_anchor(dest_foot)
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
	_move_tween_destinations[unit_id] = cell
	tween.tween_property(actor, "position", _map_view.grid_to_foot_local(cell), step_time)
	tween.finished.connect(func() -> void:
		_move_tweens.erase(unit_id)
		_move_tween_destinations.erase(unit_id)
		actor.set_walking(false)
		_update_depth(unit_id)
	)


func _kill_move_tween(unit_id: int) -> void:
	var existing: Variant = _move_tweens.get(unit_id)
	if existing is Tween:
		(existing as Tween).kill()
	_move_tweens.erase(unit_id)
	_move_tween_destinations.erase(unit_id)


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
		if unit != null and target_coord != unit.position:
			facing = _facing_toward(unit.position, target_coord)
		elif unit != null:
			facing = unit.facing
	elif event.data.has("target_unit"):
		var target := _board.get_unit_by_id(int(event.data["target_unit"])) if _board != null else null
		if target != null and unit != null and target.position != unit.position:
			facing = _facing_toward(unit.position, target.position)
		elif unit != null:
			facing = unit.facing
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
	if ability_data != null and AbilitySystem.ability_has_movement_effect(ability_data):
		var pres_anim: int = ability_data.presentation_anim
		if pres_anim == GameEnums.PresentationAnim.AUTO:
			if AbilitySystem.effect_amount(ability_data, GameEnums.EffectType.DASH) > 0:
				pres_anim = GameEnums.PresentationAnim.SUPER_RUN
			elif AbilitySystem.effect_amount(ability_data, GameEnums.EffectType.BULLDOZE) > 0:
				pres_anim = GameEnums.PresentationAnim.RUN
			elif AbilitySystem.effect_amount(ability_data, GameEnums.EffectType.MOVE) > 0:
				pres_anim = GameEnums.PresentationAnim.WALK
				
		if pres_anim == GameEnums.PresentationAnim.SUPER_RUN:
			actor.play_dash_windup(thrust_dir, anim)
			return
		if pres_anim in [GameEnums.PresentationAnim.WALK, GameEnums.PresentationAnim.RUN, GameEnums.PresentationAnim.NONE]:
			return
	if ability_data != null and AbilitySystem.ability_uses_spellcast_animation(ability_data):
		var target_ids: Array[int] = _ability_affected_unit_ids_from_event(event, ability_data)
		_spellcast_released = false
		_pending_spellcast_damage.clear()
		_pending_spellcast_deaths.clear()
		_spellcast_target_ids.clear()
		for target_id: int in target_ids:
			_spellcast_target_ids[target_id] = true
		actor.play_spellcast(_spell_anim(facing), func() -> void:
			_on_spellcast_release(target_ids)
		)
		return
	actor.play_attack_thrust(thrust_dir, anim)


func _ability_affected_unit_ids_from_event(event: SimEvent, ability: AbilityData) -> Array[int]:
	var out: Array[int] = []
	if _board == null or ability == null:
		return out
	var actor_id: int = int(event.data.get("actor", -1))
	var actor := _board.get_unit_by_id(actor_id)
	if actor == null:
		return out
	var target_coord: Vector2i = event.data.get("target_coord", actor.position)
	if target_coord == Vector2i.ZERO:
		target_coord = actor.position
	var shape: int = ability.target_shape
	var shape_size: int = ability.target_shape_size
	if actor.is_ability_upgraded(ability.id):
		if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
			shape = ability.upgraded_target_shape
		if ability.upgraded_target_shape_size >= 0:
			shape_size = ability.upgraded_target_shape_size
	var affected: Array[Vector2i] = GridSystem.get_affected_tiles(
		_board, actor.position, target_coord, shape, shape_size,
	)
	var seen: Dictionary = {}
	for cell: Vector2i in affected:
		var occ := _board.get_unit_at(cell)
		if occ != null and occ.is_alive():
			_append_target_id(out, seen, occ.id)
	var target_unit_id: int = int(event.data.get("target_unit", -1))
	if target_unit_id >= 0:
		var target_unit := _board.get_unit_by_id(target_unit_id)
		if target_unit != null and target_unit.is_alive():
			_append_target_id(out, seen, target_unit.id)
	return out


func _on_spellcast_release(target_ids: Array[int]) -> void:
	if _sfx != null:
		_sfx.play("spellcast")
	var hold_sec: float = LpcConstants.spellcast_flash_hold_sec()
	_spellcast_released = true
	for target_id: int in target_ids:
		var target_actor: CharacterActor = _actors.get(target_id)
		if target_actor != null:
			target_actor.flash_spell_hit(hold_sec)
		_apply_spellcast_hit_presentation(target_id)
		_apply_spellcast_death_presentation(target_id)
	get_tree().create_timer(hold_sec).timeout.connect(
		func() -> void:
			for target_id: int in target_ids:
				_spellcast_target_ids.erase(target_id)
			_spellcast_released = false,
		CONNECT_ONE_SHOT,
	)


func _apply_unit_damaged_vfx(target_id: int, target: UnitState, damage_taken: int) -> void:
	if damage_taken <= 0:
		return
	_damage_flash[target_id] = 0.85
	_spawn_hit_burst(target_id)
	var actor: CharacterActor = _actors.get(target_id)
	if actor == null or target == null or actor.is_dying():
		return
	var kb: Vector2 = Vector2.ZERO
	if not _suppress_hurt_knockback:
		kb = _knockback_dir_for(target_id)
	actor.play_hurt(_facing_anim(target.facing), kb)


func _apply_spellcast_hit_presentation(target_id: int) -> void:
	if not _pending_spellcast_damage.has(target_id):
		return
	var pending: Dictionary = _pending_spellcast_damage[target_id]
	_pending_spellcast_damage.erase(target_id)
	var target := _board.get_unit_by_id(target_id) if _board != null else null
	var hp_dmg: int = int(pending.get("hp_damaged", 0))
	var armor_dmg: int = int(pending.get("armor_damaged", 0))
	var damage_taken: int = hp_dmg + armor_dmg
	_apply_unit_damaged_vfx(target_id, target, damage_taken)
	var shown: int = int(pending.get("amount", 0))
	if shown <= 0:
		shown = damage_taken
	if shown > 0:
		spawn_floating_damage(
			target_id,
			shown,
			pending.get("damage_type", &"physical"),
		)


func _apply_spellcast_death_presentation(dead_id: int) -> void:
	if not _pending_spellcast_deaths.has(dead_id):
		return
	_pending_spellcast_deaths.erase(dead_id)
	_begin_death(dead_id)

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
			return &"slash_up"
		GameEnums.Facing.WEST:
			return &"slash_left"
		GameEnums.Facing.SOUTH:
			return &"slash_down"
		_:
			return &"slash_right"


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


func _sync_planning_facings_for_queued_actions() -> void:
	if _board == null or _director == null:
		return
	for unit: UnitState in _board.units:
		if not unit.is_alive() or unit.is_enemy():
			continue
		if _move_tweens.has(unit.id):
			continue
		if _actor_grid_cell(unit.id) != unit.position:
			continue
		_sync_planning_final_facing(unit.id)


## Last cardinal step along committed pre / action / post moves (dash + walk legs).
func _facing_from_last_planned_movement(unit_id: int) -> int:
	if _director == null:
		return -1
	var plan_board: BoardState = (
		_director.base_board if _director.base_board != null else _board
	)
	if plan_board == null:
		return -1
	var preview: CombatPlanningPreview = _committed_planning_preview()
	return CombatPlanningPreview.facing_along_last_planned_step(
		plan_board,
		_director.get_player_plan(),
		unit_id,
		preview,
	)


func _facing_toward_queued_action(unit_id: int) -> int:
	if _director == null or _board == null:
		return -1
	var unit := _proj_unit(unit_id)
	if unit == null:
		unit = _board.get_unit_by_id(unit_id)
	if unit == null:
		return -1
	var origin: Vector2i = unit.position
	var lookup_board: BoardState = (
		_director.projected_state if _director.projected_state != null else _board
	)
	# Action bucket first so pre-move movement skills do not steal attack facing.
	for plan: Timeline in [_director.plan_action, _director.plan_post_move, _director.plan_pre_move]:
		for action: TimelineAction in plan.entries:
			if action.actor_id != unit_id or action.type != GameEnums.ActionType.ABILITY:
				continue
			if action.ability == null:
				continue
			if action.ability.is_movement_kind() or action.ability.is_universal_run() or action.ability.is_universal_wait():
				continue
			# CLASS_SKILL movement (e.g. Trampling Advance) — path facing, not attack aim.
			if AbilitySystem.ability_has_movement_effect(action.ability):
				continue
			var target_coord: Vector2i = action.target_coord
			if action.target_unit_id >= 0:
				var tgt := lookup_board.get_unit_by_id(action.target_unit_id)
				if tgt != null:
					target_coord = tgt.position
			if target_coord != origin:
				return _facing_toward(origin, target_coord)
			return unit.facing
	return -1


func begin_drag_preview(unit_id: int) -> void:
	_drag_preview_id = unit_id
	_drag_preview_active = true
	_drag_preview_last_anim = -1
	_drag_preview_last_facing = -1
	_drag_preview_last_failed = false
	_kill_move_tween(unit_id)


func end_drag_preview(snap_back: bool = false) -> void:
	if _drag_preview_id < 0:
		return
	var unit_id: int = _drag_preview_id
	_drag_preview_active = false
	_drag_preview_id = -1
	_drag_preview_failed = false
	_drag_preview_last_anim = -1
	_drag_preview_last_facing = -1
	_drag_preview_last_failed = false
	clear_drag_attack_target()
	var unit := _board.get_unit_by_id(unit_id) if _board != null else null
	var actor: CharacterActor = _actors.get(unit_id)
	if unit == null or actor == null:
		return
	var home: Vector2 = _map_view.grid_to_foot_local(unit.position)
	if snap_back and actor.position.distance_to(home) > 1.5:
		_snap_actor_rubberband(unit_id, unit.position)
		return
	if snap_back:
		_finish_drag_preview_at_home(unit_id, unit)
		return
	var drop_cell: Vector2i = _actor_grid_cell(unit_id)
	_finish_snap_at_cell(unit_id, drop_cell)
	_apply_exhaustion_state(unit)


func _finish_drag_preview_at_home(unit_id: int, unit: UnitState) -> void:
	_finish_snap_at_cell(unit_id, unit.position)
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
	_set_drag_preview_actor_position(actor, map_local, preview_cell, cursor_cell)
	if (
		anim_mode == _drag_preview_last_anim
		and facing == _drag_preview_last_facing
		and failed == _drag_preview_last_failed
	):
		_update_depth(_drag_preview_id)
		return
	_drag_preview_last_anim = anim_mode
	_drag_preview_last_facing = facing
	_drag_preview_last_failed = failed
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


func update_drag_preview_position(
	map_local: Vector2,
	preview_cell: Vector2i,
	cursor_cell: Vector2i = Vector2i(-999999, -999999),
) -> void:
	if not _drag_preview_active or _drag_preview_id < 0 or _map_view == null:
		return
	var actor: CharacterActor = _actors.get(_drag_preview_id)
	if actor == null:
		return
	_set_drag_preview_actor_position(actor, map_local, preview_cell, cursor_cell)
	_update_depth(_drag_preview_id)


func _set_drag_preview_actor_position(
	actor: CharacterActor,
	map_local: Vector2,
	preview_cell: Vector2i,
	cursor_cell: Vector2i,
) -> void:
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
	_draw_hit_bursts()
	if _drag_preview_active and _drag_preview_id >= 0 and _drag_preview_failed:
		var drag_unit := _board.get_unit_by_id(_drag_preview_id) if _board != null else null
		if drag_unit != null:
			var actor: CharacterActor = _actors.get(_drag_preview_id)
			if actor != null:
				_draw_prohibition_badge(actor.position + Vector2(0.0, -18.0))


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


func _status_badge(status_type: int) -> Dictionary:
	## Sharp 2-letter badges — no emoji (emoji at tiny sizes blurs unreadably).
	match status_type:
		GameEnums.StatusType.STAT_BUFF_STR:
			return {"abbr": "S+", "bg": Color(0.22, 0.55, 0.28), "fg": Color(0.92, 1.0, 0.92)}
		GameEnums.StatusType.STAT_BUFF_MAG:
			return {"abbr": "M+", "bg": Color(0.35, 0.28, 0.62), "fg": Color(0.92, 0.88, 1.0)}
		GameEnums.StatusType.STAT_BUFF_DEF:
			return {"abbr": "D+", "bg": Color(0.28, 0.42, 0.62), "fg": Color(0.9, 0.95, 1.0)}
		GameEnums.StatusType.STAT_BUFF_MOV:
			return {"abbr": "V+", "bg": Color(0.22, 0.48, 0.55), "fg": Color(0.9, 1.0, 1.0)}
		GameEnums.StatusType.STAT_BUFF_MP:
			return {"abbr": "V+", "bg": Color(0.22, 0.48, 0.55), "fg": Color(0.9, 1.0, 1.0)}
		GameEnums.StatusType.STAT_BUFF_ACC:
			return {"abbr": "A+", "bg": Color(0.45, 0.38, 0.18), "fg": Color(1.0, 0.96, 0.82)}
		GameEnums.StatusType.STAT_DEBUFF_DEF:
			return {"abbr": "D-", "bg": Color(0.52, 0.22, 0.22), "fg": Color(1.0, 0.9, 0.9)}
		GameEnums.StatusType.STAT_DEBUFF_ACC:
			return {"abbr": "A-", "bg": Color(0.48, 0.32, 0.18), "fg": Color(1.0, 0.92, 0.82)}
		GameEnums.StatusType.STAT_DEBUFF_MOV:
			return {"abbr": "V-", "bg": Color(0.38, 0.28, 0.48), "fg": Color(0.95, 0.9, 1.0)}
		GameEnums.StatusType.ELECTRIFIED:
			return {"abbr": "EL", "bg": Color(0.75, 0.72, 0.18), "fg": Color(0.12, 0.1, 0.05)}
		GameEnums.StatusType.WEAK_TRAP:
			return {"abbr": "TP", "bg": Color(0.42, 0.32, 0.22), "fg": Color(1.0, 0.92, 0.82)}
		GameEnums.StatusType.BURN:
			return {"abbr": "BR", "bg": Color(0.78, 0.32, 0.08), "fg": Color(1.0, 0.95, 0.88)}
		GameEnums.StatusType.BLEED:
			return {"abbr": "BL", "bg": Color(0.62, 0.12, 0.12), "fg": Color(1.0, 0.9, 0.9)}
		GameEnums.StatusType.POISON:
			return {"abbr": "PS", "bg": Color(0.22, 0.55, 0.22), "fg": Color(0.9, 1.0, 0.9)}
		GameEnums.StatusType.WEAKEN:
			return {"abbr": "WK", "bg": Color(0.45, 0.35, 0.22), "fg": Color(1.0, 0.92, 0.82)}
		GameEnums.StatusType.VULNERABLE:
			return {"abbr": "VU", "bg": Color(0.58, 0.22, 0.48), "fg": Color(1.0, 0.9, 0.96)}
		GameEnums.StatusType.STAGGER:
			return {"abbr": "ST", "bg": Color(0.72, 0.62, 0.12), "fg": Color(0.12, 0.1, 0.05)}
		GameEnums.StatusType.ROOT:
			return {"abbr": "RT", "bg": Color(0.32, 0.48, 0.22), "fg": Color(0.92, 1.0, 0.88)}
		GameEnums.StatusType.SILENCE:
			return {"abbr": "SI", "bg": Color(0.35, 0.35, 0.42), "fg": Color(0.92, 0.92, 0.98)}
		GameEnums.StatusType.TAUNT:
			return {"abbr": "TN", "bg": Color(0.55, 0.22, 0.18), "fg": Color(1.0, 0.9, 0.88)}
		GameEnums.StatusType.BLIND:
			return {"abbr": "BD", "bg": Color(0.28, 0.28, 0.32), "fg": Color(0.92, 0.92, 0.96)}
		GameEnums.StatusType.PACIFY:
			return {"abbr": "PC", "bg": Color(0.38, 0.48, 0.58), "fg": Color(0.92, 0.96, 1.0)}
		GameEnums.StatusType.FEAR:
			return {"abbr": "FR", "bg": Color(0.42, 0.28, 0.52), "fg": Color(0.96, 0.9, 1.0)}
		GameEnums.StatusType.CONFUSION:
			return {"abbr": "CF", "bg": Color(0.48, 0.32, 0.58), "fg": Color(0.98, 0.92, 1.0)}
		GameEnums.StatusType.PIERCE:
			return {"abbr": "PI", "bg": Color(0.48, 0.38, 0.22), "fg": Color(1.0, 0.95, 0.85)}
		GameEnums.StatusType.GHOST:
			return {"abbr": "GH", "bg": Color(0.42, 0.52, 0.62), "fg": Color(0.95, 0.98, 1.0)}
		GameEnums.StatusType.TRAMPLE:
			return {"abbr": "TR", "bg": Color(0.42, 0.32, 0.28), "fg": Color(1.0, 0.92, 0.88)}
		GameEnums.StatusType.STEALTH:
			return {"abbr": "SL", "bg": Color(0.22, 0.28, 0.32), "fg": Color(0.88, 0.92, 0.96)}
		GameEnums.StatusType.INTERCEPT:
			return {"abbr": "IN", "bg": Color(0.28, 0.42, 0.58), "fg": Color(0.9, 0.95, 1.0)}
		GameEnums.StatusType.MARK:
			return {"abbr": "MK", "bg": Color(0.58, 0.22, 0.22), "fg": Color(1.0, 0.9, 0.9)}
		GameEnums.StatusType.STURDY:
			return {"abbr": "SD", "bg": Color(0.38, 0.38, 0.42), "fg": Color(0.95, 0.95, 0.98)}
		GameEnums.StatusType.INVULNERABLE:
			return {"abbr": "IV", "bg": Color(0.72, 0.62, 0.18), "fg": Color(0.12, 0.1, 0.05)}
		GameEnums.StatusType.AIRBORNE:
			return {"abbr": "AR", "bg": Color(0.32, 0.48, 0.68), "fg": Color(0.92, 0.96, 1.0)}
		GameEnums.StatusType.CANTO:
			return {"abbr": "CA", "bg": Color(0.32, 0.42, 0.28), "fg": Color(0.92, 1.0, 0.9)}
		GameEnums.StatusType.RUNNING:
			return {"abbr": "RN", "bg": Color(0.28, 0.48, 0.42), "fg": Color(0.9, 1.0, 0.96)}
		GameEnums.StatusType.RETALIATION_PROTOCOL:
			return {"abbr": "RT", "bg": Color(0.55, 0.28, 0.18), "fg": Color(1.0, 0.92, 0.88)}
		GameEnums.StatusType.RETALIATION_INFINITE_RANGE:
			return {"abbr": "R+", "bg": Color(0.62, 0.32, 0.18), "fg": Color(1.0, 0.94, 0.88)}
		GameEnums.StatusType.INDOMITABLE_WILL:
			return {"abbr": "IW", "bg": Color(0.42, 0.35, 0.58), "fg": Color(0.96, 0.92, 1.0)}
		GameEnums.StatusType.THORNS:
			return {"abbr": "TH", "bg": Color(0.32, 0.52, 0.28), "fg": Color(0.92, 1.0, 0.9)}
		GameEnums.StatusType.IRON_GRIP_DEBUFF:
			return {"abbr": "IG", "bg": Color(0.48, 0.35, 0.22), "fg": Color(1.0, 0.92, 0.85)}
		GameEnums.StatusType.POLYMORPH:
			return {"abbr": "PM", "bg": Color(0.38, 0.52, 0.32), "fg": Color(0.92, 1.0, 0.9)}
		_:
			return {"abbr": "??", "bg": Color(0.32, 0.32, 0.38), "fg": Color(0.95, 0.95, 0.98)}


func _unit_foot_map_local(unit_id: int, fallback_cell: Vector2i) -> Vector2:
	var actor: CharacterActor = _actors.get(unit_id)
	if actor != null:
		return actor.position
	if _map_view != null:
		return _map_view.grid_to_foot_local(fallback_cell)
	return Vector2.ZERO


func _unit_visual_cell(unit_id: int, fallback_cell: Vector2i) -> Vector2i:
	if _map_view == null:
		return fallback_cell
	var actor: CharacterActor = _actors.get(unit_id)
	if actor != null:
		return _map_view.foot_local_to_grid(actor.position)
	return fallback_cell


func _draw_hp_bar(unit: UnitState) -> void:
	var foot: Vector2 = _unit_foot_map_local(unit.id, unit.position)
	var origin := foot + Vector2(-BAR_W * 0.5, _hp_bar_vertical_offset(unit))
	var current_hp: int = unit.health.current_hp
	var predicted: int = int(_predicted_hp.get(unit.id, current_hp))
	var max_hp: int = unit.health.max_hp
	if max_hp <= 0:
		return
	var armor: int = maxi(0, unit.armor)
	var predicted_armor: int = int(_predicted_armor.get(unit.id, armor))
	var fortitude: int = 0
	var visual_cell: Vector2i = _unit_visual_cell(unit.id, unit.position)
	if _board != null and _board.is_in_bounds(visual_cell):
		var tile := _board.get_tile(visual_cell)
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


func get_units_for_status_display() -> Array[UnitState]:
	var units: Array[UnitState] = []
	if _board == null:
		return units
	for unit: UnitState in _board.units:
		if not unit.is_alive() or _pending_death.has(unit.id):
			continue
		if _drag_preview_active and unit.id == _drag_preview_id:
			continue
		if unit.active_statuses.is_empty():
			continue
		units.append(unit)
	return units


func status_badge_anchor_map_local(unit: UnitState) -> Vector2:
	var foot: Vector2 = _unit_foot_map_local(unit.id, unit.position)
	return foot + Vector2(-BAR_W * 0.5, _hp_bar_vertical_offset(unit) + BAR_H + 1.0)


func status_badge_style(status_type: int) -> Dictionary:
	return _status_badge(status_type)


func _hp_bar_vertical_offset(unit: UnitState) -> float:
	if _board == null:
		return BAR_OFFSET_Y
	var visual_cell: Vector2i = _unit_visual_cell(unit.id, unit.position)
	var below: Vector2i = visual_cell + Vector2i(0, 1)
	var above: Vector2i = visual_cell + Vector2i(0, -1)
	if _living_unit_at_cell(below, unit.id) != null and _living_unit_at_cell(above, unit.id) == null:
		return BAR_OFFSET_ABOVE_Y
	return BAR_OFFSET_Y


func _living_unit_at_cell(coord: Vector2i, exclude_id: int = -1) -> UnitState:
	if _board == null or not _board.is_in_bounds(coord):
		return null
	var occupant: UnitState = _board.get_unit_at(coord)
	if occupant == null or not occupant.is_alive() or occupant.id == exclude_id:
		return null
	return occupant


func _draw_prohibition_badge(center: Vector2) -> void:
	var scale: float = maxf(1.0, _display_scale())
	var half: float = roundf(5.0 * scale)
	var c: Vector2 = Vector2(roundf(center.x), roundf(center.y))
	var bg := Rect2(c - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	draw_rect(bg, Color(0.55, 0.08, 0.08, 0.92), true)
	draw_rect(bg, Color(1.0, 0.35, 0.35), false, 1.0)
	var pad: float = roundf(2.0 * scale)
	draw_line(c + Vector2(-half + pad, -half + pad), c + Vector2(half - pad, half - pad), Color.WHITE, 1.5)
	draw_line(c + Vector2(-half + pad, half - pad), c + Vector2(half - pad, -half + pad), Color.WHITE, 1.5)


func _draw_centered_icon(pos: Vector2, text: String, color: Color, size_px: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var px: int = maxi(8, size_px)
	var snapped: Vector2 = Vector2(roundf(pos.x), roundf(pos.y))
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_string(font, snapped - Vector2(roundf(sz.x * 0.5), roundf(sz.y * 0.5)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


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
	if _any_predicted_change():
		need_redraw = true
	if not _move_tweens.is_empty():
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
