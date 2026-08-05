class_name BirdFlyoverActor
extends Node2D

## Rare bird crossing â€” drift archetype with wing flap.

const TILE_PX: int = 16

var _sprite: AnimatedSprite2D
var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0


func setup(map_size_px: Vector2, seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = EcologyActorArt.bird_frames()
	_sprite.animation = &"flap"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.speed_scale = rng.randf_range(0.92, 1.12)
	add_child(_sprite)
	var from_left: bool = rng.randf() < 0.5
	_sprite.scale.x = 1.0 if from_left else -1.0
	var y: float = float(roundi(rng.randf_range(map_size_px.y * 0.15, map_size_px.y * 0.55)))
	position = Vector2(-8.0 if from_left else map_size_px.x + 8.0, y)
	var speed: float = rng.randf_range(28.0, 44.0)
	_velocity = Vector2(speed if from_left else -speed, rng.randf_range(-2.0, 2.0))
	_lifetime = map_size_px.x / speed + 1.2
	_sprite.play()
	set_process(true)


func _process(delta: float) -> void:
	_lifetime -= delta
	position += Vector2(roundi(_velocity.x * delta), roundi(_velocity.y * delta))
	if _lifetime <= 0.0:
		queue_free()
