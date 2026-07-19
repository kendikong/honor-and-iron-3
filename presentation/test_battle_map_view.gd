class_name TestBattleMapView
extends TacticalMapView

## 6×6 grass training arena — full tactical combat + debug tooling.

var _session: TestBattleSession = TestBattleSession.new()
var _debug_panel: TestBattleDebugPanel


func _ready() -> void:
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
	super._start_combat()
	apply_training_board()


func apply_training_board() -> void:
	if _director == null:
		return
	_encounter = TestBattleEncounterBuilder.build_encounter(_session)
	_director.start_from_custom(TestBattleEncounterBuilder.build_board(_session))


func _on_training_turn_phase(phase: int) -> void:
	if phase != CombatDirector.Phase.PLANNING or not _session.unkillable_dummies:
		return
	if _director == null or _director.board == null:
		return
	for unit: UnitState in _director.board.units:
		if unit.definition == null or unit.definition.id != &"training_dummy":
			continue
		if not unit.is_alive():
			apply_training_board()
			return
		unit.health.current_hp = unit.health.max_hp
