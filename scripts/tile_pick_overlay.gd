class_name TilePickOverlay
extends CanvasLayer

## Hover highlight + click-to-lock. Uses map_root canvas transform + top-left grid math.

const TILE_PX: int = 16

var _highlight: ColorRect
var _map_root: Node2D
var _grid: PlayerGrid
var _phantom: TileMapLayer
var _inspector: TileInspectorPanel
var _left_inset: int = 300
var _right_inset: int = 520
var _last_cell: Vector2i = Vector2i(-9999, -9999)
var _last_mouse_px: Vector2i = Vector2i(-9999, -9999)
var _map_transform: Transform2D = Transform2D.IDENTITY
var _map_transform_dirty: bool = true


func _ready() -> void:
	layer = 15
	_highlight = ColorRect.new()
	_highlight.color = Color(1.0, 0.92, 0.35, 0.22)
	_highlight.visible = false
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)
	set_process(true)


func setup(
	map_root: Node2D,
	grid: PlayerGrid,
	inspector: TileInspectorPanel,
	phantom: TileMapLayer = null,
	_ground: TileMapLayer = null,
) -> void:
	_map_root = map_root
	_grid = grid
	_phantom = phantom
	_inspector = inspector
	_map_transform_dirty = true
	_last_cell = Vector2i(-9999, -9999)
	_last_mouse_px = Vector2i(-9999, -9999)
	if inspector != null:
		_right_inset = inspector.panel_width()


func set_chrome_insets(left_px: int, right_px: int) -> void:
	_left_inset = maxi(left_px, 0)
	_right_inset = maxi(right_px, 0)
	_map_transform_dirty = true


func sync_grid(grid: PlayerGrid) -> void:
	_grid = grid
	_last_cell = Vector2i(-9999, -9999)


func _process(_delta: float) -> void:
	if _map_root == null or _grid == null:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if not _is_over_map(mouse):
		return
	var mouse_px: Vector2i = Vector2i(int(mouse.x), int(mouse.y))
	if mouse_px == _last_mouse_px:
		return
	_last_mouse_px = mouse_px
	var cell: Vector2i = _mouse_to_cell(mouse)
	if not _is_inspectable(cell):
		_highlight.visible = false
		if _inspector != null:
			_inspector.set_hover_cell(Vector2i(-1, -1))
		return
	if cell == _last_cell:
		return
	_last_cell = cell
	_update_highlight(cell, _is_phantom_cell(cell))
	if _inspector != null:
		_inspector.set_hover_cell(cell)


func _unhandled_input(event: InputEvent) -> void:
	if _map_root == null or _grid == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse: Vector2 = event.position
			if not _is_over_map(mouse):
				return
			var cell: Vector2i = _mouse_to_cell(mouse)
			if _is_inspectable(cell) and _inspector != null:
				_inspector.set_selected_cell(cell)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _inspector != null:
			_inspector.clear_selection()
			get_viewport().set_input_as_handled()


func _mouse_to_cell(screen_pos: Vector2) -> Vector2i:
	if _map_root == null:
		return Vector2i(-1, -1)
	if _map_transform_dirty:
		_map_transform = _map_root.get_global_transform_with_canvas()
		_map_transform_dirty = false
	var local: Vector2 = _map_transform.affine_inverse() * screen_pos
	return Vector2i(floori(local.x / float(TILE_PX)), floori(local.y / float(TILE_PX)))


func _is_over_map(mouse: Vector2) -> bool:
	var viewport_w: float = get_viewport().get_visible_rect().size.x
	return mouse.x >= float(_left_inset) and mouse.x < viewport_w - float(_right_inset)


func mark_transform_dirty() -> void:
	_map_transform_dirty = true
	_last_cell = Vector2i(-9999, -9999)
	_last_mouse_px = Vector2i(-9999, -9999)


func _update_highlight(cell: Vector2i, is_phantom: bool = false) -> void:
	if _map_root == null:
		return
	if _map_transform_dirty:
		_map_transform = _map_root.get_global_transform_with_canvas()
		_map_transform_dirty = false
	_highlight.color = (
		Color(0.55, 0.88, 1.0, 0.32) if is_phantom else Color(1.0, 0.92, 0.35, 0.22)
	)
	var zoom: float = _map_root.scale.x
	var tile_px: float = TILE_PX * zoom
	var top_left: Vector2 = _map_transform * (Vector2(cell) * float(TILE_PX))
	_highlight.position = top_left
	_highlight.size = Vector2(tile_px, tile_px)
	_highlight.visible = true


func _in_grid(cell: Vector2i) -> bool:
	if _grid == null:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid.width and cell.y < _grid.height


func _is_phantom_cell(cell: Vector2i) -> bool:
	return not _in_grid(cell) and _phantom != null and _phantom.get_cell_source_id(cell) != -1


func _is_inspectable(cell: Vector2i) -> bool:
	if _in_grid(cell):
		return true
	return _is_phantom_cell(cell)
