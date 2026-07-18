class_name CharacterSelectionGlow
extends Node

## Selection glow — toggles outline uniforms on existing LPC layer materials (no duplicate sprites).

const _SPRITE_SHADER: Shader = preload("res://shaders/lpc_sprite.gdshader")

const _OUTLINE_OUTER_ALPHA: float = 0.42

var enabled: bool = false
var glow_color: Color = Color(0.36, 0.62, 0.92, 1.0)
var _muted: bool = false
var _actor: CharacterActor
## AnimatedSprite2D -> base Material (shared cache or null) before selection swap.
var _base_materials: Dictionary = {}
## AnimatedSprite2D -> duplicated ShaderMaterial used while selected.
var _selection_materials: Dictionary = {}


func bind_actor(actor: CharacterActor) -> void:
	_actor = actor


func is_active() -> bool:
	return enabled


func is_outline_empty() -> bool:
	return not enabled


func set_active(active: bool, color: Color = glow_color) -> void:
	if active == enabled and (not active or color == glow_color):
		if active:
			_update_all_selection_params()
		return
	enabled = active
	glow_color = color
	if active:
		_apply_to_all_layers()
	else:
		_restore_all_layers()


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_update_all_selection_params()


func on_layer_added(layer: AnimatedSprite2D) -> void:
	if not enabled or layer == null:
		return
	_apply_to_layer(layer)


func on_layers_cleared() -> void:
	_base_materials.clear()
	_selection_materials.clear()


func _apply_to_all_layers() -> void:
	if _actor == null:
		return
	for layer: AnimatedSprite2D in _actor.get_sprite_layers():
		_apply_to_layer(layer)


func _apply_to_layer(layer: AnimatedSprite2D) -> void:
	if layer == null or not layer.visible or layer.sprite_frames == null:
		return
	if _selection_materials.has(layer):
		layer.material = _selection_materials[layer] as Material
		_update_material_params(_selection_materials[layer] as ShaderMaterial)
		return
	var base_mat: Material = layer.material
	_base_materials[layer] = base_mat
	var sel_mat: ShaderMaterial = _duplicate_for_selection(base_mat)
	if sel_mat == null:
		return
	_selection_materials[layer] = sel_mat
	layer.material = sel_mat
	_update_material_params(sel_mat)


func _duplicate_for_selection(base_mat: Material) -> ShaderMaterial:
	var sel_mat: ShaderMaterial
	if base_mat is ShaderMaterial:
		sel_mat = (base_mat as ShaderMaterial).duplicate() as ShaderMaterial
	elif base_mat == null:
		sel_mat = ShaderMaterial.new()
		sel_mat.shader = _SPRITE_SHADER
	else:
		return null
	_ensure_selection_uniforms(sel_mat)
	return sel_mat


func _ensure_selection_uniforms(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("selection_inner_px", 2)
	mat.set_shader_parameter("selection_outer_px", 4)


func _update_all_selection_params() -> void:
	for layer: Variant in _selection_materials:
		var mat: ShaderMaterial = _selection_materials[layer] as ShaderMaterial
		_update_material_params(mat)


func _update_material_params(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("selection_active", 1.0)
	mat.set_shader_parameter("selection_color", _draw_color())
	mat.set_shader_parameter("selection_inner_alpha", 1.0 if not _muted else 0.85)
	mat.set_shader_parameter(
		"selection_outer_alpha",
		_OUTLINE_OUTER_ALPHA if not _muted else _OUTLINE_OUTER_ALPHA * 0.75,
	)


func _draw_color() -> Color:
	if _muted:
		return Color(0.55, 0.55, 0.60, 1.0)
	return glow_color


func _restore_all_layers() -> void:
	for layer: Variant in _base_materials:
		var spr: AnimatedSprite2D = layer as AnimatedSprite2D
		if spr == null or not is_instance_valid(spr):
			continue
		var base_mat: Material = _base_materials[layer] as Material
		spr.material = base_mat
	_base_materials.clear()
	_selection_materials.clear()
