extends SceneTree
func _init():
    AbilityModuleBridge.finalize_ability(null)
    print("Bridge parsed successfully!")
    quit()