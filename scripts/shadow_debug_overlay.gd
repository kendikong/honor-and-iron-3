class_name ShadowDebugOverlay
extends CanvasLayer

## Dev overlay — per-tile foot-pixel shadow sampling (sprite path). Toggle **J**.

const TILE_PX: int = 16
const REFRESH_INTERVAL_SEC: float = 0.4

const COLOR_CLOUD: Color = Color(1.0, 0.12, 0.12, 0.58)
const COLOR_OBLIQUE: Color = Color(0.22, 0.42, 1.0, 0.52)
const COLOR_UNIFIED: Color = Color(0.12, 0.92, 0.28, 0.48)
const COLOR_BOTH: Color = Color(0.92, 0.18, 0.92, 0.62)
const COLOR_ACTOR_FOOT: Color = Color(1.0, 0.92, 0.12, 0.95)
const COLOR_ACTOR_MISMATCH: Color = Color(1.0, 0.45, 0.0, 0.95)

const CLOUD_MASK_GATE: float = 0.125
const OBLIQUE_ALPHA_GATE: float = 0.04
const UNIFIED_ALPHA_GATE: float = 0.04

var _grid: PlayerGrid
var _map_root: Node2D
var _ground: TileMapLayer
var _settings: EffectsSettings
var _actors: Array[CharacterActor] = []
var _container: Control
var _legend: PanelContainer
var _legend_body: Label
var _tile_overlay: TextureRect
var _tile_img: Image
var _tile_tex: ImageTexture
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
	_rebuild(false)


func _rebuild(_force: bool = false) -> void:
	if _grid == null or _map_root == null:
		return
	_ensure_tile_overlay()
	var zoom: float = _map_root.scale.x
	var origin_px: Vector2 = MapPixelSpace.origin_px(_ground)
	var size_px: Vector2 = MapPixelSpace.size_px(_ground, _grid)
	_tile_overlay.position = _map_root.to_global(origin_px)
	_tile_overlay.size = size_px * zoom
	_last_zoom = zoom

	var cloud_count: int = 0
	var oblique_count: int = 0
	var unified_count: int = 0
	var both_count: int = 0
	var want_cloud: bool = _settings != null and _settings.cloud_shadows
	var want_oblique: bool = _settings != null and _settings.oblique_contact_shadows
	var drift: Vector2 = WeatherBus.cloud_drift_offset

	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var cell: Vector2i = Vector2i(x, y)
			var map_px: Vector2 = ShadowPlacer.foot_map_px_from_cell(cell)
			var cloud_hit: bool = false
			var oblique_hit: bool = false
			var unified_hit: bool = false
			if want_cloud:
				cloud_hit = CloudShadowField.shadow_mask_at(map_px, drift) >= CLOUD_MASK_GATE
			if want_oblique:
				oblique_hit = (
					ShadowPlacer.sample_map_oblique_alpha_at(map_px, _settings) >= OBLIQUE_ALPHA_GATE
				)
			if not cloud_hit and not oblique_hit:
				unified_hit = (
					ShadowPlacer.sample_unified_shadow_alpha_at(map_px, _settings) >= UNIFIED_ALPHA_GATE
				)
			if cloud_hit:
				cloud_count += 1
			if oblique_hit:
				oblique_count += 1
			if unified_hit:
				unified_count += 1
			var color: Color = Color(0.0, 0.0, 0.0, 0.0)
			if cloud_hit and oblique_hit:
				both_count += 1
				color = COLOR_BOTH
			elif cloud_hit:
				color = COLOR_CLOUD
			elif oblique_hit:
				color = COLOR_OBLIQUE
			elif unified_hit:
				color = COLOR_UNIFIED
			_tile_img.set_pixel(x, y, color)

	_tile_tex.update(_tile_img)
	_paint_actor_feet(zoom)
	_update_legend(cloud_count, oblique_count, unified_count, both_count)
	_last_stamp = ShadowPlacer.cloud_drift_stamp(_settings)


func _ensure_tile_overlay() -> void:
	var need_new: bool = (
		_tile_overlay == null
		or not is_instance_valid(_tile_overlay)
		or _tile_img == null
		or _tile_img.get_width() != _grid.width
		or _tile_img.get_height() != _grid.height
	)
	if need_new:
		_tile_img = Image.create(_grid.width, _grid.height, false, Image.FORMAT_RGBA8)
		_tile_tex = ImageTexture.create_from_image(_tile_img)
		if _tile_overlay != null and is_instance_valid(_tile_overlay):
			_tile_overlay.queue_free()
		_tile_overlay = TextureRect.new()
		_tile_overlay.texture = _tile_tex
		_tile_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tile_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		_tile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tile_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		var cloud_mask: float = ShadowPlacer.tile_cloud_mask_at_foot(foot)
		var sprite_shaded: bool = (
			_settings != null
			and _settings.cloud_shadows
			and cloud_mask >= CLOUD_MASK_GATE
		)
		var tile_hit: bool = (
			_cell_in_grid(cell)
			and _settings != null
			and _settings.cloud_shadows
			and CloudShadowField.shadow_mask_at(
				ShadowPlacer.foot_map_px_from_cell(cell),
				WeatherBus.cloud_drift_offset,
			) >= CLOUD_MASK_GATE
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


func _update_legend(cloud_count: int, oblique_count: int, unified_count: int, both_count: int) -> void:
	var origin: Vector2i = MapPixelSpace.origin_cells(_ground)
	var lines: PackedStringArray = PackedStringArray([
		"Shadow hit debug (J) — one sample per tile (foot pixel)",
		"Updates ~%.1fs · red=cloud blue=oblique green=unified magenta=both" % REFRESH_INTERVAL_SEC,
		"Red tiles: %d · Blue: %d · Green: %d · Magenta: %d"
		% [cloud_count - both_count, oblique_count - both_count, unified_count, both_count],
		"Yellow foot = actor; orange = sprite/tile cloud mismatch",
		"Map origin cells: (%d, %d)" % [origin.x, origin.y],
	])
	_legend_body.text = "\n".join(lines)


func _teardown() -> void:
	if _tile_overlay != null and is_instance_valid(_tile_overlay):
		_tile_overlay.queue_free()
	_tile_overlay = null
	_tile_img = null
	_tile_tex = null
	for marker: ColorRect in _foot_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_foot_markers.clear()
