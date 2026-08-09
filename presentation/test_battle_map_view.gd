class_name TestBattleMapView
extends TacticalMapView

## 10×10 grass training arena — full tactical combat + debug tooling.

var _session: TestBattleSession = TestBattleSession.new()
var _debug_panel: TestBattleDebugPanel


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
		and (_qa_perf_mode or OS.has_environment("LIVE_QA_PROFILE"))
	):
		get_tree().quit(130)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _ready() -> void:
	_session.load_prefs()
	super._ready()
	_debug_panel = TestBattleDebugPanel.new()
	_debug_panel.name = "TestBattleDebugPanel"
	add_child(_debug_panel)
	_debug_panel.setup(self, _session, _director)
	EventBus.turn_phase_changed.connect(_on_training_turn_phase)


func _load_skirmish() -> void:
	_biome_variant = 1
	_player_grid = TestBattleEncounterBuilder.build_grass_grid()
	_encounter = TestBattleEncounterBuilder.build_encounter(_session)
	_skirmish = SkirmishGenerator.SkirmishResult.new()
	_skirmish.grid = _player_grid
	_skirmish.map_seed = TestBattleSession.MAP_SEED
	_skirmish.biome_variant = _biome_variant
	_skirmish.blocked_cells = {}
	_skirmish.player_spawns = _encounter.player_spawns
	_skirmish.enemy_spawns = _encounter.enemy_spawns
	_decorator.map_seed = _skirmish.map_seed
	_decorator.decoration_density = 0.0


func _refine_spawn_positions() -> void:
	pass


func _start_combat() -> void:
	_encounter = TestBattleEncounterBuilder.build_encounter(_session)
	var board: BoardState = TestBattleEncounterBuilder.build_board(_session)
	_wire_training_director()
	_combat_shell.start_combat(_encounter, board)
	_combat_shell.bind_settings(_settings)
	_sim_presenter.set_game_settings(_settings)
	_configure_arena_hud()
	_director.select_unit(_first_player_unit_id())


func _active_board() -> BoardState:
	if _director == null:
		return null
	if _director.base_board != null:
		return _director.base_board
	return _director.board


func apply_training_board() -> void:
	if _director == null:
		return
	if _unit_layer != null:
		_unit_layer.abort_planning_commit_sequence()
	_director.flush_plan_refresh_signals_if_pending()
	_encounter = TestBattleEncounterBuilder.build_encounter(_session)
	var board: BoardState = TestBattleEncounterBuilder.build_board(_session)
	_director.start_from_custom(board)
	if _unit_layer != null:
		_unit_layer.rebuild_all_actor_visuals()
	_director.flush_plan_refresh_signals_if_pending()
	_director.select_unit(_first_player_unit_id())


func get_session() -> TestBattleSession:
	return _session


func get_live_board() -> BoardState:
	return _active_board()


func _wire_training_director() -> void:
	if _director == null:
		return
	_director.suppress_end_state = Callable(self, "_suppress_training_victory")


func _suppress_training_victory(board: BoardState) -> bool:
	if board == null or not _session.unkillable_dummies:
		return false
	if board.has_living_team(GameEnums.Team.ENEMY):
		return false
	TestBattleEncounterBuilder.maintain_training_dummies(board, _session)
	return board.has_living_team(GameEnums.Team.ENEMY)


func _configure_arena_hud() -> void:
	if _combat_hud == null:
		return
	_combat_hud.configure_victory_restart(
		"Continue Training",
		func() -> void:
			apply_training_board(),
	)


func _on_training_turn_phase(phase: int) -> void:
	var board: BoardState = _active_board()
	if board == null:
		return
	if phase == CombatDirector.Phase.PLANNING:
		if _session.infinite_player_ap:
			for unit: UnitState in board.units:
				if unit.team != GameEnums.Team.PLAYER:
					continue
				unit.ability.points_left = unit.ability.max_points
				unit.movement.points_left = unit.movement.max_points
				unit.turn_action_used = false
		if _session.unkillable_dummies:
			TestBattleEncounterBuilder.maintain_training_dummies(board, _session)


func _first_player_unit_id() -> int:
	var board: BoardState = _active_board()
	if board == null:
		return 1
	for unit: UnitState in board.units:
		if unit.is_alive() and not unit.is_enemy():
			return unit.id
	return 1


func _center_map() -> void:
	var used: Rect2i = _ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var map_pixels: Vector2 = Vector2(used.size) * float(TILE_PX)
	var viewport: Vector2 = get_viewport_rect().size
	var right_inset: float = float(TestBattleDebugPanel.PANEL_WIDTH + 16)
	var layout: Dictionary = _camera.compute_layout(
		_settings, map_pixels, viewport, 0.0, right_inset, used.position,
	)
	_map_root.scale = layout["map_root_scale"]
	position = layout["scene_position"]
	_effects.sync_map_transform()
	_sync_overlay_huds(layout["origin"], layout["scaled_size"])
	if _unit_overlay != null:
		_unit_overlay.queue_redraw()
	if _unit_layer != null:
		_unit_layer.queue_redraw()
	if _planning_overlay != null:
		_planning_overlay.queue_redraw()
