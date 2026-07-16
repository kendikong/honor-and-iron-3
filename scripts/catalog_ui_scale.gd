class_name CatalogUiScale
extends RefCounted

## Scales catalog / editor UI from a 1280×720 design baseline when the window grows.

const DESIGN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MIN_SCALE: float = 1.0
const MAX_SCALE: float = 4.0


static func factor(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return MIN_SCALE
	var sx: float = viewport_size.x / DESIGN_SIZE.x
	var sy: float = viewport_size.y / DESIGN_SIZE.y
	var raw: float = minf(sx, sy)
	# Quarter-step quantization — avoids rebuilding lists every pixel while dragging resize.
	var stepped: float = floor(raw * 4.0) / 4.0
	return clampf(stepped, MIN_SCALE, MAX_SCALE)


static func px(base: int, viewport_size: Vector2) -> int:
	return maxi(base, int(round(float(base) * factor(viewport_size))))


static func dim(base: float, viewport_size: Vector2) -> float:
	return maxf(base, base * factor(viewport_size))


static func font_size(base: int, viewport_size: Vector2) -> int:
	return maxi(base, int(round(float(base) * factor(viewport_size))))
