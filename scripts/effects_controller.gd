class_name EffectsController
extends RefCounted

const _SparkleSprites = preload("res://scripts/water_sparkle_sprites.gd")
const _EcologyLayer = preload("res://scripts/ecology_layer.gd")
const _C = preload("res://scripts/mana_seed_constants.gd")

## Applies EffectsSettings to WindBus, WeatherBus, atmosphere overlays, ground/water effects, and VFX.

var settings: EffectsSettings = EffectsSettings.new()
var biome_profile: BiomeProfile = BiomeProfile.for_variant(1)

var _ground_effects: GroundEffectsBinder = GroundEffectsBinder.new()
var _tile_cloud: TileCloudReceiveBinder = TileCloudReceiveBinder.new()
var _water_vfx: WaterVfxPlacer = WaterVfxPlacer.new()
var _water_burst: WaterBurstDirector = WaterBurstDirector.new()
var _ambient_director: AmbientEventDirector = AmbientEventDirector.new()
var _sparkle_sprites: Node2D
var _ecology: EcologyLayer
var _atmosphere: AtmosphereBinder

var _ground: TileMapLayer
var _scatter: TileMapLayer
var _overlay: TileMapLayer
var _trees: TileMapLayer
var _vfx: TileMapLayer
var _shadow_sprites: Node2D
var _world_modulate: CanvasModulate
var _sky_overlay: Node2D
var _map_root: Node2D
var _map_seed: int = 1

var _ground_wired: bool = false
var _weather_wired: bool = false
var _last_grid: PlayerGrid
var _character_contact_shadow_sync: Callable = Callable()
var _foot_compositor: ActorFootShadowCompositor
var _last_foot_shadow_map_epoch: int = -1


func setup(
	atmosphere: AtmosphereBinder,
	ground: TileMapLayer,
	overlay: TileMapLayer,
	trees: TileMapLayer,
	vfx: TileMapLayer,
	shadow_sprites: Node2D,
	world_modulate: CanvasModulate,
	sky_overlay: Node2D,
	map_root: Node2D,
	map_seed: int = 1,
	sparkle_sprites: Node2D = null,
	ecology_layer: EcologyLayer = null,
	scatter: TileMapLayer = null,
) -> void:
	_atmosphere = atmosphere
	_ground = ground
	_scatter = scatter
	_overlay = overlay
	_trees = trees
	_vfx = vfx
	_shadow_sprites = shadow_sprites
	_world_modulate = world_modulate
	_sky_overlay = sky_overlay
	_map_root = map_root
	_map_seed = map_seed
	_sparkle_sprites = sparkle_sprites
	_ecology = ecology_layer
	_water_burst.setup(_vfx, _map_seed)
	_ambient_director.setup(
		_map_root,
		_water_burst,
		_map_seed,
		_ecology.readability() if _ecology != null else ReadabilityEnforcer.new(),
	)
	settings.load_from_disk()
	biome_profile = BiomeProfile.for_variant(settings.biome_variant)
	WeatherBus.apply_biome_profile(biome_profile)
	_wire_weather_bus()
	_ensure_shadow_draw_order()
	ShadowPlacer.set_active_shadow_root(_shadow_sprites)
	_tile_cloud.setup(_trees, _overlay, _map_root)
	apply_all(null, 0.0)


func set_map_seed(map_seed: int) -> void:
	_map_seed = map_seed
	_water_burst.setup(_vfx, _map_seed)
	_ambient_director.set_map_seed(_map_seed)


func set_biome_variant(variant: int) -> void:
	settings.biome_variant = clampi(variant, 1, BiomeProfile.variant_count())
	biome_profile = BiomeProfile.for_variant(settings.biome_variant)
	WeatherBus.apply_biome_profile(biome_profile)
	WaterSparkleFrames.clear_cache()


func apply_all(grid: PlayerGrid, water_ratio: float, ecology_hints: Dictionary = {}) -> void:
	if grid != null:
		_last_grid = grid
	ShadowDebug.sync_weather_bus(settings)
	_apply_wind_bus()
	_apply_ground_effects(grid)
	_apply_tile_cloud_receive(grid)
	_apply_weather_bus()
	_apply_atmosphere_visuals(grid, water_ratio)
	_apply_oblique_contact_shadows(grid)
	_apply_water_vfx(grid)
	_sync_sparkle_sprites()
	_water_burst.sync_grid(grid)
	_apply_ecology(grid, ecology_hints)
	_sync_ambient_director(grid)


func _apply_ecology(grid: PlayerGrid, ecology_hints: Dictionary) -> void:
	if _ecology == null:
		return
	if not settings.any_phase7():
		_ecology.sync(null, {}, _map_seed, false, false)
		_sync_ambient_director(grid)
		return
	_ecology.sync(
		grid,
		ecology_hints,
		_map_seed,
		settings.ambient_particles,
		settings.ecology_actors,
		biome_profile,
	)


func _sync_ambient_director(grid: PlayerGrid) -> void:
	if grid == null:
		_ambient_director.sync_map(Vector2i.ZERO, false)
		return
	_ambient_director.sync_map(
		Vector2i(grid.width, grid.height),
		settings.rare_events,
	)


func _sync_sparkle_sprites() -> void:
	if _sparkle_sprites == null:
		return
	_sparkle_sprites.sync(
		_water_vfx,
		settings.shoreline_foam,
		settings.water_sparkles,
		_map_seed,
		settings.biome_variant,
	)


func process_water_burst(delta: float) -> void:
	var splash_timer: bool = settings.fish_splash and not settings.rare_events
	_water_burst.process(delta, splash_timer)
	_ambient_director.process(delta, settings.fish_splash and settings.rare_events)


func process_frame(delta: float) -> void:
	process_water_burst(delta)
	if settings.cloud_shadows and _atmosphere != null:
		_atmosphere.refresh_cloud_drift()
	var want_env_receive: bool = (
		settings.oblique_contact_shadows or settings.cloud_shadows
	)
	if want_env_receive and _character_contact_shadow_sync.is_valid():
		_character_contact_shadow_sync.call(settings)
	var want_ground_shadows: bool = want_env_receive
	if want_ground_shadows and _shadow_sprites != null:
		ShadowPlacer.sync_ground_shadow_drift(settings, _shadow_sprites)
	_apply_tile_cloud_drift()
	if settings.oblique_contact_shadows and _shadow_sprites != null and _last_grid != null:
		var map_epoch: int = ShadowPlacer.map_composite_apply_epoch()
		if map_epoch != _last_foot_shadow_map_epoch:
			_last_foot_shadow_map_epoch = map_epoch
			ShadowPlacer.invalidate_foot_cluster_layout()
		if WeatherBus.shadows_visible() and ShadowPlacer.is_layer_cache_empty():
			_apply_oblique_contact_shadows(_last_grid)
		else:
			ShadowPlacer.sync_cycle(_shadow_sprites, settings)


func set_character_contact_shadow_sync(callback: Callable) -> void:
	_character_contact_shadow_sync = callback


static func sync_contact_shadow_on_actor(actor: Node, settings: EffectsSettings) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if not actor is CharacterActor:
		return
	var char_actor: CharacterActor = actor as CharacterActor
	if settings == null or (
		not settings.oblique_contact_shadows and not settings.cloud_shadows
	):
		char_actor.clear_oblique_modulate()
		return
	char_actor.sync_contact_shadow(settings)


static func sync_contact_shadow_on_actors(
	actors: Dictionary,
	settings: EffectsSettings,
	shadow_root: Node2D = null,
) -> void:
	var sorted: Array = []
	for actor: Variant in actors.values():
		if actor != null and is_instance_valid(actor):
			sorted.append(actor)
	for actor: Variant in sorted:
		sync_contact_shadow_on_actor(actor as Node, settings)
	ShadowPlacer.rebuild_foot_shadow_clusters(sorted, settings, shadow_root)


static func sync_contact_shadow_on_actor_list(
	actors: Array,
	settings: EffectsSettings,
	shadow_root: Node2D = null,
) -> void:
	var sorted: Array = []
	for actor: Variant in actors:
		if actor != null and is_instance_valid(actor):
			sorted.append(actor)
	for actor: Variant in sorted:
		sync_contact_shadow_on_actor(actor as Node, settings)
	ShadowPlacer.rebuild_foot_shadow_clusters(sorted, settings, shadow_root)


func _sync_contact_shadow_mask() -> void:
	pass


func _apply_wind_bus() -> void:
	if settings.wind_field:
		WindBus.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		WindBus.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_ground_effects(grid: PlayerGrid) -> void:
	var want: bool = settings.any_ground_effects()
	if want:
		var wind_on: bool = settings.wind_field
		var water_on: bool = settings.water_ripples
		if not _ground_wired:
			_ground_effects.setup(_ground, _overlay, _trees, wind_on, water_on)
			_ground_wired = true
		elif not _ground_effects.mode_matches(wind_on, water_on):
			_ground_effects.teardown(_ground, _overlay, _trees)
			_ground_effects.setup(_ground, _overlay, _trees, wind_on, water_on)
		if grid != null:
			_ground_effects.sync_map(grid, _map_root)
	else:
		if _ground_wired:
			_ground_effects.teardown(_ground, _overlay, _trees)
			_ground_wired = false


func _apply_weather_bus() -> void:
	if settings.needs_weather_bus():
		WeatherBus.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		WeatherBus.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_atmosphere_visuals(grid: PlayerGrid, water_ratio: float) -> void:
	var cloud_rect: ColorRect = _sky_overlay.get_node("CloudShadows") as ColorRect
	var mist_rect: ColorRect = _sky_overlay.get_node("MistOverlay") as ColorRect
	_sky_overlay.visible = settings.cloud_shadows or settings.mist
	mist_rect.visible = settings.mist
	cloud_rect.visible = false

	if settings.time_light:
		_world_modulate.color = WeatherBus.canvas_modulate_color()
	else:
		_world_modulate.color = Color.WHITE

	if grid != null and settings.needs_weather_bus():
		_atmosphere.sync_map(grid, water_ratio)
	elif not settings.time_light:
		_world_modulate.color = Color.WHITE
	if settings.cloud_shadows and _atmosphere != null:
		_atmosphere.push_cloud_shadow_uniforms(settings)
		_atmosphere.sync_sky_transform()


func sync_map_transform() -> void:
	if _atmosphere != null:
		_atmosphere.sync_sky_transform()
		if settings.cloud_shadows:
			_atmosphere.push_cloud_shadow_uniforms(settings)
	if settings.cloud_shadows and _last_grid != null:
		_apply_tile_cloud_receive(_last_grid)


func _apply_oblique_contact_shadows(grid: PlayerGrid) -> void:
	if _shadow_sprites == null:
		return
	if not settings.oblique_contact_shadows and not settings.cloud_shadows:
		ShadowPlacer.clear(_shadow_sprites)
		_shadow_sprites.visible = false
		_shadow_sprites.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if grid == null:
		return
	_ensure_shadow_draw_order()
	_shadow_sprites.process_mode = Node.PROCESS_MODE_INHERIT
	_shadow_sprites.visible = true
	ShadowPlacer.apply(grid, _shadow_sprites, _ground, _trees, _overlay, null, settings, _scatter)
	sync_map_transform()


func _ensure_shadow_draw_order() -> void:
	if _shadow_sprites == null:
		return
	_shadow_sprites.z_as_relative = false
	_shadow_sprites.z_index = _C.Z_SHADOW
	if _map_root == null or _trees == null:
		return
	# z=1: above grass, below OverlayLayer casters and TreeLayer — casters paint over own shadow.
	var tree_idx: int = _trees.get_index()
	if tree_idx >= 0 and _shadow_sprites.get_parent() == _map_root:
		_map_root.move_child(_shadow_sprites, tree_idx)
	_ensure_foot_compositor()


func _ensure_foot_compositor() -> void:
	if _map_root == null:
		return
	if _foot_compositor != null and is_instance_valid(_foot_compositor):
		return
	for child: Node in _map_root.get_children():
		if child is ActorFootShadowCompositor:
			_foot_compositor = child as ActorFootShadowCompositor
			ShadowPlacer.set_foot_cluster_root(_foot_compositor)
			return
	_foot_compositor = ActorFootShadowCompositor.new()
	_map_root.add_child(_foot_compositor)
	ShadowPlacer.set_foot_cluster_root(_foot_compositor)


func _apply_water_vfx(grid: PlayerGrid) -> void:
	if _vfx == null:
		return
	if grid == null:
		return
	if not settings.any_phase6():
		_water_vfx.erase_sparkle_cells(_vfx)
		return
	_water_vfx.apply(_vfx, settings.shoreline_foam, settings.water_sparkles)


func rebuild_water_vfx_cache(grid: PlayerGrid, rng: RandomNumberGenerator) -> void:
	_water_vfx.rebuild(grid, rng)
	_apply_water_vfx(grid)


func _wire_weather_bus() -> void:
	if _weather_wired:
		return
	if not WeatherBus.state_changed.is_connected(_on_weather_changed):
		WeatherBus.state_changed.connect(_on_weather_changed)
	_weather_wired = true


func _on_weather_changed() -> void:
	if not settings.time_light:
		_world_modulate.color = Color.WHITE
	else:
		_world_modulate.color = WeatherBus.canvas_modulate_color()
	if _ground_wired and settings.water_ripples:
		_ground_effects.refresh_uniforms()
	if not settings.oblique_contact_shadows and not settings.cloud_shadows:
		return
	if _last_grid == null or _shadow_sprites == null:
		return
	if settings.oblique_contact_shadows:
		if WeatherBus.shadows_visible() and ShadowPlacer.is_layer_cache_empty():
			_apply_oblique_contact_shadows(_last_grid)
		else:
			ShadowPlacer.sync_cycle(_shadow_sprites, settings)
	if settings.cloud_shadows:
		sync_map_transform()
	_apply_tile_cloud_drift()


func _apply_tile_cloud_receive(grid: PlayerGrid) -> void:
	_tile_cloud.apply(
		settings,
		grid,
		settings.wind_field and _ground_wired,
		_ground_effects.tree_shader_material(),
	)


func _apply_tile_cloud_drift() -> void:
	_tile_cloud.sync_drift(
		settings,
		settings.wind_field and _ground_wired,
		_ground_effects.tree_shader_material(),
	)
