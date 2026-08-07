class_name QaPlanningMockViewport
extends SubViewport

## Headless viewport stub â€” returns a fixed screen mouse position for drag-drop E2E.

var mock_mouse: Vector2 = Vector2.ZERO


func get_mouse_position() -> Vector2:
	return mock_mouse
