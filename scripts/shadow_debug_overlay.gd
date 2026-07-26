class_name ShadowDebugOverlay
extends CanvasLayer

## Dev overlay — GPU per-pixel cloud shade bake (same shader as ground). Toggle **J**.

const TILE_PX: int = 16
const REFRESH_INTERVAL_SEC: float = 0.4

const COLOR_ACTOR_FOOT: Color = Color(1.0, 0.92, 0.12, 0.95)
const COLOR_ACTOR_MISMATCH: Color = Color(1.0, 0.45, 0.0, 0.95)

const CLOUD_SHADE_GATE: float = CloudShadowMaskBaker.SHADE_GATE

var _grid: PlayerGrid
var _map_root: Node2D
var _ground: TileMapLayer
var _settings: EffectsSettings
var _actors: Array[CharacterActor] = []
var _container: Control
var _legend: PanelContainer
var _legend_body: Label
var _tile_overlay: ColorRect
var _debug_material: ShaderMaterial
var _foot_layer: Control
var _foot_markers: Array[ColorRect] = []
var _refresh_accum: float = 0.0
var _last_stamp: int = -1
var _last_zoom: float = -1.0


func _ready() -> void:
	layer = 12
	visible = false
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_foot_layer = Control.new()
	_foot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_foot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_foot_layer)
	_build_legend_shell()


func sync(
	grid: PlayerGrid,
	map_root: Node2D,
	settings: EffectsSettings = null,
	actors: Array[CharacterActor] = [],
	ground: TileMapLayer = null,
) -> void:
	_grid = grid
	_map_root = map_root
	_ground = ground
	_settings = settings
	_actors = actors
	_last_stamp = -1
	_last_zoom = -1.0
	if visible:
		_rebuild()


func toggle() -> bool:
	visible = not visible
	_last_stamp = -1
	if visible:
		_rebuild()
	else:
		_teardown()
	return visible


func process_refresh(delta: float) -> void:
	if not visible or _grid == null or _map_root == null:
		return
	_refresh_accum += delta
	if _refresh_accum < REFRESH_INTERVAL_SEC:
		return
	_refresh_accum = 0.0
	var stamp: int = ShadowPlacer.cloud_drift_stamp(_settings)
	var zoom: float = _map_root.scale.x
	if stamp == _last_stamp and is_equal_approx(zoom, _last_zoom):
		return
	_rebuild()


func _rebuild() -> void:
	if _grid == null or _map_root == null:
		return
	var baker: CloudShadowMaskBaker = CloudShadowMaskBaker.ensure(_map_root)
	if baker == null:
		return
	var size_px: Vector2 = (
		MapPixelSpace.size_px_from_ground(_ground)
		if _ground != null
		else MapPixelSpace.size_px_from_grid(_grid)
	)
	if _settings != null and _settings.cloud_shadows:
		var content_origin: Vector2i = MapPixelSpace.used_origin_cell(_ground)
		baker.request_sync(size_px, _settings, content_origin)
		_connect_baker(baker)
	_ensure_tile_overlay(baker)
	var zoom: float = _map_root.scale.x
	var map_origin: Vector2 = (
		MapPixelSpace.content_top_left_px(_ground)
		if _ground != null
		else Vector2.ZERO
	)
	_tile_overlay.position = _map_root.to_global(map_origin)
	_tile_overlay.size = size_px * zoom
	_last_zoom = zoom
	if baker.is_ready():
		var bake_tex: Texture2D = baker.get_bake_texture()
		if bake_tex != null:
			_debug_material.set_shader_parameter("shade_tex", bake_tex)
	_tile_overlay.visible = baker.is_ready()
	_paint_actor_feet(zoom)
	var cloud_count: int = CloudShadowMaskBaker.count_shaded_pixels()
	_update_legend(cloud_count, baker.is_ready())
	_last_stamp = ShadowPlacer.cloud_drift_stamp(_settings)


func _connect_baker(baker: CloudShadowMaskBaker) -> void:
	if baker.bake_completed.is_connected(_on_cloud_bake_completed):
		return
	baker.bake_completed.connect(_on_cloud_bake_completed)


func _on_cloud_bake_completed() -> void:
	if visible:
		_last_stamp = -1
		_rebuild()


func _ensure_tile_overlay(baker: CloudShadowMaskBaker) -> void:
	if _tile_overlay != null and is_instance_valid(_tile_overlay):
		return
	_tile_overlay = ColorRect.new()
	_tile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_material = baker.make_debug_material()
	_debug_material.set_shader_parameter("shade_gate", CLOUD_SHADE_GATE)
	_tile_overlay.material = _debug_material
	_container.add_child(_tile_overlay)
	_container.move_child(_tile_overlay, 0)


func _paint_actor_feet(zoom: float) -> void:
	var needed: int = _actors.size()
	while _foot_markers.size() < needed:
		var marker: ColorRect = ColorRect.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_foot_layer.add_child(marker)
		_foot_markers.append(marker)
	while _foot_markers.size() > needed:
		var extra: ColorRect = _foot_markers.pop_back()
		extra.queue_free()

	var half: float = maxf(2.0, float(TILE_PX) * zoom * 0.12)
	for i: int in range(needed):
		var actor: CharacterActor = _actors[i]
		var marker: ColorRect = _foot_markers[i]
		if actor == null or not is_instance_valid(actor):
			marker.visible = false
			continue
		marker.visible = true
		var foot: Vector2 = actor.position
		var cell: Vector2i = ShadowPlacer.cell_from_foot_px(foot)
		var cloud_shade: float = ShadowPlacer.cloud_shade_at(
			MapPixelSpace.foot_map_px(foot), WeatherBus.cloud_drift_offset, _settings,
		)
		var sprite_shaded: bool = (
			_settings != null
			and _settings.cloud_shadows
			and cloud_shade >= CLOUD_SHADE_GATE
		)
		var tile_hit: bool = (
			_cell_in_grid(cell)
			and ShadowPlacer.tile_cloud_visible_at_cell(cell, _settings)
		)
		marker.color = COLOR_ACTOR_MISMATCH if sprite_shaded != tile_hit else COLOR_ACTOR_FOOT
		var global_foot: Vector2 = _map_root.to_global(foot)
		marker.position = global_foot - Vector2(half, half)
		marker.size = Vector2(half * 2.0, half * 2.0)


func _cell_in_grid(cell: Vector2i) -> bool:
	return (
		_grid != null
		and cell.x >= 0
		and cell.y >= 0
		and cell.x < _grid.width
		and cell.y < _grid.height
	)


func _build_legend_shell() -> void:
	_legend = PanelContainer.new()
	_legend.position = Vector2(8.0, 8.0)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_body = Label.new()
	_legend_body.add_theme_font_size_override("font_size", 10)
	_legend.add_child(_legend_body)
	_container.add_child(_legend)


func _update_legend(cloud_count: int, bake_ready: bool) -> void:
	var ready_line: String = "GPU bake ready" if bake_ready else "GPU bake pending…"
	var lines: PackedStringArray = PackedStringArray([
		"Cloud shadow debug (J) — GPU per-pixel bake",
		"Red = shade >= %.2f (%d px) · %s" % [CLOUD_SHADE_GATE, cloud_count, ready_line],
		"Updates ~%.1fs · yellow foot = actor · orange = sprite/tile mismatch" % REFRESH_INTERVAL_SEC,
	])
	_legend_body.text = "\n".join(lines)


func _teardown() -> void:
	if _tile_overlay != null and is_instance_valid(_tile_overlay):
		_tile_overlay.queue_free()
	_tile_overlay = null
	_debug_material = null
	for marker: ColorRect in _foot_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_foot_markers.clear()
