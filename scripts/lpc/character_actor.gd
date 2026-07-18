class_name CharacterActor
extends Node2D

## Layered LPC walk/idle preview — reuses sprite nodes; shares cached SpriteFrames.

const _C = preload("res://scripts/lpc/lpc_constants.gd")
const _ContactShadow = preload("res://scripts/lpc/character_contact_shadow.gd")
const HURT_ANIM: StringName = &"hurt_down"
const HURT_SPEED_SCALE: float = 1.6
const DEATH_GROUND_LINGER_SEC: float = 1.75
const DEATH_FADE_SEC: float = 0.4
const NUDGE_PULLBACK_PX: float = 7.0
const NUDGE_THRUST_PX: float = 20.0
const NUDGE_PULLBACK_HOLD_SEC: float = 0.16
const NUDGE_KNOCKBACK_PX: float = 13.0

const META_ITEM_ID: StringName = &"lpc_item_id"

var _layers: Array[AnimatedSprite2D] = []
var _pool: Array[AnimatedSprite2D] = []
var _facing: StringName = &"walk_down"
var _walking: bool = false
var _contact_shadow: CharacterContactShadow
var _one_shot_generation: int = 0
var _hurt_tween: Tween
var _combat_tween: Tween
var _anchor_position: Vector2 = Vector2.ZERO
var _is_dying: bool = false


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


func play_attack_thrust(world_dir: Vector2, attack_anim: StringName) -> void:
	_kill_combat_tween()
	_anchor_position = position
	var dir: Vector2 = world_dir.normalized() if world_dir.length_squared() > 0.01 else Vector2(0.0, 1.0)
	var tw: Tween = create_tween()
	_combat_tween = tw
	tw.tween_property(
		self,
		"position",
		_anchor_position - dir * NUDGE_PULLBACK_PX,
		0.14,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		set_facing(attack_anim)
		set_walking(true)
	)
	tw.tween_interval(NUDGE_PULLBACK_HOLD_SEC)
	tw.tween_property(
		self,
		"position",
		_anchor_position + dir * NUDGE_THRUST_PX,
		0.06,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", _anchor_position, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		set_walking(false)
		_combat_tween = null
	)


func play_hurt(facing_anim: StringName, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_dying:
		return
	_begin_hurt(facing_anim, knockback_dir, false, Callable())


func play_death(
	facing_anim: StringName,
	knockback_dir: Vector2,
	on_finished: Callable,
) -> void:
	_is_dying = true
	_kill_combat_tween()
	_begin_hurt(facing_anim, knockback_dir, true, on_finished)


func snap_to_anchor(anchor: Vector2) -> void:
	_anchor_position = anchor
	if _combat_tween == null or not _combat_tween.is_valid():
		position = anchor


func is_dying() -> bool:
	return _is_dying


func _begin_hurt(
	facing_anim: StringName,
	knockback_dir: Vector2,
	is_death: bool,
	on_finished: Callable,
) -> void:
	_facing = facing_anim
	_walking = false
	_one_shot_generation += 1
	var generation: int = _one_shot_generation
	_anchor_position = position
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
	_flash_layers_red(is_death)
	if knockback_dir.length_squared() > 0.01:
		_apply_knockback_nudge(knockback_dir, duration, is_death)
	if is_death:
		get_tree().create_timer(duration).timeout.connect(
			_hold_death_pose.bind(generation, on_finished),
			CONNECT_ONE_SHOT,
		)
	else:
		get_tree().create_timer(duration).timeout.connect(
			_finish_hurt.bind(generation),
			CONNECT_ONE_SHOT,
		)


func _apply_knockback_nudge(knockback_dir: Vector2, hurt_duration: float, hold_on_ground: bool) -> void:
	_kill_combat_tween()
	var dir: Vector2 = knockback_dir.normalized()
	var pushed: Vector2 = _anchor_position + dir * NUDGE_KNOCKBACK_PX
	var tw: Tween = create_tween()
	_combat_tween = tw
	tw.tween_property(self, "position", pushed, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if hold_on_ground:
		tw.tween_property(self, "position", pushed, maxf(0.0, hurt_duration - 0.06))
	else:
		tw.tween_property(self, "position", _anchor_position, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			_combat_tween = null
		)


func _hold_death_pose(generation: int, on_finished: Callable) -> void:
	if generation != _one_shot_generation:
		return
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(HURT_ANIM):
			continue
		spr.stop()
		spr.frame = maxi(0, spr.sprite_frames.get_frame_count(HURT_ANIM) - 1)
	_rebuild_contact_shadow_silhouette()
	get_tree().create_timer(DEATH_GROUND_LINGER_SEC).timeout.connect(
		_fade_out_death.bind(generation, on_finished),
		CONNECT_ONE_SHOT,
	)


func _fade_out_death(generation: int, on_finished: Callable) -> void:
	if generation != _one_shot_generation:
		return
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	var tw: Tween = create_tween().set_parallel(true)
	for spr: AnimatedSprite2D in _layers:
		tw.tween_property(spr, "self_modulate:a", 0.0, DEATH_FADE_SEC)
	if _contact_shadow != null:
		tw.tween_property(_contact_shadow, "modulate:a", 0.0, DEATH_FADE_SEC)
	tw.finished.connect(func() -> void:
		if generation != _one_shot_generation:
			return
		_one_shot_generation = 0
		_is_dying = false
		if on_finished.is_valid():
			on_finished.call()
	, CONNECT_ONE_SHOT)


func _flash_layers_red(death: bool = false) -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_hurt_tween = create_tween().set_parallel(true)
	for spr: AnimatedSprite2D in _layers:
		spr.self_modulate = Color(1.55, 1.35, 1.35, 1.0)
		_hurt_tween.tween_property(spr, "self_modulate", Color(1.0, 0.04, 0.04, 1.0), 0.05)
		if death:
			_hurt_tween.tween_property(
				spr,
				"self_modulate",
				Color(0.72, 0.72, 0.76, 1.0),
				0.22,
			).set_delay(0.05)
		else:
			_hurt_tween.tween_property(spr, "self_modulate", Color.WHITE, 0.28).set_delay(0.05)


func _finish_hurt(generation: int) -> void:
	if generation != _one_shot_generation or _is_dying:
		return
	_one_shot_generation = 0
	position = _anchor_position
	for spr: AnimatedSprite2D in _layers:
		spr.speed_scale = 1.0
		spr.self_modulate = Color.WHITE
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func _kill_combat_tween() -> void:
	if _combat_tween != null and _combat_tween.is_valid():
		_combat_tween.kill()
	_combat_tween = null


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
