class_name GrassPetalPatch
extends Node2D

## Flat midtone base + synced Pixel Pete blades (shared frame + speed).


func setup(variant_idx: int, _seed: int = 0) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var bg: Sprite2D = Sprite2D.new()
	bg.texture = GrassPetalArt.base_fill_texture(variant_idx)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.centered = true
	bg.z_index = 0
	add_child(bg)

	var frames: SpriteFrames = GrassPetalArt.cluster_frames(variant_idx)
	var placements: Array[Vector2] = GrassPetalArt.cluster_placements(variant_idx)

	for i: int in range(placements.size()):
		var spr: AnimatedSprite2D = AnimatedSprite2D.new()
		spr.sprite_frames = frames
		spr.animation = &"sway"
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.position = _snap(placements[i])
		spr.speed_scale = 1.0
		spr.frame = 0
		spr.z_index = 1 + i
		spr.play()
		add_child(spr)


static func _snap(p: Vector2) -> Vector2:
	return Vector2(float(roundi(p.x)), float(roundi(p.y)))
