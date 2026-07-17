class_name CharacterActor
extends Node2D

## Layered LPC walk/idle preview — reuses sprite nodes; shares cached SpriteFrames.

const _C = preload("res://scripts/lpc/lpc_constants.gd")
const _ContactShadow = preload("res://scripts/lpc/character_contact_shadow.gd")
const HURT_ANIM: StringName = &"hurt_down"
const HURT_SPEED_SCALE: float = 1.6

const META_ITEM_ID: StringName = &"lpc_item_id"

var _layers: Array[AnimatedSprite2D] = []
var _pool: Array[AnimatedSprite2D] = []
var _facing: StringName = &"walk_down"
var _walking: bool = false
var _contact_shadow: CharacterContactShadow
var _one_shot_generation: int = 0
var _hurt_tween: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	_contact_shadow = _ContactShadow.new()
	_contact_shadow.name = "ContactShadow"
	add_child(_contact_shadow)
	move_child(_contact_shadow, 0)


func clear_layers() -> void:
	for spr: AnimatedSprite2D in _layers:
		spr.stop()
		spr.sprite_frames = null
		spr.material = null
		spr.z_index = 0
		spr.visible = false
		_pool.append(spr)
	_layers.clear()
	if _contact_shadow != null:
		_contact_shadow.rebuild_silhouette([], &"walk_down")


func add_layer(
	frames: SpriteFrames,
	z_pos: int = 0,
	recolor_kind: String = "none",
	recolor: String = "",
	palette_base: String = "",
	view_plane: String = "unified",
	item_id: String = "",
	slot_name: String = "",
) -> void:
	var spr: AnimatedSprite2D
	if _pool.is_empty():
		spr = _make_sprite()
		add_child(spr)
	else:
		spr = _pool.pop_back()
	
	# Godot 2D draws in tree index order.
	# We must move the sprite to the end of the children array so it draws on top of previous layers.
	move_child(spr, -1)
		
	spr.set_meta(CharacterComposer.META_VIEW_PLANE, view_plane)
	spr.set_meta(META_ITEM_ID, item_id)
	spr.set_meta("lpc_slot", slot_name)
	spr.set_meta("user_hidden", false)
	spr.z_index = 0
	spr.z_as_relative = true
	spr.visible = true
	spr.sprite_frames = frames
	_apply_recolor_material(spr, recolor_kind, recolor, palette_base)
	_apply_motion_state(spr)
	_layers.append(spr)
	move_child(spr, -1)


## Show or hide all sprite layers that belong to a given item_id.
func set_item_visibility(item_id: String, visible: bool) -> void:
	for spr: AnimatedSprite2D in _layers:
		if str(spr.get_meta(META_ITEM_ID, "")) == item_id:
			spr.set_meta("user_hidden", not visible)
			spr.visible = visible


func rebuild_contact_shadow(settings: EffectsSettings = null) -> void:
	_rebuild_contact_shadow_silhouette()
	sync_contact_shadow(settings)


func sync_contact_shadow(settings: EffectsSettings = null) -> void:
	if _contact_shadow != null:
		_contact_shadow.sync(settings)


func _rebuild_contact_shadow_silhouette() -> void:
	if _contact_shadow == null:
		return
	var anim: StringName = _facing if _walking else _idle_for(_facing)
	_contact_shadow.rebuild_silhouette(_layers, anim)


func set_facing(anim: StringName) -> void:
	_facing = anim
	if _one_shot_generation > 0:
		return
	for spr: AnimatedSprite2D in _layers:
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func set_walking(moving: bool) -> void:
	if _walking == moving:
		return
	_walking = moving
	if _one_shot_generation > 0:
		return
	for spr: AnimatedSprite2D in _layers:
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func play_hurt(facing_anim: StringName) -> void:
	_facing = facing_anim
	_walking = false
	_one_shot_generation += 1
	var generation: int = _one_shot_generation
	var duration: float = 0.35
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null:
			continue
		LpcSheetFrames.ensure_animation(spr.sprite_frames, HURT_ANIM)
		if not spr.sprite_frames.has_animation(HURT_ANIM):
			continue
		spr.sprite_frames.set_animation_loop(HURT_ANIM, false)
		spr.animation = HURT_ANIM
		spr.speed_scale = HURT_SPEED_SCALE
		spr.frame = 0
		spr.play()
		var fps: float = spr.sprite_frames.get_animation_speed(HURT_ANIM) * HURT_SPEED_SCALE
		var frame_count: int = spr.sprite_frames.get_frame_count(HURT_ANIM)
		if fps > 0.0:
			duration = maxf(duration, float(frame_count) / fps)
	_flash_layers_red()
	get_tree().create_timer(duration).timeout.connect(
		_finish_hurt.bind(generation),
		CONNECT_ONE_SHOT,
	)


func _flash_layers_red() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_hurt_tween = create_tween().set_parallel(true)
	for spr: AnimatedSprite2D in _layers:
		spr.self_modulate = Color(1.0, 0.18, 0.18, 1.0)
		_hurt_tween.tween_property(spr, "self_modulate", Color.WHITE, 0.2)


func _finish_hurt(generation: int) -> void:
	if generation != _one_shot_generation:
		return
	_one_shot_generation = 0
	for spr: AnimatedSprite2D in _layers:
		spr.speed_scale = 1.0
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func set_display_scale(scale_factor: float) -> void:
	scale = Vector2(scale_factor, scale_factor)


func update_tree_depth_sort(
	grid: PlayerGrid,
	trees: TileMapLayer,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
) -> void:
	TreeGameplay.apply_character_depth(self, grid, trees, overlay, settings)


func get_layer_count() -> int:
	return _layers.size()


## Apply a CharacterRecipe using CharacterComposer.
## Returns the report dictionary from CharacterComposer.apply.
func apply_recipe(recipe: CharacterRecipe) -> Dictionary:
	return CharacterComposer.apply(self, recipe)


func _make_sprite() -> AnimatedSprite2D:
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	# LPC sprites are 64x64, feet are 26px below center. Shift up by 26 so the actor's origin is exactly the feet.
	spr.position.y = -26.0
	return spr


func _apply_recolor_material(
	spr: AnimatedSprite2D,
	recolor_kind: String,
	recolor: String,
	palette_base: String = "",
) -> void:
	if not LpcPaletteStore.palettes_available():
		spr.material = null
		return
	spr.material = LpcPaletteStore.get_recolor_material(recolor_kind, recolor, palette_base)


func _apply_motion_state(spr: AnimatedSprite2D) -> void:
	if spr.sprite_frames == null:
		return
	var anim: StringName = _facing if _walking else _idle_for(_facing)
	
	LpcSheetFrames.ensure_animation(spr.sprite_frames, anim)
	
	if not spr.sprite_frames.has_animation(anim):
		anim = _facing
		LpcSheetFrames.ensure_animation(spr.sprite_frames, anim)
		
	if not spr.sprite_frames.has_animation(anim):
		var base_action = LpcConstants.get_base_action(anim)
		if LpcConstants.ACTIONS.has(base_action) and LpcConstants.ACTIONS[base_action][2].size() == 1:
			anim = StringName(base_action + "_" + LpcConstants.ACTIONS[base_action][2][0])
			LpcSheetFrames.ensure_animation(spr.sprite_frames, anim)
			
	var slot_name = spr.get_meta("lpc_slot", "")
	var is_held_item = slot_name in [
		"weapon", "weapon_magic_crystal", "shield", "shield_paint", "shield_pattern", "shield_trim"
	]
			
	if not spr.sprite_frames.has_animation(anim) and not is_held_item:
		var fb = LpcSheetFrames.get_fallback_animation(spr.sprite_frames, anim)
		if fb != &"":
			anim = fb
			
	if not spr.sprite_frames.has_animation(anim):
		spr.visible = false
		return
		
	if not spr.get_meta("user_hidden", false):
		spr.visible = true
		
	spr.animation = anim
	if _walking or anim.begins_with("idle_"):
		spr.play()
	else:
		spr.stop()
		spr.frame = 0



static func _idle_for(action_anim: StringName) -> StringName:
	var parts = str(action_anim).split("_")
	if parts.size() > 1:
		return StringName("idle_" + parts[1])
	return &"idle_down"
