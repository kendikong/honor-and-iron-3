class_name EffectsSettings
extends RefCounted

## Persisted on/off toggles for living-environment systems.

signal changed

const CONFIG_PATH: String = "user://game_settings.cfg"

# Phase 4 — Wind & Grass (GPU)
var wind_field: bool = false

# Phase 5 — Sky, Light, Atmosphere
var time_light: bool = true
var cloud_shadows: bool = true
var mist: bool = false

## Cloud shadow field tuning — GPU + CPU share CloudTuning.
var cloud_shadow_strength: float = CloudTuning.STRENGTH_DEFAULT
var cloud_scale_tiles: float = CloudTuning.SCALE_TILES_DEFAULT
var cloud_coverage: float = CloudTuning.COVERAGE_DEFAULT
var cloud_edge_softness: float = CloudTuning.EDGE_SOFTNESS_DEFAULT
var cloud_mask_steps: float = CloudTuning.MASK_STEPS_DEFAULT
var cloud_shape_mix: float = CloudTuning.SHAPE_MIX_DEFAULT
var cloud_shape_scale: float = CloudTuning.SHAPE_SCALE_DEFAULT

# Phase 9 — Composites & pixel-height shadows (each deliverable = one toggle)
var oblique_contact_shadows: bool = true
var tree_variant_b: bool = true

# Debug — freeze WeatherBus clock/sun; cloud drift keeps running independently.
var shadow_freeze_time: bool = false
var shadow_cycle_sun_angle: bool = false
var shadow_cycle_length: bool = false
var shadow_cycle_tint_strength: bool = false
var shadow_disable_tree_nudge: bool = false
var shadow_disable_caster_punch: bool = true
## Experiment — low-res bake, no twilight throttle, linear filter (performance over pixel fidelity).
var shadow_perf_mode: bool = false
## Quality shader + full-res bake by day; perf LOD bake + throttle when contrast is low (dawn/dusk).
var shadow_hybrid_twilight_lod: bool = true
## 3×3 box blur on baked shadow alpha after binarize (off = hard pixel edges).
var shadow_edge_soften: bool = false

## Shadow twilight / timing / perf scalars — map + player share WeatherBus + ShadowPalette path.
var shadow_twilight_fade_deg: float = ShadowTuning.TWILIGHT_FADE_DEG_DEFAULT
var shadow_contrast_ease: float = ShadowTuning.CONTRAST_EASE_DEFAULT
var shadow_full_contrast_below_noon_deg: float = ShadowTuning.FULL_CONTRAST_BELOW_NOON_DEFAULT
var shadow_atmosphere_presence_power: float = ShadowTuning.ATMOSPHERE_PRESENCE_POWER_DEFAULT
var shadow_geometry_gate: float = ShadowTuning.GEOMETRY_GATE_DEFAULT
var shadow_actor_appearance_gate: float = ShadowTuning.ACTOR_APPEARANCE_GATE_DEFAULT
var shadow_twilight_tint_night_lerp: float = ShadowTuning.TINT_NIGHT_LERP_DEFAULT
var shadow_twilight_tint_white_lerp: float = ShadowTuning.TINT_WHITE_LERP_DEFAULT
var shadow_strength_contrast_mult: float = ShadowTuning.STRENGTH_CONTRAST_MULT_DEFAULT
var shadow_preset_ramp_min: float = ShadowTuning.PRESET_RAMP_MIN_DEFAULT
var shadow_night_to_dusk_start_min: float = ShadowTuning.NIGHT_TO_DUSK_START_DEFAULT
var shadow_dusk_to_day_start_min: float = ShadowTuning.DUSK_TO_DAY_START_DEFAULT
var shadow_day_to_dusk_start_min: float = ShadowTuning.DAY_TO_DUSK_START_DEFAULT
var shadow_dusk_to_night_start_min: float = ShadowTuning.DUSK_TO_NIGHT_START_DEFAULT
var shadow_rebake_fast_ms: float = ShadowTuning.REBAKE_FAST_MS_DEFAULT
var shadow_rebake_slow_ms: float = ShadowTuning.REBAKE_SLOW_MS_DEFAULT
var shadow_throttle_ramp_end: float = ShadowTuning.THROTTLE_RAMP_END_DEFAULT
var shadow_perf_rebake_fast_ms: float = ShadowTuning.PERF_REBAKE_FAST_MS_DEFAULT
var shadow_perf_rebake_slow_ms: float = ShadowTuning.PERF_REBAKE_SLOW_MS_DEFAULT
var shadow_perf_throttle_ramp_end: float = ShadowTuning.PERF_THROTTLE_RAMP_END_DEFAULT
var shadow_perf_max_axis_low: float = ShadowTuning.PERF_MAX_AXIS_LOW_DEFAULT
var shadow_perf_max_cot_low: float = ShadowTuning.PERF_MAX_COT_LOW_DEFAULT
var shadow_perf_raster_stride_low: float = ShadowTuning.PERF_RASTER_STRIDE_LOW_DEFAULT
var shadow_perf_caster_downscale_low: float = ShadowTuning.PERF_DOWNSCALE_LOW_DEFAULT
var shadow_perf_tier_threshold: float = ShadowTuning.PERF_TIER_THRESHOLD_DEFAULT
var shadow_perf_tier_ease: float = ShadowTuning.PERF_TIER_EASE_DEFAULT
var shadow_arc_half_span_deg: float = ShadowTuning.ARC_HALF_SPAN_DEFAULT
var shadow_noon_height_ratio: float = ShadowTuning.NOON_HEIGHT_RATIO_DEFAULT

const SHADOW_DEBUG_KEYS: PackedStringArray = [
	"shadow_freeze_time",
	"shadow_disable_tree_nudge",
	"shadow_disable_caster_punch",
	"shadow_perf_mode",
	"shadow_hybrid_twilight_lod",
	"shadow_edge_soften",
]

# Phase 6 — Water Channel
var water_ripples: bool = true
var shoreline_foam: bool = true
var water_sparkles: bool = true
var fish_splash: bool = true

# Phase 7 — Ecology & Rare Events
var ambient_particles: bool = true
var ecology_actors: bool = true
var rare_events: bool = true

# Phase 8 — Biome / Palette Swap
var biome_variant: int = 1

var sandbox_character_scale: float = 2.0


func load_from_disk() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	wind_field = bool(cfg.get_value("effects", "wind_field", wind_field))
	sandbox_character_scale = float(cfg.get_value("sandbox", "character_scale", sandbox_character_scale))
	time_light = bool(cfg.get_value("effects", "time_light", time_light))
	cloud_shadows = bool(cfg.get_value("effects", "cloud_shadows", cloud_shadows))
	mist = bool(cfg.get_value("effects", "mist", mist))
	if cfg.has_section_key("effects", "oblique_contact_shadows"):
		oblique_contact_shadows = bool(
			cfg.get_value("effects", "oblique_contact_shadows", oblique_contact_shadows)
		)
	elif cfg.has_section_key("effects", "drop_shadows"):
		oblique_contact_shadows = bool(cfg.get_value("effects", "drop_shadows", oblique_contact_shadows))
	tree_variant_b = bool(cfg.get_value("effects", "tree_variant_b", tree_variant_b))
	for key: String in SHADOW_DEBUG_KEYS:
		set(key, bool(cfg.get_value("effects", key, get(key))))
	for key: String in ShadowTuning.PERSIST_KEYS:
		set(key, ShadowTuning.load_scalar(cfg, key, float(get(key))))
	ShadowTuning.clamp_all(self)
	for key: String in CloudTuning.PERSIST_KEYS:
		set(key, CloudTuning.load_scalar(cfg, key, float(get(key))))
	CloudTuning.clamp_all(self)
	water_ripples = bool(cfg.get_value("effects", "water_ripples", water_ripples))
	shoreline_foam = bool(cfg.get_value("effects", "shoreline_foam", shoreline_foam))
	water_sparkles = bool(cfg.get_value("effects", "water_sparkles", water_sparkles))
	fish_splash = bool(cfg.get_value("effects", "fish_splash", fish_splash))
	ambient_particles = bool(cfg.get_value("effects", "ambient_particles", ambient_particles))
	ecology_actors = bool(cfg.get_value("effects", "ecology_actors", ecology_actors))
	rare_events = bool(cfg.get_value("effects", "rare_events", rare_events))
	biome_variant = clampi(int(cfg.get_value("effects", "biome_variant", biome_variant)), 1, 3)


func save_to_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		cfg.load(CONFIG_PATH)
	cfg.set_value("effects", "wind_field", wind_field)
	cfg.set_value("sandbox", "character_scale", sandbox_character_scale)
	cfg.set_value("effects", "time_light", time_light)
	cfg.set_value("effects", "cloud_shadows", cloud_shadows)
	cfg.set_value("effects", "mist", mist)
	cfg.set_value("effects", "oblique_contact_shadows", oblique_contact_shadows)
	cfg.set_value("effects", "tree_variant_b", tree_variant_b)
	for key: String in SHADOW_DEBUG_KEYS:
		cfg.set_value("effects", key, bool(get(key)))
	for key: String in ShadowTuning.PERSIST_KEYS:
		cfg.set_value("effects", key, float(get(key)))
	for key: String in CloudTuning.PERSIST_KEYS:
		cfg.set_value("effects", key, float(get(key)))
	cfg.set_value("effects", "water_ripples", water_ripples)
	cfg.set_value("effects", "shoreline_foam", shoreline_foam)
	cfg.set_value("effects", "water_sparkles", water_sparkles)
	cfg.set_value("effects", "fish_splash", fish_splash)
	cfg.set_value("effects", "ambient_particles", ambient_particles)
	cfg.set_value("effects", "ecology_actors", ecology_actors)
	cfg.set_value("effects", "rare_events", rare_events)
	cfg.set_value("effects", "biome_variant", clampi(biome_variant, 1, 3))
	cfg.save(CONFIG_PATH)
	changed.emit()


func needs_weather_bus() -> bool:
	return time_light or cloud_shadows or mist or water_ripples or oblique_contact_shadows


func any_phase5() -> bool:
	return time_light or cloud_shadows or mist


func any_phase9() -> bool:
	return oblique_contact_shadows or tree_variant_b


func any_phase6() -> bool:
	return water_ripples or shoreline_foam or water_sparkles or fish_splash


func any_phase7() -> bool:
	return ambient_particles or ecology_actors or rare_events


func any_ground_effects() -> bool:
	return wind_field or water_ripples

