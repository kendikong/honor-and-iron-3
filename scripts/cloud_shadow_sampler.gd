class_name CloudShadowSampler
extends RefCounted

## CPU mirror of `shaders/cloud_shadow.gdshader` for actors drawn above SkyOverlay.

const TILE_PX: float = 16.0
const FIELD_TILE_SPAN: float = TILE_PX * 32.0
const MASK_CUTOFF: float = 0.01

const _ROT: Transform2D = Transform2D(
	Vector2(0.8, 0.6),
	Vector2(-0.6, 0.8),
	Vector2.ZERO,
)


static func environment_stamp() -> int:
	var d: Vector2 = WeatherBus.cloud_drift_offset
	return hash(Vector2i(int(floor(d.x * 2048.0)), int(floor(d.y * 2048.0))))


static func sample_mask_at_map_px(map_px: Vector2) -> float:
	var map_local: Vector2 = Vector2(floor(map_px.x), floor(map_px.y))
	return _shadow_mask(_field_at_pixel(map_local, WeatherBus.cloud_drift_offset))


static func modulate_from_mask(mask: float, settings: EffectsSettings = null) -> Color:
	if mask < MASK_CUTOFF:
		return Color.WHITE
	var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
	var tint: Color = params.get("shadow_tint", Color(0.74, 0.72, 0.80, 1.0))
	var strength: float = float(params.get("shadow_strength", 1.0))
	var shade: float = strength * mask
	return Color(
		lerpf(1.0, tint.r, shade),
		lerpf(1.0, tint.g, shade),
		lerpf(1.0, tint.b, shade),
		1.0,
	)


static func _field_at_pixel(map_local: Vector2, drift_time: Vector2) -> float:
	var p: Vector2 = map_local / FIELD_TILE_SPAN
	var uv: Vector2 = Vector2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time
	return _blob_field(uv)


static func _blob_field(p: Vector2) -> float:
	var a: float = _fbm(p)
	var b: float = _fbm(p * 1.73 + Vector2(4.7, 2.1))
	return a * 0.62 + b * 0.38


static func _fbm(p: Vector2) -> float:
	var v: float = 0.0
	var a: float = 0.5
	var pt: Vector2 = p
	for _i: int in range(4):
		v += _value_noise(pt) * a
		pt = _ROT * (pt * 2.05)
		a *= 0.5
	return v


static func _value_noise(p: Vector2) -> float:
	var i: Vector2 = Vector2(floor(p.x), floor(p.y))
	var f: Vector2 = Vector2(p.x - i.x, p.y - i.y)
	var u: Vector2 = Vector2(
		f.x * f.x * (3.0 - 2.0 * f.x),
		f.y * f.y * (3.0 - 2.0 * f.y),
	)
	var n00: float = _hash22(i + Vector2(0.0, 0.0)).dot(f - Vector2(0.0, 0.0))
	var n10: float = _hash22(i + Vector2(1.0, 0.0)).dot(f - Vector2(1.0, 0.0))
	var n01: float = _hash22(i + Vector2(0.0, 1.0)).dot(f - Vector2(0.0, 1.0))
	var n11: float = _hash22(i + Vector2(1.0, 1.0)).dot(f - Vector2(1.0, 1.0))
	return lerpf(lerpf(n00, n10, u.x), lerpf(n01, n11, u.x), u.y) + 0.5


static func _hash22(p: Vector2) -> Vector2:
	var dotted: Vector2 = Vector2(
		p.x * 127.1 + p.y * 311.7,
		p.x * 269.5 + p.y * 183.3,
	)
	return Vector2(-1.0, -1.0) + 2.0 * Vector2(
		_fract(sin(dotted.x) * 43758.5453123),
		_fract(sin(dotted.y) * 43758.5453123),
	)


static func _shadow_mask(field: float) -> float:
	var s: float = smoothstep(0.58, 0.60, field)
	return round(s * 8.0) / 8.0


static func _fract(x: float) -> float:
	return x - floor(x)
