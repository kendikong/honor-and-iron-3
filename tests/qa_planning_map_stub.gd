class_name QaPlanningMapStub
extends Node2D

## Headless map stub for drag-drop E2E (grid â†” screen). Assigned via set("_map_view", â€¦).
## Mouse position is injected on CombatPlanningInput.set_qa_pointer_screen_pos â€” do not
## override Node2D.get_viewport / get_local_mouse_position (engine will not call them).

var _mock_screen_mouse: Vector2 = Vector2.ZERO


func set_mock_mouse_for_cell(cell: Vector2i) -> void:
	var t: float = float(TacticalConstants.TILE_PX)
	_mock_screen_mouse = Vector2(cell) * t + Vector2(t * 0.5, t * 0.5)


func get_mock_screen_mouse() -> Vector2:
	return _mock_screen_mouse


func grid_to_local(cell: Vector2i) -> Vector2:
	var t: float = float(TacticalConstants.TILE_PX)
	return Vector2(cell) * t + Vector2(t, t) * 0.5


func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var t: float = float(TacticalConstants.TILE_PX)
	return Vector2i(int(floor(screen_pos.x / t)), int(floor(screen_pos.y / t)))
