class_name CloudShadowField
extends RefCounted

## Fallback CPU mirror when GPU bake is not ready — prefer CloudShadowMaskBaker.

const TILE_PX: float = 16.0
const ALPHA_CUTOFF: float = 0.04


static func shadow_mask_at(
	map_local: Vector2,
	drift: Vector2,
	settings: EffectsSettings = null,
) -> float:
	var params: Dictionary = CloudTuning.shader_params(settings)
	var field: float = _field_at_pixel(map_local, drift, params)
	return _shadow_mask_from_field(field, params)


static func shadow_strength_at(
	map_local: Vector2,
	drift: Vector2,
	cloud_strength: float,
) -> float:
	return shadow_mask_at(map_local, drift) * cloud_strength


static func _field_at_pixel(
	map_local: Vector2,
	drift_time: Vector2,
	params: Dictionary,
) -> float:
	var px: Vector2 = Vector2(floor(map_local.x), floor(map_local.y))
	var scale_tiles: float = maxf(float(params.get("cloud_scale_tiles", 10.0)), 1.0)
	var p: Vector2 = px / (TILE_PX * scale_tiles)
	var uv: Vector2 = Vector2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time
	return _blob_field(uv, params)


static func _blob_field(p: Vector2, params: Dictionary) -> float:
	var mix_a: float = float(params.get("cloud_shape_mix", 0.50))
	var mix_b: float = 1.0 - mix_a
	var shape_scale: float = float(params.get("cloud_shape_scale", 1.20))
	var a: float = _fbm(p)
	var b: float = _fbm(p * shape_scale + Vector2(4.7, 2.1))
	return a * mix_a + b * mix_b


static func _shadow_mask_from_field(field: float, params: Dictionary) -> float:
	var lo: float = minf(
		float(params.get("cloud_mask_low", 0.505)),
		float(params.get("cloud_mask_high", 0.555)) - 0.001,
	)
	var hi: float = maxf(float(params.get("cloud_mask_high", 0.555)), lo + 0.001)
	var s: float = smoothstep(lo, hi, field)
	var steps: float = maxf(float(params.get("cloud_mask_steps", 10.0)), 1.0)
	return round(s * steps) / steps


static func _fbm(p: Vector2) -> float:
	var v: float = 0.0
	var a: float = 0.5
	var rot: Vector2 = Vector2(0.8, -0.6)
	var rot2: Vector2 = Vector2(0.6, 0.8)
	for _i: int in range(4):
		v += _value_noise(p) * a
		var nx: float = rot.x * p.x + rot2.x * p.y
		var ny: float = rot.y * p.x + rot2.y * p.y
		p = Vector2(nx, ny) * 2.05
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
	var a: float = p.dot(Vector2(127.1, 311.7))
	var b: float = p.dot(Vector2(269.5, 183.3))
	return Vector2(-1.0, -1.0) + 2.0 * Vector2(
		_fract(sin(a) * 43758.5453123),
		_fract(sin(b) * 43758.5453123),
	)


static func _fract(v: float) -> float:
	return v - floor(v)
