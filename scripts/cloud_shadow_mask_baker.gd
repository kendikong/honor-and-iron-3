class_name CloudShadowMaskBaker
extends Node

## GPU bake of the cloud shade field (identical shader math to ground multiply).
## Sprites and the J-key debug overlay sample this — not the GDScript FBM mirror.

signal bake_completed

const SHADE_GATE: float = 0.01
const TILE_PX: float = 16.0

const _BAKE_SHADER: Shader = preload("res://shaders/cloud_shadow_mask_bake.gdshader")
const _DEBUG_SHADER: Shader = preload("res://shaders/cloud_shadow_debug_visualize.gdshader")

static var _active: CloudShadowMaskBaker

var _viewport: SubViewport
var _rect: ColorRect
var _bake_material: ShaderMaterial
var _image: Image
var _stamp: int = -1
var _map_size: Vector2i = Vector2i.ZERO
var _content_origin_cell: Vector2i = Vector2i.ZERO
var _baking: bool = false
var _queued_sync: Dictionary = {}
var _bake_stamp_target: int = -1


static func ensure(map_root: Node2D) -> CloudShadowMaskBaker:
	if map_root == null:
		return null
	var existing: Node = map_root.get_node_or_null("CloudShadowMaskBaker")
	if existing is CloudShadowMaskBaker:
		return existing as CloudShadowMaskBaker
	var baker: CloudShadowMaskBaker = CloudShadowMaskBaker.new()
	baker.name = "CloudShadowMaskBaker"
	map_root.add_child(baker)
	return baker


static func active() -> CloudShadowMaskBaker:
	return _active


static func shade_at(map_px: Vector2) -> float:
	if _active == null or _active._image == null:
		return -1.0
	return _active._sample_shade(map_px)


static func cloud_visible_at(map_px: Vector2) -> bool:
	var shade: float = shade_at(map_px)
	return shade >= SHADE_GATE


static func tile_cloud_visible_at_cell(cell: Vector2i) -> bool:
	if _active == null or _active._image == null:
		return false
	var local_cell: Vector2i = cell - _active._content_origin_cell
	var x0: int = local_cell.x * int(TILE_PX)
	var y0: int = local_cell.y * int(TILE_PX)
	for dy: int in range(int(TILE_PX)):
		for dx: int in range(int(TILE_PX)):
			if _active._sample_shade(Vector2(float(x0 + dx), float(y0 + dy))) >= SHADE_GATE:
				return true
	return false


static func count_shaded_pixels() -> int:
	if _active == null or _active._image == null:
		return 0
	return _active._count_shaded_pixels()


func _enter_tree() -> void:
	_active = self


func _exit_tree() -> void:
	if _active == self:
		_active = null
	_baking = false
	_queued_sync = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	_viewport = SubViewport.new()
	_viewport.name = &"BakeViewport"
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_rect = ColorRect.new()
	_rect.name = &"BakeRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bake_material = ShaderMaterial.new()
	_bake_material.shader = _BAKE_SHADER
	_rect.material = _bake_material
	_viewport.add_child(_rect)


func request_sync(
	map_size: Vector2,
	settings: EffectsSettings,
	content_origin_cell: Vector2i = Vector2i.ZERO,
) -> void:
	if settings == null or not settings.cloud_shadows:
		_clear_bake()
		return
	var size_i: Vector2i = Vector2i(maxi(1, int(map_size.x)), maxi(1, int(map_size.y)))
	var stamp: int = _bake_stamp(map_size, settings, content_origin_cell)
	if stamp == _stamp and _image != null and size_i == _map_size:
		return
	if _baking:
		_queued_sync = {
			"map_size": map_size,
			"settings": settings,
			"stamp": stamp,
			"content_origin_cell": content_origin_cell,
		}
		return
	_start_bake(map_size, settings, stamp, content_origin_cell)


func is_ready() -> bool:
	return _image != null and not _image.is_empty()


func get_bake_texture() -> Texture2D:
	if _viewport == null:
		return null
	return _viewport.get_texture()


func make_debug_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _DEBUG_SHADER
	mat.set_shader_parameter("shade_gate", SHADE_GATE)
	mat.set_shader_parameter("tint_color", Color(1.0, 0.12, 0.12, 0.58))
	if _viewport != null:
		mat.set_shader_parameter("shade_tex", _viewport.get_texture())
	return mat


func _bake_stamp(
	map_size: Vector2,
	settings: EffectsSettings,
	content_origin_cell: Vector2i,
) -> int:
	return hash([
		int(floor(map_size.x)),
		int(floor(map_size.y)),
		content_origin_cell.x,
		content_origin_cell.y,
		ShadowPlacer.cloud_drift_stamp(settings),
	])


func _start_bake(
	map_size: Vector2,
	settings: EffectsSettings,
	stamp: int,
	content_origin_cell: Vector2i = Vector2i.ZERO,
) -> void:
	_baking = true
	_bake_stamp_target = stamp
	_content_origin_cell = content_origin_cell
	var size_i: Vector2i = Vector2i(maxi(1, int(map_size.x)), maxi(1, int(map_size.y)))
	if size_i != _map_size:
		_viewport.size = size_i
		_map_size = size_i
	_rect.size = map_size
	_rect.position = Vector2.ZERO
	_bake_material.set_shader_parameter("map_size_px", map_size)
	_bake_material.set_shader_parameter("tile_px", TILE_PX)
	_bake_material.set_shader_parameter(
		"cloud_shadow_strength", CloudTuning.strength(settings),
	)
	_bake_material.set_shader_parameter("cloud_drift_offset", WeatherBus.cloud_drift_offset)
	CloudTuning.push_shader_uniforms(_bake_material, settings)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	call_deferred("_finish_bake_async")


func _finish_bake_async() -> void:
	if not _await_bake_frames():
		_abort_bake()
		return
	var tex: Texture2D = _viewport.get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			_image = img
			_stamp = _bake_stamp_target
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_baking = false
	bake_completed.emit()
	if not _queued_sync.is_empty():
		var queued: Dictionary = _queued_sync
		_queued_sync = {}
		_start_bake(
			queued["map_size"] as Vector2,
			queued["settings"] as EffectsSettings,
			int(queued["stamp"]),
			queued.get("content_origin_cell", Vector2i.ZERO) as Vector2i,
		)


func _await_bake_frames() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	await tree.process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return false
	tree = get_tree()
	if tree == null:
		return false
	await tree.process_frame
	return is_instance_valid(self) and is_inside_tree()


func _abort_bake() -> void:
	_baking = false
	_bake_stamp_target = -1
	_queued_sync = {}
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _clear_bake() -> void:
	_stamp = -1
	_image = null
	_queued_sync = {}
	_baking = false
	_bake_stamp_target = -1
	_content_origin_cell = Vector2i.ZERO


func _sample_shade(map_px: Vector2) -> float:
	if _image == null or _image.is_empty():
		return -1.0
	var x: int = int(floor(map_px.x))
	var y: int = int(floor(map_px.y))
	if x < 0 or y < 0 or x >= _image.get_width() or y >= _image.get_height():
		return 0.0
	return _image.get_pixel(x, y).r


func _count_shaded_pixels() -> int:
	if _image == null or _image.is_empty():
		return 0
	var count: int = 0
	for y: int in range(_image.get_height()):
		for x: int in range(_image.get_width()):
			if _image.get_pixel(x, y).r >= SHADE_GATE:
				count += 1
	return count
