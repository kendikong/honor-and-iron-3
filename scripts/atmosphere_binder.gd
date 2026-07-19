class_name AtmosphereBinder
extends RefCounted

## Wires WeatherBus → CanvasModulate, cloud/mist overlays, participation masks.

const TILE_PX: float = 16.0
const CLOUD_SHADOW_TINT: Color = Color(0.75, 0.73, 0.82, 1.0)
const CLOUD_SHADOW_STRENGTH: float = 0.90

var _world_modulate: CanvasModulate
var _cloud_rect: ColorRect
var _mist_rect: ColorRect
var _sky_overlay: Node2D
var _map_root: Node2D
var _cloud_material: ShaderMaterial
var _mist_material: ShaderMaterial
var _participation_tex: ImageTexture


func setup(
	world_modulate: CanvasModulate,
	sky_overlay: Node2D,
	map_root: Node2D,
) -> void:
	_world_modulate = world_modulate
	_map_root = map_root
	_sky_overlay = sky_overlay
	_cloud_rect = sky_overlay.get_node("CloudShadows") as ColorRect
	_mist_rect = sky_overlay.get_node("MistOverlay") as ColorRect
	_cloud_material = _make_material("res://shaders/cloud_shadow.gdshader")
	_mist_material = _make_material("res://shaders/mist_overlay.gdshader")
	_cloud_rect.material = _cloud_material
	_mist_rect.material = _mist_material
	_cloud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_overlay.z_as_relative = false
	_sky_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not WeatherBus.state_changed.is_connected(_on_weather_changed):
		WeatherBus.state_changed.connect(_on_weather_changed)
	_on_weather_changed()


func sync_map(grid: PlayerGrid, water_ratio: float) -> void:
	if grid == null:
		return
	var ruin_count: int = _count_tile(grid, TileId.Type.RUIN)
	WeatherBus.set_map_humidity(water_ratio, ruin_count, grid.width * grid.height)
	_rebuild_participation(grid)
	_resize_overlays(grid)
	_push_uniforms(grid)


func _make_material(shader_path: String) -> ShaderMaterial:
	var shader: Shader = load(shader_path)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _resize_overlays(grid: PlayerGrid) -> void:
	var size_px: Vector2 = Vector2(grid.width, grid.height) * TILE_PX
	_cloud_rect.position = Vector2.ZERO
	_cloud_rect.size = size_px
	_mist_rect.position = Vector2.ZERO
	_mist_rect.size = size_px
	_sync_sky_transform()


func _sync_sky_transform() -> void:
	if _sky_overlay == null or _map_root == null:
		return
	_sky_overlay.scale = _map_root.scale
	_sky_overlay.position = _map_root.position


func _rebuild_participation(grid: PlayerGrid) -> void:
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RF)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var weight: float = 0.2
			match grid.get_cell(Vector2i(x, y)):
				TileId.Type.GRASS:
					weight = 0.25
				TileId.Type.DIRT:
					weight = 0.22
				TileId.Type.ROCK:
					weight = 0.45
				TileId.Type.RUIN:
					weight = 0.85
				TileId.Type.TREE:
					weight = 0.7
				_:
					weight = 0.1
			img.set_pixel(x, y, Color(weight, 0.0, 0.0, 1.0))
	_participation_tex = ImageTexture.create_from_image(img)


func _on_weather_changed() -> void:
	if _world_modulate != null:
		_world_modulate.color = WeatherBus.canvas_modulate_color()
	if _cloud_material == null and _mist_material == null:
		return
	var atmo: Dictionary = WeatherBus.atmosphere_uniforms()
	if _cloud_material != null and _cloud_material.shader != null:
		_cloud_material.set_shader_parameter("cloud_drift_offset", atmo["cloud_drift_offset"])
	if _mist_material != null and _mist_material.shader != null:
		_mist_material.set_shader_parameter("mist_density", atmo["mist_density"])
		_mist_material.set_shader_parameter("humidity", atmo["humidity"])
		_mist_material.set_shader_parameter("ruin_ratio", atmo["ruin_ratio"])


func refresh_cloud_drift() -> void:
	if _cloud_material == null or _cloud_material.shader == null:
		return
	_cloud_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)


func sync_sky_transform() -> void:
	_sync_sky_transform()


func push_cloud_shadow_uniforms(settings: EffectsSettings = null) -> void:
	if _cloud_material == null or _cloud_material.shader == null or _cloud_rect == null:
		return
	var strength: float = CLOUD_SHADOW_STRENGTH
	var tint: Color = CLOUD_SHADOW_TINT
	if settings != null:
		var params: Dictionary = ShadowPalette.multiply_shader_params(settings)
		if params.has("shadow_tint"):
			tint = params["shadow_tint"]
		if params.has("shadow_strength"):
			strength = params["shadow_strength"]
			
	_cloud_material.set_shader_parameter("shadow_tint", tint)
	_cloud_material.set_shader_parameter("shadow_strength", strength)
	_cloud_rect.modulate = Color.WHITE


## Retired — cloud shadows resolve in ground_shadow_composite.gdshader.
func set_contact_shadow_overlay(_tex: Texture2D, _origin: Vector2, _active: bool) -> void:
	pass


func _push_uniforms(grid: PlayerGrid) -> void:
	if _map_root == null:
		return
	_sync_sky_transform()
	var origin: Vector2 = _map_root.global_position
	var size_px: Vector2 = Vector2(grid.width, grid.height) * TILE_PX
	var scale: float = _map_root.scale.x
	var shared: Array = [
		["map_origin_px", origin],
		["map_size_px", size_px],
		["map_scale", scale],
		["map_size_cells", Vector2(grid.width, grid.height)],
		["tile_px", TILE_PX],
	]
	for pair: Array in shared:
		_cloud_material.set_shader_parameter(pair[0], pair[1])
		_mist_material.set_shader_parameter(pair[0], pair[1])
	var atmo: Dictionary = WeatherBus.atmosphere_uniforms()
	_cloud_material.set_shader_parameter("cloud_drift_offset", atmo["cloud_drift_offset"])
	_mist_material.set_shader_parameter("mist_density", atmo["mist_density"])
	_mist_material.set_shader_parameter("humidity", atmo["humidity"])
	_mist_material.set_shader_parameter("ruin_ratio", atmo["ruin_ratio"])
	if _participation_tex != null:
		_mist_material.set_shader_parameter("participation_tex", _participation_tex)
		_mist_material.set_shader_parameter("has_participation", 1.0)
	else:
		_mist_material.set_shader_parameter("has_participation", 0.0)


static func _count_tile(grid: PlayerGrid, tile_id: int) -> int:
	var count: int = 0
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			if grid.get_cell(Vector2i(x, y)) == tile_id:
				count += 1
	return count
