extends SceneTree
func _init():
    var m = AbilityModule.new()
    print("Type of primary_type: ", typeof(m.primary_type))
    var val = m.get("primary_type")
    print("Value: ", val, " Type: ", typeof(val))
    quit()