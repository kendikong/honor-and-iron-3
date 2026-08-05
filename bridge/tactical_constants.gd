class_name TacticalConstants
extends RefCounted

## Shared grid + presentation constants for Honor & Iron 3.
## One mana-seed tile (16Ã—16 px) equals one tactics cell.

const TILE_PX: int = 16
const CELL: int = TILE_PX

## Target on-screen character height in tiles (before user scale slider).
const CHARACTER_HEIGHT_TILES: float = 1.5
const CHARACTER_HEIGHT_PX: float = TILE_PX * CHARACTER_HEIGHT_TILES

## LPC sheet frame size (Universal LPC).
const LPC_FRAME_PX: int = 64

## Default tactical character scale: 1.5 tiles tall at multiplier 1.0.
static func default_character_scale() -> float:
	return CHARACTER_HEIGHT_PX / float(LPC_FRAME_PX)


## Skirmish map size presets (width Ã— height tiles, 2:1 aspect).
const SKIRMISH_PRESETS: Array[Vector2i] = [
	Vector2i(16, 8),
	Vector2i(20, 10),
	Vector2i(24, 12),
	Vector2i(28, 14),
	Vector2i(32, 16),
	Vector2i(36, 18),
	Vector2i(40, 20),
]
