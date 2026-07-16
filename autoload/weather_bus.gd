extends Node

## Sky / atmosphere composition — time-of-day tint, mist, humidity, ripple multiplier.
## Phase 4 WindBus coupling deferred; drift vectors are internal until wind re-enabled.

signal state_changed

enum TimePreset { DAWN, DAY, DUSK, NIGHT }

const PRESET_COLORS: Dictionary = {
	TimePreset.DAWN: Color(1.08, 0.94, 0.86),
	TimePreset.DAY: Color(1.0, 1.0, 1.0),
	TimePreset.DUSK: Color(0.78, 0.74, 0.92),
	TimePreset.NIGHT: Color(0.58, 0.64, 0.86),
}

const PRESET_ORDER: Array[TimePreset] = [
	TimePreset.DAWN, TimePreset.DAY, TimePreset.DUSK, TimePreset.NIGHT,
]

const PRESET_LABELS: PackedStringArray = ["Dawn", "Day", "Dusk", "Night"]

const CLOUD_DRIFT_DIRS: Array[Vector2] = [
	Vector2(0.962872, 0.269604),
	Vector2(0.890053, 0.455445),
	Vector2(-0.945632, 0.325147),
]

## Normalized direction from the sun toward the ground (+x east, +y south/down).
## Legacy preset dirs — debug lock only; runtime uses LA solar model below.
const SUN_LIGHT_DIRS: Array[Vector2] = [
	Vector2(0.97, 0.24),
	Vector2(0.06, 0.998),
	Vector2(-0.97, 0.24),
	Vector2(-0.12, -0.93),
]

## Los Angeles (~34°N) sundial model — azimuth + elevation from clock time.
const LA_LATITUDE_DEG: float = 34.05
const LA_DECLINATION_DEG: float = 14.0
const SOLAR_NOON_CLOCK_MIN: int = 12 * 60 + 30
const HORIZON_EPSILON_RAD: float = 0.0087
## Elevation band (above horizon) where shadows become visible / hide.
const TWILIGHT_FADE_ELEVATION_DEG: float = 40.0
const TWILIGHT_FADE_ELEVATION_RAD: float = deg_to_rad(TWILIGHT_FADE_ELEVATION_DEG)
## Game-clock minutes for evening dusk→night and mirrored morning night→dawn ramps.
const TWILIGHT_PRESET_RAMP_MIN: float = 450.0
const NIGHT_TO_DUSK_START_MIN: float = 180.0    # 3:00 AM
const DUSK_TO_DAY_START_MIN: float = 420.0      # 7:00 AM
const DUSK_TO_DAY_END_MIN: float = 870.0        # 7:00 AM + 450 min
const DAY_TO_DUSK_START_MIN: float = 840.0      # 2:00 PM
const DAY_TO_DUSK_END_MIN: float = 1290.0       # 2:00 PM + 450 min
const DUSK_TO_NIGHT_START_MIN: float = 1080.0   # 6:00 PM
const DUSK_TO_NIGHT_END_MIN: float = 1530.0     # 6:00 PM + 450 min
## >1 keeps CanvasModulate nearer night longer at low sun (symmetric dawn/dusk).
const ATMOSPHERE_PRESENCE_POWER: float = 1.45
## Full shadow contrast only when sun is within this many degrees of solar-noon elevation.
const SHADOW_FULL_CONTRAST_BELOW_NOON_DEG: float = 22.0
## < 1.0 = dimmer longer at dawn/dusk before reaching peak daytime contrast.
const SHADOW_CONTRAST_EASE_POWER: float = 1.25
## Summer-narrow shadow arc: compress solar west-east sweep toward NW-NE (±60° from north).
const SHADOW_ARC_HALF_SPAN_DEG: float = 60.0
## Peak midday: floor cot so contact shadow reach ≈ this × caster height (slightly under 1:1).
const NOON_SHADOW_HEIGHT_RATIO: float = 1.0

## Shadow / atmosphere tuning — defaults match legacy consts; overridden by EffectsSettings.
var tune_twilight_fade_deg: float = TWILIGHT_FADE_ELEVATION_DEG
var tune_preset_ramp_min: float = TWILIGHT_PRESET_RAMP_MIN
var tune_night_to_dusk_start_min: float = NIGHT_TO_DUSK_START_MIN
var tune_dusk_to_day_start_min: float = DUSK_TO_DAY_START_MIN
var tune_day_to_dusk_start_min: float = DAY_TO_DUSK_START_MIN
var tune_dusk_to_night_start_min: float = DUSK_TO_NIGHT_START_MIN
var tune_atmosphere_presence_power: float = ATMOSPHERE_PRESENCE_POWER
var tune_shadow_contrast_ease: float = SHADOW_CONTRAST_EASE_POWER
var tune_full_contrast_below_noon_deg: float = SHADOW_FULL_CONTRAST_BELOW_NOON_DEG
var tune_arc_half_span_deg: float = SHADOW_ARC_HALF_SPAN_DEG
var tune_noon_height_ratio: float = NOON_SHADOW_HEIGHT_RATIO
var tune_geometry_gate: float = 0.01
var tune_twilight_tint_night_lerp: float = 0.42
var tune_twilight_tint_white_lerp: float = 0.26
var tune_strength_contrast_mult: float = 1.0
var tune_perf_max_axis_low: float = 1536.0
var tune_perf_max_cot_low: float = 6.0
var tune_perf_raster_stride_low: float = 2.0
var tune_perf_caster_downscale_low: float = 6.0
var tune_perf_tier_threshold: float = 0.85
var tune_perf_tier_ease: float = 0.55

var time_preset: TimePreset = TimePreset.DAY
var mist_density: float = 0.12
var humidity: float = 0.0
var ripple_multiplier: float = 1.0
var ruin_ratio: float = 0.0
var cloud_drift_dir: Vector2 = CLOUD_DRIFT_DIRS[0]
var cloud_drift_offset: Vector2 = Vector2.ZERO

var _biome_modulate: Color = Color.WHITE
var _biome_mist_floor: float = 0.06

## Discrete clock — 5 min steps while sun is up, 10 min at night (same real sec/tick → longer day).
var _cycle_offset_minutes: float = 360.0
var _clock_step_accum: float = 0.0
var _preset_blend: float = 0.0
var _preset_index: int = 1
var _drift_index: int = 0
var _drift_target: Vector2 = CLOUD_DRIFT_DIRS[0]
var _drift_hold: float = 24.0
var _emit_accum: float = 0.0
var _last_emit_signature: int = -1

## Shadow debug — sun lock/override for oblique bakes only (world clock keeps running).
var shadow_lock_sun_angle: bool = false
var _shadow_sun_override: Vector2 = Vector2.ZERO
var _shadow_sun_override_active: bool = false

const STATE_EMIT_INTERVAL_SEC: float = 0.1
const CLOUD_DRIFT_SPEED: float = 0.034
const CLOUD_DRIFT_DIR_BLEND: float = 0.08
## Real seconds for one full 24h loop on the HUD clock.
const CYCLE_DURATION_SEC: float = 96.0
const CLOCK_START_MINUTES: int = 5 * 60 + 30
const CLOCK_STEP_MINUTES_NIGHT: int = 10
const CLOCK_STEP_MINUTES_DAY: int = 5
## Real seconds per tick — unchanged from legacy 10-min uniform day (96s / 144 steps).
const CLOCK_STEP_INTERVAL_SEC: float = CYCLE_DURATION_SEC / 144.0
## Skip-night button target — 5:00 AM (just before dawn preset at 6:00).
const DAWN_SKIP_CLOCK_MIN: int = 5 * 60
## Skip-to-dusk button target — 4:00 PM (start of evening dusk→night ramp).
const DUSK_SKIP_CLOCK_MIN: int = 16 * 60


func _ready() -> void:
	_rng_init()


func _rng_init() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_drift_hold = rng.randf_range(20.0, 32.0)


func _process(delta: float) -> void:
	_advance_time_preset(delta)
	_advance_cloud_drift(delta)
	cloud_drift_offset += cloud_drift_dir.normalized() * delta * CLOUD_DRIFT_SPEED
	_recompute_mist()
	_emit_accum += delta
	if _emit_accum < STATE_EMIT_INTERVAL_SEC:
		return
	_emit_accum = 0.0
	var signature: int = _atmosphere_signature()
	if signature == _last_emit_signature:
		return
	_last_emit_signature = signature
	state_changed.emit()


func _atmosphere_signature() -> int:
	return hash([
		int(floor(_cycle_offset_minutes)),
		_preset_index,
		_drift_index,
		int(round(mist_density * 40.0)),
		int(round(humidity * 20.0)),
		int(round(ruin_ratio * 20.0)),
	])


func set_map_humidity(water_ratio: float, ruin_cells: int, total_cells: int) -> void:
	humidity = clampf(water_ratio, 0.0, 1.0)
	if total_cells > 0:
		ruin_ratio = clampf(float(ruin_cells) / float(total_cells), 0.0, 1.0)
	else:
		ruin_ratio = 0.0
	ripple_multiplier = lerpf(1.0, 1.45, humidity)


func apply_biome_profile(profile: BiomeProfile) -> void:
	if profile == null:
		_biome_modulate = Color.WHITE
		_biome_mist_floor = 0.06
	else:
		_biome_modulate = profile.modulate_tint
		_biome_mist_floor = profile.mist_density_floor
	_last_emit_signature = -1
	state_changed.emit()


func apply_shadow_tuning(settings: EffectsSettings) -> void:
	tune_twilight_fade_deg = settings.shadow_twilight_fade_deg
	tune_preset_ramp_min = settings.shadow_preset_ramp_min
	tune_night_to_dusk_start_min = settings.shadow_night_to_dusk_start_min
	tune_dusk_to_day_start_min = settings.shadow_dusk_to_day_start_min
	tune_day_to_dusk_start_min = settings.shadow_day_to_dusk_start_min
	tune_dusk_to_night_start_min = settings.shadow_dusk_to_night_start_min
	tune_atmosphere_presence_power = settings.shadow_atmosphere_presence_power
	tune_shadow_contrast_ease = settings.shadow_contrast_ease
	tune_full_contrast_below_noon_deg = settings.shadow_full_contrast_below_noon_deg
	tune_arc_half_span_deg = settings.shadow_arc_half_span_deg
	tune_noon_height_ratio = settings.shadow_noon_height_ratio
	tune_geometry_gate = settings.shadow_geometry_gate
	tune_twilight_tint_night_lerp = settings.shadow_twilight_tint_night_lerp
	tune_twilight_tint_white_lerp = settings.shadow_twilight_tint_white_lerp
	tune_strength_contrast_mult = settings.shadow_strength_contrast_mult
	tune_perf_max_axis_low = settings.shadow_perf_max_axis_low
	tune_perf_max_cot_low = settings.shadow_perf_max_cot_low
	tune_perf_raster_stride_low = settings.shadow_perf_raster_stride_low
	tune_perf_caster_downscale_low = settings.shadow_perf_caster_downscale_low
	tune_perf_tier_threshold = settings.shadow_perf_tier_threshold
	tune_perf_tier_ease = settings.shadow_perf_tier_ease
	_sync_preset_from_time_phase()
	_last_emit_signature = -1
	state_changed.emit()


func reset_shadow_tuning() -> void:
	tune_twilight_fade_deg = TWILIGHT_FADE_ELEVATION_DEG
	tune_preset_ramp_min = TWILIGHT_PRESET_RAMP_MIN
	tune_night_to_dusk_start_min = NIGHT_TO_DUSK_START_MIN
	tune_dusk_to_day_start_min = DUSK_TO_DAY_START_MIN
	tune_day_to_dusk_start_min = DAY_TO_DUSK_START_MIN
	tune_dusk_to_night_start_min = DUSK_TO_NIGHT_START_MIN
	tune_atmosphere_presence_power = ATMOSPHERE_PRESENCE_POWER
	tune_shadow_contrast_ease = SHADOW_CONTRAST_EASE_POWER
	tune_full_contrast_below_noon_deg = SHADOW_FULL_CONTRAST_BELOW_NOON_DEG
	tune_arc_half_span_deg = SHADOW_ARC_HALF_SPAN_DEG
	tune_noon_height_ratio = NOON_SHADOW_HEIGHT_RATIO
	tune_geometry_gate = 0.01
	tune_twilight_tint_night_lerp = 0.42
	tune_twilight_tint_white_lerp = 0.26
	tune_strength_contrast_mult = 1.0
	tune_perf_max_axis_low = 1536.0
	tune_perf_max_cot_low = 6.0
	tune_perf_raster_stride_low = 2.0
	tune_perf_caster_downscale_low = 6.0
	tune_perf_tier_threshold = 0.85
	tune_perf_tier_ease = 0.55


func _tune_twilight_fade_rad() -> float:
	return deg_to_rad(tune_twilight_fade_deg)


func _tune_dusk_to_day_end_min() -> float:
	return tune_dusk_to_day_start_min + tune_preset_ramp_min


func _tune_day_to_dusk_end_min() -> float:
	return tune_day_to_dusk_start_min + tune_preset_ramp_min


func _tune_dusk_to_night_end_min() -> float:
	return tune_dusk_to_night_start_min + tune_preset_ramp_min


func canvas_modulate_color() -> Color:
	var phase: float = time_phase()
	var idx: int = clampi(int(floor(phase)), 0, PRESET_ORDER.size() - 1)
	var next_idx: int = mini(idx + 1, PRESET_ORDER.size() - 1)
	var blend: float = clampf(phase - float(idx), 0.0, 1.0)
	var current: Color = PRESET_COLORS[PRESET_ORDER[idx]]
	var next: Color = PRESET_COLORS[PRESET_ORDER[next_idx]]
	var base: Color = current.lerp(next, blend)
	var humid_tint: Color = Color(0.82, 0.86, 0.96)
	base = base.lerp(humid_tint, humidity * 0.32)
	return Color(
		base.r * _biome_modulate.r,
		base.g * _biome_modulate.g,
		base.b * _biome_modulate.b,
		base.a,
	)


func atmosphere_uniforms() -> Dictionary:
	return {
		"cloud_drift_dir": cloud_drift_dir,
		"cloud_drift_offset": cloud_drift_offset,
		"mist_density": mist_density,
		"humidity": humidity,
		"ruin_ratio": ruin_ratio,
		"time_phase": time_phase(),
		"sun_light_dir": sun_light_dir(),
	}


func time_phase() -> float:
	var m_f: float = clock_minutes_float()
	if solar_elevation_rad_f(m_f) <= HORIZON_EPSILON_RAD:
		return 3.0
	var presence: float = pow(shadow_presence_factor(m_f), tune_atmosphere_presence_power)
	var base: float = _time_phase_from_minutes_f(m_f)
	if presence >= 0.999:
		return base
	# Symmetric twilight: low sun presence pulls toward night (3) at dawn and dusk alike.
	return lerpf(3.0, base, presence)


func _time_phase_from_minutes_f(m_f: float) -> float:
	var dusk_day_end: float = _tune_dusk_to_day_end_min()
	var day_dusk_end: float = _tune_day_to_dusk_end_min()
	var dusk_night_end: float = _tune_dusk_to_night_end_min()
	if m_f >= tune_night_to_dusk_start_min and m_f < tune_dusk_to_day_start_min:
		var t_night_dusk: float = (m_f - tune_night_to_dusk_start_min) / tune_preset_ramp_min
		return lerpf(3.0, 2.0, t_night_dusk)
	if m_f >= tune_dusk_to_day_start_min and m_f < dusk_day_end:
		var t_dusk_day: float = (m_f - tune_dusk_to_day_start_min) / tune_preset_ramp_min
		return lerpf(2.0, 1.0, t_dusk_day)
	if m_f >= tune_day_to_dusk_start_min and m_f < day_dusk_end:
		var t_day_dusk: float = (m_f - tune_day_to_dusk_start_min) / (day_dusk_end - tune_day_to_dusk_start_min)
		return lerpf(1.0, 2.0, t_day_dusk)
	if m_f >= tune_dusk_to_night_start_min and m_f < dusk_night_end:
		var t_dusk_night: float = (m_f - tune_dusk_to_night_start_min) / tune_preset_ramp_min
		return lerpf(2.0, 3.0, t_dusk_night)
	# Hold full phases in gaps between ramps (avoid accidental night flash at noon).
	if m_f >= dusk_day_end and m_f < tune_day_to_dusk_start_min:
		return 1.0
	if m_f >= day_dusk_end and m_f < tune_dusk_to_night_start_min:
		return 2.0
	return 3.0


## HUD label for which clock-window ramp is driving time_phase right now.
func clock_preset_window_label(clock_min_f: float = -1.0) -> String:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var dusk_day_end: float = _tune_dusk_to_day_end_min()
	var day_dusk_end: float = _tune_day_to_dusk_end_min()
	var dusk_night_end: float = _tune_dusk_to_night_end_min()
	if clock_min_f >= tune_night_to_dusk_start_min and clock_min_f < tune_dusk_to_day_start_min:
		return "night→dawn twilight"
	if clock_min_f >= tune_dusk_to_day_start_min and clock_min_f < dusk_day_end:
		return "dawn→day (morning)"
	if clock_min_f >= tune_day_to_dusk_start_min and clock_min_f < day_dusk_end:
		return "day→dusk (afternoon)"
	if clock_min_f >= tune_dusk_to_night_start_min and clock_min_f < dusk_night_end:
		return "dusk→night (evening)"
	if clock_min_f >= dusk_day_end and clock_min_f < tune_day_to_dusk_start_min:
		return "day (hold)"
	if clock_min_f >= day_dusk_end and clock_min_f < tune_dusk_to_night_start_min:
		return "dusk (hold)"
	return "night (hold)"


func sun_arc_phase() -> float:
	return time_phase()


func _solar_hour_angle_rad(clock_min: int) -> float:
	return _solar_hour_angle_rad_f(float(clock_min))


func _solar_hour_angle_rad_f(clock_min_f: float) -> float:
	var hours_from_noon: float = (clock_min_f - float(SOLAR_NOON_CLOCK_MIN)) / 60.0
	return deg_to_rad(15.0 * hours_from_noon)


func solar_elevation_rad(clock_min: int = -1) -> float:
	if clock_min < 0:
		return solar_elevation_rad_f(-1.0)
	return solar_elevation_rad_f(float(clock_min))


func solar_elevation_rad_f(clock_min_f: float = -1.0) -> float:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var phi: float = deg_to_rad(LA_LATITUDE_DEG)
	var decl: float = deg_to_rad(LA_DECLINATION_DEG)
	var H: float = _solar_hour_angle_rad_f(clock_min_f)
	var sin_el: float = sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(H)
	return asin(clampf(sin_el, -1.0, 1.0))


func solar_azimuth_north_cw_rad(clock_min: int = -1) -> float:
	if clock_min < 0:
		return solar_azimuth_north_cw_rad_f(-1.0)
	return solar_azimuth_north_cw_rad_f(float(clock_min))


func solar_azimuth_north_cw_rad_f(clock_min_f: float = -1.0) -> float:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var phi: float = deg_to_rad(LA_LATITUDE_DEG)
	var decl: float = deg_to_rad(LA_DECLINATION_DEG)
	var H: float = _solar_hour_angle_rad_f(clock_min_f)
	var el: float = solar_elevation_rad_f(clock_min_f)
	if el <= HORIZON_EPSILON_RAD:
		return PI * 0.5
	var az: float = atan2(sin(H), cos(H) * sin(phi) - tan(decl) * cos(phi))
	return az + PI


func sun_above_horizon(clock_min: int = -1) -> bool:
	return solar_elevation_rad(clock_min) > HORIZON_EPSILON_RAD


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 0 at/below horizon, 1 in the twilight visibility band — gentle spawn / hide gate.
func shadow_presence_factor(clock_min_f: float = -1.0) -> float:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var el: float = solar_elevation_rad_f(clock_min_f)
	if el <= HORIZON_EPSILON_RAD:
		return 0.0
	var fade_top: float = HORIZON_EPSILON_RAD + _tune_twilight_fade_rad()
	if el >= fade_top:
		return 1.0
	var t: float = (el - HORIZON_EPSILON_RAD) / maxf(fade_top - HORIZON_EPSILON_RAD, 0.0001)
	return pow(_smoothstep(0.0, 1.0, t), tune_shadow_contrast_ease)


## 0 at horizon, 1 only near peak daytime elevation — drives contrast / strength / tint.
func shadow_contrast_factor(clock_min_f: float = -1.0) -> float:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var el: float = solar_elevation_rad_f(clock_min_f)
	if el <= HORIZON_EPSILON_RAD:
		return 0.0
	var noon_el: float = solar_elevation_rad_f(float(SOLAR_NOON_CLOCK_MIN))
	var full_el: float = maxf(
		HORIZON_EPSILON_RAD + _tune_twilight_fade_rad(),
		noon_el - deg_to_rad(tune_full_contrast_below_noon_deg),
	)
	if el >= full_el:
		return 1.0
	var t: float = (el - HORIZON_EPSILON_RAD) / maxf(full_el - HORIZON_EPSILON_RAD, 0.0001)
	return pow(_smoothstep(0.0, 1.0, t), tune_shadow_contrast_ease)


func shadows_visible() -> bool:
	return shadow_presence_factor() > 0.001


func sun_light_dir_from_clock(clock_min: int) -> Vector2:
	var el: float = solar_elevation_rad(clock_min)
	if el <= HORIZON_EPSILON_RAD:
		return Vector2.ZERO
	var az: float = solar_azimuth_north_cw_rad(clock_min)
	var sun_horiz: Vector2 = Vector2(sin(az), -cos(az))
	var horizon: float = 1.0 - sin(el)
	return Vector2(sun_horiz.x, maxf(0.1, horizon)).normalized()


func _clock_minutes_from_midnight() -> int:
	var hm: Vector2i = clock_hours_minutes()
	return hm.x * 60 + hm.y


func clock_minutes_from_midnight() -> int:
	return _clock_minutes_from_midnight()


## Continuous clock for shadows.
func clock_minutes_float() -> float:
	return fmod(float(CLOCK_START_MINUTES) + _cycle_offset_minutes, 24.0 * 60.0)


func seek_clock_minutes(clock_min: int) -> void:
	clock_min = ((clock_min % (24 * 60)) + (24 * 60)) % (24 * 60)
	_cycle_offset_minutes = fmod(
		float(clock_min - CLOCK_START_MINUTES + 24 * 60), float(24 * 60),
	)
	_clock_step_accum = 0.0
	_sync_preset_from_time_phase()
	_last_emit_signature = -1
	state_changed.emit()


func skip_night_to_dawn() -> void:
	seek_clock_minutes(DAWN_SKIP_CLOCK_MIN)


func skip_to_dusk() -> void:
	seek_clock_minutes(DUSK_SKIP_CLOCK_MIN)


func _sync_preset_from_time_phase() -> void:
	var phase: float = time_phase()
	_preset_index = clampi(int(floor(phase)), 0, PRESET_ORDER.size() - 1)
	_preset_blend = clampf(phase - float(_preset_index), 0.0, 1.0)
	time_preset = PRESET_ORDER[_preset_index]


func sun_light_dir() -> Vector2:
	return sun_light_dir_from_clock(_clock_minutes_from_midnight())


func sun_light_dir_at_phase(_phase: float) -> Vector2:
	return sun_light_dir_from_clock(SOLAR_NOON_CLOCK_MIN)


func shadow_sun_signature() -> int:
	return shadow_sundial_signature()


## Quantized sundial state for rebake triggers (~0.25° azimuth steps).
func shadow_sundial_signature() -> int:
	return shadow_rebake_signature(1.0)


## Coarser quantization at low contrast — dawn/dusk long shadows are expensive to rebake.
func shadow_rebake_signature(contrast: float = 1.0) -> int:
	var s: Dictionary = shadow_sundial()
	if not s.visible:
		return 0
	var c: float = clampf(contrast, 0.0, 1.0)
	# Twilight: tie rebakes to HUD clock steps — smooth cot/az spams full-map composites.
	if c < 0.75:
		var m_f: float = clock_minutes_float()
		var el_q: int = int(floor(rad_to_deg(solar_elevation_rad_f(m_f)) * 0.25))
		var pace_min: int = _clock_step_minutes_at(m_f)
		var step_bucket: int = int(floor(m_f / float(pace_min)))
		return step_bucket * 1000 + el_q
	var az_scale: float = lerpf(2.5, 4.0, c)
	var cot_scale: float = lerpf(12.0, 64.0, c)
	var az_q: int = int(round(rad_to_deg(float(s.az)) * az_scale))
	var cot_q: int = int(round(float(s.cot) * cot_scale))
	return az_q * 10000 + cot_q


func _noon_shadow_cot() -> float:
	var noon_el: float = solar_elevation_rad_f(float(SOLAR_NOON_CLOCK_MIN))
	return cos(noon_el) / maxf(sin(noon_el), 0.001)


## Shrink solar shadow sweep (west↔east) toward summer NW↔NE without changing spin direction.
func _narrow_shadow_dir(sun_az: float) -> Vector2:
	var sun_horiz: Vector2 = Vector2(sin(sun_az), -cos(sun_az))
	if sun_horiz.length_squared() < 0.0001:
		return Vector2.ZERO
	var natural: Vector2 = (-sun_horiz).normalized()
	var off: float = atan2(natural.x, -natural.y)
	var full_half: float = PI * 0.5
	var narrow_half: float = deg_to_rad(tune_arc_half_span_deg)
	var compressed: float = off * (narrow_half / full_half)
	return Vector2(sin(compressed), -cos(compressed))


## LA sundial — single source for shadow direction and length.
## Map +x east, +y south. Solar azimuth, narrowed arc (NW→N→NE vs full W→N→E).
## dir: unit ground cast; cot: cot(elevation); length_px = height_px * cot * mult.
func shadow_sundial(clock_min_f: float = -1.0) -> Dictionary:
	if shadow_lock_sun_angle and not _shadow_sun_override_active:
		clock_min_f = float(SOLAR_NOON_CLOCK_MIN)
	elif clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	var el: float = solar_elevation_rad_f(clock_min_f)
	if el <= HORIZON_EPSILON_RAD:
		return {"dir": Vector2.ZERO, "cot": 0.0, "az": 0.0, "visible": false}
	var sun_az: float = solar_azimuth_north_cw_rad_f(clock_min_f)
	var dir: Vector2 = _narrow_shadow_dir(sun_az)
	if dir.length_squared() < 0.0001:
		return {"dir": Vector2.ZERO, "cot": 0.0, "az": sun_az, "visible": false}
	dir = dir.normalized()
	var az: float = atan2(dir.x, -dir.y)
	var cot_el: float = cos(el) / maxf(sin(el), 0.001)
	cot_el = maxf(cot_el, tune_noon_height_ratio)
	return {"dir": dir, "cot": cot_el, "az": az, "visible": true}


func shadow_cast_pixels(height_px: float, clock_min_f: float = -1.0) -> Vector2:
	var s: Dictionary = shadow_sundial(clock_min_f)
	if not s.visible or height_px <= 0.5:
		return Vector2.ZERO
	var length: float = height_px * float(s.cot)
	var offset: Vector2 = (s.dir as Vector2) * length
	return Vector2(float(int(round(offset.x))), float(int(round(offset.y))))


func shadow_length_runtime_ratio() -> float:
	return shadow_length_runtime_ratio_at_clock_f(-1.0)


func shadow_length_runtime_ratio_at_clock(clock_min: int) -> float:
	return shadow_length_runtime_ratio_at_clock_f(float(clock_min))


func shadow_length_runtime_ratio_at_clock_f(clock_min_f: float) -> float:
	var s: Dictionary = shadow_sundial(clock_min_f)
	if not s.visible:
		return 0.0
	var noon: Dictionary = shadow_sundial(float(SOLAR_NOON_CLOCK_MIN))
	if noon.cot <= 0.001:
		return 1.0
	return maxf(1.0, float(s.cot) / float(noon.cot))


func shadow_cast_signature() -> int:
	var cast: Vector2 = shadow_cast_direction_pixels(2, 80)
	return int(cast.x) * 10000 + int(cast.y)


func shadow_phase_signature() -> int:
	return int(round(time_phase() * 64.0))


func shadow_sun_light_dir() -> Vector2:
	if _shadow_sun_override_active:
		return _shadow_sun_override
	if shadow_lock_sun_angle:
		return sun_light_dir_from_clock(SOLAR_NOON_CLOCK_MIN)
	return sun_light_dir()


func set_shadow_sun_override(dir: Vector2) -> void:
	_shadow_sun_override = dir.normalized()
	_shadow_sun_override_active = true


func clear_shadow_sun_override() -> void:
	_shadow_sun_override_active = false


func cycle_fraction() -> float:
	return fmod(_cycle_offset_minutes, float(24 * 60)) / float(24 * 60)


func clock_hours_minutes() -> Vector2i:
	var clock_minutes: int = int(floor(clock_minutes_float())) % (24 * 60)
	return Vector2i(clock_minutes / 60, clock_minutes % 60)


func clock_display_text() -> String:
	var hm: Vector2i = clock_hours_minutes()
	var hour24: int = hm.x
	var hour12: int = hour24 % 12
	if hour12 == 0:
		hour12 = 12
	var ampm: String = "AM" if hour24 < 12 else "PM"
	var label: String = _clock_preset_label(hm.x * 60 + hm.y)
	return "%d:%02d %s  %s" % [hour12, hm.y, ampm, label]


func _clock_preset_label(minutes: int) -> String:
	if not sun_above_horizon(minutes):
		return PRESET_LABELS[TimePreset.NIGHT]
	if minutes < int(DUSK_TO_DAY_END_MIN):
		return PRESET_LABELS[TimePreset.DAWN]
	if minutes < int(DAY_TO_DUSK_END_MIN):
		return PRESET_LABELS[TimePreset.DAY]
	return PRESET_LABELS[TimePreset.DUSK]


const SHADOW_DAY_PHASE: float = 1.0
const SHADOW_LENGTH_SHORT: float = 0.58
const SHADOW_LENGTH_LONG: float = 2.18


func shadow_length_multiplier_at_phase(_phase: float) -> float:
	return shadow_length_multiplier()


func shadow_length_multiplier() -> float:
	var m: int = _clock_minutes_from_midnight()
	var el: float = solar_elevation_rad(m)
	if el <= HORIZON_EPSILON_RAD:
		return 0.0
	var noon_el: float = solar_elevation_rad(SOLAR_NOON_CLOCK_MIN)
	var sin_e: float = maxf(sin(el), 0.04)
	var sin_noon: float = maxf(sin(noon_el), 0.04)
	var cot: float = cos(el) / sin_e
	var cot_noon: float = cos(noon_el) / sin_noon
	return clampf(cot / cot_noon, 1.0, SHADOW_LENGTH_LONG) * SHADOW_LENGTH_SHORT


func shadow_length_runtime_ratio_at_phase(_phase: float) -> float:
	return shadow_length_runtime_ratio_at_clock(SOLAR_NOON_CLOCK_MIN)


const SHADOW_TILE_PX: float = 16.0


func shadow_cast_direction_pixels(_z_height: int = 0, caster_height_px: int = 0) -> Vector2:
	var h: float = float(maxi(caster_height_px, int(SHADOW_TILE_PX)))
	return shadow_cast_pixels(h)


func shadow_cast_direction_pixels_at_phase(
	_phase: float,
	_z_height: int,
	caster_height_px: int = 0,
) -> Vector2:
	return shadow_cast_direction_pixels(_z_height, caster_height_px)


func shadow_cast_direction_pixels_for_sun(
	sun_dir: Vector2,
	_z_height: int,
	caster_height_px: int = 0,
) -> Vector2:
	var h: float = float(maxi(caster_height_px, int(SHADOW_TILE_PX)))
	return shadow_cast_pixels(h)


var time_speed_mult: float = 1.0
var fast_night: bool = true

func set_time_speed(speed: float) -> void:
	time_speed_mult = speed

func set_fast_night(fast: bool) -> void:
	fast_night = fast

func _advance_time_preset(delta: float) -> void:
	if time_speed_mult <= 0.0:
		return
	
	var current_mult: float = time_speed_mult
	if fast_night:
		var current_clock: float = fmod(float(CLOCK_START_MINUTES) + _cycle_offset_minutes, 24.0 * 60.0)
		if solar_elevation_rad_f(current_clock) <= HORIZON_EPSILON_RAD:
			current_mult *= 2.0
			
	var old_minute: int = int(floor(_cycle_offset_minutes))
	_cycle_offset_minutes = fmod(_cycle_offset_minutes + delta * current_mult, float(24 * 60))
	var new_minute: int = int(floor(_cycle_offset_minutes))
	if old_minute != new_minute:
		_sync_preset_from_time_phase()
		_last_emit_signature = -1
		state_changed.emit()


func clock_step_minutes_at(clock_min_f: float = -1.0) -> int:
	if clock_min_f < 0.0:
		clock_min_f = clock_minutes_float()
	return _clock_step_minutes_at(clock_min_f)


func _is_daytime_clock_pace(clock_min_f: float) -> bool:
	return solar_elevation_rad_f(clock_min_f) > HORIZON_EPSILON_RAD


func _clock_step_minutes_at(clock_min_f: float) -> int:
	if _is_daytime_clock_pace(clock_min_f):
		return CLOCK_STEP_MINUTES_DAY
	return CLOCK_STEP_MINUTES_NIGHT


func _advance_cloud_drift(delta: float) -> void:
	_drift_hold -= delta
	if _drift_hold <= 0.0:
		_drift_index = (_drift_index + 1) % CLOUD_DRIFT_DIRS.size()
		_drift_target = CLOUD_DRIFT_DIRS[_drift_index]
		_drift_hold = 24.0
	if not cloud_drift_dir.is_equal_approx(_drift_target):
		cloud_drift_dir = cloud_drift_dir.lerp(
			_drift_target, clampf(delta * CLOUD_DRIFT_DIR_BLEND, 0.0, 1.0)
		).normalized()


func _recompute_mist() -> void:
	mist_density = clampf(
		_biome_mist_floor + humidity * 0.28 + ruin_ratio * 0.22,
		0.0,
		0.58,
	)
