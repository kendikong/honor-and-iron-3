class_name WaterSparkleSprites
extends Node2D

const _Frames = preload("res://scripts/water_sparkle_frames.gd")

## Animated sparkle VFX â€” Mana Seed 3-frame loops (not static TileMap cells).

const TILE_PX: int = 16

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func sync(placer: WaterVfxPlacer, foam_on: bool, sparkles_on: bool, map_seed: int, variant: int = 1) -> void:
	_rng.seed = map_seed + 7711
	for child: Node in get_children():
		child.queue_free()
	if placer == null or (not foam_on and not sparkles_on):
		return
	var frames: SpriteFrames = _Frames.get_frames(variant)
	if frames == null:
		return
	if foam_on:
		for pos: Vector2i in placer.foam_cells:
			_spawn_sprite(pos, _Frames.anim_for_atlas(placer.foam_atlas_at(pos)), frames)
	if sparkles_on:
		for pos: Vector2i in placer.sparkle_cells:
			_spawn_sprite(pos, &"full", frames)


func _spawn_sprite(cell: Vector2i, anim: StringName, frames: SpriteFrames) -> void:
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.animation = anim
	spr.frame = _rng.randi_range(0, 2)
	spr.speed_scale = _rng.randf_range(0.88, 1.12)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(cell) * float(TILE_PX)
	spr.play(anim)
	add_child(spr)
