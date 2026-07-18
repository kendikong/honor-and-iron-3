extends Node2D

const _SparkleSprites = preload("res://scripts/water_sparkle_sprites.gd")
const _EcologyLayer = preload("res://scripts/ecology_layer.gd")
const _WorldClockHud = preload("res://scripts/world_clock_hud.gd")
const _FpsHud = preload("res://scripts/fps_hud.gd")
const _C = preload("res://scripts/mana_seed_constants.gd")
const _CharacterActor = preload("res://scripts/lpc/character_actor.gd")
const _CharacterGridMover = preload("res://scripts/lpc/character_grid_mover.gd")

const TILE_PX: int = TacticalConstants.TILE_PX

@export_range(1, 3) var biome_variant: int = 1

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
@onready var _effects_panel: EffectsPanel = $EffectsPanel
@onready var _debug_overlay: TileDebugOverlay = $TileDebugOverlay
@onready var _walkability_overlay: WalkabilityDebugOverlay = $WalkabilityDebugOverlay
@onready var _inspector: TileInspectorPanel = $TileInspectorPanel
@onready var _pick_overlay: TilePickOverlay = $TilePickOverlay
@onready var _options: OptionsMenu = $OptionsMenu

var _tile_set: TileSet
var _decorator: AutoDecorator = AutoDecorator.new()
var _generator: MapGenerator = MapGenerator.new()
var _atmosphere: AtmosphereBinder = AtmosphereBinder.new()
var _effects: EffectsController = EffectsController.new()
var _player_grid: PlayerGrid
var _logical_provenance: PlayerGridProvenance = PlayerGridProvenance.new()
var _render_provenance: MapRenderProvenance = MapRenderProvenance.new()
var _settings: GameSettings = GameSettings.new()
var _boredom_atmosphere_mode: bool = false
var _boredom_water_mode: bool = false
var _last_tree_variant_b: bool = false
var _camera: MapCameraController = MapCameraController.new()
var _clock_hud: WorldClockHud
var _fps_hud: FpsHud
var _lpc_catalog: LpcCatalog
var _char_profile: CharacterGenProfile = CharacterGenProfile.new()
var _char_actor: CharacterActor
var _char_mover: CharacterGridMover
var _char_recipe: CharacterRecipe
var _asset_preloader: LpcAssetPreloader


func _ready() -> void:
	_settings.load_from_disk()
	_load_character_profile()
	_settings.apply_to_window(get_window())
	_settings.apply_audio_buses()

	_lpc_catalog = LpcCatalog.load_from_disk()
	if not LpcConstants.spritesheets_available():
		push_warning(
			"LPC sprites missing — run: powershell -ExecutionPolicy Bypass -File tools/fetch_lpc_spritesheets.ps1"
		)
	elif not LpcPaletteStore.palettes_available():
		push_warning(
			"LPC palette JSON missing — clone Universal-LPC-Spritesheet-Character-Generator-master for GPU recolor"
		)

	_atmosphere.setup(_world_modulate, _sky_overlay, _map_root)

	_shadow_sprites.z_as_relative = false
	_shadow_sprites.z_index = _C.Z_SHADOW

	var sparkle_sprites: Node2D = _SparkleSprites.new()
	sparkle_sprites.name = "SparkleSprites"
	sparkle_sprites.z_as_relative = false
	sparkle_sprites.z_index = _C.Z_VFX
	_map_root.add_child(sparkle_sprites)

	var ecology_layer: EcologyLayer = _EcologyLayer.new()
	ecology_layer.name = "EcologyLayer"
	ecology_layer.z_as_relative = false
	ecology_layer.z_index = _C.Z_ECOLOGY
	_map_root.add_child(ecology_layer)

	_effects.setup(
		_atmosphere, _ground, _overlay, _trees, _vfx, _shadow_sprites,
		_world_modulate, _sky_overlay, _map_root, _generator.map_seed,
		sparkle_sprites,
		ecology_layer,
		_scatter,
	)
	_effects.set_character_contact_shadow_sync(_sync_test_char_contact_shadow)
	biome_variant = _effects.settings.biome_variant
	_apply_biome_swap(false)

	_decorator.render_provenance = _render_provenance
	_decorator.logical_provenance = _logical_provenance
	_sync_tree_variant_setting()
	_effects_panel.setup(_effects.settings, _on_effects_toggled)
	_effects_panel.setup_character_gen(_char_profile, _reroll_character)
	_effects_panel.biome_changed.connect(_on_biome_changed)
	_effects_panel.character_gen_changed.connect(_on_character_gen_changed)
	_connect_map_tool_signals()

	_generator.width = MapGenerator.DEFAULT_MAP_WIDTH
	_generator.height = MapGenerator.DEFAULT_MAP_HEIGHT
	_generator.water_ratio = 0.22
	_generator.map_seed = 42
	_decorator.map_seed = _generator.map_seed

	_inspector.apply_display_settings(_settings)
	_options.setup(_settings, _on_display_settings_applied)
	_options.setup_character_gen(_char_profile)
	_options.opened.connect(_on_options_opened)
	_options.closed.connect(_on_options_closed)

	_pick_overlay.setup(_map_root, null, _inspector, _phantom, _ground)
	_clock_hud = _WorldClockHud.new()
	_clock_hud.name = "WorldClockHud"
	add_child(_clock_hud)
	_fps_hud = _FpsHud.new()
	_fps_hud.name = "FpsHud"
	add_child(_fps_hud)
	get_viewport().size_changed.connect(_on_viewport_resized)
	get_window().close_requested.connect(_persist_settings)

	_generate_map()
	_spawn_character_actor()
	_sync_map_tool_panel()

	# Asset Preloader (Phase 11)
	_asset_preloader = LpcAssetPreloader.new()
	_asset_preloader.name = "LpcAssetPreloader"
	add_child(_asset_preloader)
	_asset_preloader.preload_complete.connect(_on_preload_complete)
	_asset_preloader.start(_lpc_catalog)


func _connect_map_tool_signals() -> void:
	_options.map_regenerate_requested.connect(_generate_map)
	_options.map_reseed_requested.connect(_reseed_and_regenerate)
	_options.map_toggle_center_requested.connect(_toggle_center_cell)
	_options.map_resize_requested.connect(_resize_map)
	_options.map_cycle_biome_requested.connect(_cycle_biome)
	_options.map_tile_labels_toggled.connect(_set_tile_labels)
	_options.map_boredom_atmosphere_toggled.connect(_set_boredom_atmosphere_mode)
	_options.map_boredom_water_toggled.connect(_set_boredom_water_mode)
	_options.character_gen_changed.connect(_on_character_gen_changed)


func _on_preload_complete(total: int, missing: int) -> void:
	if missing > 0:
		print("LpcAssetPreloader: %d/%d sprites missing." % [missing, total])
	else:
		print("LpcAssetPreloader: all %d sprite sheets verified.")


func _sync_map_tool_panel() -> void:
	_options.set_map_tool_state(
		_settings.dev_tile_labels or _debug_overlay.visible,
		_settings.dev_boredom_atmosphere or _boredom_atmosphere_mode,
		_settings.dev_boredom_water or _boredom_water_mode,
	)
	if _settings.dev_tile_labels:
		_set_tile_labels(true)
	if _settings.dev_boredom_atmosphere:
		_set_boredom_atmosphere_mode(true)
	if _settings.dev_boredom_water:
		_set_boredom_water_mode(true)


func _load_character_profile() -> void:
	_char_profile.load_from_user_disk()


func _exit_tree() -> void:
	_persist_settings()


func _persist_settings() -> void:
	_settings.capture_from_window(get_window())
	_settings.save_to_disk()
	_effects.settings.save_to_disk()


func _on_viewport_resized() -> void:
	_center_map()
	_apply_effects()
	_pick_overlay.mark_transform_dirty()
	_sync_debug_views()


func _unhandled_input(event: InputEvent) -> void:
	if _camera.handle_input(event, _options.is_open()):
		_center_map()
		get_viewport().set_input_as_handled()
		return

	if _options.is_open():
		return
		
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			if _char_mover != null and is_instance_valid(_char_mover):
				_char_mover.is_running = event.pressed
				
	if event is InputEventKey and event.pressed:
		if _try_character_step(event as InputEventKey):
			return
			
	if event is InputEventKey and event.pressed and not event.echo:
		if _char_mover != null and is_instance_valid(_char_mover):
			match event.keycode:
				KEY_SPACE, KEY_1:
					_char_mover.request_action(&"slash")
					return
				KEY_2:
					_char_mover.request_action(&"thrust")
					return
				KEY_3:
					_char_mover.request_action(&"spellcast")
					return
				KEY_4:
					_char_mover.request_action(&"shoot")
					return
				KEY_H:
					_char_mover.request_action(&"hurt")
					return
					
		match event.keycode:
			KEY_G:
				_generate_map()
			KEY_T:
				_toggle_center_cell()
			KEY_R:
				_reseed_and_regenerate()
			KEY_BRACKETLEFT:
				_resize_map(-2)
			KEY_BRACKETRIGHT:
				_resize_map(2)
			KEY_L:
				_set_tile_labels(not _debug_overlay.visible)
			KEY_K:
				_set_walkability_overlay(not _walkability_overlay.visible)
			KEY_B:
				_set_boredom_atmosphere_mode(not _boredom_atmosphere_mode)
			KEY_P:
				_cycle_biome()
			KEY_C:
				_reroll_character()
			KEY_E:
				_export_player_grid()


func _try_character_step(event: InputEventKey) -> bool:
	if event.echo:
		return false
	match event.keycode:
		KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT:
			pass
		_:
			return false
	var dir: Vector2i = _CharacterGridMover.move_dir_from_input()
	if dir == Vector2i.ZERO:
		return false
	get_viewport().set_input_as_handled()
	if _char_mover != null and is_instance_valid(_char_mover) and _player_grid != null:
		_char_mover.request_step(dir, _player_grid)
	return true


func _process(delta: float) -> void:
	_effects.process_frame(delta)


func _sync_test_char_contact_shadow(settings: EffectsSettings) -> void:
	EffectsController.sync_contact_shadow_on_actor(_char_actor, settings)


func _on_effects_toggled() -> void:
	var tree_changed: bool = (
		_effects.settings.tree_variant_b != _last_tree_variant_b
	)
	_sync_tree_variant_setting()
	if tree_changed and _player_grid != null:
		_regenerate()
	else:
		_apply_effects()
	_refresh_walk_gameplay()


func _on_biome_changed(variant: int) -> void:
	_apply_biome_swap(true, variant)


func _cycle_biome() -> void:
	var next: int = (biome_variant % BiomeProfile.variant_count()) + 1
	_effects.settings.biome_variant = next
	_effects.settings.save_to_disk()
	_effects_panel.setup(_effects.settings, _on_effects_toggled)
	_apply_biome_swap(true, next)


func _apply_biome_swap(regenerate: bool = true, variant: int = -1) -> void:
	if variant < 1:
		variant = biome_variant
	variant = clampi(variant, 1, BiomeProfile.variant_count())
	biome_variant = variant
	_effects.settings.biome_variant = variant
	_effects.set_biome_variant(variant)
	_tile_set = TileSetFactory.build_combined_tileset(variant)
	_decorator.setup(_ground, _scatter, _overlay, _trees, _vfx, _phantom, _shadow_sprites, _tile_set)
	ShadowPlacer.clear_bake_cache()
	var profile: BiomeProfile = BiomeProfile.for_variant(variant)
	print("Biome: %s (press P to cycle)" % profile.display_name)
	if regenerate and _player_grid != null:
		_regenerate()


func _on_options_opened() -> void:
	_pick_overlay.set_process(false)


func _on_options_closed() -> void:
	_pick_overlay.set_process(true)
	_pick_overlay.mark_transform_dirty()


func _on_display_settings_applied() -> void:
	_inspector.apply_display_settings(_settings)
	_center_map()
	_apply_effects()
	_sync_debug_views()


func _apply_effects() -> void:
	var water_ratio: float = _generator.water_ratio if _player_grid != null else 0.0
	_effects.apply_all(_player_grid, water_ratio, _decorator.ecology_hints)


func _toggle_center_cell() -> void:
	var center: Vector2i = Vector2i(_player_grid.width / 2, _player_grid.height / 2)
	var current: int = _player_grid.get_cell(center)
	if current == TileId.Type.GRASS:
		_player_grid.set_cell(center, TileId.Type.WATER)
		_logical_provenance.add_step(
			center, "manual_toggle", TileId.Type.WATER, "Key T — toggled center cell to WATER",
		)
	else:
		_player_grid.set_cell(center, TileId.Type.GRASS)
		_logical_provenance.add_step(
			center, "manual_toggle", TileId.Type.GRASS, "Key T — toggled center cell to GRASS",
		)
	_regenerate()


func _generate_map() -> void:
	if _boredom_water_mode:
		_player_grid = _generator.generate_boredom_water(_logical_provenance)
	elif _boredom_atmosphere_mode:
		_player_grid = _generator.generate_boredom_atmosphere(_logical_provenance)
	else:
		_player_grid = _generator.generate(_logical_provenance)
	_regenerate()


func _reseed_and_regenerate() -> void:
	_generator.map_seed += 1
	_decorator.map_seed = _generator.map_seed
	_effects.set_map_seed(_generator.map_seed)
	_generate_map()


func _resize_map(delta: int) -> void:
	if _boredom_atmosphere_mode or _boredom_water_mode:
		return
	# Pass width 0 so snap_widescreen follows height delta (not stale width).
	var wide_size: Vector2i = MapGenerator.snap_widescreen(0, _generator.height + delta)
	_generator.width = wide_size.x
	_generator.height = wide_size.y
	_generate_map()


func _set_tile_labels(enabled: bool) -> void:
	if _debug_overlay.visible == enabled:
		return
	_debug_overlay.visible = enabled
	_settings.dev_tile_labels = enabled
	_settings.save_to_disk()
	_sync_phantom_visibility()
	_debug_overlay.sync(_player_grid, _map_root, _ground, _phantom, _render_provenance)
	_sync_map_tool_panel()


func _set_walkability_overlay(enabled: bool) -> void:
	if _walkability_overlay.visible == enabled:
		return
	_walkability_overlay.visible = enabled
	if enabled:
		print("Walkability overlay ON — K toggles · blue=logical red=trunk magenta=prop")
	else:
		print("Walkability overlay OFF")
	_walkability_overlay.sync(
		_player_grid, _map_root, _trees, _overlay, _effects.settings,
	)


func _refresh_walk_gameplay() -> void:
	if _char_mover != null and _player_grid != null:
		_char_mover.sync_grid(_player_grid, _trees, _overlay, _effects.settings, _scatter)
	if _walkability_overlay.visible:
		_walkability_overlay.sync(
			_player_grid, _map_root, _trees, _overlay, _effects.settings,
		)


func _set_boredom_atmosphere_mode(enabled: bool) -> void:
	if _boredom_atmosphere_mode == enabled:
		return
	_boredom_atmosphere_mode = enabled
	_settings.dev_boredom_atmosphere = enabled
	if enabled:
		_settings.dev_boredom_water = false
	_settings.save_to_disk()
	if _boredom_atmosphere_mode:
		_boredom_water_mode = false
		_generator.width = 16
		_generator.height = 16
		_generator.water_ratio = 0.0
		_generator.tree_count = 0
		print("Phase 5 Boredom Test map ON — 16×16 GRASS+RUIN")
	else:
		_restore_default_generator()
		print("Phase 5 Boredom Test map OFF — full procedural map")
	_generate_map()
	_sync_map_tool_panel()


func _set_boredom_water_mode(enabled: bool) -> void:
	if _boredom_water_mode == enabled:
		return
	_boredom_water_mode = enabled
	_settings.dev_boredom_water = enabled
	if enabled:
		_settings.dev_boredom_atmosphere = false
	_settings.save_to_disk()
	if _boredom_water_mode:
		_boredom_atmosphere_mode = false
		_generator.width = 16
		_generator.height = 16
		_generator.water_ratio = 0.35
		_generator.tree_count = 0
		print("Phase 6 Boredom Test map ON — 16×16 GRASS+WATER")
	else:
		_restore_default_generator()
		print("Phase 6 Boredom Test map OFF — full procedural map")
	_generate_map()
	_sync_map_tool_panel()


func _restore_default_generator() -> void:
	_generator.width = MapGenerator.DEFAULT_MAP_WIDTH
	_generator.height = MapGenerator.DEFAULT_MAP_HEIGHT
	_generator.water_ratio = 0.22
	_generator.tree_count = -1
	_generator.tree_density = 0.022
	_generator.tree_min_spacing = 3


func _regenerate() -> void:
	_sync_tree_variant_setting()
	_decorator.regenerate(_player_grid)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _decorator.map_seed
	_effects.rebuild_water_vfx_cache(_player_grid, rng)
	TileInspectorReport.invalidate_cache()
	_center_map()
	_apply_effects()
	_pick_overlay.mark_transform_dirty()
	_sync_debug_views()
	_inspector.invalidate_display_cache()
	if _char_mover != null and _player_grid != null:
		_char_mover.sync_grid(_player_grid, _trees, _overlay, _effects.settings, _scatter)


func _sync_debug_views() -> void:
	_pick_overlay.sync_grid(_player_grid)
	_inspector.setup(
		_player_grid, _logical_provenance, _render_provenance,
		_map_root, _ground, _overlay, _vfx, _phantom,
	)
	_sync_phantom_visibility()
	if _debug_overlay.visible:
		_debug_overlay.sync(_player_grid, _map_root, _ground, _phantom, _render_provenance)
	if _walkability_overlay.visible:
		_walkability_overlay.sync(
			_player_grid, _map_root, _trees, _overlay, _effects.settings,
		)


func _sync_phantom_visibility() -> void:
	_phantom.visible = _debug_overlay.visible


func _center_map() -> void:
	var used: Rect2i = _ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var map_pixels: Vector2 = Vector2(used.size) * float(TILE_PX)
	var viewport: Vector2 = get_viewport_rect().size
	var left_w: float = float(_effects_panel.panel_width())
	# Right inset: whichever panel is wider (char gen panel or inspector).
	var right_inset: float = float(maxf(
		float(CharacterGeneratorPanel.PANEL_WIDTH),
		float(_inspector.panel_width())
	))
	var layout: Dictionary = _camera.compute_layout(
		_settings, map_pixels, viewport, left_w, right_inset, used.position,
	)
	_map_root.scale = layout["map_root_scale"]
	var scaled_size: Vector2 = layout["scaled_size"]
	var origin: Vector2 = layout["origin"]
	position = layout["scene_position"]
	_pick_overlay.set_chrome_insets(int(left_w), int(right_inset))
	_pick_overlay.mark_transform_dirty()
	_sync_clock_hud(origin, scaled_size)


func _sync_clock_hud(map_origin: Vector2 = Vector2.ZERO, map_size: Vector2 = Vector2.ZERO) -> void:
	if _clock_hud == null and _fps_hud == null:
		return
	if map_size.x < 1.0:
		var used: Rect2i = _ground.get_used_rect()
		if used.size == Vector2i.ZERO:
			return
		var map_pixels: Vector2 = Vector2(used.size) * float(TILE_PX)
		var viewport: Vector2 = get_viewport_rect().size
		var left_w: float = float(_effects_panel.panel_width())
		var right_w: float = float(_inspector.panel_width())
		var map_viewport: Vector2 = Vector2(viewport.x - left_w - right_w, viewport.y)
		var zoom: int = _settings.compute_map_zoom(
			map_pixels,
			_settings.map_zoom_viewport_size(viewport, right_w, left_w),
		)
		map_size = map_pixels * float(zoom)
		map_origin = Vector2(left_w, 0.0) + (map_viewport - map_size) * 0.5
	if _clock_hud != null:
		_clock_hud.visible = _settings.show_time_of_day_hud
		_clock_hud.configure_map_rect(Rect2(map_origin, map_size))
	if _fps_hud != null:
		_fps_hud.visible = _settings.show_fps_hud
		_fps_hud.configure_map_rect(Rect2(map_origin, map_size))


func _sync_tree_variant_setting() -> void:
	_last_tree_variant_b = _effects.settings.tree_variant_b
	_decorator.tree_variant_b = _last_tree_variant_b


func _spawn_character_actor() -> void:
	if _char_actor != null:
		_char_actor.queue_free()
	_char_actor = _CharacterActor.new()
	_char_actor.name = "LpcCharacter"
	_map_root.add_child(_char_actor)
	_map_root.move_child(_char_actor, -1)
	_char_mover = _CharacterGridMover.new()
	_char_mover.name = "GridMover"
	_char_actor.add_child(_char_mover)
	_reroll_character()
	if _player_grid != null:
		var center: Vector2i = Vector2i(_player_grid.width >> 1, _player_grid.height >> 1)
		var spawn: Vector2i = Walkability.find_spawn_cell(
			_player_grid, center, _trees, _overlay, _effects.settings, _scatter,
		)
		_char_mover.setup(
			_char_actor, _player_grid, spawn, _trees, _overlay, _effects.settings, _scatter,
		)


func _reroll_character() -> void:
	# Always reload the master catalog and profile from disk before generating.
	_lpc_catalog = LpcCatalog.load_from_disk()
	_load_character_profile()
	
	# Re-apply the in-memory overrides from the left panel.
	if _effects_panel != null:
		var overrides: Dictionary = _effects_panel.get_character_overrides()
		if not overrides["male"]:
			_char_profile.body_type_weights["male"] = 0.0
		elif _char_profile.body_type_weights.get("male", 1.0) <= 0.0:
			_char_profile.body_type_weights["male"] = 1.0
			
		if not overrides["female"]:
			_char_profile.body_type_weights["female"] = 0.0
		elif _char_profile.body_type_weights.get("female", 1.0) <= 0.0:
			_char_profile.body_type_weights["female"] = 1.0
		_char_profile.allow_non_human_parts = overrides["nonhuman"]
	
	_char_profile.seed = int(Time.get_ticks_msec()) & 0x7fffffff
	_char_recipe = CharacterRoller.roll(_lpc_catalog, _char_profile, _char_profile.seed)
	if _char_actor == null:
		return
	if _char_mover != null and is_instance_valid(_char_mover):
		_char_mover.cancel_movement()
	var compose_report: Dictionary = CharacterComposer.apply(_char_actor, _char_recipe)
	compose_report["seed"] = _char_profile.seed
	_char_actor.set_display_scale(_char_profile.display_scale)
	_char_actor.rebuild_contact_shadow(_effects.settings)
	var report_text: String = CharacterComposer.format_report(compose_report, true)
	print(report_text)
	_effects_panel.set_character_parts_report(report_text)
	_warn_missing_head(compose_report)
	var drawn_layers: int = int(compose_report.get("drawn", 0))
	if drawn_layers < 1:
		push_error(
			"LPC character invisible — 0 layers drawn. Sprites root: %s"
			% LpcConstants.spritesheet_root()
		)
	if _char_mover != null and is_instance_valid(_char_mover):
		_char_mover.refresh_depth_sort()


func _export_player_grid() -> void:
	if _player_grid == null:
		push_warning("PlayerGrid export: no grid loaded")
		return
	var path: String = "user://player_grid_export.json"
	var err: Error = _player_grid.save_export(path, _generator.map_seed)
	if err != OK:
		push_error("PlayerGrid export failed (%d): %s" % [err, path])
		return
	print("PlayerGrid exported → %s (seed %d, %dx%d)" % [
		ProjectSettings.globalize_path(path),
		_generator.map_seed,
		_player_grid.width,
		_player_grid.height,
	])


func _warn_missing_head(report: Dictionary) -> void:
	var parts: Variant = report.get("parts", [])
	if typeof(parts) != TYPE_ARRAY:
		return
	for raw: Variant in parts:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw
		if str(p.get("slot", "")) != "head":
			continue
		var status: String = str(p.get("status", ""))
		if status == "drawn":
			return
		push_warning(
			"LPC invisible face: head id '%s' %s — %s"
			% [str(p.get("id", "")), status, str(p.get("path", ""))]
		)
		return


func _on_character_gen_changed() -> void:
	if _char_actor != null:
		_char_actor.set_display_scale(_char_profile.display_scale)
