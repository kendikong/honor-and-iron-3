extends SceneTree
func _initialize() -> void:
    print("HELLO WORLD")
    print(DataLibrary.get_unit(&"knight"))
    quit(0)
