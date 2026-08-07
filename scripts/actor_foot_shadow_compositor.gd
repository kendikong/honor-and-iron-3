class_name ActorFootShadowCompositor
extends Node2D

## Parent for cluster-composited actor foot shadows (max-alpha, single multiply per cluster).

const _C = preload("res://scripts/mana_seed_constants.gd")


func _init() -> void:
	name = "ActorFootShadowCompositor"
	z_as_relative = false
	z_index = _C.Z_SHADOW + 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func clear_clusters() -> void:
	for child: Node in get_children():
		child.queue_free()
