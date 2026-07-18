class_name ShadowPlacer
extends RefCounted

## Oblique contact shadows — LA sundial projection, one composite multiply layer.
##
## Sundial: ground_offset = height_above_foot * cot(elevation) * dir(azimuth)
## Tree A (atlas x=0) has baked PNG shadow — skip procedural. Tree B / rocks / props bake.

const _BAKE_FAIL: Dictionary = {}

const _SHADOW_SHADER: Shader = preload("res://shaders/oblique_contact_shadow.gdshader")
const _SHADOW_SHADER_PERF: Shader = preload("res://shaders/oblique_contact_shadow_perf.gdshader")

const TILE_PX: int = 16

## Empirical tree shadow nudge (grid cells): left 2, up 3.
const _TREE_SHADOW_NUDGE: Vector2 = Vector2(-2.0 * float(TILE_PX), -3.0 * float(TILE_PX))

const _PROFILES: Dictionary = {
	TileId.Type.ROCK: {"footprint_cells": Vector2i(1, 1)},
	TileId.Type.RUIN: {"footprint_cells": Vector2i(1, 1)},
	TileId.Type.TREE: {"footprint_cells": Vector2i(5, 6)},
}

const _PROPS_32_FOOTPRINT: Vector2i = Vector2i(2, 2)
## Only forest scatter #88 gets oblique shadows — low 1×1 decor pebble cluster.
const _SCATTER_PEBBLE_SHADOW_ID: int = 88
const _PEBBLE_88_SHADOW_HEIGHT_MULT: float = 0.28
## Scatter tiles share a cell with ground; baked offset lands one tile low without this.
const _PEBBLE_88_SHADOW_NUDGE: Vector2 = Vector2(0.0, -float(TILE_PX))
## Guard against sunset cot blow-up allocating gigapixel shadow atlases.
const _MAX_SHADOW_AXIS: int = 2048
## One-pixel 3×3 box blur on baked alpha — very slight edge soften, still on pixel grid.
const _SHADOW_EDGE_SOFTEN_RADIUS: int = 1
const _SHADOW_BAKE_CACHE_TAG: String = "solid2"
const _SHADOW_BAKE_CACHE_TAG_PERF: String = "perf_solid4"
const _PERF_RASTER_STRIDE: int = 2
## Legacy defaults — runtime values come from EffectsSettings / ShadowTuning.
const TWILIGHT_LOFI_VISIBILITY: float = 0.08
const TWILIGHT_THROTTLE_RAMP_END: float = 0.40

static var _shadow_material: ShaderMaterial
static var _shadow_layer_cache: Array[Dictionary] = []
static var _last_shadow_tint: Color = Color.WHITE
static var _last_shadow_strength: float = -1.0
static var _last_shadow_visible: bool = true
static var _last_shadow_presence: float = -1.0
static var _last_shadow_contrast: float = -1.0
static var _last_shadow_geometry_lo_fi: bool = true
static var _last_bake_signature: int = -1
static var _last_composite_queue_ms: int = 0
const _MIN_COMPOSITE_REBAKE_MS: int = 1500
const _MIN_COMPOSITE_REBAKE_MS_SLOW: int = 750
static var _oblique_bake_cache: Dictionary = {}
static var _async_task_id: int = -1
static var _async_request_token: int = 0
static var _async_mutex: Mutex
static var _async_result: Dictionary = {}
static var _async_pending: Dictionary = {}
static var _map_oblique_overlay: Dictionary = {}
static var _overlay_sample_image: Image
static var _overlay_sample_epoch: int = -1
static var _actor_contact_sync_cache: Dictionary = {}
static var _actor_shadow_bases: Dictionary = {}
static var _peer_actor_shadow_registry: Dictionary = {}

const ACTOR_SHADOW_BAND_COUNT: int = 3
const ACTOR_SHADOW_MAJORITY_RATIO: float = 0.5
const ACTOR_SHADOW_BAND_X: Array = [-16.0, -8.0, 0.0, 8.0, 16.0]
## Vertical bands from actor foot (y=0): lower legs, torso, head/hair.
const ACTOR_SHADOW_BAND_Y: Array = [
	[0.0, -8.0, -16.0],
	[-14.0, -22.0, -30.0],
	[-28.0, -38.0, -48.0],
]
static var _dbg_map_queued: int = 0
static var _dbg_map_applied: int = 0
static var _dbg_map_stale: int = 0
static var _dbg_actor_rebaked: int = 0
static var _dbg_last_map_build_ms: int = 0
static var _dbg_last_actor_build_ms: int = 0
static var _dbg_rate_timestamps_ms: PackedInt64Array = PackedInt64Array()
const _DBG_RATE_WINDOW_MS: int = 60_000
static var _last_actor_bake_key: int = -1
static var _last_actor_applied_epoch: int = -1
static var _last_actor_synced_silhouette: int = -1
static var _map_composite_apply_epoch: int = 0
static var _last_actor_presence: float = -1.0
static var _last_actor_tint: Color = Color.WHITE
static var _last_actor_strength: float = -1.0
static var _last_actor_contrast: float = -1.0
static var _last_actor_geometry_lo_fi: bool = true
static var _last_actor_silhouette_version: int = -1
static var _last_perf_mode_active: bool = false
static var _last_bake_lod_active: bool = false
static var _last_hybrid_lod_enabled: bool = false
static var _last_edge_soften_active: bool = false
static var _pending_composite_apply: Dictionary = {}
static var _deferred_apply_hooked: bool = false


static func is_layer_cache_empty() -> bool:
	return _shadow_layer_cache.is_empty()


static func apply(
	grid: PlayerGrid,
	shadow_root: Node2D,
	ground: TileMapLayer,
	trees: TileMapLayer,
	overlay: TileMapLayer = null,
	provenance: MapRenderProvenance = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> void:
	_shadow_layer_cache.clear()
	clear_bake_cache()
	clear_immediate(shadow_root)
	if grid == null or shadow_root == null:
		return
	var layers: Array[Dictionary] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var tile_id: int = grid.get_cell(pos)
			match tile_id:
				TileId.Type.ROCK, TileId.Type.RUIN:
					_collect_shadow_layer(
						layers, ground, pos, tile_id, _PROFILES[tile_id], provenance, settings,
					)
				TileId.Type.TREE:
					if _tree_has_baked_atlas_shadow(pos, trees, provenance):
						continue
					_collect_shadow_layer(
						layers, trees, pos, tile_id, _PROFILES[tile_id], provenance, settings,
					)
	_collect_props_shadow_layers(layers, overlay, provenance, settings)
	_collect_scatter_pebble_shadow_layers(layers, scatter, provenance, settings)
	_cache_shadow_layers(layers)
	if _shadow_layer_cache.is_empty():
		return
	var apply_presence: float = WeatherBus.shadow_presence_factor()
	var apply_contrast: float = WeatherBus.shadow_contrast_factor()
	if not _geometry_blocked(apply_presence, apply_contrast, settings):
		_queue_async_composite(
			shadow_root,
			_shadow_layer_cache,
			settings,
			apply_contrast,
			_cycle_bake_signature(settings, apply_contrast),
		)
	sync_cycle(shadow_root, settings)


static func sync_cycle(shadow_root: Node2D, settings: EffectsSettings = null) -> void:
	_poll_async_composite(shadow_root, settings)
	var perf_active: bool = _is_perf_mode(settings)
	var soften_active: bool = _use_edge_soften(settings)
	var hybrid_active: bool = _hybrid_twilight_lod_enabled(settings)
	if perf_active != _last_perf_mode_active or soften_active != _last_edge_soften_active:
		_last_perf_mode_active = perf_active
		_last_edge_soften_active = soften_active
		_last_bake_signature = -1
		clear_bake_cache()
	if hybrid_active != _last_hybrid_lod_enabled:
		_last_hybrid_lod_enabled = hybrid_active
		_last_bake_lod_active = false
		_last_bake_signature = -1
		clear_bake_cache()
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
	var tint: Color = params["shadow_tint"] as Color
	var strength: float = float(params["shadow_strength"])
	var presence: float = float(params["shadow_presence"])
	var contrast: float = float(params["shadow_contrast"])
	var bake_lod: bool = _bake_lod_active(settings, contrast)
	if bake_lod != _last_bake_lod_active:
		_last_bake_lod_active = bake_lod
		_last_bake_signature = -1
		clear_bake_cache()
	var sun_up: bool = _sun_above_horizon_f(clock_f)
	var was_present: bool = _last_shadow_presence > 0.001
	var is_present: bool = presence > 0.001
	var geometry_blocked: bool = _geometry_blocked(presence, contrast, settings)
	var entering_geometry: bool = is_present and not geometry_blocked and _last_shadow_geometry_lo_fi
	var bake_sig: int = _cycle_bake_signature(settings, contrast)
	var sun_changed: bool = bake_sig != _last_bake_signature
	## Dawn: no children after night clear — must bake fresh morning sun geometry (not dusk leftovers).
	var need_first_bake: bool = (
		shadow_root != null
		and is_present
		and not _shadow_layer_cache.is_empty()
		and shadow_root.get_child_count() == 0
	)
	var visual_changed: bool = (
		not _last_shadow_tint.is_equal_approx(tint)
		or not is_equal_approx(_last_shadow_strength, strength)
		or not is_equal_approx(presence, _last_shadow_presence)
		or not is_equal_approx(contrast, _last_shadow_contrast)
		or is_present != was_present
		or geometry_blocked != _last_shadow_geometry_lo_fi
	)
	if not need_first_bake and not entering_geometry and not visual_changed and not sun_changed:
		return
	_last_shadow_tint = tint
	_last_shadow_strength = strength
	_last_shadow_presence = presence
	_last_shadow_contrast = contrast
	_last_shadow_visible = sun_up
	_last_shadow_geometry_lo_fi = geometry_blocked
	if shadow_root == null:
		return
	if not is_present:
		_last_bake_signature = -1
		if shadow_root.get_child_count() > 0:
			clear_immediate(shadow_root)
			_pending_composite_apply = {}
			clear_bake_cache()
		shadow_root.visible = false
		return
	# Dusk fade band: keep baked sprites, shader fades out — cancel only expensive rebakes.
	if geometry_blocked and shadow_root.get_child_count() > 0:
		_async_pending = {}
	var need_rebake: bool = (
		not _shadow_layer_cache.is_empty()
		and not geometry_blocked
		and (entering_geometry or sun_changed)
	)
	var need_respawn: bool = need_first_bake or need_rebake
	if need_respawn:
		var interval_ms: int = (
			0
			if need_first_bake
			else _composite_rebake_interval_ms(presence, contrast, settings)
		)
		var now_ms: int = Time.get_ticks_msec()
		if interval_ms <= 0 or now_ms - _last_composite_queue_ms >= interval_ms or not _async_busy():
			_last_composite_queue_ms = now_ms
			_queue_async_composite(shadow_root, _shadow_layer_cache, settings, contrast, bake_sig)
	var show: bool = is_present and shadow_root.get_child_count() > 0
	shadow_root.visible = show
	shadow_root.modulate = Color.WHITE
	var mat: ShaderMaterial = _material()
	_apply_shader_mode(mat, settings)
	mat.set_shader_parameter("shadow_tint", tint)
	mat.set_shader_parameter("shadow_strength", strength)


## LPC actor contact shadow — geometry rebakes only when map composite applies.
static func sync_actor_contact_shadow(
	sprite: Sprite2D,
	caster: Image,
	foot_center_tex: Vector2,
	foot_local: Vector2,
	silhouette_version: int,
	settings: EffectsSettings = null,
	actor: Node2D = null,
) -> void:
	if sprite == null or caster == null:
		return
	var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
	var tint: Color = params["shadow_tint"] as Color
	var strength: float = float(params["shadow_strength"])
	var presence: float = float(params["shadow_presence"])
	var contrast: float = float(params["shadow_contrast"])
	var is_present: bool = presence > 0.001
	var geometry_blocked: bool = _geometry_blocked(presence, contrast, settings)
	var map_epoch: int = _map_composite_apply_epoch
	var map_has_casters: bool = not _shadow_layer_cache.is_empty()
	var map_overlay_active: bool = bool(map_oblique_overlay().get("active", false))
	var map_ready: bool = not map_has_casters or map_epoch > 0 or map_overlay_active
	var map_applied: bool = map_has_casters and map_epoch > _last_actor_applied_epoch
	var silhouette_stale: bool = (
		map_has_casters
		and map_epoch == _last_actor_applied_epoch
		and map_epoch > 0
		and silhouette_version != _last_actor_synced_silhouette
	)
	var actor_vis: float = _fade_visibility(presence, contrast)
	var actor_gate: float = ShadowTuning.actor_appearance_gate(settings)
	var actor_visible_enough: bool = actor_vis >= actor_gate
	var want_first_actor_bake: bool = (
		is_present
		and actor_visible_enough
		and sprite.texture == null
		and map_ready
	)
	_last_actor_tint = tint
	_last_actor_strength = strength
	_last_actor_presence = presence
	_last_actor_contrast = contrast
	_last_actor_geometry_lo_fi = geometry_blocked
	_last_actor_silhouette_version = silhouette_version
	if not is_present:
		_last_actor_bake_key = -1
		_last_actor_applied_epoch = -1
		_last_actor_synced_silhouette = -1
		if actor != null:
			var aid: int = actor.get_instance_id()
			_actor_contact_sync_cache.erase(aid)
			_actor_shadow_bases.erase(aid)
			_peer_actor_shadow_registry.erase(aid)
		_clear_actor_sprite(sprite)
		return
	var actor_id: int = actor.get_instance_id() if actor != null else -1
	var want_actor_rebake: bool = not geometry_blocked and (map_applied or silhouette_stale)
	var need_geometry: bool = (
		_snapshot_sundial(settings).visible
		and (want_first_actor_bake or want_actor_rebake)
	)
	if (
		need_geometry
		and not want_first_actor_bake
		and _bake_lod_active(settings, contrast)
		and contrast < (settings.shadow_perf_tier_threshold if settings != null else 0.75)
		and _async_busy()
	):
		need_geometry = false
	if need_geometry:
		var t0_us: int = Time.get_ticks_usec()
		var baked: Dictionary = rebake_actor_shadow(
			caster, foot_center_tex, foot_local, settings,
		)
		if baked.is_empty():
			_clear_actor_sprite(sprite)
			return
		debug_record_actor_bake(int((Time.get_ticks_usec() - t0_us) / 1000))
		var img: Image = baked["image"] as Image
		var tex: ImageTexture = sprite.texture as ImageTexture
		if tex == null:
			tex = ImageTexture.create_from_image(img)
			sprite.texture = tex
		else:
			tex.set_image(img)
		sprite.position = baked["position"] as Vector2
		_last_actor_applied_epoch = map_epoch if map_has_casters else 0
		_last_actor_synced_silhouette = silhouette_version
		_last_actor_bake_key = map_epoch * 1000 + silhouette_version
		if actor_id >= 0:
			_actor_shadow_bases[actor_id] = img.duplicate()
	var show: bool = is_present and sprite.texture != null and actor_visible_enough
	var actor_pos: Vector2 = actor.position if actor != null else Vector2.ZERO
	var pos_key: Vector2i = Vector2i(int(round(actor_pos.x)), int(round(actor_pos.y)))
	var heavy_key: int = hash([
		silhouette_version,
		map_epoch,
		tint,
		strength,
		is_present,
		actor_visible_enough,
		geometry_blocked,
		need_geometry,
	])
	var light_key: int = hash([pos_key, _cloud_drift_key(), map_epoch])
	var cached: Dictionary = _actor_contact_sync_cache.get(actor_id, {})
	if (
		not need_geometry
		and cached.get("heavy_key", -1) == heavy_key
		and bool(cached.get("visible", false)) == show
	):
		if cached.get("light_key", -1) == light_key:
			return
		_sync_actor_map_oblique(sprite, actor)
		_sync_actor_cloud_uniforms(sprite, settings, actor_id)
		cached["light_key"] = light_key
		_actor_contact_sync_cache[actor_id] = cached
		return
	_actor_contact_sync_cache[actor_id] = {
		"heavy_key": heavy_key,
		"light_key": light_key,
		"visible": show,
	}
	sprite.visible = show
	sprite.modulate = Color.WHITE
	sprite.texture_filter = _shadow_texture_filter(settings)
	sync_shadow_material(sprite.material as ShaderMaterial, settings)
	_sync_actor_map_oblique(sprite, actor)
	_sync_actor_cloud_uniforms(sprite, settings, actor_id)


static func _sync_actor_cloud_uniforms(
	sprite: Sprite2D,
	settings: EffectsSettings = null,
	actor_id: int = -1,
) -> void:
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return
	var atmo: Dictionary = WeatherBus.atmosphere_uniforms()
	var has_clouds: float = 0.0
	if settings != null and settings.cloud_shadows and float(atmo.get("cloud_shadow_strength", 1.0)) >= 0.01:
		has_clouds = 1.0
	mat.set_shader_parameter("has_cloud_shadow", has_clouds)
	mat.set_shader_parameter("cloud_drift_offset", atmo["cloud_drift_offset"])
	if actor_id >= 0:
		var entry: Dictionary = _actor_contact_sync_cache.get(actor_id, {})
		entry["drift_key"] = _cloud_drift_key()
		_actor_contact_sync_cache[actor_id] = entry


static func _cloud_drift_key() -> int:
	var d: Vector2 = WeatherBus.cloud_drift_offset
	return hash(Vector2i(int(floor(d.x * 64.0)), int(floor(d.y * 64.0))))


static func sync_actor_cloud_drift_only(
	sprite: Sprite2D,
	settings: EffectsSettings,
	actor_id: int,
) -> void:
	if settings == null or not settings.cloud_shadows:
		return
	if sprite == null or not sprite.visible:
		return
	var drift_key: int = _cloud_drift_key()
	var cached: Dictionary = _actor_contact_sync_cache.get(actor_id, {})
	if cached.get("drift_key", -1) == drift_key:
		return
	_sync_actor_cloud_uniforms(sprite, settings, actor_id)


static func apply_actor_peer_shadow_batch(actors: Array) -> void:
	_peer_actor_shadow_registry.clear()
	var sorted: Array = actors.duplicate()
	sorted.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			if a == null or not is_instance_valid(a as Node):
				return false
			if b == null or not is_instance_valid(b as Node):
				return true
			return (a as Node).get_instance_id() < (b as Node).get_instance_id()
	)
	for actor_var: Variant in sorted:
		var actor: Node2D = actor_var as Node2D
		if actor == null:
			continue
		var sprite: Sprite2D = _actor_shadow_sprite(actor)
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
		var base: Image = _actor_shadow_bases.get(actor.get_instance_id()) as Image
		if base == null or base.is_empty():
			continue
		var img: Image = base.duplicate()
		if img.is_compressed():
			img.decompress()
		var map_origin: Vector2 = _actor_shadow_map_origin(sprite, actor)
		_punch_peer_actor_shadows(img, map_origin, actor)
		var tex: ImageTexture = sprite.texture as ImageTexture
		if tex != null:
			tex.set_image(img)
		_register_peer_actor_shadow(actor, img, map_origin)


static func _actor_shadow_sprite(actor: Node2D) -> Sprite2D:
	if actor == null:
		return null
	if actor.has_method("get_contact_shadow_sprite"):
		return actor.call("get_contact_shadow_sprite") as Sprite2D
	return null


static func _actor_shadow_map_origin(sprite: Sprite2D, actor: Node2D) -> Vector2:
	if sprite == null:
		return Vector2.ZERO
	if actor == null:
		return sprite.position
	return actor.position + sprite.position * actor.scale


static func _register_peer_actor_shadow(actor: Node2D, img: Image, map_origin: Vector2) -> void:
	if actor == null or img == null:
		return
	_peer_actor_shadow_registry[actor.get_instance_id()] = {
		"image": img.duplicate(),
		"origin": map_origin,
	}


static func _punch_peer_actor_shadows(dst: Image, dst_origin: Vector2, actor: Node2D) -> void:
	if dst == null or actor == null:
		return
	var self_id: int = actor.get_instance_id()
	for peer_id: Variant in _peer_actor_shadow_registry:
		if int(peer_id) >= self_id:
			continue
		var peer: Dictionary = _peer_actor_shadow_registry[peer_id]
		var peer_img: Image = peer.get("image") as Image
		if peer_img == null or peer_img.is_empty():
			continue
		_punch_image_alpha_at(peer_img, peer.get("origin", Vector2.ZERO), dst, dst_origin)


static func _punch_image_alpha_at(
	src: Image,
	src_origin: Vector2,
	dst: Image,
	dst_origin: Vector2,
) -> void:
	var ox: int = int(round(src_origin.x - dst_origin.x))
	var oy: int = int(round(src_origin.y - dst_origin.y))
	for sy: int in range(src.get_height()):
		for sx: int in range(src.get_width()):
			if src.get_pixel(sx, sy).a < 0.04:
				continue
			var dx: int = ox + sx
			var dy: int = oy + sy
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			dst.set_pixel(dx, dy, Color(0.0, 0.0, 0.0, 0.0))


static func _sync_actor_map_oblique(sprite: Sprite2D, actor: Node2D) -> void:
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return
	var overlay: Dictionary = map_oblique_overlay()
	if not bool(overlay.get("active", false)):
		mat.set_shader_parameter("has_map_oblique", 0.0)
		return
	mat.set_shader_parameter("has_map_oblique", 1.0)
	mat.set_shader_parameter("map_oblique_tex", overlay.get("tex"))
	mat.set_shader_parameter("map_oblique_origin", overlay.get("origin", Vector2.ZERO))
	mat.set_shader_parameter("map_oblique_size", overlay.get("size", Vector2.ONE))
	var map_origin: Vector2 = sprite.position
	var sprite_scale: Vector2 = Vector2.ONE
	if actor != null:
		sprite_scale = actor.scale
		map_origin = actor.position + sprite.position * sprite_scale
	mat.set_shader_parameter("sprite_map_origin", map_origin)
	mat.set_shader_parameter("sprite_scale", sprite_scale)


static func _clear_actor_sprite(sprite: Sprite2D) -> void:
	if sprite == null:
		return
	sprite.texture = null
	sprite.visible = false


static func _fade_visibility(presence: float, contrast: float) -> float:
	return clampf(presence * contrast, 0.0, 1.0)


## Fade band: skip sun-angle rebakes while essentially invisible (map + player shader still fades).
static func _geometry_blocked(presence: float, contrast: float, settings: EffectsSettings = null) -> bool:
	return _fade_visibility(presence, contrast) < ShadowTuning.geometry_gate(settings)


static func _lofi_visibility(settings: EffectsSettings = null) -> float:
	return ShadowTuning.geometry_gate(settings)


static func _composite_rebake_interval_ms(
	presence: float,
	contrast: float,
	settings: EffectsSettings = null,
) -> int:
	var vis: float = _fade_visibility(presence, contrast)
	var gate: float = _lofi_visibility(settings)
	var bake_lod: bool = _bake_lod_active(settings, contrast)
	var ramp_end: float = ShadowTuning.throttle_ramp_end(settings, bake_lod) if settings != null else (
		TWILIGHT_THROTTLE_RAMP_END if not bake_lod else 0.55
	)
	var fast_ms: int = ShadowTuning.rebake_fast_ms(settings, bake_lod) if settings != null else (
		500 if bake_lod else _MIN_COMPOSITE_REBAKE_MS
	)
	var slow_ms: int = ShadowTuning.rebake_slow_ms(settings, bake_lod) if settings != null else (
		2400 if bake_lod else _MIN_COMPOSITE_REBAKE_MS_SLOW
	)
	if bake_lod:
		if vis >= ramp_end:
			return 0
		var span_perf: float = ramp_end - gate
		if span_perf <= 0.0001:
			return fast_ms
		var t_perf: float = clampf((vis - gate) / span_perf, 0.0, 1.0)
		t_perf = t_perf * t_perf * (3.0 - 2.0 * t_perf)
		return int(lerpf(float(slow_ms), float(fast_ms), t_perf))
	if vis < gate:
		return -1
	var span: float = ramp_end - gate
	if span <= 0.0001:
		return fast_ms
	var t: float = clampf((vis - gate) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return int(lerpf(float(slow_ms), float(fast_ms), t))


static func _geometry_lo_fi(presence: float, contrast: float) -> bool:
	return _geometry_blocked(presence, contrast)


static func _sun_above_horizon_f(clock_f: float) -> bool:
	if clock_f < 0.0:
		return WeatherBus.solar_elevation_rad_f() > WeatherBus.HORIZON_EPSILON_RAD
	return WeatherBus.solar_elevation_rad_f(clock_f) > WeatherBus.HORIZON_EPSILON_RAD


static func _cycle_bake_signature(
	settings: EffectsSettings = null,
	contrast: float = 1.0,
) -> int:
	var punch_sig: int = 0 if _use_caster_punch(settings) else 1
	var sun_sig: int = WeatherBus.shadow_rebake_signature(contrast)
	if _bake_lod_active(settings, contrast) and contrast < (
		settings.shadow_perf_tier_threshold if settings != null else 0.75
	):
		var m_f: float = WeatherBus.clock_minutes_float()
		var pace_min: int = WeatherBus.clock_step_minutes_at(m_f)
		sun_sig = int(floor(m_f / float(pace_min))) * 1000
	return sun_sig * 10 + punch_sig * 1000000


static func _ensure_async_mutex() -> void:
	if _async_mutex == null:
		_async_mutex = Mutex.new()


static func _async_busy() -> bool:
	return _async_task_id >= 0 and not WorkerThreadPool.is_task_completed(_async_task_id)


static func _snapshot_sundial(settings: EffectsSettings = null) -> Dictionary:
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	if clock_f < 0.0:
		return WeatherBus.shadow_sundial()
	return WeatherBus.shadow_sundial(clock_f)


static func _queue_async_composite(
	shadow_root: Node2D,
	layers: Array[Dictionary],
	settings: EffectsSettings,
	contrast: float,
	bake_sig: int,
) -> void:
	if shadow_root == null or layers.is_empty():
		return
	if not _snapshot_sundial(settings).visible:
		return
	var job: Dictionary = {
		"shadow_root": shadow_root,
		"layers": layers,
		"settings": settings,
		"contrast": contrast,
		"bake_sig": bake_sig,
	}
	if _async_busy():
		_async_pending = job
		return
	_start_async_composite(job)


static func _start_async_composite(job: Dictionary) -> void:
	_dbg_map_queued += 1
	_ensure_async_mutex()
	_async_request_token += 1
	var token: int = _async_request_token
	var payload: Dictionary = _make_thread_payload(job, token)
	_async_task_id = WorkerThreadPool.add_task(
		_thread_build_composite.bind(payload),
		false,
		"shadow_composite_bake",
	)


static func _make_thread_payload(job: Dictionary, token: int) -> Dictionary:
	var layer_copies: Array[Dictionary] = []
	for entry: Dictionary in job.layers:
		var src: Image = entry.get("caster_source") as Image
		if src == null:
			continue
		layer_copies.append({
			"caster_source": src.duplicate(),
			"caster_origin": entry.get("caster_origin", Vector2.ZERO),
			"foot_world": entry.get("foot_world", Vector2.ZERO),
			"foot_center_tex": entry.get("foot_center_tex", Vector2.ZERO),
			"nudge": entry.get("nudge", Vector2.ZERO),
			"height_mult": float(entry.get("height_mult", 1.0)),
		})
	var settings: EffectsSettings = job.settings as EffectsSettings
	return {
		"token": token,
		"bake_sig": int(job.bake_sig),
		"layers": layer_copies,
		"sundial": _snapshot_sundial(settings),
		"use_punch": _use_caster_punch(settings) and not _is_perf_mode(settings),
		"perf_mode": _bake_lod_active(settings, float(job.contrast)),
		"edge_soften": _use_edge_soften(settings),
		"contrast": float(job.contrast),
		"local_cache": {},
	}


static func _thread_build_composite(payload: Dictionary) -> void:
	var t0_us: int = Time.get_ticks_usec()
	var built: Dictionary = _build_composite_sync(
		payload.layers as Array[Dictionary],
		payload.sundial as Dictionary,
		bool(payload.use_punch),
		bool(payload.get("perf_mode", false)),
		bool(payload.get("edge_soften", false)),
		float(payload.get("contrast", 1.0)),
		payload.local_cache as Dictionary,
	)
	built["build_ms"] = int((Time.get_ticks_usec() - t0_us) / 1000)
	built["token"] = int(payload.token)
	built["bake_sig"] = int(payload.bake_sig)
	_ensure_async_mutex()
	_async_mutex.lock()
	_async_result = built
	_async_mutex.unlock()


static func _poll_async_composite(shadow_root: Node2D, settings: EffectsSettings = null) -> void:
	if _async_task_id < 0:
		return
	if not WorkerThreadPool.is_task_completed(_async_task_id):
		return
	_async_task_id = -1
	_ensure_async_mutex()
	_async_mutex.lock()
	var result: Dictionary = _async_result
	_async_result = {}
	_async_mutex.unlock()
	if result.is_empty():
		_maybe_start_pending_composite()
		return
	if int(result.get("token", -1)) != _async_request_token:
		_dbg_map_stale += 1
		_maybe_start_pending_composite()
		return
	if bool(result.get("ok", false)) and shadow_root != null:
		_schedule_composite_apply(shadow_root, result, settings)
		_dbg_map_applied += 1
		_dbg_last_map_build_ms = int(result.get("build_ms", 0))
		_dbg_record_bake_event()
	var poll_contrast: float = _shadow_bake_contrast(settings)
	if not _bake_lod_active(settings, poll_contrast) or poll_contrast >= (
		settings.shadow_perf_tier_threshold if settings != null else 0.75
	):
		_maybe_start_pending_composite()


static func _maybe_start_pending_composite() -> void:
	if _async_pending.is_empty():
		return
	var job: Dictionary = _async_pending
	_async_pending = {}
	_start_async_composite(job)


static func _build_composite_sync(
	layers: Array[Dictionary],
	sundial: Dictionary,
	use_punch: bool,
	perf_mode: bool,
	edge_soften: bool,
	bake_contrast: float,
	local_cache: Dictionary,
) -> Dictionary:
	if not bool(sundial.get("visible", false)):
		return {"ok": false}
	var baked_layers: Array[Dictionary] = []
	for entry: Dictionary in layers:
		var baked: Dictionary = _rebake_entry_with_sundial(
			entry, sundial, local_cache, perf_mode, edge_soften, bake_contrast,
		)
		if baked.is_empty():
			continue
		var merged: Dictionary = entry.duplicate()
		merged["image"] = baked["image"]
		merged["position"] = baked["position"]
		baked_layers.append(merged)
	if baked_layers.is_empty():
		return {"ok": false}
	var bounds: Rect2i = _composite_bounds(baked_layers)
	if bounds.size.x < 1 or bounds.size.y < 1:
		return {"ok": false}
	var max_axis: int = _max_shadow_axis(perf_mode, bake_contrast)
	var composite: Image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	composite.fill(Color(0, 0, 0, 0))
	var origin: Vector2 = Vector2(bounds.position)
	for entry: Dictionary in baked_layers:
		_blit_max_alpha(composite, entry["image"] as Image, (entry["position"] as Vector2) - origin)
	if use_punch and not perf_mode:
		_punch_all_casters(composite, baked_layers, origin)
	var fitted: Dictionary = _fit_image_to_max_axis(composite, origin, max_axis, false)
	return {"ok": true, "composite": fitted["image"] as Image, "origin": origin}


static func _schedule_composite_apply(
	shadow_root: Node2D,
	result: Dictionary,
	settings: EffectsSettings = null,
) -> void:
	_pending_composite_apply = {
		"shadow_root": shadow_root,
		"result": result,
		"settings": settings,
	}
	var tree: SceneTree = shadow_root.get_tree()
	if tree == null:
		_flush_composite_apply()
		return
	if _deferred_apply_hooked:
		return
	_deferred_apply_hooked = true
	tree.process_frame.connect(_on_deferred_composite_apply, CONNECT_ONE_SHOT)


static func _on_deferred_composite_apply() -> void:
	_deferred_apply_hooked = false
	_flush_composite_apply()


static func _flush_composite_apply() -> void:
	if _pending_composite_apply.is_empty():
		return
	var pending: Dictionary = _pending_composite_apply
	_pending_composite_apply = {}
	var shadow_root: Node2D = pending.get("shadow_root") as Node2D
	if shadow_root == null:
		return
	_apply_composite_result(
		shadow_root,
		pending.get("result") as Dictionary,
		pending.get("settings") as EffectsSettings,
	)


static func _apply_composite_result(
	shadow_root: Node2D,
	result: Dictionary,
	_settings: EffectsSettings = null,
) -> void:
	var composite: Image = result.get("composite") as Image
	if composite == null:
		return
	var sprite: Sprite2D = shadow_root.get_node_or_null("ShadowComposite") as Sprite2D
	if sprite == null:
		clear_immediate(shadow_root)
		sprite = Sprite2D.new()
		sprite.name = "ShadowComposite"
		sprite.centered = false
		sprite.texture_filter = _shadow_texture_filter(_settings)
		sprite.material = _material()
		shadow_root.add_child(sprite)
	var tex: ImageTexture = sprite.texture as ImageTexture
	if tex == null:
		tex = ImageTexture.create_from_image(composite)
		sprite.texture = tex
	else:
		tex.set_image(composite)
	sprite.texture_filter = _shadow_texture_filter(_settings)
	_apply_shader_mode(sprite.material as ShaderMaterial, _settings)
	sprite.position = result.origin as Vector2
	_refresh_map_oblique_overlay(shadow_root)
	_last_bake_signature = int(result.get("bake_sig", -1))
	_map_composite_apply_epoch += 1


static func _use_caster_punch(settings: EffectsSettings = null) -> bool:
	if settings == null:
		return true
	return not settings.shadow_disable_caster_punch


static func _sundial(settings: EffectsSettings = null) -> Dictionary:
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	if clock_f < 0.0:
		return WeatherBus.shadow_sundial()
	return WeatherBus.shadow_sundial(clock_f)


static func _tree_nudge(settings: EffectsSettings = null) -> Vector2:
	return ShadowDebug.tree_nudge(settings, _TREE_SHADOW_NUDGE)


static func _collect_shadow_layer(
	layers: Array[Dictionary],
	layer: TileMapLayer,
	grid_pos: Vector2i,
	tile_id: int,
	profile: Dictionary,
	provenance: MapRenderProvenance,
	settings: EffectsSettings = null,
) -> void:
	var nudge: Vector2 = _tree_nudge(settings) if tile_id == TileId.Type.TREE else Vector2.ZERO
	_collect_shadow_layer_profile(
		layers,
		layer,
		grid_pos,
		profile["footprint_cells"] as Vector2i,
		provenance,
		TileId.type_name(tile_id).to_lower(),
		settings,
		nudge,
	)


static func _collect_props_shadow_layers(
	layers: Array[Dictionary],
	overlay: TileMapLayer,
	provenance: MapRenderProvenance,
	settings: EffectsSettings = null,
) -> void:
	if overlay == null:
		return
	for cell: Vector2i in overlay.get_used_cells():
		if overlay.get_cell_source_id(cell) != TileSetFactory.SOURCE_PROPS_32:
			continue
		var atlas_x: int = overlay.get_cell_atlas_coords(cell).x
		_collect_shadow_layer_profile(
			layers,
			overlay,
			cell,
			_PROPS_32_FOOTPRINT,
			provenance,
			"props32_%d" % atlas_x,
			settings,
			Vector2.ZERO,
		)


static func _collect_scatter_pebble_shadow_layers(
	layers: Array[Dictionary],
	scatter: TileMapLayer,
	provenance: MapRenderProvenance,
	settings: EffectsSettings = null,
) -> void:
	if scatter == null:
		return
	for cell: Vector2i in scatter.get_used_cells():
		if scatter.get_cell_source_id(cell) != TileSetFactory.SOURCE_FOREST:
			continue
		var atlas: Vector2i = scatter.get_cell_atlas_coords(cell)
		var local_id: int = atlas.x + atlas.y * TileCatalog.ATLAS_COLUMNS
		if local_id != _SCATTER_PEBBLE_SHADOW_ID:
			continue
		_collect_shadow_layer_profile(
			layers,
			scatter,
			cell,
			Vector2i.ONE,
			provenance,
			"pebble_%d" % local_id,
			settings,
			_PEBBLE_88_SHADOW_NUDGE,
			_PEBBLE_88_SHADOW_HEIGHT_MULT,
		)


static func _collect_shadow_layer_profile(
	layers: Array[Dictionary],
	layer: TileMapLayer,
	grid_pos: Vector2i,
	footprint: Vector2i,
	provenance: MapRenderProvenance,
	label: String,
	settings: EffectsSettings = null,
	nudge: Vector2 = Vector2.ZERO,
	height_mult: float = 1.0,
) -> void:
	if layer == null or layer.get_cell_source_id(grid_pos) == -1:
		return
	var atlas_tex: AtlasTexture = _atlas_texture_for_cell(layer, grid_pos)
	if atlas_tex == null:
		return
	var source: Image = _source_image_from_atlas(atlas_tex)
	if source == null:
		return
	var foot_center: Vector2 = _foot_center_from_image(source)
	var foot_world: Vector2
	if footprint.x > 1 or footprint.y > 1:
		foot_world = _foot_world_on_root(layer, grid_pos, footprint)
	else:
		foot_world = _cell_draw_origin_on_root(layer, grid_pos) + foot_center
	var caster_origin: Vector2 = _cell_draw_origin_on_root(layer, grid_pos)
	layers.append({
		"caster_source": source,
		"caster_origin": caster_origin,
		"foot_world": foot_world,
		"foot_center_tex": foot_center,
		"footprint_cells": footprint,
		"nudge": nudge,
		"height_mult": height_mult,
	})


static func _spawn_composite_shadow(
	shadow_root: Node2D,
	layers: Array[Dictionary],
	settings: EffectsSettings = null,
	contrast: float = 1.0,
) -> void:
	_queue_async_composite(
		shadow_root,
		layers,
		settings,
		contrast,
		_cycle_bake_signature(settings, contrast),
	)


static func _rebake_entry(
	entry: Dictionary,
	settings: EffectsSettings = null,
	_contrast: float = 1.0,
) -> Dictionary:
	var bake_contrast: float = _shadow_bake_contrast(settings)
	return _rebake_entry_with_sundial(
		entry,
		_sundial(settings),
		_oblique_bake_cache,
		_bake_lod_active(settings, bake_contrast),
		_use_edge_soften(settings),
		bake_contrast,
	)


static func _rebake_entry_with_sundial(
	entry: Dictionary,
	sundial: Dictionary,
	local_cache: Dictionary,
	perf_mode: bool = false,
	edge_soften: bool = false,
	bake_contrast: float = 1.0,
) -> Dictionary:
	var source: Image = entry["caster_source"] as Image
	if source == null:
		return {}
	var foot_center: Vector2 = entry["foot_center_tex"] as Vector2
	if not sundial.visible:
		return {}
	var bake_sundial: Dictionary = _sundial_scaled_for_caster(
		sundial, float(entry.get("height_mult", 1.0)), perf_mode, bake_contrast,
	)
	var bake: Dictionary = _bake_oblique_shadow_texture(
		source, foot_center, bake_sundial, local_cache, perf_mode, edge_soften, bake_contrast,
	)
	if bake.is_empty():
		return {}
	var img: Image = bake["image"] as Image
	if img == null:
		return {}
	var foot_world: Vector2 = entry["foot_world"] as Vector2
	var nudge: Vector2 = entry.get("nudge", Vector2.ZERO)
	return {
		"image": img,
		"position": foot_world + (bake["offset"] as Vector2) + nudge,
	}


static func _composite_bounds(layers: Array[Dictionary]) -> Rect2i:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for entry: Dictionary in layers:
		var img: Image = entry["image"] as Image
		if img == null:
			continue
		var pos: Vector2 = entry["position"] as Vector2
		min_x = minf(min_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_x = maxf(max_x, pos.x + float(img.get_width()))
		max_y = maxf(max_y, pos.y + float(img.get_height()))
	if min_x == INF:
		return Rect2i()
	return Rect2i(
		Vector2i(int(floor(min_x)), int(floor(min_y))),
		Vector2i(int(ceil(max_x - min_x)), int(ceil(max_y - min_y))),
	)


static func _blit_max_alpha(dst: Image, src: Image, at: Vector2) -> void:
	var used: Rect2i = src.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var ox: int = int(floor(at.x))
	var oy: int = int(floor(at.y))
	var x0: int = used.position.x
	var y0: int = used.position.y
	var x1: int = x0 + used.size.x
	var y1: int = y0 + used.size.y
	for sy: int in range(y0, y1):
		for sx: int in range(x0, x1):
			var a: float = src.get_pixel(sx, sy).a
			if a < 0.04:
				continue
			var dx: int = ox + sx
			var dy: int = oy + sy
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			var prev: Color = dst.get_pixel(dx, dy)
			dst.set_pixel(dx, dy, Color(1.0, 1.0, 1.0, maxf(prev.a, a)))


static func _punch_all_casters(dst: Image, layers: Array[Dictionary], origin: Vector2) -> void:
	for entry: Dictionary in layers:
		var src: Image = entry.get("caster_source") as Image
		if src == null:
			continue
		var caster_origin: Vector2 = entry["caster_origin"] as Vector2
		var ox: int = int(round(caster_origin.x - origin.x))
		var oy: int = int(round(caster_origin.y - origin.y))
		for sy: int in range(src.get_height()):
			for sx: int in range(src.get_width()):
				if src.get_pixel(sx, sy).a < 0.04:
					continue
				var dx: int = ox + sx
				var dy: int = oy + sy
				if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
					continue
				dst.set_pixel(dx, dy, Color(0.0, 0.0, 0.0, 0.0))


static func _cache_shadow_layers(layers: Array[Dictionary]) -> void:
	_shadow_layer_cache.clear()
	for entry: Dictionary in layers:
		var cached: Dictionary = {
			"caster_source": (entry["caster_source"] as Image).duplicate(),
			"caster_origin": entry["caster_origin"],
			"foot_world": entry["foot_world"],
			"foot_center_tex": entry["foot_center_tex"],
			"footprint_cells": entry["footprint_cells"],
			"nudge": entry.get("nudge", Vector2.ZERO),
			"height_mult": float(entry.get("height_mult", 1.0)),
		}
		if entry.has("image"):
			cached["image"] = (entry["image"] as Image).duplicate()
		if entry.has("position"):
			cached["position"] = entry["position"]
		_shadow_layer_cache.append(cached)


static func _material() -> ShaderMaterial:
	if _shadow_material != null:
		return _shadow_material
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = _SHADOW_SHADER
	var params: Dictionary = ShadowPalette.multiply_shader_params()
	_shadow_material.set_shader_parameter("shadow_tint", params["shadow_tint"])
	_shadow_material.set_shader_parameter("shadow_strength", params["shadow_strength"])
	return _shadow_material


static func _foot_center_from_image(source: Image) -> Vector2:
	var w: int = source.get_width()
	var h: int = source.get_height()
	var min_x: int = w
	var max_x: int = -1
	var max_y: int = -1
	for py: int in range(h):
		for px: int in range(w):
			if source.get_pixel(px, py).a < 0.04:
				continue
			min_x = mini(min_x, px)
			max_x = maxi(max_x, px)
			max_y = maxi(max_y, py)
	if max_y < 0:
		return Vector2(float(w) * 0.5, float(h) - 1.0)
	return Vector2(float(min_x + max_x) * 0.5, float(max_y))


static func _sundial_scaled_for_caster(
	sundial: Dictionary,
	height_mult: float,
	perf_mode: bool,
	bake_contrast: float,
) -> Dictionary:
	var scaled: Dictionary = sundial.duplicate()
	if is_equal_approx(height_mult, 1.0):
		return scaled
	var cot_el: float = float(sundial.cot)
	if perf_mode:
		cot_el = _perf_clamp_cot(cot_el, bake_contrast)
	scaled["cot"] = cot_el * clampf(height_mult, 0.05, 1.0)
	return scaled


static func _bake_oblique_shadow_texture(
	source: Image,
	foot_center: Vector2,
	sundial: Dictionary,
	local_cache: Dictionary = {},
	perf_mode: bool = false,
	edge_soften: bool = false,
	bake_contrast: float = 1.0,
) -> Dictionary:
	var bake_source: Image = source
	var bake_foot: Vector2 = foot_center
	if perf_mode:
		var prep: Dictionary = _downscale_caster_for_perf(source, foot_center, bake_contrast)
		bake_source = prep["source"] as Image
		bake_foot = prep["foot_center"] as Vector2
	var dir: Vector2 = sundial.dir as Vector2
	var cot_el: float = float(sundial.cot)
	if perf_mode:
		cot_el = _perf_clamp_cot(cot_el, bake_contrast)
	var tier: Dictionary = _perf_bake_tier(bake_contrast) if perf_mode else {}
	var cache_tag: String = _bake_cache_tag(perf_mode, edge_soften)
	var cache_key: String = "%dx%d|%s|%s|%s|%s" % [
		bake_source.get_width(), bake_source.get_height(), bake_foot, dir, cot_el, cache_tag,
	]
	if local_cache.has(cache_key):
		return _finalize_baked_shadow(
			local_cache[cache_key] as Dictionary,
			perf_mode,
			edge_soften,
			_bake_raster_stride(perf_mode, edge_soften, bake_contrast),
			bake_contrast,
		)
	if local_cache.is_empty() and _oblique_bake_cache.has(cache_key):
		return _finalize_baked_shadow(
			_oblique_bake_cache[cache_key] as Dictionary,
			perf_mode,
			edge_soften,
			_bake_raster_stride(perf_mode, edge_soften, bake_contrast),
			bake_contrast,
		)
	var w: int = bake_source.get_width()
	var h: int = bake_source.get_height()
	if w < 1 or h < 1 or cot_el <= 0.001:
		return _BAKE_FAIL
	# Perf: stride raster + dilate stays solid; full raster only in quality mode.
	var source_stride: int = 1
	var raster_stride: int = 1
	if perf_mode:
		raster_stride = int(tier.get("raster_stride", _PERF_RASTER_STRIDE))
		if edge_soften:
			source_stride = raster_stride
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var min_lx: float = INF
	var min_ly: float = INF
	var max_lx: float = -INF
	var max_ly: float = -INF
	var max_cast_by_across: Dictionary = {}
	for py: int in range(0, h, source_stride):
		for px: int in range(0, w, source_stride):
			if bake_source.get_pixel(px, py).a < 0.04:
				continue
			var land: Vector2 = _project_land(px, py, bake_foot, dir, cot_el)
			var along: float = land.x * dir.x + land.y * dir.y
			var across_i: int = int(round(land.x * perp.x + land.y * perp.y))
			max_cast_by_across[across_i] = maxf(
				float(max_cast_by_across.get(across_i, -INF)),
				along,
			)
			min_lx = minf(min_lx, land.x)
			min_ly = minf(min_ly, land.y)
			max_lx = maxf(max_lx, land.x)
			max_ly = maxf(max_ly, land.y)
	if min_lx == INF or max_lx < min_lx or max_ly < min_ly:
		return _BAKE_FAIL
	if source_stride > 1:
		_fill_max_cast_gaps(max_cast_by_across)
	var min_ix: int = int(floor(min_lx))
	var min_iy: int = int(floor(min_ly))
	var out_w: int = int(ceil(max_lx)) - min_ix + 1
	var out_h: int = int(ceil(max_ly)) - min_iy + 1
	if out_w < 1 or out_h < 1:
		return _BAKE_FAIL
	var max_axis: int = _max_shadow_axis(perf_mode, bake_contrast)
	if out_w > max_axis or out_h > max_axis:
		var fit_scale: float = minf(float(max_axis) / float(out_w), float(max_axis) / float(out_h))
		var scaled_sundial: Dictionary = sundial.duplicate()
		var base_cot: float = float(sundial.cot)
		if perf_mode:
			base_cot = _perf_clamp_cot(base_cot, bake_contrast)
		scaled_sundial["cot"] = base_cot * fit_scale
		return _bake_oblique_shadow_texture(
			source, foot_center, scaled_sundial, local_cache, perf_mode, edge_soften, bake_contrast,
		)
	var out: Image = Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for oy: int in range(0, out_h, raster_stride):
		for ox: int in range(0, out_w, raster_stride):
			var lx: float = float(ox + min_ix)
			var ly: float = float(oy + min_iy)
			var strength: float = _sample_shadow_at_land(
				bake_source, lx, ly, bake_foot, w, h, dir, cot_el, perp, max_cast_by_across,
			)
			if strength >= 0.04:
				if raster_stride > 1:
					_write_alpha_block(out, ox, oy, raster_stride, 1.0)
				else:
					_write_alpha(out, ox, oy, 1.0)
	var used: Rect2i = out.get_used_rect()
	if used.size == Vector2i.ZERO:
		return _BAKE_FAIL
	var cropped: Image = out.get_region(used)
	var stored: Dictionary = {
		"image": cropped.duplicate(),
		"offset": Vector2(float(min_ix + used.position.x), float(min_iy + used.position.y)),
	}
	if local_cache.is_empty():
		_oblique_bake_cache[cache_key] = stored
	else:
		local_cache[cache_key] = stored
	return _finalize_baked_shadow(stored, perf_mode, edge_soften, raster_stride, bake_contrast)


## height_px * cot(el) along dir, full sprite width along perpendicular.
static func _project_land(
	px: int,
	py: int,
	foot_center: Vector2,
	dir: Vector2,
	cot_el: float,
) -> Vector2:
	var height_px: float = maxf(foot_center.y - float(py), 0.0)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	return dir * (height_px * cot_el) + perp * (float(px) - foot_center.x)


static func _sample_shadow_at_land(
	source: Image,
	lx: float,
	ly: float,
	foot_center: Vector2,
	w: int,
	h: int,
	dir: Vector2,
	cot_el: float,
	perp: Vector2,
	max_cast_by_across: Dictionary,
) -> float:
	var along: float = lx * dir.x + ly * dir.y
	var across: float = lx * perp.x + ly * perp.y
	var across_i: int = int(round(across))
	if not max_cast_by_across.has(across_i):
		return 0.0
	if along > float(max_cast_by_across[across_i]) + 0.5:
		return 0.0
	if along < -0.5:
		return 0.0
	if cot_el < 0.001:
		return 0.0
	var height_px: float = along / cot_el
	var py: float = foot_center.y - height_px
	var px: float = foot_center.x + across
	return _sample_alpha_nearest(source, px, py)


static func _sample_alpha_nearest(img: Image, x: float, y: float) -> float:
	var ix: int = int(round(x))
	var iy: int = int(round(y))
	if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
		return 0.0
	return img.get_pixel(ix, iy).a


static func _write_alpha(img: Image, x: int, y: int, alpha: float) -> void:
	if alpha < 0.04:
		return
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var prev: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(prev.a, alpha)))


static func _write_alpha_block(img: Image, x: int, y: int, stride: int, alpha: float) -> void:
	if stride < 2:
		_write_alpha(img, x, y, alpha)
		return
	for dy: int in range(stride):
		for dx: int in range(stride):
			_write_alpha(img, x + dx, y + dy, alpha)


static func _is_perf_mode(settings: EffectsSettings = null) -> bool:
	return settings != null and settings.shadow_perf_mode


static func _hybrid_twilight_lod_enabled(settings: EffectsSettings = null) -> bool:
	return (
		settings != null
		and settings.shadow_hybrid_twilight_lod
		and not settings.shadow_perf_mode
	)


## Perf bake LOD (axis cap, stride, cot clamp, twilight throttle) — full perf mode or hybrid twilight.
static func _bake_lod_active(settings: EffectsSettings, contrast: float) -> bool:
	if _is_perf_mode(settings):
		return true
	if not _hybrid_twilight_lod_enabled(settings):
		return false
	var thr: float = settings.shadow_perf_tier_threshold
	var band: float = clampf(settings.shadow_perf_tier_ease * 0.06, 0.02, 0.12)
	if _last_bake_lod_active:
		return contrast < thr + band * 0.5
	return contrast < thr - band * 0.5


static func _use_edge_soften(settings: EffectsSettings = null) -> bool:
	return settings != null and settings.shadow_edge_soften


static func _shadow_bake_contrast(settings: EffectsSettings = null) -> float:
	if settings == null:
		return WeatherBus.shadow_contrast_factor()
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	if clock_f < 0.0:
		return WeatherBus.shadow_contrast_factor()
	return WeatherBus.shadow_contrast_factor(clock_f)


static func _bake_raster_stride(perf_mode: bool, edge_soften: bool, bake_contrast: float = 1.0) -> int:
	if not perf_mode:
		return 1
	return int(_perf_bake_tier(bake_contrast).get("raster_stride", _PERF_RASTER_STRIDE))


static func _max_shadow_axis(perf_mode: bool, bake_contrast: float) -> int:
	if not perf_mode:
		return _MAX_SHADOW_AXIS
	return int(_perf_bake_tier(bake_contrast).get("max_axis", _MAX_SHADOW_AXIS))


static func _perf_bake_tier(bake_contrast: float) -> Dictionary:
	var c: float = clampf(bake_contrast, 0.0, 1.0)
	var threshold: float = WeatherBus.tune_perf_tier_threshold
	if c >= threshold:
		return {
			"caster_downscale": 2,
			"raster_stride": 2,
			"max_cot": 999.0,
			"max_axis": _MAX_SHADOW_AXIS,
		}
	var t: float = pow(clampf(c / maxf(threshold, 0.001), 0.0, 1.0), WeatherBus.tune_perf_tier_ease)
	var stride_low: int = maxi(1, int(WeatherBus.tune_perf_raster_stride_low))
	return {
		"caster_downscale": int(round(lerpf(WeatherBus.tune_perf_caster_downscale_low, 2.0, t))),
		"raster_stride": stride_low if c < 0.30 else 2,
		"max_cot": lerpf(WeatherBus.tune_perf_max_cot_low, 10.0, t),
		"max_axis": int(round(lerpf(WeatherBus.tune_perf_max_axis_low, float(_MAX_SHADOW_AXIS), t))),
	}


static func _perf_clamp_cot(cot_el: float, bake_contrast: float) -> float:
	var cap: float = float(_perf_bake_tier(bake_contrast).get("max_cot", cot_el))
	return minf(cot_el, cap)


static func _bake_cache_tag(perf_mode: bool, edge_soften: bool) -> String:
	var tag: String = _SHADOW_BAKE_CACHE_TAG_PERF if perf_mode else _SHADOW_BAKE_CACHE_TAG
	return "%s|%s" % [tag, "soft" if edge_soften else "solid"]


static func _shadow_texture_filter(settings: EffectsSettings = null) -> CanvasItem.TextureFilter:
	if _use_edge_soften(settings):
		return CanvasItem.TEXTURE_FILTER_LINEAR
	return CanvasItem.TEXTURE_FILTER_NEAREST


static func _shader_for_settings(settings: EffectsSettings = null) -> Shader:
	if _is_perf_mode(settings):
		return _SHADOW_SHADER_PERF
	return _SHADOW_SHADER


static func _apply_shader_mode(mat: ShaderMaterial, settings: EffectsSettings = null) -> void:
	if mat == null:
		return
	var shader: Shader = _shader_for_settings(settings)
	if mat.shader != shader:
		mat.shader = shader


static func _downscale_caster_for_perf(
	source: Image,
	foot_center: Vector2,
	bake_contrast: float,
) -> Dictionary:
	var scale: int = maxi(1, int(_perf_bake_tier(bake_contrast).get("caster_downscale", 2)))
	var w: int = source.get_width()
	var h: int = source.get_height()
	if w <= scale or h <= scale:
		return {"source": source, "foot_center": foot_center}
	var small: Image = source.duplicate()
	small.resize(maxi(1, w / scale), maxi(1, h / scale), Image.INTERPOLATE_BILINEAR)
	return {
		"source": small,
		"foot_center": foot_center / float(scale),
	}


static func _finalize_baked_shadow(
	stored: Dictionary,
	perf_mode: bool,
	edge_soften: bool,
	raster_stride: int = 1,
	bake_contrast: float = 1.0,
) -> Dictionary:
	var img: Image = (stored["image"] as Image).duplicate()
	var offset: Vector2 = stored["offset"] as Vector2
	if perf_mode:
		var scale: int = maxi(1, int(_perf_bake_tier(bake_contrast).get("caster_downscale", 2)))
		var iw: int = img.get_width()
		var ih: int = img.get_height()
		if iw > 0 and ih > 0:
			var interp: int = (
				Image.INTERPOLATE_BILINEAR if edge_soften else Image.INTERPOLATE_NEAREST
			)
			img.resize(iw * scale, ih * scale, interp)
			offset *= float(scale)
	_postprocess_baked_alpha(img, edge_soften, perf_mode, raster_stride)
	var max_axis: int = _max_shadow_axis(perf_mode, bake_contrast)
	return _fit_image_to_max_axis(img, offset, max_axis, true)


static func _fit_image_to_max_axis(
	img: Image,
	offset: Vector2,
	max_axis: int,
	scale_offset: bool,
) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 1 or h < 1 or (w <= max_axis and h <= max_axis):
		return {"image": img, "offset": offset}
	var scale: float = minf(float(max_axis) / float(w), float(max_axis) / float(h))
	var nw: int = maxi(1, int(round(float(w) * scale)))
	var nh: int = maxi(1, int(round(float(h) * scale)))
	var out: Image = img.duplicate()
	out.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	var out_offset: Vector2 = offset * scale if scale_offset else offset
	return {"image": out, "offset": out_offset}


static func _postprocess_baked_alpha(
	img: Image,
	edge_soften: bool,
	perf_mode: bool,
	raster_stride: int = 1,
) -> void:
	if edge_soften:
		_soften_shadow_alpha(img)
	else:
		_solidify_shadow_alpha(img)
		var dilate_r: int = maxi(raster_stride, 1) if perf_mode else 1
		_dilate_shadow_alpha(img, dilate_r)


static func _fill_max_cast_gaps(max_cast_by_across: Dictionary) -> void:
	if max_cast_by_across.is_empty():
		return
	var keys: Array = max_cast_by_across.keys()
	keys.sort()
	var min_k: int = int(keys[0])
	var max_k: int = int(keys[keys.size() - 1])
	for across_i: int in range(min_k, max_k + 1):
		if max_cast_by_across.has(across_i):
			continue
		var left: float = float(max_cast_by_across.get(across_i - 1, -INF))
		var right: float = float(max_cast_by_across.get(across_i + 1, -INF))
		var fill: float = maxf(left, right)
		if fill > -INF:
			max_cast_by_across[across_i] = fill


static func _dilate_shadow_alpha(img: Image, radius: int) -> void:
	if radius < 1:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			if src.get_pixel(x, y).a >= 0.5:
				continue
			var filled: bool = false
			for dy: int in range(-radius, radius + 1):
				if filled:
					break
				for dx: int in range(-radius, radius + 1):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if src.get_pixel(nx, ny).a >= 0.5:
						img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
						filled = true
						break


static func _solidify_shadow_alpha(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in range(h):
		for x: int in range(w):
			if img.get_pixel(x, y).a >= 0.5:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


static func _soften_shadow_alpha(img: Image, radius: int = _SHADOW_EDGE_SOFTEN_RADIUS) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 2 or h < 2 or radius < 1:
		return
	var src: Image = img.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			var sum: float = 0.0
			var count: int = 0
			for dy: int in range(-radius, radius + 1):
				for dx: int in range(-radius, radius + 1):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					sum += src.get_pixel(nx, ny).a
					count += 1
			if count < 1:
				continue
			var a: float = sum / float(count)
			if a < 0.04:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))


static func _source_image_from_atlas(atlas_tex: AtlasTexture) -> Image:
	var atlas: Texture2D = atlas_tex.atlas
	if atlas == null:
		return null
	var img: Image = atlas.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var region: Rect2i = Rect2i(atlas_tex.region)
	if region.size.x < 1 or region.size.y < 1:
		return null
	if region.position.x < 0 or region.position.y < 0:
		return null
	if region.position.x + region.size.x > img.get_width():
		return null
	if region.position.y + region.size.y > img.get_height():
		return null
	return img.get_region(region)


static func clear_bake_cache() -> void:
	_oblique_bake_cache.clear()
	_async_pending = {}
	if _async_task_id >= 0:
		if WorkerThreadPool.is_task_completed(_async_task_id):
			WorkerThreadPool.wait_for_task_completion(_async_task_id)
		_async_task_id = -1
	_ensure_async_mutex()
	_async_mutex.lock()
	_async_result = {}
	_async_mutex.unlock()


static func _atlas_texture_for_cell(layer: TileMapLayer, cell: Vector2i) -> AtlasTexture:
	var source_id: int = layer.get_cell_source_id(cell)
	if source_id == -1:
		return null
	var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
	var tile_set: TileSet = layer.tile_set
	if tile_set == null:
		return null
	var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return null
	var region_size: Vector2i = source.texture_region_size
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = source.texture
	tex.region = Rect2(Vector2(atlas_coords) * Vector2(region_size), Vector2(region_size))
	tex.filter_clip = true
	return tex


static func _foot_cell_offset(footprint_cells: Vector2i) -> Vector2i:
	return Vector2i((footprint_cells.x - 1) / 2, footprint_cells.y - 1)


static func _foot_world_on_root(
	layer: TileMapLayer,
	anchor_cell: Vector2i,
	footprint_cells: Vector2i,
) -> Vector2:
	var foot_cell: Vector2i = anchor_cell + _foot_cell_offset(footprint_cells)
	return layer.position + layer.map_to_local(foot_cell)


static func _cell_draw_origin_on_root(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	var local_pos: Vector2 = layer.map_to_local(cell)
	var tile_data: TileData = layer.get_cell_tile_data(cell)
	if tile_data != null:
		local_pos -= Vector2(tile_data.texture_origin)
	return layer.position + local_pos


static func _tree_has_baked_atlas_shadow(
	grid_pos: Vector2i,
	trees: TileMapLayer,
	provenance: MapRenderProvenance,
) -> bool:
	if trees != null and trees.get_cell_source_id(grid_pos) == TileSetFactory.SOURCE_TREES:
		return trees.get_cell_atlas_coords(grid_pos).x == 0
	if provenance == null:
		return true
	var entry: Dictionary = provenance.overlay_anchors.get(
		"%d,%d" % [grid_pos.x, grid_pos.y], {},
	)
	if str(entry.get("reason", "")) != "ecology_tree":
		return true
	return int((entry.get("atlas", Vector2i.ZERO) as Vector2i).x) == 0


static func foot_center_from_image(source: Image) -> Vector2:
	return _foot_center_from_image(source)


static func actor_shadow_bake_signature(settings: EffectsSettings = null) -> int:
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	var contrast: float = (
		WeatherBus.shadow_contrast_factor(clock_f)
		if clock_f >= 0.0
		else WeatherBus.shadow_contrast_factor()
	)
	return _cycle_bake_signature(settings, contrast)


static func applied_cycle_bake_signature() -> int:
	return _last_bake_signature


static func reset_actor_bake_key() -> void:
	_last_actor_bake_key = -1
	_last_actor_applied_epoch = -1
	_last_actor_synced_silhouette = -1


static func map_composite_apply_epoch() -> int:
	return _map_composite_apply_epoch


static func map_oblique_overlay() -> Dictionary:
	return _map_oblique_overlay


static func sample_map_oblique_alpha_at(map_px: Vector2) -> float:
	var overlay: Dictionary = map_oblique_overlay()
	if not bool(overlay.get("active", false)):
		return 0.0
	var img: Image = _shadow_overlay_image()
	if img == null or img.is_empty():
		return 0.0
	var origin: Vector2 = overlay.get("origin", Vector2.ZERO)
	var size: Vector2 = overlay.get("size", Vector2.ONE)
	var local: Vector2 = map_px - origin
	if local.x < 0.0 or local.y < 0.0 or local.x >= size.x or local.y >= size.y:
		return 0.0
	return _sample_alpha_nearest(img, floor(local.x), floor(local.y))


static func actor_oblique_band_modulates(
	actor: Node2D,
	settings: EffectsSettings = null,
) -> Array[Color]:
	var bands: Array[Color] = []
	bands.resize(ACTOR_SHADOW_BAND_COUNT)
	for i: int in ACTOR_SHADOW_BAND_COUNT:
		bands[i] = Color.WHITE
	if actor == null or settings == null:
		return bands
	if not settings.oblique_contact_shadows:
		return bands
	var foot: Vector2 = actor.position
	var scale_y: float = actor.scale.y
	for band_i: int in ACTOR_SHADOW_BAND_COUNT:
		var y_rows: Variant = ACTOR_SHADOW_BAND_Y[band_i]
		if typeof(y_rows) != TYPE_ARRAY:
			continue
		var hit_count: int = 0
		var sample_count: int = 0
		var alpha_sum: float = 0.0
		for y_off: Variant in y_rows:
			var y_px: float = float(y_off) * scale_y
			for x_off: Variant in ACTOR_SHADOW_BAND_X:
				sample_count += 1
				var alpha: float = sample_map_oblique_alpha_at(
					foot + Vector2(float(x_off) * actor.scale.x, y_px)
				)
				if alpha >= 0.04:
					hit_count += 1
					alpha_sum += alpha
		if sample_count < 1:
			continue
		if float(hit_count) / float(sample_count) < ACTOR_SHADOW_MAJORITY_RATIO:
			continue
		var coverage: float = alpha_sum / float(hit_count)
		bands[band_i] = _modulate_from_shadow_coverage(coverage, settings)
	return bands


## Legacy single-tint path — darkest band that passed majority gate.
static func actor_oblique_modulate(actor: Node2D, settings: EffectsSettings = null) -> Color:
	var bands: Array[Color] = actor_oblique_band_modulates(actor, settings)
	var darkest: Color = Color.WHITE
	for band: Color in bands:
		if band.r < darkest.r:
			darkest = band
	return darkest


static func _modulate_from_shadow_coverage(coverage: float, settings: EffectsSettings) -> Color:
	if coverage < 0.04:
		return Color.WHITE
	var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
	var tint: Color = params.get("shadow_tint", Color(0.74, 0.72, 0.80, 1.0))
	var strength: float = float(params.get("shadow_strength", 1.0)) * coverage
	return Color(
		lerpf(1.0, tint.r, strength),
		lerpf(1.0, tint.g, strength),
		lerpf(1.0, tint.b, strength),
		1.0,
	)


static func _shadow_overlay_image() -> Image:
	if _overlay_sample_epoch == _map_composite_apply_epoch and _overlay_sample_image != null:
		return _overlay_sample_image
	var overlay: Dictionary = map_oblique_overlay()
	if not bool(overlay.get("active", false)):
		_overlay_sample_image = null
		_overlay_sample_epoch = -1
		return null
	var tex: Texture2D = overlay.get("tex") as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	_overlay_sample_image = img
	_overlay_sample_epoch = _map_composite_apply_epoch
	return _overlay_sample_image


static func _refresh_map_oblique_overlay(shadow_root: Node2D) -> void:
	_map_oblique_overlay = {}
	if shadow_root == null:
		return
	var sprite: Sprite2D = shadow_root.get_node_or_null("ShadowComposite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	_map_oblique_overlay = {
		"active": true,
		"tex": sprite.texture,
		"origin": sprite.position,
		"size": sprite.texture.get_size(),
	}
	_overlay_sample_image = null
	_overlay_sample_epoch = -1


static func duplicate_shadow_material() -> ShaderMaterial:
	return _material().duplicate()


static func sync_shadow_material(mat: ShaderMaterial, settings: EffectsSettings = null) -> void:
	if mat == null:
		return
	_apply_shader_mode(mat, settings)
	var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
	mat.set_shader_parameter("shadow_tint", params["shadow_tint"])
	mat.set_shader_parameter("shadow_strength", params["shadow_strength"])


## Rebake one moving actor silhouette — foot_world is contact point in parent local space.
static func rebake_actor_shadow(
	caster_source: Image,
	foot_center_tex: Vector2,
	foot_world: Vector2,
	settings: EffectsSettings = null,
) -> Dictionary:
	if caster_source == null:
		return {}
	var sundial: Dictionary = _snapshot_sundial(settings)
	if not bool(sundial.get("visible", false)):
		return {}
	var entry: Dictionary = {
		"caster_source": caster_source,
		"caster_origin": Vector2.ZERO,
		"foot_world": foot_world,
		"foot_center_tex": foot_center_tex,
		"nudge": Vector2.ZERO,
	}
	var bake_contrast: float = _shadow_bake_contrast(settings)
	var baked: Dictionary = _rebake_entry_with_sundial(
		entry,
		sundial,
		{},
		_bake_lod_active(settings, bake_contrast),
		_use_edge_soften(settings),
		bake_contrast,
	)
	if baked.is_empty():
		return {}
	var img: Image = baked["image"] as Image
	if img == null:
		return {}
	return {
		"image": img,
		"position": baked["position"] as Vector2,
	}


static func clear(shadow_root: Node2D) -> void:
	if shadow_root == null:
		return
	for child: Node in shadow_root.get_children():
		child.queue_free()


static func clear_immediate(shadow_root: Node2D) -> void:
	if shadow_root == null:
		return
	_map_oblique_overlay = {}
	var children: Array[Node] = shadow_root.get_children()
	for child: Node in children:
		if child is Sprite2D:
			var sprite: Sprite2D = child as Sprite2D
			sprite.material = null
			sprite.texture = null
		elif child is CanvasItem:
			(child as CanvasItem).material = null
		shadow_root.remove_child(child)
		child.queue_free()


static func debug_record_actor_bake(build_ms: int) -> void:
	_dbg_actor_rebaked += 1
	_dbg_last_actor_build_ms = build_ms
	_dbg_record_bake_event()


static func debug_snapshot() -> Dictionary:
	_dbg_prune_rate_window()
	return {
		"map_queued": _dbg_map_queued,
		"map_applied": _dbg_map_applied,
		"map_stale": _dbg_map_stale,
		"actor_rebaked": _dbg_actor_rebaked,
		"last_map_build_ms": _dbg_last_map_build_ms,
		"last_actor_build_ms": _dbg_last_actor_build_ms,
		"bakes_last_60s": _dbg_rate_timestamps_ms.size(),
		"bakes_last_1s": _dbg_bakes_in_window(1000),
		"async_busy": _async_busy(),
	}


static func debug_format_line() -> String:
	var s: Dictionary = debug_snapshot()
	var avg_per_sec: float = float(s.bakes_last_60s) / 60.0
	return (
		"60s: %d bakes | 1s: %d (~%.2f/s avg) | map Q%d A%d stale%d last %dms"
		% [
			s.bakes_last_60s,
			s.bakes_last_1s,
			avg_per_sec,
			s.map_queued,
			s.map_applied,
			s.map_stale,
			s.last_map_build_ms,
		]
		+ " | actor %d last %dms | worker %s"
		% [
			s.actor_rebaked,
			s.last_actor_build_ms,
			"busy" if s.async_busy else "idle",
		]
	)


static func debug_reset_counters() -> void:
	_dbg_map_queued = 0
	_dbg_map_applied = 0
	_dbg_map_stale = 0
	_dbg_actor_rebaked = 0
	_dbg_last_map_build_ms = 0
	_dbg_last_actor_build_ms = 0
	_dbg_rate_timestamps_ms = PackedInt64Array()


static func _dbg_record_bake_event() -> void:
	var now_ms: int = Time.get_ticks_msec()
	_dbg_rate_timestamps_ms.append(now_ms)
	_dbg_prune_rate_window()


static func _dbg_prune_rate_window() -> void:
	var cutoff: int = Time.get_ticks_msec() - _DBG_RATE_WINDOW_MS
	while not _dbg_rate_timestamps_ms.is_empty() and _dbg_rate_timestamps_ms[0] < cutoff:
		_dbg_rate_timestamps_ms.remove_at(0)


static func _dbg_bakes_in_window(window_ms: int) -> int:
	if window_ms <= 0:
		return 0
	var cutoff: int = Time.get_ticks_msec() - window_ms
	var count: int = 0
	for i: int in range(_dbg_rate_timestamps_ms.size() - 1, -1, -1):
		if _dbg_rate_timestamps_ms[i] < cutoff:
			break
		count += 1
	return count
