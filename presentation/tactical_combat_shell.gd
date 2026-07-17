class_name TacticalCombatShell
extends Node

## Orchestrates tactical combat presentation wiring.
## Setup order (mandatory):
##   1. Map pipeline + options (map view _ready)
##   2. shell.setup() — bind listeners before director emits board_changed
##   3. director.start_from_encounter()
## Layer z: SidePanels=21, Hud=22, Pause=35, Options=40 (when open)

var intent_state: CombatIntentState = CombatIntentState.new()
var planning_input: CombatPlanningInput = CombatPlanningInput.new()

var _map_view: TacticalMapView
var _director: CombatDirector
var _side_panels: TacticalSidePanels
var _pause_menu: TacticalPauseMenu
var _combat_hud: TacticalCombatHud
var _unit_layer: TacticalUnitLayer
var _unit_overlay: TacticalUnitOverlay
var _planning_overlay: TacticalPlanningOverlay
var _sim_presenter: TacticalSimPresenter
var _input_controller: TacticalInputController
var _sfx: SfxPlayer
var _options: OptionsMenu
var _char_profile: CharacterGenProfile


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	side_panels: TacticalSidePanels,
	pause_menu: TacticalPauseMenu,
	combat_hud: TacticalCombatHud,
	unit_layer: TacticalUnitLayer,
	unit_overlay: TacticalUnitOverlay,
	planning_overlay: TacticalPlanningOverlay,
	sim_presenter: TacticalSimPresenter,
	input_controller: TacticalInputController,
	sfx: SfxPlayer,
	options: OptionsMenu,
	char_profile: CharacterGenProfile,
) -> void:
	_map_view = map_view
	_director = director
	_side_panels = side_panels
	_pause_menu = pause_menu
	_combat_hud = combat_hud
	_unit_layer = unit_layer
	_unit_overlay = unit_overlay
	_planning_overlay = planning_overlay
	_sim_presenter = sim_presenter
	_input_controller = input_controller
	_sfx = sfx
	_options = options
	_char_profile = char_profile

	intent_state.bind(director)
	_wire_intent_state()
	_wire_pause_visibility()
	_wire_unit_feedback()


var _settings: GameSettings


func bind_settings(settings: GameSettings) -> void:
	_settings = settings
	_apply_ui_settings()


func _apply_ui_settings() -> void:
	if _settings == null:
		return
	if _side_panels != null:
		_side_panels.apply_settings(_settings)
	if _combat_hud != null:
		_combat_hud.apply_settings(_settings)


func start_combat(encounter: EncounterData) -> void:
	_unit_layer.setup(_map_view, _director, _char_profile)
	_unit_overlay.setup(_map_view, _director, _unit_layer)
	_planning_overlay.setup(_map_view, _director, intent_state)
	_planning_overlay.bind_unit_layer(_unit_layer)
	_side_panels.setup(_director, _map_view, intent_state, planning_input)
	_pause_menu.setup(_director, _map_view, _options)
	_director.start_from_encounter(encounter)
	_combat_hud.setup(_director, _map_view, _sfx, _side_panels, intent_state)
	_sim_presenter.setup(_director, _unit_overlay, _unit_layer, _map_view)
	planning_input.setup(
		_map_view,
		_director,
		_planning_overlay,
		intent_state,
		_sfx,
	)
	_planning_overlay.bind_planning_input(planning_input)
	_input_controller.setup(
		_map_view,
		_director,
		_planning_overlay,
		_sfx,
		planning_input,
		intent_state,
		func() -> bool: return _options.is_open() or _pause_menu.is_open(),
	)
	_sfx.bind_director(_director)
	if _director.board != null:
		intent_state.set_board(_director.board)
	_apply_ui_settings()


func _wire_intent_state() -> void:
	EventBus.board_changed.connect(func(board: BoardState) -> void:
		intent_state.set_board(board),
	)
	EventBus.preview_updated.connect(func(result: SimResult) -> void:
		intent_state.set_preview_board(result.final_state),
	)
	EventBus.selection_changed.connect(func(unit_id: int) -> void:
		intent_state.set_selection(unit_id),
	)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		intent_state.set_phase(phase),
	)


func _wire_pause_visibility() -> void:
	if _pause_menu == null:
		return
	_pause_menu.opened.connect(func() -> void:
		if _side_panels != null:
			_side_panels.visible = false
		if _combat_hud != null:
			_combat_hud.visible = false,
	)
	_pause_menu.closed.connect(func() -> void:
		if _side_panels != null:
			_side_panels.visible = true
		if _combat_hud != null:
			_combat_hud.visible = true,
	)


func _wire_unit_feedback() -> void:
	if _unit_layer == null or intent_state == null:
		return
	intent_state.intents_changed.connect(func(units: Dictionary) -> void:
		_unit_layer.set_intent_units(units),
	)
	intent_state.timeline_hover_changed.connect(func(unit_id: int) -> void:
		_unit_layer.set_timeline_hover(unit_id),
	)
