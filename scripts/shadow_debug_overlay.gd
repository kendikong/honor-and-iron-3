class_name ShadowDebugOverlay
extends CanvasLayer

## Dev overlay — foot-pixel shadow sampling (same path as LPC body receive). Toggle **J**.

const TILE_PX: int = 16

const COLOR_CLOUD: Color = Color(1.0, 0.12, 0.12, 0.52)
const COLOR_OBLIQUE: Color = Color(0.22, 0.42, 1.0, 0.48)
const COLOR_UNIFIED: Color = Color(0.12, 0.92, 0.28, 0.42)
const COLOR_BOTH: Color = Color(0.92, 0.18, 0.92, 0.58)
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
var _heatmap: TextureRect
var _rebuild_stamp: int = -1


func _ready() -> void:
	layer = 12
	visible = false
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
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
	_rebuild_stamp = -1
	if visible:
		_rebuild()


func toggle() -> bool:
	visible = not visible
	_rebuild_stamp = -1
	if visible:
		_rebuild()
	else:
		_clear()
	return visible


func process_refresh() -> void:
	if not visible or _grid == null or _map_root == null:
		return
	if _settings != null:
		CloudTuning.sync_runtime(_settings)
	var stamp: int = ShadowPlacer.cloud_drift_stamp(_settings)
	if stamp == _rebuild_stamp:
		return
	_rebuild_stamp = stamp
	_rebuild()


func _rebuild() -> void:
	_clear()
	if _grid == null or _map_root == null:
		return
	_build_cpu_cloud_heatmap()
	var zoom: float = _map_root.scale.x
	var tile_px: float = float(TILE_PX) * zoom
	var cloud_count: int = 0
	var oblique_count: int = 0
	var unified_count: int = 0
	var both_count: int = 0
	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var cell: Vector2i = Vector2i(x, y)
			var cloud_hit: bool = _cell_cloud_hit(cell)
			var oblique_hit: bool = _cell_oblique_hit(cell)
			var unified_hit: bool = _cell_unified_hit(cell)
			if cloud_hit:
				cloud_count += 1
			if oblique_hit:
				oblique_count += 1
			if unified_hit:
				unified_count += 1
			if cloud_hit and oblique_hit:
				both_count += 1
				_add_cell_rect(cell, tile_px, COLOR_BOTH)
			elif cloud_hit:
				_add_cell_rect(cell, tile_px, COLOR_CLOUD)
			elif oblique_hit:
				_add_cell_rect(cell, tile_px, COLOR_OBLIQUE)
			elif unified_hit:
				_add_cell_rect(cell, tile_px, COLOR_UNIFIED)
	_paint_actor_feet(tile_px)
	_update_legend(cloud_count, oblique_count, unified_count, both_count)


func _build_cpu_cloud_heatmap() -> void:
	if _ground == null or _map_root == null:
		return
	var origin_px: Vector2 = MapPixelSpace.origin_px(_ground)
	var size_px: Vector2 = MapPixelSpace.size_px(_ground, _grid)
	var width_px: int = maxi(1, int(size_px.x))
	var height_px: int = maxi(1, int(size_px.y))
	var img: Image = Image.create(width_px, height_px, false, Image.FORMAT_RGBA8)
	var drift: Vector2 = WeatherBus.cloud_drift_offset
	for py: int in height_px:
		for px: int in width_px:
			var map_px: Vector2 = origin_px + Vector2(px, py)
			var mask: float = CloudShadowField.shadow_mask_at(map_px, drift)
			if mask < CLOUD_MASK_GATE:
				continue
			var alpha: float = clampf(mask, 0.0, 1.0) * 0.45
			img.set_pixel(px, py, Color(1.0, 0.1, 0.1, alpha))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_heatmap = TextureRect.new()
	_heatmap.texture = tex
	_heatmap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heatmap.stretch_mode = TextureRect.STRETCH_SCALE
	_heatmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_left: Vector2 = _map_root.to_global(origin_px)
	_heatmap.position = top_left
	_heatmap.size = size_px * _map_root.scale.x
	_container.add_child(_heatmap)
	_container.move_child(_heatmap, 0)


func _cell_cloud_hit(cell: Vector2i) -> bool:
	if _settings == null or not _settings.cloud_shadows:
		return false
	return ShadowPlacer.tile_cloud_mask_at_cell(cell) >= CLOUD_MASK_GATE


func _cell_oblique_hit(cell: Vector2i) -> bool:
	if _settings == null or not _settings.oblique_contact_shadows:
		return false
	var map_px: Vector2 = ShadowPlacer.foot_map_px_from_cell(cell)
	return ShadowPlacer.sample_map_oblique_alpha_at(map_px, _settings) >= OBLIQUE_ALPHA_GATE


func _cell_unified_hit(cell: Vector2i) -> bool:
	if _settings == null:
		return false
	var map_px: Vector2 = ShadowPlacer.foot_map_px_from_cell(cell)
	return ShadowPlacer.sample_unified_shadow_alpha_at(map_px, _settings) >= UNIFIED_ALPHA_GATE


func _paint_actor_feet(tile_px: float) -> void:
	if _actors.is_empty():
		return
	for actor: CharacterActor in _actors:
		if actor == null or not is_instance_valid(actor):
			continue
		var foot: Vector2 = actor.position
		var cell: Vector2i = ShadowPlacer.cell_from_foot_px(foot)
		var cloud_mask: float = ShadowPlacer.tile_cloud_mask_at_foot(foot)
		var sprite_shaded: bool = (
			_settings != null
			and _settings.cloud_shadows
			and cloud_mask >= CLOUD_MASK_GATE
		)
		var tile_hit: bool = _cell_in_grid(cell) and _cell_cloud_hit(cell)
		var color: Color = COLOR_ACTOR_FOOT
		if sprite_shaded != tile_hit:
			color = COLOR_ACTOR_MISMATCH
		var marker: ColorRect = ColorRect.new()
		var half: float = maxf(2.0, tile_px * 0.12)
		var global_foot: Vector2 = _map_root.to_global(foot)
		marker.position = global_foot - Vector2(half, half)
		marker.size = Vector2(half * 2.0, half * 2.0)
		marker.color = color
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.add_child(marker)


func _add_cell_rect(cell: Vector2i, tile_px: float, color: Color) -> void:
	var rect: ColorRect = ColorRect.new()
	var top_left: Vector2 = _map_root.to_global(MapPixelSpace.cell_top_left_px(_ground, cell))
	rect.position = top_left
	rect.size = Vector2(tile_px, tile_px)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(rect)


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
		"Shadow hit debug (J) — CPU foot-pixel sampling",
		"Dark red wash — full CPU cloud field (should match ground GPU)",
		"Red tile — cloud mask >= %.2f (%d cells)" % [CLOUD_MASK_GATE, cloud_count - both_count],
		"Blue tile — oblique alpha >= %.2f (%d cells)" % [OBLIQUE_ALPHA_GATE, oblique_count - both_count],
		"Green tile — unified ground CPU >= %.2f (%d cells)" % [UNIFIED_ALPHA_GATE, unified_count],
		"Magenta — cloud + oblique (%d cells)" % both_count,
		"Yellow foot — actor; orange — sprite/tile cloud mismatch",
		"Map origin cells: (%d, %d)" % [origin.x, origin.y],
	])
	_legend_body.text = "\n".join(lines)


func _clear() -> void:
	for child: Node in _container.get_children():
		if child == _legend:
			continue
		child.queue_free()
	_heatmap = null
