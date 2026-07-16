class_name ShadowDebug
extends RefCounted

## Shadow sun + length follow Time & light by default.
## Debug toggles opt into extra channels or isolate tint when time_light is off.

const DAY_PHASE: float = 1.0

static var _frozen_phase: float = DAY_PHASE
static var _frozen_sun: Vector2 = Vector2(0.06, 0.998)
static var _frozen_clock_min: float = 12.0 * 60.0 + 30.0
static var _freeze_snapshotted: bool = false


static func follows_sun_angle(settings: EffectsSettings) -> bool:
	if settings == null:
		return false
	if settings.shadow_freeze_time:
		return false
	return settings.shadow_cycle_sun_angle or settings.time_light


static func follows_length(settings: EffectsSettings) -> bool:
	if settings == null:
		return false
	return settings.shadow_cycle_length or settings.time_light


static func any_time_cycle(settings: EffectsSettings) -> bool:
	if settings == null:
		return false
	return (
		follows_sun_angle(settings)
		or follows_length(settings)
		or settings.shadow_cycle_tint_strength
	)


static func sundial_clock_minutes(settings: EffectsSettings) -> float:
	if settings != null and settings.shadow_freeze_time:
		return float(_frozen_clock_min)
	return -1.0


static func sundial_clock_min(settings: EffectsSettings) -> int:
	var m: float = sundial_clock_minutes(settings)
	if m < 0.0:
		return -1
	return int(m)


static func runtime_length_ratio(settings: EffectsSettings = null) -> float:
	if settings == null or not follows_length(settings):
		return 1.0
	if settings.shadow_freeze_time:
		return WeatherBus.shadow_length_runtime_ratio_at_clock_f(_frozen_clock_min)
	return WeatherBus.shadow_length_runtime_ratio()


static func time_phase(settings: EffectsSettings = null) -> float:
	if settings != null and settings.shadow_freeze_time:
		return _frozen_phase
	if settings == null or not (settings.shadow_cycle_tint_strength or settings.time_light):
		return DAY_PHASE
	return float(WeatherBus.atmosphere_uniforms().get("time_phase", DAY_PHASE))


static func multiply_tint(settings: EffectsSettings = null) -> Color:
	return ShadowPalette.multiply_tint(time_phase(settings))


static func shadow_strength(settings: EffectsSettings = null) -> float:
	return ShadowPalette.shadow_strength(time_phase(settings))


static func tree_nudge(settings: EffectsSettings, default_nudge: Vector2) -> Vector2:
	if settings != null and settings.shadow_disable_tree_nudge:
		return Vector2.ZERO
	return default_nudge


static func sync_weather_bus(settings: EffectsSettings) -> void:
	if settings == null:
		WeatherBus.clear_shadow_sun_override()
		WeatherBus.shadow_lock_sun_angle = true
		ShadowTuning.apply_to_weather_bus(null)
		_freeze_snapshotted = false
		return

	ShadowTuning.apply_to_weather_bus(settings)

	if settings.shadow_freeze_time:
		if not _freeze_snapshotted:
			_frozen_phase = float(
				WeatherBus.atmosphere_uniforms().get("time_phase", DAY_PHASE),
			)
			_frozen_sun = WeatherBus.sun_light_dir()
			_frozen_clock_min = WeatherBus.clock_minutes_float()
			_freeze_snapshotted = true
		WeatherBus.set_shadow_sun_override(_frozen_sun)
		WeatherBus.shadow_lock_sun_angle = false
	else:
		_freeze_snapshotted = false
		WeatherBus.clear_shadow_sun_override()
		var track_sun: bool = settings.shadow_cycle_sun_angle or settings.time_light
		WeatherBus.shadow_lock_sun_angle = not track_sun
