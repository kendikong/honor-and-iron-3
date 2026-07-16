class_name ShadowTuning
extends RefCounted

## Runtime bridge: persisted EffectsSettings scalars → WeatherBus + shared shadow math.

const TWILIGHT_FADE_DEG_MIN: float = 4.0
const TWILIGHT_FADE_DEG_MAX: float = 48.0
const TWILIGHT_FADE_DEG_DEFAULT: float = 40.0

const CONTRAST_EASE_MIN: float = 0.15
const CONTRAST_EASE_MAX: float = 2.5
const CONTRAST_EASE_DEFAULT: float = 1.25

const FULL_CONTRAST_BELOW_NOON_MIN: float = 4.0
const FULL_CONTRAST_BELOW_NOON_MAX: float = 45.0
const FULL_CONTRAST_BELOW_NOON_DEFAULT: float = 22.0

const ATMOSPHERE_PRESENCE_POWER_MIN: float = 0.35
const ATMOSPHERE_PRESENCE_POWER_MAX: float = 3.0
const ATMOSPHERE_PRESENCE_POWER_DEFAULT: float = 1.45

const GEOMETRY_GATE_MIN: float = 0.01
const GEOMETRY_GATE_MAX: float = 0.30
const GEOMETRY_GATE_DEFAULT: float = 0.01

const ACTOR_APPEARANCE_GATE_MIN: float = 0.0
const ACTOR_APPEARANCE_GATE_MAX: float = 0.25
const ACTOR_APPEARANCE_GATE_DEFAULT: float = 0.11

const TINT_NIGHT_LERP_MIN: float = 0.0
const TINT_NIGHT_LERP_MAX: float = 1.0
const TINT_NIGHT_LERP_DEFAULT: float = 0.42

const TINT_WHITE_LERP_MIN: float = 0.0
const TINT_WHITE_LERP_MAX: float = 1.0
const TINT_WHITE_LERP_DEFAULT: float = 0.26

const STRENGTH_CONTRAST_MULT_MIN: float = 0.1
const STRENGTH_CONTRAST_MULT_MAX: float = 2.0
const STRENGTH_CONTRAST_MULT_DEFAULT: float = 1.0

const PRESET_RAMP_MIN_MIN: float = 30.0
const PRESET_RAMP_MIN_MAX: float = 600.0
const PRESET_RAMP_MIN_DEFAULT: float = 450.0

const CLOCK_WINDOW_MIN: float = 0.0
const CLOCK_WINDOW_MAX: float = 1380.0

const REBAKE_FAST_MS_MIN: float = 50.0
const REBAKE_FAST_MS_MAX: float = 4000.0
const REBAKE_SLOW_MS_MIN: float = 100.0
const REBAKE_SLOW_MS_MAX: float = 8000.0
const REBAKE_FAST_MS_DEFAULT: float = 1500.0
const REBAKE_SLOW_MS_DEFAULT: float = 2400.0
const PERF_REBAKE_FAST_MS_DEFAULT: float = 250.0
const PERF_REBAKE_SLOW_MS_DEFAULT: float = 1000.0

const THROTTLE_RAMP_END_MIN: float = 0.05
const THROTTLE_RAMP_END_MAX: float = 0.90
const THROTTLE_RAMP_END_DEFAULT: float = 0.41
const PERF_THROTTLE_RAMP_END_DEFAULT: float = 0.05

const PERF_MAX_AXIS_LOW_MIN: float = 256.0
const PERF_MAX_AXIS_LOW_MAX: float = 1536.0
const PERF_MAX_AXIS_LOW_DEFAULT: float = 1536.0

const PERF_MAX_COT_LOW_MIN: float = 0.8
const PERF_MAX_COT_LOW_MAX: float = 6.0
const PERF_MAX_COT_LOW_DEFAULT: float = 6.0

const PERF_RASTER_STRIDE_LOW_MIN: float = 1.0
const PERF_RASTER_STRIDE_LOW_MAX: float = 4.0
const PERF_RASTER_STRIDE_LOW_DEFAULT: float = 2.0

const PERF_DOWNSCALE_LOW_MIN: float = 2.0
const PERF_DOWNSCALE_LOW_MAX: float = 8.0
const PERF_DOWNSCALE_LOW_DEFAULT: float = 6.0

const PERF_TIER_THRESHOLD_MIN: float = 0.25
const PERF_TIER_THRESHOLD_MAX: float = 0.95
const PERF_TIER_THRESHOLD_DEFAULT: float = 0.85

const PERF_TIER_EASE_MIN: float = 0.2
const PERF_TIER_EASE_MAX: float = 1.5
const PERF_TIER_EASE_DEFAULT: float = 0.55

const ARC_HALF_SPAN_MIN: float = 20.0
const ARC_HALF_SPAN_MAX: float = 90.0
const ARC_HALF_SPAN_DEFAULT: float = 60.0

const NOON_HEIGHT_RATIO_MIN: float = 0.4
const NOON_HEIGHT_RATIO_MAX: float = 1.25
const NOON_HEIGHT_RATIO_DEFAULT: float = 1.0

const NIGHT_TO_DUSK_START_DEFAULT: float = 180.0   # 3:00 AM
const DUSK_TO_DAY_START_DEFAULT: float = 420.0     # 7:00 AM
const DAY_TO_DUSK_START_DEFAULT: float = 840.0     # 2:00 PM
const DUSK_TO_NIGHT_START_DEFAULT: float = 1080.0  # 6:00 PM

const PERSIST_KEYS: PackedStringArray = [
	"shadow_twilight_fade_deg",
	"shadow_contrast_ease",
	"shadow_full_contrast_below_noon_deg",
	"shadow_atmosphere_presence_power",
	"shadow_geometry_gate",
	"shadow_actor_appearance_gate",
	"shadow_twilight_tint_night_lerp",
	"shadow_twilight_tint_white_lerp",
	"shadow_strength_contrast_mult",
	"shadow_preset_ramp_min",
	"shadow_night_to_dusk_start_min",
	"shadow_dusk_to_day_start_min",
	"shadow_day_to_dusk_start_min",
	"shadow_dusk_to_night_start_min",
	"shadow_rebake_fast_ms",
	"shadow_rebake_slow_ms",
	"shadow_throttle_ramp_end",
	"shadow_perf_rebake_fast_ms",
	"shadow_perf_rebake_slow_ms",
	"shadow_perf_throttle_ramp_end",
	"shadow_perf_max_axis_low",
	"shadow_perf_max_cot_low",
	"shadow_perf_raster_stride_low",
	"shadow_perf_caster_downscale_low",
	"shadow_perf_tier_threshold",
	"shadow_perf_tier_ease",
	"shadow_arc_half_span_deg",
	"shadow_noon_height_ratio",
]


static func clamp_all(settings: EffectsSettings) -> void:
	if settings == null:
		return
	settings.shadow_twilight_fade_deg = clampf(
		settings.shadow_twilight_fade_deg, TWILIGHT_FADE_DEG_MIN, TWILIGHT_FADE_DEG_MAX,
	)
	settings.shadow_contrast_ease = clampf(
		settings.shadow_contrast_ease, CONTRAST_EASE_MIN, CONTRAST_EASE_MAX,
	)
	settings.shadow_full_contrast_below_noon_deg = clampf(
		settings.shadow_full_contrast_below_noon_deg,
		FULL_CONTRAST_BELOW_NOON_MIN,
		FULL_CONTRAST_BELOW_NOON_MAX,
	)
	settings.shadow_atmosphere_presence_power = clampf(
		settings.shadow_atmosphere_presence_power,
		ATMOSPHERE_PRESENCE_POWER_MIN,
		ATMOSPHERE_PRESENCE_POWER_MAX,
	)
	settings.shadow_geometry_gate = clampf(
		settings.shadow_geometry_gate, GEOMETRY_GATE_MIN, GEOMETRY_GATE_MAX,
	)
	settings.shadow_actor_appearance_gate = clampf(
		settings.shadow_actor_appearance_gate,
		ACTOR_APPEARANCE_GATE_MIN,
		ACTOR_APPEARANCE_GATE_MAX,
	)
	settings.shadow_twilight_tint_night_lerp = clampf(
		settings.shadow_twilight_tint_night_lerp, TINT_NIGHT_LERP_MIN, TINT_NIGHT_LERP_MAX,
	)
	settings.shadow_twilight_tint_white_lerp = clampf(
		settings.shadow_twilight_tint_white_lerp, TINT_WHITE_LERP_MIN, TINT_WHITE_LERP_MAX,
	)
	settings.shadow_strength_contrast_mult = clampf(
		settings.shadow_strength_contrast_mult,
		STRENGTH_CONTRAST_MULT_MIN,
		STRENGTH_CONTRAST_MULT_MAX,
	)
	settings.shadow_preset_ramp_min = clampf(
		settings.shadow_preset_ramp_min, PRESET_RAMP_MIN_MIN, PRESET_RAMP_MIN_MAX,
	)
	_clamp_clock_windows(settings)
	settings.shadow_rebake_fast_ms = clampf(
		settings.shadow_rebake_fast_ms, REBAKE_FAST_MS_MIN, REBAKE_FAST_MS_MAX,
	)
	settings.shadow_rebake_slow_ms = clampf(
		settings.shadow_rebake_slow_ms, REBAKE_SLOW_MS_MIN, REBAKE_SLOW_MS_MAX,
	)
	settings.shadow_throttle_ramp_end = clampf(
		settings.shadow_throttle_ramp_end, THROTTLE_RAMP_END_MIN, THROTTLE_RAMP_END_MAX,
	)
	settings.shadow_perf_rebake_fast_ms = clampf(
		settings.shadow_perf_rebake_fast_ms, REBAKE_FAST_MS_MIN, REBAKE_FAST_MS_MAX,
	)
	settings.shadow_perf_rebake_slow_ms = clampf(
		settings.shadow_perf_rebake_slow_ms, REBAKE_SLOW_MS_MIN, REBAKE_SLOW_MS_MAX,
	)
	settings.shadow_perf_throttle_ramp_end = clampf(
		settings.shadow_perf_throttle_ramp_end, THROTTLE_RAMP_END_MIN, THROTTLE_RAMP_END_MAX,
	)
	settings.shadow_perf_max_axis_low = clampf(
		settings.shadow_perf_max_axis_low, PERF_MAX_AXIS_LOW_MIN, PERF_MAX_AXIS_LOW_MAX,
	)
	settings.shadow_perf_max_cot_low = clampf(
		settings.shadow_perf_max_cot_low, PERF_MAX_COT_LOW_MIN, PERF_MAX_COT_LOW_MAX,
	)
	settings.shadow_perf_raster_stride_low = clampf(
		settings.shadow_perf_raster_stride_low,
		PERF_RASTER_STRIDE_LOW_MIN,
		PERF_RASTER_STRIDE_LOW_MAX,
	)
	settings.shadow_perf_caster_downscale_low = clampf(
		settings.shadow_perf_caster_downscale_low,
		PERF_DOWNSCALE_LOW_MIN,
		PERF_DOWNSCALE_LOW_MAX,
	)
	settings.shadow_perf_tier_threshold = clampf(
		settings.shadow_perf_tier_threshold,
		PERF_TIER_THRESHOLD_MIN,
		PERF_TIER_THRESHOLD_MAX,
	)
	settings.shadow_perf_tier_ease = clampf(
		settings.shadow_perf_tier_ease, PERF_TIER_EASE_MIN, PERF_TIER_EASE_MAX,
	)
	settings.shadow_arc_half_span_deg = clampf(
		settings.shadow_arc_half_span_deg, ARC_HALF_SPAN_MIN, ARC_HALF_SPAN_MAX,
	)
	settings.shadow_noon_height_ratio = clampf(
		settings.shadow_noon_height_ratio, NOON_HEIGHT_RATIO_MIN, NOON_HEIGHT_RATIO_MAX,
	)


static func _clamp_clock_windows(settings: EffectsSettings) -> void:
	settings.shadow_night_to_dusk_start_min = clampf(
		settings.shadow_night_to_dusk_start_min, CLOCK_WINDOW_MIN, CLOCK_WINDOW_MAX,
	)
	settings.shadow_dusk_to_day_start_min = clampf(
		settings.shadow_dusk_to_day_start_min,
		settings.shadow_night_to_dusk_start_min + 30.0,
		CLOCK_WINDOW_MAX,
	)
	settings.shadow_day_to_dusk_start_min = clampf(
		settings.shadow_day_to_dusk_start_min,
		settings.shadow_dusk_to_day_start_min + 30.0,
		CLOCK_WINDOW_MAX,
	)
	settings.shadow_dusk_to_night_start_min = clampf(
		settings.shadow_dusk_to_night_start_min,
		settings.shadow_day_to_dusk_start_min + 30.0,
		CLOCK_WINDOW_MAX,
	)


static func apply_to_weather_bus(settings: EffectsSettings) -> void:
	if settings == null:
		WeatherBus.reset_shadow_tuning()
		return
	clamp_all(settings)
	WeatherBus.apply_shadow_tuning(settings)


static func load_scalar(cfg: ConfigFile, key: String, fallback: float) -> float:
	return float(cfg.get_value("effects", key, fallback))


static func dusk_to_day_end_min(settings: EffectsSettings) -> float:
	return settings.shadow_dusk_to_day_start_min + settings.shadow_preset_ramp_min


static func day_to_dusk_end_min(settings: EffectsSettings) -> float:
	return settings.shadow_day_to_dusk_start_min + settings.shadow_preset_ramp_min


static func dusk_to_night_end_min(settings: EffectsSettings) -> float:
	return settings.shadow_dusk_to_night_start_min + settings.shadow_preset_ramp_min


static func geometry_gate(settings: EffectsSettings = null) -> float:
	if settings == null:
		return WeatherBus.tune_geometry_gate
	return settings.shadow_geometry_gate


static func actor_appearance_gate(settings: EffectsSettings = null) -> float:
	if settings == null:
		return ACTOR_APPEARANCE_GATE_DEFAULT
	return settings.shadow_actor_appearance_gate


static func throttle_ramp_end(settings: EffectsSettings, perf_mode: bool) -> float:
	if perf_mode:
		return settings.shadow_perf_throttle_ramp_end
	return settings.shadow_throttle_ramp_end


static func rebake_fast_ms(settings: EffectsSettings, perf_mode: bool) -> int:
	if perf_mode:
		return int(settings.shadow_perf_rebake_fast_ms)
	return int(settings.shadow_rebake_fast_ms)


static func rebake_slow_ms(settings: EffectsSettings, perf_mode: bool) -> int:
	if perf_mode:
		return int(settings.shadow_perf_rebake_slow_ms)
	return int(settings.shadow_rebake_slow_ms)


static func live_readout(settings: EffectsSettings = null) -> String:
	var m_f: float = WeatherBus.clock_minutes_float()
	var presence: float = WeatherBus.shadow_presence_factor(m_f)
	var contrast: float = WeatherBus.shadow_contrast_factor(m_f)
	var vis: float = presence * contrast
	var gate: float = geometry_gate(settings)
	var actor_gate: float = actor_appearance_gate(settings)
	var blocked: bool = vis < gate
	var el_deg: float = rad_to_deg(WeatherBus.solar_elevation_rad_f(m_f))
	var phase: float = WeatherBus.time_phase()
	var window: String = WeatherBus.clock_preset_window_label(m_f)
	return (
		"Clock %s · window %s · phase %.2f · elev %.1f° · presence %.2f · contrast %.2f · vis %.3f · map gate %.3f · actor gate %.3f · geom %s"
		% [
			format_clock_minutes(m_f),
			window,
			phase,
			el_deg,
			presence,
			contrast,
			vis,
			gate,
			actor_gate,
			"blocked" if blocked else "rebake",
		]
	)


static func format_clock_minutes(m_f: float) -> String:
	var total: int = int(m_f) % (24 * 60)
	var h: int = total / 60
	var m: int = total % 60
	var suffix: String = "AM" if h < 12 else "PM"
	var h12: int = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


static func format_slider_value(spec: Dictionary, value: float) -> String:
	var fmt: String = str(spec.get("fmt", "%.2f"))
	if fmt == "clock":
		return format_clock_minutes(value)
	return fmt % value


static func panel_slider_specs() -> Array[Dictionary]:
	return [
		{"kind": "section", "text": "Solar fade (map + player)"},
		{
			"kind": "slider",
			"key": "shadow_twilight_fade_deg",
			"label": "Twilight fade band (° elev) (higher=longer dawn/dusk fade)",
			"min": TWILIGHT_FADE_DEG_MIN,
			"max": TWILIGHT_FADE_DEG_MAX,
			"step": 1.0,
			"fmt": "%.0f°",
		},
		{
			"kind": "slider",
			"key": "shadow_contrast_ease",
			"label": "Contrast / presence exponent (higher=slower at horizon)",
			"min": CONTRAST_EASE_MIN,
			"max": CONTRAST_EASE_MAX,
			"step": 0.05,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_full_contrast_below_noon_deg",
			"label": "Full contrast below noon (°) (higher=full strength at lower sun)",
			"min": FULL_CONTRAST_BELOW_NOON_MIN,
			"max": FULL_CONTRAST_BELOW_NOON_MAX,
			"step": 1.0,
			"fmt": "%.0f°",
		},
		{
			"kind": "slider",
			"key": "shadow_atmosphere_presence_power",
			"label": "Atmosphere night pull (higher=stays darker at low sun)",
			"min": ATMOSPHERE_PRESENCE_POWER_MIN,
			"max": ATMOSPHERE_PRESENCE_POWER_MAX,
			"step": 0.05,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_geometry_gate",
			"label": "Map rebake gate (higher=later map rebakes)",
			"min": GEOMETRY_GATE_MIN,
			"max": GEOMETRY_GATE_MAX,
			"step": 0.01,
			"fmt": "%.3f",
		},
		{
			"kind": "slider",
			"key": "shadow_actor_appearance_gate",
			"label": "Player shadow appear gate (higher=later player shadow)",
			"min": ACTOR_APPEARANCE_GATE_MIN,
			"max": ACTOR_APPEARANCE_GATE_MAX,
			"step": 0.005,
			"fmt": "%.3f",
		},
		{
			"kind": "slider",
			"key": "shadow_twilight_tint_night_lerp",
			"label": "Twilight tint → night match (higher=more night-colored shadows)",
			"min": TINT_NIGHT_LERP_MIN,
			"max": TINT_NIGHT_LERP_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_twilight_tint_white_lerp",
			"label": "Twilight tint → white wash (higher=shadows fade out faster)",
			"min": TINT_WHITE_LERP_MIN,
			"max": TINT_WHITE_LERP_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_strength_contrast_mult",
			"label": "Shadow strength × contrast (higher=darker at same sun)",
			"min": STRENGTH_CONTRAST_MULT_MIN,
			"max": STRENGTH_CONTRAST_MULT_MAX,
			"step": 0.05,
			"fmt": "%.2f×",
		},
		{"kind": "section", "text": "Clock atmosphere (map brightness tint — not shadows)"},
		{
			"kind": "slider",
			"key": "shadow_preset_ramp_min",
			"label": "Preset ramp duration (higher=slower color transitions)",
			"min": PRESET_RAMP_MIN_MIN,
			"max": PRESET_RAMP_MIN_MAX,
			"step": 15.0,
			"fmt": "%.0f min",
		},
		{
			"kind": "slider",
			"key": "shadow_night_to_dusk_start_min",
			"label": "Night → dawn twilight start (later=starts later in morning)",
			"min": CLOCK_WINDOW_MIN,
			"max": CLOCK_WINDOW_MAX,
			"step": 15.0,
			"fmt": "clock",
		},
		{
			"kind": "slider",
			"key": "shadow_dusk_to_day_start_min",
			"label": "Dawn → day start (later=when morning reaches full daylight)",
			"min": CLOCK_WINDOW_MIN,
			"max": CLOCK_WINDOW_MAX,
			"step": 15.0,
			"fmt": "clock",
		},
		{
			"kind": "slider",
			"key": "shadow_day_to_dusk_start_min",
			"label": "Day → dusk start (later=afternoon dim starts later)",
			"min": CLOCK_WINDOW_MIN,
			"max": CLOCK_WINDOW_MAX,
			"step": 15.0,
			"fmt": "clock",
		},
		{
			"kind": "slider",
			"key": "shadow_dusk_to_night_start_min",
			"label": "Dusk → night start (later=evening fade starts later)",
			"min": CLOCK_WINDOW_MIN,
			"max": CLOCK_WINDOW_MAX,
			"step": 15.0,
			"fmt": "clock",
		},
		{"kind": "section", "text": "Rebake timing (map; player follows map)"},
		{
			"kind": "slider",
			"key": "shadow_rebake_fast_ms",
			"label": "Quality rebake fast (higher=fewer rebakes, less CPU)",
			"min": REBAKE_FAST_MS_MIN,
			"max": REBAKE_FAST_MS_MAX,
			"step": 50.0,
			"fmt": "%.0f ms",
		},
		{
			"kind": "slider",
			"key": "shadow_rebake_slow_ms",
			"label": "Quality rebake slow (higher=longer twilight rebake delay)",
			"min": REBAKE_SLOW_MS_MIN,
			"max": REBAKE_SLOW_MS_MAX,
			"step": 50.0,
			"fmt": "%.0f ms",
		},
		{
			"kind": "slider",
			"key": "shadow_throttle_ramp_end",
			"label": "Quality throttle ramp end (higher=full speed at higher visibility)",
			"min": THROTTLE_RAMP_END_MIN,
			"max": THROTTLE_RAMP_END_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_rebake_fast_ms",
			"label": "Perf rebake fast (higher=fewer rebakes, less CPU)",
			"min": REBAKE_FAST_MS_MIN,
			"max": REBAKE_FAST_MS_MAX,
			"step": 50.0,
			"fmt": "%.0f ms",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_rebake_slow_ms",
			"label": "Perf rebake slow (higher=longer twilight rebake delay)",
			"min": REBAKE_SLOW_MS_MIN,
			"max": REBAKE_SLOW_MS_MAX,
			"step": 50.0,
			"fmt": "%.0f ms",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_throttle_ramp_end",
			"label": "Perf throttle ramp end (higher=full speed at higher visibility)",
			"min": THROTTLE_RAMP_END_MIN,
			"max": THROTTLE_RAMP_END_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
		{"kind": "section", "text": "Perf bake quality (low contrast)"},
		{
			"kind": "slider",
			"key": "shadow_perf_max_axis_low",
			"label": "Perf max atlas axis (higher=sharper shadows, more VRAM)",
			"min": PERF_MAX_AXIS_LOW_MIN,
			"max": PERF_MAX_AXIS_LOW_MAX,
			"step": 32.0,
			"fmt": "%.0f px",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_max_cot_low",
			"label": "Perf max cot (higher=longer shadows at low sun)",
			"min": PERF_MAX_COT_LOW_MIN,
			"max": PERF_MAX_COT_LOW_MAX,
			"step": 0.1,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_raster_stride_low",
			"label": "Perf raster stride (higher=chunkier/faster bakes)",
			"min": PERF_RASTER_STRIDE_LOW_MIN,
			"max": PERF_RASTER_STRIDE_LOW_MAX,
			"step": 1.0,
			"fmt": "%.0f",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_caster_downscale_low",
			"label": "Perf caster downscale (higher=more blur, faster bakes)",
			"min": PERF_DOWNSCALE_LOW_MIN,
			"max": PERF_DOWNSCALE_LOW_MAX,
			"step": 1.0,
			"fmt": "%.0f×",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_tier_threshold",
			"label": "Perf full-quality contrast (higher=low-quality mode longer)",
			"min": PERF_TIER_THRESHOLD_MIN,
			"max": PERF_TIER_THRESHOLD_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
		{
			"kind": "slider",
			"key": "shadow_perf_tier_ease",
			"label": "Perf tier blend ease (higher=snappier quality ramp-up)",
			"min": PERF_TIER_EASE_MIN,
			"max": PERF_TIER_EASE_MAX,
			"step": 0.05,
			"fmt": "%.2f",
		},
		{"kind": "section", "text": "Sun arc / length"},
		{
			"kind": "slider",
			"key": "shadow_arc_half_span_deg",
			"label": "Shadow arc half-span (higher=wider E↔W shadow sweep)",
			"min": ARC_HALF_SPAN_MIN,
			"max": ARC_HALF_SPAN_MAX,
			"step": 1.0,
			"fmt": "%.0f°",
		},
		{
			"kind": "slider",
			"key": "shadow_noon_height_ratio",
			"label": "Noon shadow height floor (higher=shorter midday shadows)",
			"min": NOON_HEIGHT_RATIO_MIN,
			"max": NOON_HEIGHT_RATIO_MAX,
			"step": 0.02,
			"fmt": "%.2f",
		},
	]


static func apply_defaults(settings: EffectsSettings) -> void:
	if settings == null:
		return
	settings.shadow_twilight_fade_deg = TWILIGHT_FADE_DEG_DEFAULT
	settings.shadow_contrast_ease = CONTRAST_EASE_DEFAULT
	settings.shadow_full_contrast_below_noon_deg = FULL_CONTRAST_BELOW_NOON_DEFAULT
	settings.shadow_atmosphere_presence_power = ATMOSPHERE_PRESENCE_POWER_DEFAULT
	settings.shadow_geometry_gate = GEOMETRY_GATE_DEFAULT
	settings.shadow_actor_appearance_gate = ACTOR_APPEARANCE_GATE_DEFAULT
	settings.shadow_twilight_tint_night_lerp = TINT_NIGHT_LERP_DEFAULT
	settings.shadow_twilight_tint_white_lerp = TINT_WHITE_LERP_DEFAULT
	settings.shadow_strength_contrast_mult = STRENGTH_CONTRAST_MULT_DEFAULT
	settings.shadow_preset_ramp_min = PRESET_RAMP_MIN_DEFAULT
	settings.shadow_night_to_dusk_start_min = NIGHT_TO_DUSK_START_DEFAULT
	settings.shadow_dusk_to_day_start_min = DUSK_TO_DAY_START_DEFAULT
	settings.shadow_day_to_dusk_start_min = DAY_TO_DUSK_START_DEFAULT
	settings.shadow_dusk_to_night_start_min = DUSK_TO_NIGHT_START_DEFAULT
	settings.shadow_rebake_fast_ms = REBAKE_FAST_MS_DEFAULT
	settings.shadow_rebake_slow_ms = REBAKE_SLOW_MS_DEFAULT
	settings.shadow_throttle_ramp_end = THROTTLE_RAMP_END_DEFAULT
	settings.shadow_perf_rebake_fast_ms = PERF_REBAKE_FAST_MS_DEFAULT
	settings.shadow_perf_rebake_slow_ms = PERF_REBAKE_SLOW_MS_DEFAULT
	settings.shadow_perf_throttle_ramp_end = PERF_THROTTLE_RAMP_END_DEFAULT
	settings.shadow_perf_max_axis_low = PERF_MAX_AXIS_LOW_DEFAULT
	settings.shadow_perf_max_cot_low = PERF_MAX_COT_LOW_DEFAULT
	settings.shadow_perf_raster_stride_low = PERF_RASTER_STRIDE_LOW_DEFAULT
	settings.shadow_perf_caster_downscale_low = PERF_DOWNSCALE_LOW_DEFAULT
	settings.shadow_perf_tier_threshold = PERF_TIER_THRESHOLD_DEFAULT
	settings.shadow_perf_tier_ease = PERF_TIER_EASE_DEFAULT
	settings.shadow_arc_half_span_deg = ARC_HALF_SPAN_DEFAULT
	settings.shadow_noon_height_ratio = NOON_HEIGHT_RATIO_DEFAULT
	settings.shadow_perf_mode = false
	settings.shadow_hybrid_twilight_lod = true
	settings.shadow_edge_soften = false
	settings.shadow_disable_caster_punch = true
	clamp_all(settings)

