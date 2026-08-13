class_name ConstructPlaceholder
extends Node2D

## Deterministic tactical fallback for constructs without LPC sprite assets.
## The placeholder is deliberately tile-sized and static so every construct
## remains readable without adding per-frame simulation or animation work.

const TEAM_PLAYER := Color(0.25, 0.70, 1.0, 1.0)
const TEAM_ENEMY := Color(1.0, 0.28, 0.22, 1.0)

var _kind: StringName = &""
var _team_color: Color = TEAM_PLAYER


func configure(kind: StringName, team: int) -> void:
	_kind = kind
	_team_color = TEAM_PLAYER if team == GameEnums.Team.PLAYER else TEAM_ENEMY
	queue_redraw()


func _draw() -> void:
	var outline := Color(0.04, 0.05, 0.08, 1.0)
	draw_circle(Vector2(0.0, 6.0), 5.0, Color(0.02, 0.03, 0.04, 0.65))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, _team_color, 1.0)
	match _kind:
		&"construct_turret":
			draw_rect(Rect2(-6.0, -3.0, 12.0, 8.0), outline, true)
			draw_rect(Rect2(-5.0, -4.0, 10.0, 7.0), _team_color, true)
			draw_rect(Rect2(-2.0, -7.0, 4.0, 5.0), outline, true)
			draw_rect(Rect2(-1.0, -9.0, 2.0, 6.0), Color(1.0, 0.72, 0.20, 1.0), true)
		&"magnetic_mine":
			draw_circle(Vector2.ZERO, 5.0, outline)
			draw_circle(Vector2.ZERO, 3.5, Color(0.75, 0.18, 0.18, 1.0))
			draw_circle(Vector2.ZERO, 1.5, Color(1.0, 0.72, 0.20, 1.0))
		&"tesla_barricade":
			draw_rect(Rect2(-7.0, -5.0, 14.0, 10.0), outline, true)
			draw_rect(Rect2(-6.0, -4.0, 12.0, 8.0), Color(0.20, 0.62, 0.78, 1.0), true)
			draw_line(Vector2(-4.0, -3.0), Vector2(1.0, 3.0), Color(0.75, 0.95, 1.0, 1.0), 1.0)
			draw_line(Vector2(1.0, 3.0), Vector2(5.0, -3.0), Color(0.75, 0.95, 1.0, 1.0), 1.0)
		_:
			draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), outline, true)
			draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), _team_color, true)
			draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color(1.0, 0.78, 0.20, 1.0), true)
