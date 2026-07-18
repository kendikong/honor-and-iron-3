class_name CloudShadowField
extends RefCounted

## CPU mirror of cloud_shadow_field.gdshaderinc — body receive samples the same mask.

const TILE_PX: float = 16.0
const ALPHA_CUTOFF: float = 0.04


static func shadow_mask_at(map_local: Vector2, drift: Vector2) -> float:
	var field: float = _field_at_pixel(map_local, drift)
	var s: float = smoothstep(0.58, 0.60, field)
	return snappedf(s * 8.0, 1.0 / 8.0)


static func shadow_strength_at(
	map_local: Vector2,
	drift: Vector2,
	cloud_strength: float,
) -> float:
	return shadow_mask_at(map_local, drift) * cloud_strength


static func _field_at_pixel(map_local: Vector2, drift_time: Vector2) -> float:
	var p: Vector2 = map_local / (TILE_PX * 32.0)
	var uv: Vector2 = Vector2(0.86 * p.x - 0.51 * p.y, 0.51 * p.x + 0.86 * p.y) + drift_time
	return _blob_field(uv)


static func _blob_field(p: Vector2) -> float:
	var a: float = _fbm(p)
	var b: float = _fbm(p * 1.73 + Vector2(4.7, 2.1))
	return a * 0.62 + b * 0.38


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
		fract(sin(a) * 43758.5453123),
		fract(sin(b) * 43758.5453123),
	)
