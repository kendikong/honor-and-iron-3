class_name OptionsMenu
extends CanvasLayer

## In-game settings overlay — **O** to toggle. Hosts the same OptionsScreen as the main menu.

const _OPTIONS_SCENE: PackedScene = preload("res://scenes/Options.tscn")

signal opened
signal closed
signal map_regenerate_requested
signal map_reseed_requested
signal map_toggle_center_requested
signal map_resize_requested(delta: int)
signal map_cycle_biome_requested
signal map_tile_labels_toggled(pressed: bool)
signal map_boredom_atmosphere_toggled(pressed: bool)
signal map_boredom_water_toggled(pressed: bool)
signal character_gen_changed

var _settings: GameSettings
var _effects_settings: EffectsSettings
var _on_applied: Callable
var _on_effects_changed: Callable
var _char_profile: CharacterGenProfile

var _screen: OptionsScreen
var _is_open: bool = false
var _combat_mode: bool = false
var _sandbox_tools_enabled: bool = false

var _pending_map_tool_state: Dictionary = {}


func _ready() -> void:
	layer = 30


func setup(settings: GameSettings, on_applied: Callable) -> void:
	_settings = settings
	_on_applied = on_applied


func setup_character_gen(profile: CharacterGenProfile) -> void:
	_char_profile = profile
	if _screen != null:
		_screen.setup_character_gen(profile)


func setup_combat_effects(settings: EffectsSettings, on_changed: Callable) -> void:
	_effects_settings = settings
	_on_effects_changed = on_changed


func setup_combat_director(_director: CombatDirector) -> void:
	pass


func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled


func set_sandbox_tools_enabled(enabled: bool) -> void:
	_sandbox_tools_enabled = enabled


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _settings == null or _is_open:
		return
	_screen = _OPTIONS_SCENE.instantiate() as OptionsScreen
	_screen.overlay_mode = true
	_screen.live_preview = true
	_screen.hide_developer_tab = false
	_screen.show_sandbox_tools = _sandbox_tools_enabled and not _combat_mode
	_screen.setup(_settings, _on_applied, _effects_settings, _on_effects_changed)
	if _char_profile != null:
		_screen.setup_character_gen(_char_profile)
	_apply_pending_map_tool_state()
	_connect_screen_signals()
	add_child(_screen)
	layer = 40
	_is_open = true
	opened.emit()


func open_display() -> void:
	open()


func close_menu() -> void:
	if not _is_open:
		return
	if _screen != null:
		_screen.queue_free()
		_screen = null
	_is_open = false
	layer = 30
	closed.emit()


func go_back() -> void:
	close_menu()


func toggle() -> void:
	if _is_open:
		close_menu()
	else:
		open()


func set_map_tool_state(tile_labels: bool, boredom_atmosphere: bool, boredom_water: bool) -> void:
	_pending_map_tool_state = {
		"tile_labels": tile_labels,
		"boredom_atmosphere": boredom_atmosphere,
		"boredom_water": boredom_water,
	}
	if _screen != null:
		_screen.set_map_tool_state(tile_labels, boredom_atmosphere, boredom_water)


func _apply_pending_map_tool_state() -> void:
	if _screen == null or _pending_map_tool_state.is_empty():
		return
	_screen.set_map_tool_state(
		bool(_pending_map_tool_state.get("tile_labels", false)),
		bool(_pending_map_tool_state.get("boredom_atmosphere", false)),
		bool(_pending_map_tool_state.get("boredom_water", false)),
	)


func _connect_screen_signals() -> void:
	if _screen == null:
		return
	_screen.close_requested.connect(close_menu)
	_screen.map_regenerate_requested.connect(func() -> void: map_regenerate_requested.emit())
	_screen.map_reseed_requested.connect(func() -> void: map_reseed_requested.emit())
	_screen.map_toggle_center_requested.connect(func() -> void: map_toggle_center_requested.emit())
	_screen.map_resize_requested.connect(func(delta: int) -> void: map_resize_requested.emit(delta))
	_screen.map_cycle_biome_requested.connect(func() -> void: map_cycle_biome_requested.emit())
	_screen.map_tile_labels_toggled.connect(func(pressed: bool) -> void: map_tile_labels_toggled.emit(pressed))
	_screen.map_boredom_atmosphere_toggled.connect(func(pressed: bool) -> void: map_boredom_atmosphere_toggled.emit(pressed))
	_screen.map_boredom_water_toggled.connect(func(pressed: bool) -> void: map_boredom_water_toggled.emit(pressed))
	_screen.character_gen_changed.connect(func() -> void: character_gen_changed.emit())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		toggle()
		get_viewport().set_input_as_handled()
