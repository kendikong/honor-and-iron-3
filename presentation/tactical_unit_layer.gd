class_name TacticalUnitLayer
extends Node2D

## LPC unit sprites on the tactical grid (Phase 5).

const _CharacterActor = preload("res://scripts/lpc/character_actor.gd")

const BAR_W: float = 14.0
const BAR_H: float = 3.0
const BAR_OFFSET_Y: float = 22.0

const _COLOR_HP_BG := Color(0.08, 0.08, 0.10, 0.92)
const _COLOR_HP_FILL := Color(0.38, 0.78, 0.46)
const _COLOR_SELECT := Color(0.98, 0.86, 0.32, 0.95)

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState
var _catalog: LpcCatalog
var _profile: CharacterGenProfile = CharacterGenProfile.new()
var _actors: Dictionary = {}
var _selected_id: int = -1


func setup(map_view: TacticalMapView, director: CombatDirector) -> void:
	_map_view = map_view
	_director = director
	z_as_relative = false
	z_index = 6
	_load_profile()
	_catalog = LpcCatalog.load_from_disk()
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.sim_event.connect(_on_sim_event)
	queue_redraw()


func is_sprites_active() -> bool:
	return not _actors.is_empty()


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists("user://character_gen.cfg"):
		cfg.load("user://character_gen.cfg")
	_profile.load_from_config(cfg)


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


func _on_sim_event(event: SimEvent) -> void:
	if _board == null:
		return
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED, GameEnums.SimEventType.UNIT_PUSHED:
			var unit_id: int = int(event.data.get("actor", event.data.get("unit", -1)))
			var to_coord: Variant = event.data.get("to", null)
			if to_coord is Vector2i:
				var unit := _board.get_unit_by_id(unit_id)
				if unit != null:
					unit.position = to_coord
					_position_actor(unit_id, to_coord)
					_apply_facing(unit_id, unit.facing)
		GameEnums.SimEventType.UNIT_DAMAGED:
			var target_id: int = int(event.data.get("unit", -1))
			var hp: int = int(event.data.get("hp", 0))
			var target := _board.get_unit_by_id(target_id)
			if target != null:
				target.health.current_hp = hp
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
		_position_actor(unit.id, unit.position)
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
		_draw_hp_bar(unit)
		if unit.id == _selected_id:
			var foot: Vector2 = _map_view.grid_to_foot_local(unit.position)
			draw_arc(foot + Vector2(0.0, -10.0), 9.0, 0.0, TAU, 24, _COLOR_SELECT, 2.0)


func _draw_hp_bar(unit: UnitState) -> void:
	var foot: Vector2 = _map_view.grid_to_foot_local(unit.position)
	var origin := foot + Vector2(-BAR_W * 0.5, -BAR_OFFSET_Y)
	var frac: float = 1.0
	if unit.health.max_hp > 0:
		frac = clampf(float(unit.health.current_hp) / float(unit.health.max_hp), 0.0, 1.0)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), _COLOR_HP_BG)
	draw_rect(Rect2(origin, Vector2(BAR_W * frac, BAR_H)), _COLOR_HP_FILL)
