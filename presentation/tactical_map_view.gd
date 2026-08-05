class_name TacticalMapView
extends Node2D

## Combat map host â€” mana-seed visuals from a generated skirmish (no dev side panels).

const _SparkleSprites = preload("res://scripts/water_sparkle_sprites.gd")
const _EcologyLayer = preload("res://scripts/ecology_layer.gd")
const _FpsHud = preload("res://scripts/fps_hud.gd")
const _WorldClockHud = preload("res://scripts/world_clock_hud.gd")
const _TreeCanopyFader = preload("res://presentation/tree_canopy_fader.gd")
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
var _planning_cursor: TacticalPlanningCursor
var _status_badges: TacticalStatusBadges
var _asset_preloader: LpcAssetPreloader

var _tile_set: TileSet
var _decorator: AutoDecorator = AutoDecorator.new()
var _atmosphere: AtmosphereBinder = AtmosphereBinder.new()
var _effects: EffectsController = EffectsController.new()
var _qa_perf_mode: bool = false
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
var _fps_hud: FpsHud
var _clock_hud: WorldClockHud
var _last_polled_hover_cell: Vector2i = Vector2i(-999999, -999999)
var _tree_fader: TreeCanopyFader
var _planning_input: CombatPlanningInput
var _autobattler_panel: AutobattlerControlPanel


func _ready() -> void:
	_settings.load_from_disk()
	_settings.apply_audio_buses()

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

	_autobattler_panel = AutobattlerControlPanel.new()
	_autobattler_panel.name = "AutobattlerPanel"
	add_child(_autobattler_panel)
	_autobattler_panel.setup(_director, _unit_layer)

	_planning_cursor = TacticalPlanningCursor.new()
	_planning_cursor.name = "PlanningCursor"
	add_child(_planning_cursor)
	_planning_cursor.apply_text_scale(_settings.combat_text_scale)
	_planning_overlay.bind_planning_cursor(_planning_cursor)

	_status_badges = TacticalStatusBadges.new()
	_status_badges.name = "StatusBadges"
	add_child(_status_badges)
	_status_badges.bind(_unit_layer, self)
	_status_badges.apply_text_scale(_settings.combat_text_scale)

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
	_combat_shell.bind_settings(_settings)
	_camera.changed.connect(_center_map)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_clock_hud = _WorldClockHud.new()
	_clock_hud.name = "WorldClockHud"
	add_child(_clock_hud)
	_clock_hud.bind_effects_settings(_effects.settings)
	_fps_hud = _FpsHud.new()
	_fps_hud.name = "FpsHud"
	add_child(_fps_hud)
	_apply_overlay_hud_visibility()

	_load_skirmish()
	_init_tile_pipeline()
	_regenerate()
	_refine_spawn_positions()
	_start_combat()


func get_encounter() -> EncounterData:
	return _encounter


func get_skirmish() -> SkirmishGenerator.SkirmishResult:
	return _skirmish


func get_ground_used_rect() -> Rect2i:
	return _ground.get_used_rect()


func set_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input


func get_map_root_scale() -> float:
	if _map_root == null:
		return 1.0
	return maxf(_map_root.scale.x, 0.001)


func map_local_to_screen(local_pos: Vector2) -> Vector2:
	if _map_root == null:
		return local_pos
	return _map_root.get_canvas_transform() * local_pos


func grid_to_local(cell: Vector2i) -> Vector2:
	var used: Rect2i = _ground.get_used_rect()
	var local_cell: Vector2i = cell - used.position
	return Vector2(local_cell) * float(TILE_PX) + Vector2(TILE_PX, TILE_PX) * 0.5


func grid_to_foot_local(cell: Vector2i) -> Vector2:
	var used: Rect2i = _ground.get_used_rect()
	var local_cell: Vector2i = cell - used.position
	return Vector2(local_cell) * float(TILE_PX) + Vector2(TILE_PX * 0.5, TILE_PX)


func foot_local_to_grid(foot_local: Vector2) -> Vector2i:
	var used: Rect2i = _ground.get_used_rect()
	var tile_px: float = float(TILE_PX)
	var local_x: int = int(round((foot_local.x - tile_px * 0.5) / tile_px))
	var local_y: int = int(round((foot_local.y - tile_px) / tile_px))
	return Vector2i(local_x, local_y) + used.position


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


## Tier 3 QA: disable ambient VFX tick and staticize planning overlay animations.
func apply_qa_performance_mode(overlay: TacticalPlanningOverlay) -> void:
	_qa_perf_mode = true
	if overlay != null:
		overlay.qa_static_overlay = true
	var fx: EffectsSettings = _effects.settings
	fx.wind_field = false
	fx.time_light = false
	fx.cloud_shadows = false
	fx.mist = false
	fx.oblique_contact_shadows = false
	fx.tree_variant_b = false
	_apply_effects()


func get_shadow_sprites() -> Node2D:
	return _shadow_sprites


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
	_combat_shell.bind_settings(_settings)
	_sim_presenter.set_game_settings(_settings)


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
	_effects.set_character_contact_shadow_sync(_unit_layer.sync_all_contact_shadows)


func _exit_tree() -> void:
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
	_sim_presenter.set_game_settings(_settings)
	_combat_shell.bind_settings(_settings)
	if _planning_cursor != null:
		_planning_cursor.apply_text_scale(_settings.combat_text_scale)
	if _status_badges != null:
		_status_badges.apply_text_scale(_settings.combat_text_scale)
	_settings.apply_audio_buses()
	_apply_overlay_hud_visibility()
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
				_options.go_back()
			elif _pause_menu.is_open():
				_pause_menu.close_menu()
			get_viewport().set_input_as_handled()
		elif _options.is_open() and event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_options.go_back()
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


var _tree_fade_sync_accum: float = 0.0
const _TREE_FADE_SYNC_INTERVAL_SEC: float = 1.0 / 20.0


func _process(delta: float) -> void:
	if not _qa_perf_mode:
		_effects.process_frame(delta)
	_update_hover_coord()
	_tree_fade_sync_accum += delta
	var interval: float = _TREE_FADE_SYNC_INTERVAL_SEC
	if _tree_fader != null and _tree_fader.has_active_fades():
		interval = 1.0 / 30.0
	if _tree_fade_sync_accum >= interval:
		_tree_fade_sync_accum = 0.0
		_sync_tree_canopy_fade()


func _regenerate() -> void:
	_sync_tree_variant_setting()
	if _tree_fader != null:
		_tree_fader.clear_all()
	_decorator.regenerate(_player_grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = _decorator.map_seed
	_effects.rebuild_water_vfx_cache(_player_grid, rng)
	if _tree_fader == null:
		_tree_fader = _TreeCanopyFader.new()
		_tree_fader.name = "TreeCanopyFader"
		_map_root.add_child(_tree_fader)
	_tree_fader.setup(_trees, _player_grid, _effects.settings)
	_center_map()
	_apply_effects()


func _refine_spawn_positions() -> void:
	if _encounter == null or _player_grid == null:
		return
	SpawnPlacer.refine_encounter_spawns(
		_player_grid,
		_encounter.player_spawns,
		_encounter.enemy_spawns,
		_skirmish.map_seed,
		_trees,
		_overlay,
		_effects.settings,
		_scatter,
	)
	_skirmish.player_spawns = _encounter.player_spawns
	_skirmish.enemy_spawns = _encounter.enemy_spawns


func _sync_tree_canopy_fade() -> void:
	if _tree_fader == null or _unit_layer == null:
		return
	_tree_fader.sync_actors(_unit_layer.get_actor_map())


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
	_effects.sync_map_transform()
	_sync_overlay_huds(layout["origin"], layout["scaled_size"])
	if _unit_overlay != null:
		_unit_overlay.queue_redraw()
	if _unit_layer != null:
		_unit_layer.queue_redraw()
	if _planning_overlay != null:
		_planning_overlay.queue_redraw()


func _apply_overlay_hud_visibility() -> void:
	if _fps_hud != null:
		_fps_hud.visible = _settings.show_fps_hud
	if _clock_hud != null:
		_clock_hud.visible = _settings.show_time_of_day_hud


func _sync_overlay_huds(map_origin: Vector2, map_size: Vector2) -> void:
	_apply_overlay_hud_visibility()
	var rect := Rect2(map_origin, map_size)
	if _fps_hud != null:
		_fps_hud.configure_map_rect(rect)
	if _clock_hud != null:
		_clock_hud.configure_map_rect(rect)


func _update_hover_coord() -> void:
	if _director == null or _director.board == null:
		return
	var qa_override: bool = (
		_planning_input != null and _planning_input.has_qa_pointer_override()
	)
	if not qa_override:
		var hc: Control = get_viewport().gui_get_hovered_control()
		if hc != null and _hover_blocked_by_ui(hc):
			var blocked_cell := Vector2i(-999, -999)
			if _last_polled_hover_cell != blocked_cell:
				_last_polled_hover_cell = blocked_cell
				if _planning_input != null:
					_planning_input.on_hover_moved(blocked_cell)
				elif _side_panels != null:
					_side_panels.set_hover_coord(blocked_cell)
			return
	var cell: Vector2i
	if _planning_input != null:
		cell = _planning_input.pointer_grid_cell()
	else:
		cell = screen_to_grid(get_viewport().get_mouse_position())
	if cell == _last_polled_hover_cell:
		return
	_last_polled_hover_cell = cell
	if _planning_input != null:
		_planning_input.on_hover_moved(cell)
	else:
		if _side_panels != null:
			_side_panels.set_hover_coord(cell)
		if _planning_overlay != null:
			_planning_overlay.set_hover_coord(cell)


func _hover_blocked_by_ui(ctrl: Control) -> bool:
	var node: Node = ctrl
	while node != null:
		if node is CanvasLayer:
			var layer: CanvasLayer = node as CanvasLayer
			if layer.layer >= 21:
				return true
		if node.name in ["OptionsMenu", "PauseMenu", "OptionsScreen", "AutobattlerPanel"]:
			return true
		node = node.get_parent()
	return false
