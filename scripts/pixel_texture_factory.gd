class_name PixelTextureFactory
extends RefCounted

## Runtime 1â€“4 px SNES-style rigid particle / actor textures (nearest only).

static var _cache: Dictionary = {}


static func solid(size: int, color: Color) -> Texture2D:
	var key: String = "%d_%s" % [size, color.to_html(false)]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cx: int = size / 2
	var cy: int = size / 2
	for y: int in range(size):
		for x: int in range(size):
			if x == cx and y == cy:
				img.set_pixel(x, y, color)
			elif size >= 3 and absi(x - cx) + absi(y - cy) == 1:
				img.set_pixel(x, y, color.darkened(0.12))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func soft_glow(radius: int, color: Color) -> Texture2D:
	var key: String = "glow_%d_%s" % [radius, color.to_html(false)]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var size: int = radius * 2 + 1
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: float = float(radius)
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(float(x), float(y)).distance_to(Vector2(center, center)) / maxf(float(radius), 1.0)
			var falloff: float = clampf(1.0 - d, 0.0, 1.0)
			var alpha: float = color.a * falloff * falloff
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
