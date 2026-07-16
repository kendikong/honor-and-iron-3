class_name ShadowPalette
extends RefCounted

## 1D palette LUT for multiply silhouette shadows (bible §3 — no generic black blobs).

const _TINT_LUT: Array[Color] = [
	Color(0.76, 0.72, 0.78, 1.0), # dawn
	Color(0.74, 0.72, 0.80, 1.0), # day
	Color(0.72, 0.70, 0.78, 1.0), # dusk
	Color(0.78, 0.80, 0.90, 1.0), # night — visible multiply, not washed out
]

const _STRENGTH_LUT: Array[float] = [
	0.94, # dawn
	1.0,  # day
	0.94, # dusk
	0.78, # night — readable contact shadow
]


static func multiply_tint(time_phase: float) -> Color:
	var idx: int = clampi(int(floor(time_phase)), 0, _TINT_LUT.size() - 1)
	var next_idx: int = mini(idx + 1, _TINT_LUT.size() - 1)
	var blend: float = clampf(time_phase - float(idx), 0.0, 1.0)
	return _TINT_LUT[idx].lerp(_TINT_LUT[next_idx], blend)


static func shadow_strength(time_phase: float) -> float:
	var idx: int = clampi(int(floor(time_phase)), 0, _STRENGTH_LUT.size() - 1)
	var next_idx: int = mini(idx + 1, _STRENGTH_LUT.size() - 1)
	var blend: float = clampf(time_phase - float(idx), 0.0, 1.0)
	return lerpf(_STRENGTH_LUT[idx], _STRENGTH_LUT[next_idx], blend)


## Fade multiply shadow into night canvas modulate — shaded grass ≈ unshaded night grass.
static func twilight_multiply_tint(
	time_phase: float,
	contrast: float,
	canvas_mod: Color,
) -> Color:
	var base: Color = multiply_tint(time_phase)
	if contrast >= 0.999:
		return base
	var night: Color = WeatherBus.PRESET_COLORS[WeatherBus.TimePreset.NIGHT]
	var night_match: Color = Color(
		clampf(night.r / maxf(canvas_mod.r, 0.01), 0.0, 1.0),
		clampf(night.g / maxf(canvas_mod.g, 0.01), 0.0, 1.0),
		clampf(night.b / maxf(canvas_mod.b, 0.01), 0.0, 1.0),
		1.0,
	)
	var fade: float = 1.0 - contrast
	var twilight: Color = base.lerp(night_match, fade * WeatherBus.tune_twilight_tint_night_lerp)
	return twilight.lerp(Color.WHITE, fade * WeatherBus.tune_twilight_tint_white_lerp)


static func twilight_shadow_strength(time_phase: float, contrast: float) -> float:
	return shadow_strength(time_phase) * contrast * WeatherBus.tune_strength_contrast_mult


## Shared multiply uniforms for oblique contact + cloud shadow shaders.
static func multiply_shader_params(settings: EffectsSettings = null) -> Dictionary:
	var clock_f: float = ShadowDebug.sundial_clock_minutes(settings)
	var presence: float = (
		WeatherBus.shadow_presence_factor(clock_f)
		if clock_f >= 0.0
		else WeatherBus.shadow_presence_factor()
	)
	var contrast: float = (
		WeatherBus.shadow_contrast_factor(clock_f)
		if clock_f >= 0.0
		else WeatherBus.shadow_contrast_factor()
	)
	var phase: float = ShadowDebug.time_phase(settings)
	var canvas_mod: Color = WeatherBus.canvas_modulate_color()
	return {
		"shadow_tint": twilight_multiply_tint(phase, contrast, canvas_mod),
		"shadow_strength": twilight_shadow_strength(phase, contrast),
		"shadow_presence": presence,
		"shadow_contrast": contrast,
	}
