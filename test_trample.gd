extends SceneTree

func _init() -> void:
	var def := KnightFactory.build(WeaponData.new())
	var trample: AbilityData = null
	for a in def.abilities:
		if a.id == &'knight_trampling_advance':
			trample = a
			break
	var origin = Vector2i(6, 3)
	var target = Vector2i(7, 3)
	var is_valid = AbilitySystem.planning_is_valid_awaiting_endpoint(origin, target, trample)
	print("is_valid: %s" % is_valid)
	print("phase: %s" % AbilitySystem.planning_awaiting_phase(trample))
	print("range: %s" % AbilitySystem.planning_awaiting_endpoint_range(trample))
	quit()

