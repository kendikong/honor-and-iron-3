class_name TileId
extends RefCounted

enum Type {
	GRASS,
	WATER,
	DIRT,
	TREE,
	RUIN,
	ROCK,
}


static func type_name(tile_id: int) -> String:
	if tile_id < 0 or tile_id >= Type.size():
		return "?"
	return Type.keys()[tile_id]


static func type_abbrev(tile_id: int) -> String:
	match tile_id:
		Type.GRASS:
			return "GRS"
		Type.WATER:
			return "WAT"
		Type.DIRT:
			return "DRT"
		Type.TREE:
			return "TRE"
		Type.RUIN:
			return "RUI"
		Type.ROCK:
			return "ROK"
		_:
			return "???"
