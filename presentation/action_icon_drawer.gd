class_name ActionIconDrawer
extends RefCounted

## Small vector action icons for planning cursor (screen-stable size via caller scale).


static func draw(canvas: CanvasItem, center: Vector2, icon_key: String, color: Color, scale: float = 1.0) -> void:
	var s: float = maxf(scale, 0.35)
	var c: Vector2 = center
	match icon_key:
		"move":
			canvas.draw_line(c + Vector2(-4, 3) * s, c + Vector2(4, -3) * s, color, 2.0 * s)
			canvas.draw_line(c + Vector2(4, -3) * s, c + Vector2(1, -3) * s, color, 2.0 * s)
			canvas.draw_line(c + Vector2(4, -3) * s, c + Vector2(4, 0) * s, color, 2.0 * s)
		"attack":
			canvas.draw_line(c + Vector2(-5, 5) * s, c + Vector2(5, -5) * s, color, 2.5 * s)
			canvas.draw_line(c + Vector2(-2, 5) * s, c + Vector2(-5, 2) * s, color, 2.0 * s)
		"dash":
			for i: int in 4:
				var ang: float = float(i) * TAU / 4.0 + PI * 0.25
				var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * 5.0 * s
				canvas.draw_line(c, p, color, 1.5 * s)
		"heal":
			canvas.draw_rect(Rect2(c.x - 1.5 * s, c.y - 5.0 * s, 3.0 * s, 10.0 * s), color, true)
			canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y - 1.5 * s, 10.0 * s, 3.0 * s), color, true)
		"armor":
			var pts := PackedVector2Array([
				c + Vector2(0, -5) * s,
				c + Vector2(5, -2) * s,
				c + Vector2(4, 5) * s,
				c + Vector2(-4, 5) * s,
				c + Vector2(-5, -2) * s,
			])
			canvas.draw_polyline(pts, color, 2.0 * s, true)
		"swap":
			canvas.draw_arc(c + Vector2(-2, 0) * s, 3.5 * s, 0.0, PI, 8, color, 1.8 * s)
			canvas.draw_arc(c + Vector2(2, 0) * s, 3.5 * s, PI, TAU, 8, color, 1.8 * s)
		"wait":
			canvas.draw_line(c + Vector2(-4, 0) * s, c + Vector2(4, 0) * s, color, 2.0 * s)
			canvas.draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 2) * s, color, 2.0 * s)
		"null":
			canvas.draw_arc(c, 5.5 * s, 0.0, TAU, 20, color, 2.2 * s)
			canvas.draw_line(c + Vector2(-4, 4) * s, c + Vector2(4, -4) * s, color, 2.2 * s)
		_:
			canvas.draw_circle(c, 3.0 * s, color)


static func key_from_emoji(emoji: String) -> String:
	match emoji:
		PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_RUN:
			return "move"
		PlanningIcons.GLYPH_ATTACK:
			return "attack"
		PlanningIcons.GLYPH_DASH:
			return "dash"
		PlanningIcons.GLYPH_NULL:
			return "null"
		PlanningIcons.GLYPH_HEAL:
			return "heal"
		PlanningIcons.GLYPH_ARMOR_UP, PlanningIcons.STAT_DEF, PlanningIcons.STAT_ARMOR:
			return "armor"
		PlanningIcons.GLYPH_SWAP:
			return "swap"
		PlanningIcons.GLYPH_WAIT:
			return "wait"
		PlanningIcons.GLYPH_SKILL, PlanningIcons.STAT_MAG:
			return "skill"
	return "skill"
