class_name ShadowDebug
extends RefCounted

## Shadow sun + length follow Time & light by default.
## Debug toggles opt into extra channels or isolate tint when time_light is off.

const DAY_PHASE: float = 1.0


static func follows_sun_angle(settings: EffectsSettings) -> bool:
	if settings == null:
		return false
	if settings.shadow_freeze_time:
		return false
	return settings.shadow_cycle_sun_angle or settings.time_light


static func follows_length(settings: EffectsSettings) -> bool:
	if settings == null:
		return false
	if settings.shadow_freeze_time:
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
		return WeatherBus.clock_minutes_float()
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
		return WeatherBus.shadow_length_runtime_ratio_at_clock_f(WeatherBus.clock_minutes_float())
	return WeatherBus.shadow_length_runtime_ratio()


static func time_phase(settings: EffectsSettings = null) -> float:
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
		WeatherBus.unfreeze_game_time()
		ShadowTuning.apply_to_weather_bus(null)
		return

	ShadowTuning.apply_to_weather_bus(settings)

	if settings.shadow_freeze_time:
		WeatherBus.freeze_game_time()
		WeatherBus.clear_shadow_sun_override()
		var track_sun: bool = settings.shadow_cycle_sun_angle or settings.time_light
		WeatherBus.shadow_lock_sun_angle = not track_sun
	else:
		WeatherBus.unfreeze_game_time()
		WeatherBus.clear_shadow_sun_override()
		var track_sun: bool = settings.shadow_cycle_sun_angle or settings.time_light
		WeatherBus.shadow_lock_sun_angle = not track_sun
