class_name ClassIconDrawer
extends RefCounted

## Vector class icons for tactical aim mode (ported from board_view).


static func draw_icon(canvas: CanvasItem, center: Vector2, class_id: StringName, color: Color, scale: float = 1.0) -> void:
	var c: Vector2 = center
	var s: float = maxf(scale, 0.5)
	match class_id:
		&"knight":
			var pts := PackedVector2Array([
				c + Vector2(-5, 8) * s,
				c + Vector2(-5, 0) * s,
				c + Vector2(-1, -7) * s,
				c + Vector2(5, -7) * s,
				c + Vector2(7, -3) * s,
				c + Vector2(2, 0) * s,
				c + Vector2(4, 8) * s,
			])
			canvas.draw_polygon(pts, [color])
		&"swordmaster":
			var start := c + Vector2(-6, 6) * s
			var tip := c + Vector2(6, -6) * s
			var dir: Vector2 = (tip - start).normalized()
			var perp := Vector2(-dir.y, dir.x)
			canvas.draw_line(start, tip, color, 3.0 * s)
			var guard_pos := start + dir * 4.0 * s
			canvas.draw_line(guard_pos - perp * 5.0 * s, guard_pos + perp * 5.0 * s, color, 3.0 * s)
			canvas.draw_line(start, guard_pos, color, 2.0 * s)
		&"archer":
			canvas.draw_arc(c + Vector2(-3, 0) * s, 7.0 * s, -PI / 2.0, PI / 2.0, 12, color, 2.5 * s)
			canvas.draw_line(c + Vector2(-3, -7) * s, c + Vector2(-3, 7) * s, color, 1.0 * s)
			canvas.draw_line(c + Vector2(-5, 0) * s, c + Vector2(4, 0) * s, color, 2.0 * s)
			var arrow_pts := PackedVector2Array([
				c + Vector2(6, 0) * s,
				c + Vector2(1, -4) * s,
				c + Vector2(1, 4) * s,
			])
			canvas.draw_polygon(arrow_pts, [color])
		&"mage":
			var pts := PackedVector2Array([
				c + Vector2(0, -9) * s,
				c + Vector2(2.5, -2.5) * s,
				c + Vector2(9, 0) * s,
				c + Vector2(2.5, 2.5) * s,
				c + Vector2(0, 9) * s,
				c + Vector2(-2.5, 2.5) * s,
				c + Vector2(-9, 0) * s,
				c + Vector2(-2.5, -2.5) * s,
			])
			canvas.draw_polygon(pts, [color])
		_:
			canvas.draw_circle(c, 6.0 * s, color)
