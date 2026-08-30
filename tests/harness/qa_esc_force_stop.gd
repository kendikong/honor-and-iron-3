extends Node
## Terminates GdUnit / live QA immediately when ESC is pressed.


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_esc(event):
		return
	_force_stop()
	get_viewport().set_input_as_handled()


func _is_esc(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	)


func _force_stop() -> void:
	var signals := GdUnitSignals.instance()
	if signals != null:
		signals.gdunit_test_session_terminate.emit()
	get_tree().quit(130)
