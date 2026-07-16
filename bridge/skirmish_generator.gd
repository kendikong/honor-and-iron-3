class_name SkirmishGenerator
extends RefCounted

## Procedural skirmish map generation wrapper (Phase 2 implementation).

class SkirmishConfig:
	var size_preset: Vector2i = Vector2i(32, 16)
	var map_seed: int = 42
	var biome_variant: int = 1


class SkirmishResult:
	var grid: PlayerGrid
	var map_seed: int
	var biome_variant: int


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
	return result
