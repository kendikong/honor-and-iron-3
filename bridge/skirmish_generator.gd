class_name SkirmishGenerator
extends RefCounted

## Procedural skirmish map generation — grid, walkability bake, MVP spawns.

class SkirmishConfig:
	var size_preset: Vector2i = Vector2i(32, 16)
	var map_seed: int = 42
	var biome_variant: int = 1


class SkirmishResult:
	var grid: PlayerGrid
	var map_seed: int
	var biome_variant: int
	var blocked_cells: Dictionary = {}
	var player_spawns: Array[UnitPlacement] = []
	var enemy_spawns: Array[UnitPlacement] = []


static func preset_index_for_size(size: Vector2i) -> int:
	for i: int in range(TacticalConstants.SKIRMISH_PRESETS.size()):
		if TacticalConstants.SKIRMISH_PRESETS[i] == size:
			return i
	return -1


static func generate(config: SkirmishConfig) -> SkirmishResult:
	var generator := MapGenerator.new()
	generator.width = config.size_preset.x
	generator.height = config.size_preset.y
	generator.map_seed = config.map_seed
	generator.force_custom_size = true
	generator.water_ratio = 0.22

	var result := SkirmishResult.new()
	result.grid = generator.generate()
	result.map_seed = config.map_seed
	result.biome_variant = config.biome_variant
	result.blocked_cells = WalkabilityBaker.bake(result.grid, null, null, null, null)
	var roster: Dictionary = SpawnPlacer.place_mvp_roster(
		result.grid,
		result.blocked_cells,
		config.map_seed,
	)
	result.player_spawns = roster["player_spawns"]
	result.enemy_spawns = roster["enemy_spawns"]
	return result


static func generate_encounter(config: SkirmishConfig) -> EncounterData:
	var skirmish: SkirmishResult = generate(config)
	return EncounterBuilder.build_from_player_grid(
		skirmish.grid,
		skirmish.blocked_cells,
		skirmish.player_spawns,
		skirmish.enemy_spawns,
	)
