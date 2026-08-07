class_name SecondOrderSpring
extends RefCounted

## Translation-only second-order dynamics â€” integer pixel snap (bible Â§3 #8).

var frequency: float = 2.4
var damping: float = 0.72
var response: float = 0.0

var _pos: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO


func reset(initial: Vector2 = Vector2.ZERO) -> void:
	_pos = initial
	_vel = Vector2.ZERO
	_target = initial


func set_target(target: Vector2) -> void:
	_target = target


func step(delta: float) -> Vector2:
	var k1: float = maxf(frequency, 0.01)
	var k2: float = clampf(damping, 0.01, 2.0)
	var k3: float = clampf(response, 0.0, 2.0)
	var f: float = k1 * TAU
	var c: float = 2.0 * k2 * f
	var k: float = f * f
	var x: Vector2 = _pos - _target * k3
	var a: Vector2 = (_target * k - c * _vel - k * x) / maxf(k, 0.0001)
	_vel += a * delta
	_pos += _vel * delta
	return Vector2(roundi(_pos.x), roundi(_pos.y))


func position_snapped() -> Vector2i:
	return Vector2i(roundi(_pos.x), roundi(_pos.y))
