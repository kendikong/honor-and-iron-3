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
@onready var _director: CombatDirector = $CombatDirector
@onready var _combat_hud: TacticalCombatHud = $CombatHud
@onready var _unit_overlay: TacticalUnitOverlay = $WorldModulate/MapRoot/UnitOverlay
@onready var _unit_layer: TacticalUnitLayer = $WorldModulate/MapRoot/UnitLayer
@onready var _planning_overlay: TacticalPlanningOverlay = $WorldModulate/MapRoot/PlanningOverlay
@onready var _sim_presenter: TacticalSimPresenter = $SimPresenter
@onready var _input_controller: TacticalInputController = $InputController
@onready var _sfx: SfxPlayer = $SfxPlayer
@onready var _combat_shell: TacticalCombatShell = $CombatShell

var _side_panels: TacticalSidePanels
var _pause_menu: TacticalPauseMenu
var _asset_preloader: LpcAssetPreloader

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
var _last_tree_variant_b: bool = false
var _char_profile: CharacterGenProfile = CharacterGenProfile.new()


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
	_load_char_profile()
	_options.setup_character_gen(_char_profile)
	_options.setup_combat_effects(_effects.settings, _on_effects_settings_changed)
	_options.set_combat_mode(true)
	_options.setup_combat_director(_director)
	_options.character_gen_changed.connect(_on_character_gen_changed)
	_options.opened.connect(_on_options_opened)
	_options.closed.connect(_on_options_closed)

	_asset_preloader = LpcAssetPreloader.new()
	_asset_preloader.name = "LpcAssetPreloader"
	add_child(_asset_preloader)
	_asset_preloader.start(LpcCatalog.load_from_disk())

	_side_panels = TacticalSidePanels.new()
	_side_panels.name = "SidePanels"
	add_child(_side_panels)

	_pause_menu = TacticalPauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)

	_combat_shell.setup(
		self,
		_director,
		_side_panels,
		_pause_menu,
		_combat_hud,
		_unit_layer,
		_unit_overlay,
		_planning_overlay,
		_sim_presenter,
		_input_controller,
		_sfx,
		_options,
		_char_profile,
	)
	_camera.changed.connect(_center_map)
	get_viewport().size_changed.connect(_on_viewport_resized)
	get_window().close_requested.connect(_persist_settings)

	_load_skirmish()
	_init_tile_pipeline()
	_regenerate()
	_start_combat()


func get_encounter() -> EncounterData:
	return _encounter


func get_skirmish() -> SkirmishGenerator.SkirmishResult:
	return _skirmish


func get_ground_used_rect() -> Rect2i:
	return _ground.get_used_rect()


func grid_to_local(cell: Vector2i) -> Vector2:
	var used: Rect2i = _ground.get_used_rect()
	var local_cell: Vector2i = cell - used.position
	return Vector2(local_cell) * float(TILE_PX) + Vector2(TILE_PX, TILE_PX) * 0.5


func grid_to_foot_local(cell: Vector2i) -> Vector2:
	var used: Rect2i = _ground.get_used_rect()
	var local_cell: Vector2i = cell - used.position
	return Vector2(local_cell) * float(TILE_PX) + Vector2(TILE_PX * 0.5, TILE_PX)


func get_player_grid() -> PlayerGrid:
	return _player_grid


func get_trees_layer() -> TileMapLayer:
	return _trees


func get_overlay_layer() -> TileMapLayer:
	return _overlay


func get_scatter_layer() -> TileMapLayer:
	return _scatter


func get_effects_settings() -> EffectsSettings:
	return _effects.settings


func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var zoom: float = _map_root.scale.x
	if zoom < 0.001:
		zoom = 1.0
	var map_local: Vector2 = (screen_pos - position) / zoom
	var used: Rect2i = _ground.get_used_rect()
	return Vector2i(
		int(floor(map_local.x / float(TILE_PX))) + used.position.x,
		int(floor(map_local.y / float(TILE_PX))) + used.position.y,
	)


func _start_combat() -> void:
	_combat_shell.start_combat(_encounter)


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


func _exit_tree() -> void:
	_persist_settings()


func _persist_settings() -> void:
	_settings.capture_from_window(get_window())
	_settings.save_to_disk()
	_effects.settings.save_to_disk()


func _on_viewport_resized() -> void:
	_center_map()
	_apply_effects()


func _on_options_opened() -> void:
	if _input_controller != null:
		_input_controller.cancel_drag()
		_input_controller.cancel_aim()


func _on_options_closed() -> void:
	_apply_effects()


func _on_effects_settings_changed() -> void:
	_effects.settings.save_to_disk()
	_apply_effects()


func _load_char_profile() -> void:
	_char_profile.load_from_user_disk()


func _on_character_gen_changed() -> void:
	if _unit_layer != null:
		_unit_layer.refresh_display_scale()


func _on_display_settings_applied() -> void:
	_center_map()
	_apply_effects()


func _unhandled_input(event: InputEvent) -> void:
	if _camera.handle_input(event, _options.is_open() or _pause_menu.is_open()):
		_center_map()
		get_viewport().set_input_as_handled()
		return
	if _options.is_open() or _pause_menu.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if _options.is_open():
				_options.close_menu()
			elif _pause_menu.is_open():
				_pause_menu.close_menu()
			get_viewport().set_input_as_handled()
		return
	if _input_controller != null and _input_controller.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_pause_menu.open()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O:
			_options.open()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_effects.process_frame(delta)
	_update_hover_coord()


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
	if _ecology_layer != null:
		_ecology_layer.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if _effects.settings.any_phase7()
			else Node.PROCESS_MODE_DISABLED
		)


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
	if _unit_overlay != null:
		_unit_overlay.queue_redraw()
	if _unit_layer != null:
		_unit_layer.queue_redraw()
	if _planning_overlay != null:
		_planning_overlay.queue_redraw()


func _update_hover_coord() -> void:
	if _director == null or _director.board == null:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var cell: Vector2i = screen_to_grid(get_viewport().get_mouse_position())
	if _side_panels != null:
		_side_panels.set_hover_coord(cell)
	if _planning_overlay != null:
		_planning_overlay.set_hover_coord(cell)
