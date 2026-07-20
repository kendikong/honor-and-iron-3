class_name CharacterActor
extends Node2D

## Layered LPC walk/idle preview — reuses sprite nodes; shares cached SpriteFrames.

const _C = preload("res://scripts/lpc/lpc_constants.gd")
const _ContactShadow = preload("res://scripts/lpc/character_contact_shadow.gd")
const _SelectionGlow = preload("res://scripts/lpc/character_selection_glow.gd")
const HURT_ANIM: StringName = &"hurt_down"
const HURT_SPEED_SCALE: float = 1.6
const RUN_ANIM_SPEED_SCALE: float = 1.3
const DASH_RUN_ANIM_SPEED_SCALE: float = 2.2
const DEATH_GROUND_LINGER_SEC: float = 1.75
const DEATH_FADE_SEC: float = 0.4
const NUDGE_PULLBACK_PX: float = 7.0
const NUDGE_THRUST_PX: float = 20.0
const NUDGE_PULLBACK_HOLD_SEC: float = 0.16
const NUDGE_KNOCKBACK_PX: float = 13.0

const ACTION_HOLD_SANDBOX_SEC: float = 1.0
const ACTION_HOLD_COMBAT_SEC: float = 0.1
const ACTION_RECOVER_FRAMES: int = 3
const ACTION_RECOVER_SPEED_SCALE: float = 12.0

const _ONE_SHOT_MELEE: Array[StringName] = [
	&"slash", &"thrust", &"halfslash", &"backslash",
]
const _ONE_SHOT_RANGED: Array[StringName] = [
	&"shoot", &"spellcast",
]

const META_ITEM_ID: StringName = &"lpc_item_id"

var _layers: Array[AnimatedSprite2D] = []
var _pool: Array[AnimatedSprite2D] = []
var _facing: StringName = &"walk_down"
var _walking: bool = false
var _contact_shadow: CharacterContactShadow
var _selection_glow: CharacterSelectionGlow
var _one_shot_generation: int = 0
var _hurt_tween: Tween
var _combat_tween: Tween
var _anchor_position: Vector2 = Vector2.ZERO
var _is_dying: bool = false
var _running: bool = false
var _dash_running: bool = false
var _planning_exhausted: bool = false
var _spell_flash_active: bool = false
var _spell_flash_generation: int = 0
var _oblique_band_modulates: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
var _oblique_modulate_stamp: int = -1
var _oblique_cloud_stamp: int = -1
var _oblique_modulate_pos_px: Vector2i = Vector2i(999999, 999999)
## Per-layer self_modulate — parent modulate does not reach LPC recolor shader output reliably.
const _EXHAUSTED_LAYER_MODULATE := Color(0.28, 0.28, 0.32, 1.0)
const _EXHAUSTED_SHADOW_TINT := Color(0.40, 0.40, 0.44, 1.0)
const _SPELL_FLASH_COLOR := Color(3.2, 3.2, 3.2, 1.0)
const _LOWER_SHADOW_SLOTS: Dictionary = {
	"legs": true,
	"shoes": true,
	"shoes_toe": true,
	"socks": true,
}
const _UPPER_SHADOW_SLOTS: Dictionary = {
	"head": true,
	"hair": true,
	"hairextl": true,
	"hairextr": true,
	"ponytail": true,
	"updo": true,
	"hairtie": true,
	"hairtie_rune": true,
	"hat": true,
	"ears": true,
	"horns": true,
	"nose": true,
	"eyebrows": true,
	"eyes": true,
	"beard": true,
	"mustache": true,
}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	_contact_shadow = _ContactShadow.new()
	_contact_shadow.name = "ContactShadow"
	add_child(_contact_shadow)
	move_child(_contact_shadow, 0)
	_selection_glow = _SelectionGlow.new()
	_selection_glow.name = "SelectionGlow"
	add_child(_selection_glow)
	_selection_glow.bind_actor(self)


func get_sprite_layers() -> Array[AnimatedSprite2D]:
	return _layers


func set_selection_glow(
	active: bool,
	color: Color = Color(0.36, 0.62, 0.92, 0.95),
	strength: CharacterSelectionGlow.GlowStrength = CharacterSelectionGlow.GlowStrength.SELECTED,
) -> void:
	if _selection_glow == null:
		return
	_selection_glow.set_glow(active, color, strength)


func get_selection_glow() -> CharacterSelectionGlow:
	return _selection_glow


func clear_layers() -> void:
	for spr: AnimatedSprite2D in _layers:
		spr.stop()
		spr.sprite_frames = null
		spr.material = null
		spr.modulate = Color.WHITE
		spr.self_modulate = Color.WHITE
		spr.z_index = 0
		spr.visible = false
		_pool.append(spr)
	_layers.clear()
	_oblique_modulate_stamp = -1
	_oblique_modulate_pos_px = Vector2i(999999, 999999)
	_reset_oblique_band_modulates()
	if _selection_glow != null:
		_selection_glow.on_layers_cleared()
		if _selection_glow.is_active():
			_selection_glow.rebuild_from_layers()
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
		for child: Node in spr.get_children():
			child.queue_free()
	
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
	spr.modulate = Color.WHITE
	spr.self_modulate = Color.WHITE
	spr.sprite_frames = frames
	_apply_recolor_material(spr, recolor_kind, recolor, palette_base)
	_apply_motion_state(spr)
	_layers.append(spr)
	move_child(spr, -1)
	if _planning_exhausted:
		_apply_visual_tint()
	if _selection_glow != null and _selection_glow.is_active():
		_selection_glow.on_layer_added(spr)


## Show or hide all sprite layers that belong to a given item_id.
func set_item_visibility(item_id: String, visible: bool) -> void:
	for spr: AnimatedSprite2D in _layers:
		if str(spr.get_meta(META_ITEM_ID, "")) == item_id:
			spr.set_meta("user_hidden", not visible)
			spr.visible = visible


func rebuild_contact_shadow(settings: EffectsSettings = null) -> void:
	_rebuild_contact_shadow_silhouette()
	invalidate_environment_shadow_sync()
	sync_contact_shadow(settings)


func invalidate_environment_shadow_sync() -> void:
	_oblique_modulate_stamp = -1
	_oblique_cloud_stamp = -1
	_oblique_modulate_pos_px = Vector2i(999999, 999999)


func clear_oblique_modulate() -> void:
	_reset_oblique_band_modulates()
	invalidate_environment_shadow_sync()
	_apply_modulate_stack()


func get_contact_shadow_sprite() -> Sprite2D:
	if _contact_shadow == null:
		return null
	return _contact_shadow.get_shadow_sprite()


func force_environment_shadow_sync(settings: EffectsSettings = null) -> void:
	invalidate_environment_shadow_sync()
	sync_contact_shadow(settings)


func sync_contact_shadow(settings: EffectsSettings = null) -> void:
	if _contact_shadow != null:
		_contact_shadow.sync(settings)
	_sync_oblique_modulate(settings)


func _sync_oblique_modulate(settings: EffectsSettings = null) -> void:
	var want_env: bool = (
		settings != null
		and (settings.oblique_contact_shadows or settings.cloud_shadows)
	)
	if not want_env:
		_reset_oblique_band_modulates()
		_apply_modulate_stack()
		return
	var stamp: int = (
		ShadowPlacer.map_composite_apply_epoch() if settings.oblique_contact_shadows else 0
	)
	var cloud_stamp: int = (
		ShadowPlacer.cloud_drift_stamp(settings) if settings.cloud_shadows else 0
	)
	var pos_tile: Vector2i = Vector2i(
		int(floor(position.x / float(ShadowPlacer.TILE_PX))),
		int(floor(position.y / float(ShadowPlacer.TILE_PX))),
	)
	if (
		stamp == _oblique_modulate_stamp
		and cloud_stamp == _oblique_cloud_stamp
		and pos_tile == _oblique_modulate_pos_px
	):
		_apply_modulate_stack()
		return
	_oblique_modulate_stamp = stamp
	_oblique_cloud_stamp = cloud_stamp
	_oblique_modulate_pos_px = pos_tile
	_oblique_band_modulates = ShadowPlacer.actor_oblique_band_modulates(self, settings)
	_apply_modulate_stack()


func _reset_oblique_band_modulates() -> void:
	_oblique_band_modulates = [Color.WHITE, Color.WHITE, Color.WHITE]


func _shadow_band_index_for_slot(slot: String) -> int:
	if _LOWER_SHADOW_SLOTS.has(slot):
		return 0
	if _UPPER_SHADOW_SLOTS.has(slot):
		return 2
	if slot.begins_with("hair") or slot.begins_with("hat") or slot.begins_with("hairext"):
		return 2
	return 1


func _layer_self_modulate(spr: AnimatedSprite2D) -> Color:
	var slot: String = str(spr.get_meta("lpc_slot", ""))
	var band_i: int = clampi(_shadow_band_index_for_slot(slot), 0, 2)
	var shadow: Color = _oblique_band_modulates[band_i]
	if not _planning_exhausted:
		return shadow
	return Color(
		shadow.r * _EXHAUSTED_LAYER_MODULATE.r,
		shadow.g * _EXHAUSTED_LAYER_MODULATE.g,
		shadow.b * _EXHAUSTED_LAYER_MODULATE.b,
		1.0,
	)


func _apply_modulate_stack() -> void:
	modulate = Color.WHITE
	for spr: AnimatedSprite2D in _layers:
		spr.modulate = Color.WHITE
		if _spell_flash_active:
			spr.self_modulate = _SPELL_FLASH_COLOR
		else:
			spr.self_modulate = _layer_self_modulate(spr)


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


func set_running(running: bool) -> void:
	if _running == running and not _dash_running:
		return
	_running = running
	_dash_running = false
	if _one_shot_generation > 0:
		return
	for spr: AnimatedSprite2D in _layers:
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func set_dash_running(enabled: bool) -> void:
	_running = enabled
	_dash_running = enabled
	if _one_shot_generation > 0:
		return
	for spr: AnimatedSprite2D in _layers:
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()


func set_planning_exhausted(exhausted: bool) -> void:
	if _planning_exhausted == exhausted:
		return
	_planning_exhausted = exhausted
	_apply_visual_tint()


func _apply_visual_tint() -> void:
	_apply_modulate_stack()
	if _contact_shadow != null:
		_contact_shadow.modulate = _EXHAUSTED_SHADOW_TINT if _planning_exhausted else Color.WHITE
	if _selection_glow != null:
		_selection_glow.set_muted(_planning_exhausted)


func play_attack_thrust(world_dir: Vector2, attack_anim: StringName) -> void:
	_kill_combat_tween()
	_anchor_position = position
	var dir: Vector2 = world_dir.normalized() if world_dir.length_squared() > 0.01 else Vector2(0.0, 1.0)
	play_one_shot_action(attack_anim, ACTION_HOLD_COMBAT_SEC)
	var tw: Tween = create_tween()
	_combat_tween = tw
	tw.tween_property(
		self,
		"position",
		_anchor_position - dir * NUDGE_PULLBACK_PX,
		0.14,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(NUDGE_PULLBACK_HOLD_SEC)
	tw.tween_property(
		self,
		"position",
		_anchor_position + dir * NUDGE_THRUST_PX,
		0.06,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", _anchor_position, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_combat_tween = null
	)
func play_dash_windup(world_dir: Vector2, attack_anim: StringName) -> void:
	_kill_combat_tween()
	_anchor_position = position
	var dir: Vector2 = world_dir.normalized() if world_dir.length_squared() > 0.01 else Vector2(0.0, 1.0)
	set_facing(attack_anim)
	var tw: Tween = create_tween()
	_combat_tween = tw
	tw.tween_property(
		self,
		"position",
		_anchor_position - dir * NUDGE_PULLBACK_PX,
		0.12,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_combat_tween = null
	)


func play_one_shot_action(
	action_anim: StringName,
	hold_sec: float = ACTION_HOLD_SANDBOX_SEC,
	on_finished: Callable = Callable(),
) -> void:
	_kill_combat_tween()
	_walking = false
	_facing = action_anim
	_one_shot_generation += 1
	var generation: int = _one_shot_generation
	var strike_sec: float = _begin_one_shot_layers(action_anim)
	get_tree().create_timer(strike_sec).timeout.connect(
		func() -> void:
			if generation != _one_shot_generation:
				return
			_hold_one_shot_layers(action_anim)
			get_tree().create_timer(hold_sec).timeout.connect(
				func() -> void:
					if generation != _one_shot_generation:
						return
					_recover_one_shot_layers(action_anim, generation, on_finished),
				CONNECT_ONE_SHOT,
			),
		CONNECT_ONE_SHOT,
	)


func play_spellcast(cast_anim: StringName, on_release: Callable = Callable()) -> void:
	_kill_combat_tween()
	_walking = false
	_facing = cast_anim
	_one_shot_generation += 1
	var generation: int = _one_shot_generation
	_begin_one_shot_layers(cast_anim)
	var release_sec: float = _C.spellcast_release_delay_sec(cast_anim)
	var tail_start_sec: float = _C.spellcast_tail_start_sec()
	var finish_sec: float = _C.spellcast_playback_delay_sec()
	if on_release.is_valid():
		get_tree().create_timer(release_sec).timeout.connect(
			func() -> void:
				if generation != _one_shot_generation:
					return
				on_release.call(),
			CONNECT_ONE_SHOT,
		)
	get_tree().create_timer(tail_start_sec).timeout.connect(
		func() -> void:
			if generation != _one_shot_generation:
				return
			_set_one_shot_speed_scale(cast_anim, _C.SPELLCAST_TAIL_SPEED_SCALE),
		CONNECT_ONE_SHOT,
	)
	get_tree().create_timer(finish_sec).timeout.connect(
		func() -> void:
			if generation != _one_shot_generation:
				return
			_finish_one_shot_action(generation, Callable()),
		CONNECT_ONE_SHOT,
	)


func _set_one_shot_speed_scale(action_anim: StringName, speed_scale: float) -> void:
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(action_anim):
			continue
		spr.speed_scale = speed_scale


func flash_spell_hit(hold_sec: float) -> void:
	if _is_dying:
		return
	_spell_flash_generation += 1
	var generation: int = _spell_flash_generation
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_spell_flash_active = true
	for spr: AnimatedSprite2D in _layers:
		spr.self_modulate = _SPELL_FLASH_COLOR
	get_tree().create_timer(maxf(hold_sec, 0.01)).timeout.connect(
		func() -> void:
			_end_spell_flash(generation),
		CONNECT_ONE_SHOT,
	)


func is_spell_flash_active() -> bool:
	return _spell_flash_active


func _end_spell_flash(generation: int) -> void:
	if generation != _spell_flash_generation:
		return
	_spell_flash_active = false
	for spr: AnimatedSprite2D in _layers:
		spr.self_modulate = Color.WHITE
	_apply_modulate_stack()


func _begin_one_shot_layers(action_anim: StringName) -> float:
	var duration: float = 0.15
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null:
			continue
		LpcSheetFrames.ensure_animation(spr.sprite_frames, action_anim)
		if not spr.sprite_frames.has_animation(action_anim):
			continue
		spr.sprite_frames.set_animation_loop(action_anim, false)
		spr.speed_scale = 1.0
		spr.animation = action_anim
		spr.frame = 0
		spr.play()
		var fps: float = spr.sprite_frames.get_animation_speed(action_anim)
		var frame_count: int = spr.sprite_frames.get_frame_count(action_anim)
		if fps > 0.0:
			duration = maxf(duration, float(frame_count) / fps)
	_rebuild_contact_shadow_silhouette()
	return duration


func _hold_one_shot_layers(action_anim: StringName) -> void:
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(action_anim):
			continue
		var last_frame: int = spr.sprite_frames.get_frame_count(action_anim) - 1
		spr.stop()
		spr.frame = last_frame


func _recover_one_shot_layers(
	action_anim: StringName,
	generation: int,
	on_finished: Callable,
) -> void:
	var base_action: StringName = LpcConstants.get_base_action(action_anim)
	if base_action in _ONE_SHOT_MELEE:
		_start_reverse_tail(action_anim, ACTION_RECOVER_FRAMES, ACTION_RECOVER_SPEED_SCALE, generation, on_finished)
	else:
		_finish_one_shot_action(generation, on_finished)


func _start_reverse_tail(
	action_anim: StringName,
	frames_back: int,
	speed_scale: float,
	generation: int,
	on_finished: Callable,
) -> void:
	if frames_back <= 0:
		_finish_one_shot_action(generation, on_finished)
		return
	var step_sec: float = _reverse_tail_step_sec(action_anim, speed_scale)
	if step_sec <= 0.0:
		_finish_one_shot_action(generation, on_finished)
		return
	_reverse_tail_step(action_anim, frames_back, step_sec, generation, on_finished)


func _reverse_tail_step_sec(action_anim: StringName, speed_scale: float) -> float:
	var fps: float = 12.0
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(action_anim):
			continue
		fps = spr.sprite_frames.get_animation_speed(action_anim)
		break
	return 1.0 / maxf(fps * absf(speed_scale), 0.001)


func _reverse_tail_step(
	action_anim: StringName,
	remaining_steps: int,
	step_sec: float,
	generation: int,
	on_finished: Callable,
) -> void:
	if generation != _one_shot_generation:
		return
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames == null or not spr.sprite_frames.has_animation(action_anim):
			continue
		spr.stop()
		spr.speed_scale = 1.0
		spr.animation = action_anim
		spr.frame = maxi(0, spr.frame - 1)
	if remaining_steps <= 1:
		_finish_one_shot_action(generation, on_finished)
		return
	get_tree().create_timer(step_sec).timeout.connect(
		func() -> void:
			_reverse_tail_step(action_anim, remaining_steps - 1, step_sec, generation, on_finished),
		CONNECT_ONE_SHOT,
	)


func _finish_one_shot_action(generation: int, on_finished: Callable) -> void:
	if generation != _one_shot_generation:
		return
	_one_shot_generation = 0
	for spr: AnimatedSprite2D in _layers:
		if spr.sprite_frames != null:
			spr.speed_scale = 1.0
	_walking = false
	_facing = _idle_for(_facing)
	for spr: AnimatedSprite2D in _layers:
		_apply_motion_state(spr)
	_rebuild_contact_shadow_silhouette()
	if on_finished.is_valid():
		on_finished.call()


func play_hurt(facing_anim: StringName, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_dying or _spell_flash_active:
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


func cancel_combat_reaction() -> void:
	_kill_combat_tween()
	_one_shot_generation += 1


func finish_combat_reaction() -> void:
	_finish_hurt(_one_shot_generation)


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
	ShadowPlacer.invalidate_foot_cluster_layout()


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
	# Recolor is baked into sheet textures in LpcSheetFrames._load_nearest_texture.
	spr.material = null


func _apply_motion_state(spr: AnimatedSprite2D) -> void:
	if spr.sprite_frames == null:
		return
	var anim: StringName = _resolve_motion_anim(_facing if _walking else _idle_for(_facing))
	
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
	if _running and _walking:
		spr.speed_scale = DASH_RUN_ANIM_SPEED_SCALE if _dash_running else RUN_ANIM_SPEED_SCALE
	else:
		spr.speed_scale = 1.0
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


func _resolve_motion_anim(action_anim: StringName) -> StringName:
	var anim_name: String = str(action_anim)
	if _running and anim_name.begins_with("walk_"):
		return StringName("run_" + anim_name.substr(5))
	return action_anim
