extends SceneTree

func _init():
    var dir = DirAccess.open("res://tests")
    if dir == null:
        print("Failed to open tests dir")
        quit()
    print("Writing trace script")
    quit()