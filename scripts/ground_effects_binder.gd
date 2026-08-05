class_name GroundEffectsBinder
extends RefCounted

## Ground + tree materials for wind and/or water ripple shaders.

const TILE_PX: float = 16.0

var ground_material: ShaderMaterial
var tree_material: ShaderMaterial

var _overlay: TileMapLayer
var _trees: TileMapLayer
var _ground: TileMapLayer
var _wind_mask: ImageTexture
var _water_mask: ImageTexture
var _tree_mask: ImageTexture
var _wind_on: bool = false
var _water_on: bool = false


func setup(
	ground: TileMapLayer,
	overlay: TileMapLayer,
	trees: TileMapLayer,
	wind_on: bool,
	water_on: bool,
) -> void:
	_ground = ground
	_overlay = overlay
	_trees = trees
	_wind_on = wind_on
	_water_on = water_on
	_rebuild_ground_material(ground)
	if wind_on:
		tree_material = _make_material("res://shaders/wind_tree.gdshader")
		if _trees != null:
			_trees.material = tree_material
			_trees.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not WindBus.field_changed.is_connected(_on_field_changed):
			WindBus.field_changed.connect(_on_field_changed)
	else:
		tree_material = null
		if _trees != null:
			_trees.material = null
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not WeatherBus.state_changed.is_connected(_on_weather_changed):
		WeatherBus.state_changed.connect(_on_weather_changed)


func sync_map(grid: PlayerGrid, map_root: Node2D) -> void:
	if grid == null or map_root == null:
		return
	if _wind_on:
		WindBus.set_map_frame(
			map_root.global_position,
			Vector2i(grid.width, grid.height),
			TILE_PX,
			map_root.scale.x,
		)
		_rebuild_wind_mask(grid)
	if _water_on:
		_rebuild_water_mask(grid)
	if _wind_on:
		_rebuild_tree_mask(grid)
	_push_uniforms(map_root, grid)


func teardown(ground: TileMapLayer, overlay: TileMapLayer, trees: TileMapLayer) -> void:
	if WindBus.field_changed.is_connected(_on_field_changed):
		WindBus.field_changed.disconnect(_on_field_changed)
	if WeatherBus.state_changed.is_connected(_on_weather_changed):
		WeatherBus.state_changed.disconnect(_on_weather_changed)
	if ground != null:
		ground.material = null
	if overlay != null:
		overlay.material = null
	if trees != null:
		trees.material = null
	ground_material = null
	tree_material = null
	_wind_mask = null
	_water_mask = null
	_tree_mask = null
	_ground = null
	_wind_on = false
	_water_on = false


func mode_matches(wind_on: bool, water_on: bool) -> bool:
	return _wind_on == wind_on and _water_on == water_on


func _rebuild_ground_material(ground: TileMapLayer) -> void:
	if _wind_on and _water_on:
		ground_material = _make_material("res://shaders/ground_effects.gdshader")
	elif _wind_on:
		ground_material = _make_material("res://shaders/wind_grass.gdshader")
	elif _water_on:
		ground_material = _make_material("res://shaders/water_ripple.gdshader")
	else:
		ground_material = null
	ground.material = ground_material


func _make_material(shader_path: String) -> ShaderMaterial:
	var shader: Shader = load(shader_path)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _rebuild_wind_mask(grid: PlayerGrid) -> void:
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RF)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var weight: float = 0.0
			match grid.get_cell(Vector2i(x, y)):
				TileId.Type.GRASS:
					weight = 1.0
				TileId.Type.DIRT:
					weight = 0.6
				TileId.Type.TREE:
					weight = 0.12
				_:
					weight = 0.0
			img.set_pixel(x, y, Color(weight, 0.0, 0.0, 1.0))
	_wind_mask = ImageTexture.create_from_image(img)


func _rebuild_water_mask(grid: PlayerGrid) -> void:
	## Interior water only â€” shore wang tiles mix grass pixels and are excluded.
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var weight: float = WaterCellMask.ripple_weight(grid, _ground, pos)
			img.set_pixel(x, y, Color(weight, weight, weight, 1.0))
	_water_mask = ImageTexture.create_from_image(img)


func _on_field_changed() -> void:
	_push_uniforms(null, null)


func _on_weather_changed() -> void:
	_push_uniforms(null, null)


func refresh_uniforms() -> void:
	_push_uniforms(null, null)


func _push_uniforms(map_root: Node2D, grid: PlayerGrid) -> void:
	if ground_material == null or ground_material.shader == null:
		return
	if map_root != null and grid != null:
		var origin: Vector2 = map_root.global_position
		var size_cells: Vector2 = Vector2(grid.width, grid.height)
		ground_material.set_shader_parameter("map_origin_px", origin)
		ground_material.set_shader_parameter("map_size_cells", size_cells)
		ground_material.set_shader_parameter("tile_px", TILE_PX)
		ground_material.set_shader_parameter("map_scale", map_root.scale.x)

	if _wind_on and _water_on:
		ground_material.set_shader_parameter("enable_wind", 1.0)
		ground_material.set_shader_parameter("enable_water", 1.0)
		var wind_params: Dictionary = WindBus.shader_uniforms()
		for key: String in wind_params:
			ground_material.set_shader_parameter(key, wind_params[key])
		_apply_mask(ground_material, _wind_mask, "wind_participation_tex", "has_wind_participation")
		_apply_mask(ground_material, _water_mask, "water_participation_tex", "has_water_participation")
		_push_ripple_uniforms(ground_material)
	elif _wind_on:
		var params: Dictionary = WindBus.shader_uniforms()
		for key: String in params:
			ground_material.set_shader_parameter(key, params[key])
		_apply_mask(ground_material, _wind_mask, "participation_tex", "has_participation")
	elif _water_on:
		_push_ripple_uniforms(ground_material)
		_apply_mask(ground_material, _water_mask, "participation_tex", "has_participation")

	if tree_material != null and tree_material.shader != null and _wind_on and _tree_mask != null:
		var tree_params: Dictionary = WindBus.shader_uniforms()
		for key: String in tree_params:
			tree_material.set_shader_parameter(key, tree_params[key])
		_apply_mask(tree_material, _tree_mask, "participation_tex", "has_participation")


func _push_ripple_uniforms(mat: ShaderMaterial) -> void:
	var ripple_dir: Vector2 = _ripple_direction()
	mat.set_shader_parameter("ripple_dir", ripple_dir)
	mat.set_shader_parameter("ripple_multiplier", WeatherBus.ripple_multiplier)
	mat.set_shader_parameter("ripple_strength", 1.35)


func _ripple_direction() -> Vector2:
	if _wind_on and WindBus.process_mode != Node.PROCESS_MODE_DISABLED:
		return WindBus.direction
	return WeatherBus.cloud_drift_dir


func _rebuild_tree_mask(grid: PlayerGrid) -> void:
	if _trees == null or grid == null:
		return
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RF)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var weight: float = (
				1.0 if _trees.get_cell_source_id(pos) == TileSetFactory.SOURCE_TREES else 0.0
			)
			img.set_pixel(x, y, Color(weight, 0.0, 0.0, 1.0))
	_tree_mask = ImageTexture.create_from_image(img)


func _apply_mask(
	mat: ShaderMaterial,
	mask: ImageTexture,
	tex_param: String,
	has_param: String,
) -> void:
	if mat == null:
		return
	if mask != null:
		mat.set_shader_parameter(tex_param, mask)
		mat.set_shader_parameter(has_param, 1.0)
	else:
		mat.set_shader_parameter(has_param, 0.0)
