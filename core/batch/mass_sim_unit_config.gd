class_name MassSimUnitConfig
extends RefCounted


static func build(
	def: UnitData,
	team: int,
	map_seed: int,
	slot: int,
	setup: MassSimSkirmishSetup,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(Vector3i(map_seed, slot, team + 17)))
	var level: int = setup.player_level if team == GameEnums.Team.PLAYER else setup.enemy_level
	var config: Dictionary = {"level": level}
	if team == GameEnums.Team.PLAYER:
		if not def.is_construct:
			config["active_passives"] = _pick_passives(def.passives, setup.player_passive_count, rng)
		config["active_abilities"] = DataLibrary.build_player_active_abilities_seeded(
			def, setup.player_class_skill_count, rng,
		)
	else:
		config["active_passives"] = def.passives.duplicate()
		config["active_abilities"] = def.abilities.duplicate()
	return config


static func _pick_passives(pool: Array[PassiveData], count: int, rng: RandomNumberGenerator) -> Array[PassiveData]:
	var remaining: Array[PassiveData] = pool.duplicate()
	var out: Array[PassiveData] = []
	for _i: int in range(mini(count, remaining.size())):
		var idx: int = rng.randi() % remaining.size()
		out.append(remaining[idx])
		remaining.remove_at(idx)
	return out
