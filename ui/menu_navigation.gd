extends Node

var _registrations: Array[Dictionary] = []

## Register a menu screen so right-click calls the same handler as its Back button.
func register(owner: Node, on_back: Callable) -> void:
	unregister(owner)
	_registrations.append({"owner": owner, "on_back": on_back})
	if not owner.tree_exiting.is_connected(_on_owner_tree_exiting):
		owner.tree_exiting.connect(_on_owner_tree_exiting.bind(owner))

func unregister(owner: Node) -> void:
	for i in range(_registrations.size() - 1, -1, -1):
		if _registrations[i]["owner"] == owner:
			_registrations.remove_at(i)

func _on_owner_tree_exiting(owner: Node) -> void:
	unregister(owner)

## Runs before GUI eats mouse events on full-screen ColorRect backdrops.
func _input(event: InputEvent) -> void:
	for i in range(_registrations.size() - 1, -1, -1):
		var reg: Dictionary = _registrations[i]
		var owner: Node = reg["owner"]
		if not is_instance_valid(owner) or not owner.is_visible_in_tree():
			continue
		if try_back(event, reg["on_back"]):
			get_viewport().set_input_as_handled()
			return

func try_back(event: InputEvent, on_back: Callable) -> bool:
	if not on_back.is_valid():
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		on_back.call()
		return true
	return false
