class_name BiomeProfile
extends Resource

## Data-driven biome palette — separate PNG per variant (v01–v03 on disk).
## Future seasonal bundles may use atlas_y_offset instead of tileset_variant.

@export var display_name: String = "Rabite Forest"
@export_range(1, 3) var tileset_variant: int = 1
@export var particle_tint: Color = Color(1.0, 0.98, 0.62, 1.0)
@export var modulate_tint: Color = Color(1.0, 1.0, 1.0)
@export var mist_density_floor: float = 0.06
@export var atlas_y_offset: int = 0


static func for_variant(variant: int) -> BiomeProfile:
	var v: int = clampi(variant, 1, 3)
	var profile: BiomeProfile = BiomeProfile.new()
	profile.tileset_variant = v
	match v:
		1:
			profile.display_name = "Rabite Forest"
			profile.particle_tint = Color(1.0, 0.98, 0.62, 1.0)
			profile.modulate_tint = Color(1.0, 1.0, 1.0)
			profile.mist_density_floor = 0.06
		2:
			profile.display_name = "Jungle"
			profile.particle_tint = Color(0.72, 1.0, 0.55, 1.0)
			profile.modulate_tint = Color(1.02, 1.05, 0.94)
			profile.mist_density_floor = 0.14
		3:
			profile.display_name = "Moonlight"
			profile.particle_tint = Color(0.78, 0.88, 1.0, 1.0)
			profile.modulate_tint = Color(0.88, 0.92, 1.08)
			profile.mist_density_floor = 0.10
	return profile


static func variant_count() -> int:
	return 3
