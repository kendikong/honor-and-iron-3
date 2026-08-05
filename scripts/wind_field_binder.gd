class_name WindFieldBinder
extends RefCounted

## Wires TileMapLayers to WindBus: runtime materials, participation masks, uniform sync.

const TILE_PX: float = 16.0

var ground_material: ShaderMaterial
var tree_material: ShaderMaterial

var _overlay: TileMapLayer
var _ground_mask: ImageTexture
var _tree_mask: ImageTexture


func setup(ground: TileMapLayer, overlay: TileMapLayer) -> void:
	_overlay = overlay
	ground_material = _make_material("res://shaders/wind_grass.gdshader")
	tree_material = _make_material("res://shaders/wind_tree.gdshader")
	ground.material = ground_material
	_overlay.material = tree_material
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not WindBus.field_changed.is_connected(_on_field_changed):
		WindBus.field_changed.connect(_on_field_changed)


func sync_map(grid: PlayerGrid, map_root: Node2D) -> void:
	if grid == null or map_root == null:
		return
	WindBus.set_map_frame(
		map_root.global_position,
		Vector2i(grid.width, grid.height),
		TILE_PX,
		map_root.scale.x,
	)
	_rebuild_ground_mask(grid)
	_rebuild_tree_mask(grid)
	_push_uniforms()


func _make_material(shader_path: String) -> ShaderMaterial:
	var shader: Shader = load(shader_path)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _rebuild_ground_mask(grid: PlayerGrid) -> void:
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
	_ground_mask = ImageTexture.create_from_image(img)


func _rebuild_tree_mask(grid: PlayerGrid) -> void:
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RF)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var weight: float = 1.0 if _overlay.get_cell_source_id(pos) == TileSetFactory.SOURCE_TREES else 0.0
			img.set_pixel(x, y, Color(weight, 0.0, 0.0, 1.0))
	_tree_mask = ImageTexture.create_from_image(img)


func _on_field_changed() -> void:
	_push_uniforms()


func _push_uniforms() -> void:
	var params: Dictionary = WindBus.shader_uniforms()
	_apply_params(ground_material, params, _ground_mask)
	_apply_params(tree_material, params, _tree_mask)


func _apply_params(mat: ShaderMaterial, params: Dictionary, mask: ImageTexture) -> void:
	if mat == null:
		return
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	if mask != null:
		mat.set_shader_parameter("participation_tex", mask)
		mat.set_shader_parameter("has_participation", 1.0)
	else:
		mat.set_shader_parameter("has_participation", 0.0)


func teardown(ground: TileMapLayer, overlay: TileMapLayer) -> void:
	if WindBus.field_changed.is_connected(_on_field_changed):
		WindBus.field_changed.disconnect(_on_field_changed)
	if ground != null:
		ground.material = null
	if overlay != null:
		overlay.material = null
	ground_material = null
	tree_material = null
	_ground_mask = null
	_tree_mask = null
