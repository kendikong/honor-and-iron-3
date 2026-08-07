extends RefCounted

## Shared TileSet source / terrain indices. Preload this script â€” do not use class_name.
## Example: const C = preload("res://scripts/mana_seed_constants.gd")

const SOURCE_FOREST: int = 0
const SOURCE_WATERFALL: int = 1
const SOURCE_TREES: int = 2
const SOURCE_SPARKLES: int = 3
const SOURCE_PROPS_32: int = 4

const TERRAIN_SET: int = 0
const TERRAIN_DIRT: int = 0
const TERRAIN_ELEVATION: int = 1
const TERRAIN_WATER: int = 2

const ASSET_ROOT: String = "res://Assets/Mana Seed/"
const FOREST_TSX: String = "res://Assets/Mana Seed/gentle forest v01.tsx"
const BAKED_COMBINED_PATH: String = "res://resources/tilesets/mana_seed_combined_v01.tres"

const MIN_TILESET_VARIANT: int = 1
const MAX_TILESET_VARIANT: int = 3


static func variant_suffix(variant: int) -> String:
	return "v%02d" % clampi(variant, MIN_TILESET_VARIANT, MAX_TILESET_VARIANT)


static func tsx_path(sheet_name: String, variant: int = 1) -> String:
	return ASSET_ROOT + "%s %s.tsx" % [sheet_name, variant_suffix(variant)]


static func baked_combined_path(variant: int = 1) -> String:
	return "res://resources/tilesets/mana_seed_combined_%s.tres" % variant_suffix(variant)

const GID_FOREST_START: int = 1
const GID_WATERFALL_START: int = 257
const GID_TREES_START: int = 317
const GID_SPARKLES_START: int = 319
const GID_PROPS_START: int = 328

## MapRoot draw order (bottom â†’ top). Contact shadows darken ground; rocks/props above shadow.
const Z_GROUND: int = 0
const Z_UNDER_TREE: int = 1
const Z_SHADOW: int = 1
const Z_OVERLAY: int = 2
const Z_ECOLOGY: int = 3
const Z_VFX: int = 4
const Z_TREE: int = 5
const Z_BIRD: int = 6
const Z_SKY: int = 7
