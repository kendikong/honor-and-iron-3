extends SceneTree

func _init():
    var d = load("res://core/factory/data_library.gd")
    var k = d.get_unit("knight")
    print("KNIGHT abilities size: " + str(k.abilities.size()))
    for i in range(k.abilities.size()):
        var a = k.abilities[i]
        print(" - [" + str(i) + "] = " + a.display_name)
    quit()