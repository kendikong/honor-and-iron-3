extends SceneTree

func _init():
    var d = load("res://core/factory/data_library.gd")
    d.get_unit("knight") # to initialize dict
    var k = d.get_unit("knight")
    print("KNIGHT passives size: " + str(k.passives.size()))
    for i in range(k.passives.size()):
        print(" - [" + str(i) + "] = " + str(k.passives[i]))
    var td = d.get_unit("training_dummy")
    print("DUMMY passives size: " + str(td.passives.size()))
    for i in range(td.passives.size()):
        print(" - [" + str(i) + "] = " + str(td.passives[i]))
    quit()