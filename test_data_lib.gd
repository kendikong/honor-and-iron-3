extends SceneTree
func _init():
    print("Testing DataLibrary...")
    var k = DataLibrary.get_unit(&"knight")
    for a in k.abilities:
        print(a.id, " modules:")
        for m in a.modules:
            print("  ", m.primary_type, " - ", GameEnums.EffectType.keys()[m.primary_type])
    quit()