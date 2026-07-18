class_name TileCloudReceiveBinder
extends RefCounted

## GPU cloud receive on TreeLayer / OverlayLayer — tints tile albedo, no multiply stack.

const TILE_PX: float = 16.0
const _CLOUD_SHADER: Shader = preload("res://shaders/tilemap_cloud_receive.gdshader")

var _trees: TileMapLayer
var _overlay: TileMapLayer
var _map_root: Node2D
var _cloud_material: ShaderMaterial
var _active: bool = false


func setup(trees: TileMapLayer, overlay: TileMapLayer, map_root: Node2D) -> void:
	_trees = trees
	_overlay = overlay
	_map_root = map_root


func apply(settings: EffectsSettings, grid: PlayerGrid) -> void:
	if settings == null or not settings.cloud_shadows:
		_teardown()
		return
	_ensure_material()
	if grid != null and _map_root != null:
		_set_map_uniforms(
			_map_root.global_position,
			_map_root.scale.x,
		)
	if _trees != null:
		_trees.material = _cloud_material
		_trees.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _overlay != null:
		_overlay.material = _cloud_material
		_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enable_cloud_uniforms()
	_active = true


func sync_drift(settings: EffectsSettings) -> void:
	if settings == null or not settings.cloud_shadows or not _active:
		return
	_push_drift_only()


func _teardown() -> void:
	if _trees != null and _trees.material == _cloud_material:
		_trees.material = null
	if _overlay != null and _overlay.material == _cloud_material:
		_overlay.material = null
	_active = false


func _ensure_material() -> void:
	if _cloud_material != null:
		return
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = _CLOUD_SHADER


func _set_map_uniforms(origin: Vector2, scale: float) -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("map_origin_px", origin)
	_cloud_material.set_shader_parameter("map_scale", scale)
	_cloud_material.set_shader_parameter("tile_px", TILE_PX)


func _enable_cloud_uniforms() -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("enable_cloud_shadows", 1.0)
	_cloud_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
	_cloud_material.set_shader_parameter("cloud_shadow_tint", AtmosphereBinder.CLOUD_SHADOW_TINT)
	_cloud_material.set_shader_parameter("cloud_shadow_strength", AtmosphereBinder.CLOUD_SHADOW_STRENGTH)
	_cloud_material.set_shader_parameter("tile_px", TILE_PX)


func _push_drift_only() -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
