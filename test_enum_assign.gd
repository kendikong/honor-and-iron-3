extends SceneTree
func _init():
    var m = AbilityModule.new()
    m.primary_type = GameEnums.EffectType.SWAP
    print("Direct assignment: ", m.primary_type)
    
    var t: GameEnums.EffectType = GameEnums.EffectType.SWAP
    m.primary_type = t
    print("Variable assignment: ", m.primary_type)
    quit()