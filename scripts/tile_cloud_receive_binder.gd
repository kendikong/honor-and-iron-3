class_name TileCloudReceiveBinder
extends RefCounted

## GPU cloud receive on TreeLayer / OverlayLayer — tints tile albedo, no multiply stack.

const TILE_PX: float = 16.0
const _CLOUD_ONLY_SHADER: Shader = preload("res://shaders/tilemap_cloud_receive.gdshader")

var _trees: TileMapLayer
var _overlay: TileMapLayer
var _map_root: Node2D
var _cloud_only_material: ShaderMaterial
var _cloud_only_trees: bool = false
var _cloud_only_overlay: bool = false
var _last_origin: Vector2 = Vector2.ZERO
var _last_scale: float = 1.0


func setup(trees: TileMapLayer, overlay: TileMapLayer, map_root: Node2D) -> void:
	_trees = trees
	_overlay = overlay
	_map_root = map_root


func apply(
	settings: EffectsSettings,
	grid: PlayerGrid,
	wind_field_active: bool,
	wind_tree_material: ShaderMaterial,
) -> void:
	if settings == null or not settings.cloud_shadows:
		_teardown(wind_field_active, wind_tree_material)
		return
	_ensure_cloud_only_material()
	if grid != null and _map_root != null:
		_last_origin = _map_root.global_position
		_last_scale = _map_root.scale.x
		_set_map_uniforms(_cloud_only_material, _last_origin, _last_scale)
		if wind_tree_material != null:
			_set_map_uniforms(wind_tree_material, _last_origin, _last_scale)
	if _overlay != null:
		_overlay.material = _cloud_only_material
		_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cloud_only_overlay = true
	if wind_field_active:
		if _cloud_only_trees and _trees != null:
			_trees.material = null
			_cloud_only_trees = false
		_enable_cloud_on_material(wind_tree_material)
	else:
		if _trees != null:
			_trees.material = _cloud_only_material
			_trees.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_cloud_only_trees = true
	_enable_cloud_on_material(_cloud_only_material)


func sync_drift(
	settings: EffectsSettings,
	wind_field_active: bool,
	wind_tree_material: ShaderMaterial,
) -> void:
	if settings == null or not settings.cloud_shadows:
		return
	if wind_field_active:
		_push_drift_only(wind_tree_material)
	_push_drift_only(_cloud_only_material)


func _teardown(wind_field_active: bool, wind_tree_material: ShaderMaterial) -> void:
	if _cloud_only_trees and _trees != null:
		_trees.material = null
		_cloud_only_trees = false
	if _cloud_only_overlay and _overlay != null:
		_overlay.material = null
		_cloud_only_overlay = false
	if wind_field_active:
		_disable_cloud_on_material(wind_tree_material)
	_disable_cloud_on_material(_cloud_only_material)


func _ensure_cloud_only_material() -> void:
	if _cloud_only_material != null:
		return
	_cloud_only_material = ShaderMaterial.new()
	_cloud_only_material.shader = _CLOUD_ONLY_SHADER


func _set_map_uniforms(mat: ShaderMaterial, origin: Vector2, scale: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("map_origin_px", origin)
	mat.set_shader_parameter("map_scale", scale)
	mat.set_shader_parameter("tile_px", TILE_PX)


func _enable_cloud_on_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("enable_cloud_shadows", 1.0)
	mat.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
	mat.set_shader_parameter("cloud_shadow_tint", AtmosphereBinder.CLOUD_SHADOW_TINT)
	mat.set_shader_parameter("cloud_shadow_strength", AtmosphereBinder.CLOUD_SHADOW_STRENGTH)
	mat.set_shader_parameter("tile_px", TILE_PX)


func _disable_cloud_on_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("enable_cloud_shadows", 0.0)


func _push_drift_only(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
