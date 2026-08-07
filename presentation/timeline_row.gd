class_name TimelineRow
extends HBoxContainer

## Purpose: One draggable entry in the plan list. Carries its own index and a drop
## handler so the player can drag a row onto another to reorder the timeline.
## Pure presentation: it only reports indices; the CombatDirector reorders the plan.

var index: int = -1
## Called as drop_handler.call(from_index, to_index) when another row is dropped here.
var drop_handler: Callable

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "Move action %d" % (index + 1)
	preview.add_theme_color_override("font_color", Color.html("fde08a"))
	set_drag_preview(preview)
	return {"timeline_index": index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("timeline_index")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if drop_handler.is_valid():
		drop_handler.call(int(data["timeline_index"]), index)
