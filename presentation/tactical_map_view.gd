class_name TacticalMapView
extends Node2D

## Combat map host — mana-seed visuals from a generated skirmish (no dev side panels).

const _SparkleSprites = preload("res://scripts/water_sparkle_sprites.gd")
const _EcologyLayer = preload("res://scripts/ecology_layer.gd")
const _C = preload("res://scripts/mana_seed_constants.gd")

const TILE_PX: int = TacticalConstants.TILE_PX

@onready var _world_modulate: CanvasModulate = $WorldModulate
@onready var _map_root: Node2D = $WorldModulate/MapRoot
@onready var _sky_overlay: Node2D = $WorldModulate/SkyOverlay
@onready var _ground: TileMapLayer = $WorldModulate/MapRoot/GroundLayer
@onready var _scatter: TileMapLayer = $WorldModulate/MapRoot/ScatterLayer
@onready var _shadow_sprites: Node2D = $WorldModulate/MapRoot/ShadowSprites
@onready var _phantom: TileMapLayer = $WorldModulate/MapRoot/PhantomLayer
@onready var _overlay: TileMapLayer = $WorldModulate/MapRoot/OverlayLayer
@onready var _trees: TileMapLayer = $WorldModulate/MapRoot/TreeLayer
@onready var _vfx: TileMapLayer = $WorldModulate/MapRoot/VFXLayer
@onready var _options: OptionsMenu = $OptionsMenu

var _tile_set: TileSet
var _decorator: AutoDecorator = AutoDecorator.new()
var _atmosphere: AtmosphereBinder = AtmosphereBinder.new()
var _effects: EffectsController = EffectsController.new()
var _player_grid: PlayerGrid
var _logical_provenance: PlayerGridProvenance = PlayerGridProvenance.new()
var _render_provenance: MapRenderProvenance = MapRenderProvenance.new()
var _settings: GameSettings = GameSettings.new()
var _camera: MapCameraController = MapCameraController.new()
var _sparkle_sprites: Node2D
var _ecology_layer: EcologyLayer
var _skirmish: SkirmishGenerator.SkirmishResult
var _encounter: EncounterData
var _biome_variant: int = 1
var _combat_hud: CanvasLayer
var _title_label: Label
var _last_tree_variant_b: bool = false


func _ready() -> void:
	_settings.load_from_disk()
	_settings.apply_to_window(get_window())

	_atmosphere.setup(_world_modulate, _sky_overlay, _map_root)
	_shadow_sprites.z_as_relative = false
	_shadow_sprites.z_index = _C.Z_SHADOW

	_sparkle_sprites = _SparkleSprites.new()
	_sparkle_sprites.name = "SparkleSprites"
	_sparkle_sprites.z_as_relative = false
	_sparkle_sprites.z_index = _C.Z_VFX
	_map_root.add_child(_sparkle_sprites)

	_ecology_layer = _EcologyLayer.new()
	_ecology_layer.name = "EcologyLayer"
	_ecology_layer.z_as_relative = false
	_ecology_layer.z_index = _C.Z_ECOLOGY
	_map_root.add_child(_ecology_layer)

	_decorator.render_provenance = _render_provenance
	_decorator.logical_provenance = _logical_provenance

	_options.setup(_settings, _on_display_settings_applied)
	_options.opened.connect(_on_options_opened)
	_options.closed.connect(_on_options_closed)

	_camera.changed.connect(_center_map)
	get_viewport().size_changed.connect(_on_viewport_resized)
	get_window().close_requested.connect(_persist_settings)

	_build_combat_hud()
	_load_skirmish()
	_init_tile_pipeline()
	_regenerate()


func get_encounter() -> EncounterData:
	return _encounter


func get_skirmish() -> SkirmishGenerator.SkirmishResult:
	return _skirmish


func _load_skirmish() -> void:
	var config: SkirmishGenerator.SkirmishConfig = SkirmishLaunch.take_pending()
	_biome_variant = config.biome_variant
	_skirmish = SkirmishGenerator.generate(config)
	_player_grid = _skirmish.grid
	_encounter = EncounterBuilder.build_from_player_grid(
		_skirmish.grid,
		_skirmish.blocked_cells,
		_skirmish.player_spawns,
		_skirmish.enemy_spawns,
	)
	_decorator.map_seed = _skirmish.map_seed
	_update_title()


func _init_tile_pipeline() -> void:
	_biome_variant = clampi(_biome_variant, 1, BiomeProfile.variant_count())
	_effects.settings.biome_variant = _biome_variant
	_effects.set_biome_variant(_biome_variant)
	_tile_set = TileSetFactory.build_combined_tileset(_biome_variant)
	_effects.setup(
		_atmosphere,
		_ground,
		_overlay,
		_trees,
		_vfx,
		_shadow_sprites,
		_world_modulate,
		_sky_overlay,
		_map_root,
		_skirmish.map_seed,
		_sparkle_sprites,
		_ecology_layer,
		_scatter,
	)
	_decorator.setup(
		_ground, _scatter, _overlay, _trees, _vfx, _phantom, _shadow_sprites, _tile_set,
	)
	ShadowPlacer.clear_bake_cache()
	_effects.set_map_seed(_skirmish.map_seed)


func _build_combat_hud() -> void:
	_combat_hud = CanvasLayer.new()
	_combat_hud.name = "CombatHud"
	_combat_hud.layer = 10
	add_child(_combat_hud)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	_combat_hud.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var back := Button.new()
	back.text = "← Battle Setup"
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_title_label)


func _update_title() -> void:
	if _title_label == null or _skirmish == null:
		return
	_title_label.text = "Random Skirmish — %dx%d · seed %d" % [
		_skirmish.grid.width,
		_skirmish.grid.height,
		_skirmish.map_seed,
	]


func _exit_tree() -> void:
	_persist_settings()


func _persist_settings() -> void:
	_settings.capture_from_window(get_window())
	_settings.save_to_disk()
	_effects.settings.save_to_disk()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")


func _on_viewport_resized() -> void:
	_center_map()
	_apply_effects()


func _on_options_opened() -> void:
	pass


func _on_options_closed() -> void:
	pass


func _on_display_settings_applied() -> void:
	_center_map()
	_apply_effects()


func _unhandled_input(event: InputEvent) -> void:
	if _camera.handle_input(event, _options.is_open()):
		_center_map()
		get_viewport().set_input_as_handled()
		return
	if _options.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _options.is_open():
				_options.close_menu()
			else:
				_options.open()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_effects.process_frame(delta)


func _regenerate() -> void:
	_sync_tree_variant_setting()
	_decorator.regenerate(_player_grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = _decorator.map_seed
	_effects.rebuild_water_vfx_cache(_player_grid, rng)
	_center_map()
	_apply_effects()


func _sync_tree_variant_setting() -> void:
	_last_tree_variant_b = _effects.settings.tree_variant_b
	_decorator.tree_variant_b = _last_tree_variant_b


func _apply_effects() -> void:
	var water_ratio: float = 0.22 if _player_grid != null else 0.0
	_effects.apply_all(_player_grid, water_ratio, _decorator.ecology_hints)


func _center_map() -> void:
	var used: Rect2i = _ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var map_pixels: Vector2 = Vector2(used.size) * float(TILE_PX)
	var viewport: Vector2 = get_viewport_rect().size
	var layout: Dictionary = _camera.compute_layout(
		_settings, map_pixels, viewport, 0.0, 0.0, used.position,
	)
	_map_root.scale = layout["map_root_scale"]
	position = layout["scene_position"]
