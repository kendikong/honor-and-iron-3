extends SceneTree
func _init():
    print("Testing _module...")
    var DataLibrary = load("res://core/factory/data_library.gd")
    var m = DataLibrary._module(GameEnums.EffectType.SWAP, 0)
    print("m: ", m)
    quit()