param (
    [string]
)
 = Get-Content  -Raw
 =  -replace 'func _sanitize_drag_route_context\(\) -> void:', "func _sanitize_drag_route_context() -> void:
	print("[DEBUG-DRAG] sanitize route: ", _drag_route)"
 =  -replace 'var basic_fallback: bool = false', "var basic_fallback: bool = false
	print("[DEBUG-DRAG] ability: ", ability.id if ability != null else "null")"
 =  -replace 'if not MovementSystem._is_legal_walk\(board, _drag_route\[0\], waypoints, budget, move_cost, unit, null\):', "print("[DEBUG-DRAG] legal_walk checking waypoints: ", waypoints, " budget: ", budget)
	if not MovementSystem._is_legal_walk(board, _drag_route[0], waypoints, budget, move_cost, unit, null):
		print("[DEBUG-DRAG] legal walk failed! find_path fallback")"
[IO.File]::WriteAllText(, )