class_name OptionsMenu
extends CanvasLayer

## In-game settings host — opens the unified `OptionsScreen` overlay (same UI as main menu).

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

const _OPTIONS_SCENE: PackedScene = preload("res://scenes/Options.tscn")

var _settings: GameSettings
var _on_applied: Callable
var _char_profile: CharacterGenProfile
var _effects_settings: EffectsSettings
var _on_effects_changed: Callable
var _combat_mode: bool = false
var _overlay: Control = null
var _is_open: bool = false


func _ready() -> void:
	layer = 30
	visible = true


func setup(settings: GameSettings, on_applied: Callable) -> void:
	_settings = settings
	_on_applied = on_applied


func setup_character_gen(profile: CharacterGenProfile) -> void:
	_char_profile = profile


func setup_combat_effects(settings: EffectsSettings, on_changed: Callable) -> void:
	_effects_settings = settings
	_on_effects_changed = on_changed


func setup_combat_director(_director: CombatDirector) -> void:
	# Battle actions live on the pause menu — settings UI is unified only.
	pass


func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled


func set_map_tool_state(tile_labels: bool, boredom_atmosphere: bool, boredom_water: bool) -> void:
	if _overlay == null:
		return
	var screen: OptionsScreen = _overlay as OptionsScreen
	if screen != null:
		screen.set_map_tool_state(tile_labels, boredom_atmosphere, boredom_water)


func is_open() -> bool:
	return _is_open


func open() -> void:
	_open_overlay()


func open_display() -> void:
	_open_overlay()


func close_menu() -> void:
	_close_overlay()


func go_back() -> void:
	close_menu()


func toggle() -> void:
	if _is_open:
		close_menu()
	else:
		open()


func _open_overlay() -> void:
	if _settings == null or _is_open:
		return
	_overlay = _OPTIONS_SCENE.instantiate() as Control
	var screen: OptionsScreen = _overlay as OptionsScreen
	if screen == null:
		_overlay.queue_free()
		_overlay = null
		return
	screen.overlay_mode = true
	screen.hide_developer_tab = _combat_mode
	screen.show_sandbox_tools = not _combat_mode
	screen.setup(_settings, _on_applied, _effects_settings, _on_effects_changed)
	if _char_profile != null:
		screen.setup_character_gen(_char_profile)
	screen.map_regenerate_requested.connect(func() -> void: map_regenerate_requested.emit())
	screen.map_reseed_requested.connect(func() -> void: map_reseed_requested.emit())
	screen.map_toggle_center_requested.connect(func() -> void: map_toggle_center_requested.emit())
	screen.map_resize_requested.connect(func(delta: int) -> void: map_resize_requested.emit(delta))
	screen.map_cycle_biome_requested.connect(func() -> void: map_cycle_biome_requested.emit())
	screen.map_tile_labels_toggled.connect(func(pressed: bool) -> void: map_tile_labels_toggled.emit(pressed))
	screen.map_boredom_atmosphere_toggled.connect(func(pressed: bool) -> void: map_boredom_atmosphere_toggled.emit(pressed))
	screen.map_boredom_water_toggled.connect(func(pressed: bool) -> void: map_boredom_water_toggled.emit(pressed))
	screen.character_gen_changed.connect(func() -> void: character_gen_changed.emit())
	screen.close_requested.connect(_close_overlay)
	add_child(_overlay)
	layer = 40
	_is_open = true
	opened.emit()


func _close_overlay() -> void:
	if not _is_open:
		return
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_is_open = false
	layer = 30
	closed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		toggle()
		get_viewport().set_input_as_handled()
