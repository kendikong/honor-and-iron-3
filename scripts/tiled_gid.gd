class_name TiledGid
extends RefCounted

const FLIP_H: int = 0x80000000
const FLIP_V: int = 0x40000000
const FLIP_D: int = 0x20000000
const ID_MASK: int = 0x1FFFFFFF


static func decode(gid: int) -> Dictionary:
	return {
		"id": gid & ID_MASK,
		"flip_h": (gid & FLIP_H) != 0,
		"flip_v": (gid & FLIP_V) != 0,
		"flip_d": (gid & FLIP_D) != 0,
	}


static func alternative_from_flips(decoded: Dictionary) -> int:
	var alt: int = 0
	if decoded.get("flip_h", false):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if decoded.get("flip_v", false):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if decoded.get("flip_d", false):
		# Tiled diagonal flip → Godot transpose (Godot 4.7)
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt
