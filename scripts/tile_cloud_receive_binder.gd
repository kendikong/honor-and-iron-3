class_name TileCloudReceiveBinder
extends RefCounted

## GPU cloud receive on TreeLayer / OverlayLayer â€” tints tile albedo, no multiply stack.

const TILE_PX: float = 16.0
const _CLOUD_SHADER: Shader = preload("res://shaders/tilemap_cloud_receive.gdshader")

var _trees: TileMapLayer
var _overlay: TileMapLayer
var _ground: TileMapLayer
var _map_root: Node2D
var _cloud_material: ShaderMaterial
var _active: bool = false


func setup(
	trees: TileMapLayer,
	overlay: TileMapLayer,
	map_root: Node2D,
	ground: TileMapLayer = null,
) -> void:
	_trees = trees
	_overlay = overlay
	_map_root = map_root
	_ground = ground


func apply(settings: EffectsSettings, grid: PlayerGrid, ground: TileMapLayer = null) -> void:
	if settings == null or not settings.cloud_shadows:
		_teardown()
		return
	if ground != null:
		_ground = ground
	_ensure_material()
	if grid != null and _map_root != null:
		_set_map_uniforms()
	if _trees != null:
		_trees.material = _cloud_material
		_trees.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _overlay != null:
		_overlay.material = _cloud_material
		_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enable_cloud_uniforms(settings)
	_active = true


func sync_drift(settings: EffectsSettings) -> void:
	if settings == null or not settings.cloud_shadows or not _active:
		return
	if _map_root != null:
		_set_map_uniforms()
	_push_drift_only()
	CloudTuning.push_shader_uniforms(_cloud_material, settings)


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


func _set_map_uniforms() -> void:
	if _cloud_material == null or _map_root == null:
		return
	var origin_global: Vector2 = MapPixelSpace.map_world_origin(_map_root)
	_cloud_material.set_shader_parameter("map_origin_px", origin_global)
	_cloud_material.set_shader_parameter("map_scale", MapPixelSpace.map_scale(_map_root))
	_cloud_material.set_shader_parameter("tile_px", TILE_PX)


func _enable_cloud_uniforms(settings: EffectsSettings = null) -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("enable_cloud_shadows", 1.0)
	_cloud_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
	_cloud_material.set_shader_parameter("cloud_shadow_tint", AtmosphereBinder.CLOUD_SHADOW_TINT)
	_cloud_material.set_shader_parameter("tile_px", TILE_PX)
	CloudTuning.push_shader_uniforms(_cloud_material, settings)


func _push_drift_only() -> void:
	if _cloud_material == null:
		return
	_cloud_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
