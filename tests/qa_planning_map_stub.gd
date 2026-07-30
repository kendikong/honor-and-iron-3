class_name QaPlanningMapStub
extends Node2D

## Headless map stub for drag-drop E2E (grid ↔ screen, mock mouse). Assigned via set("_map_view", …).

var _qa_viewport: QaPlanningMockViewport


func _init() -> void:
	_qa_viewport = QaPlanningMockViewport.new()


func get_viewport() -> Viewport:
	return _qa_viewport


func set_mock_mouse_for_cell(cell: Vector2i) -> void:
	var t: float = float(TacticalConstants.TILE_PX)
	_qa_viewport.mock_mouse = Vector2(cell) * t + Vector2(t * 0.5, t * 0.5)


func grid_to_local(cell: Vector2i) -> Vector2:
	var t: float = float(TacticalConstants.TILE_PX)
	return Vector2(cell) * t + Vector2(t, t) * 0.5


func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var t: float = float(TacticalConstants.TILE_PX)
	return Vector2i(int(floor(screen_pos.x / t)), int(floor(screen_pos.y / t)))


func get_local_mouse_position() -> Vector2:
	return grid_to_local(screen_to_grid(_qa_viewport.mock_mouse))
