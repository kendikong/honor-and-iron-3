extends SceneTree
func _init():
    var script = load("res://core/systems/ability_system.gd")
    print("Loaded: ", script != null)
    quit()