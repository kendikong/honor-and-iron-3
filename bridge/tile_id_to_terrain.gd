class_name TileIdToTerrain
extends RefCounted

## Maps mana-seed PlayerGrid TileId values to H&I TerrainData definitions.

static func terrain_for_tile_id(tile_id: int) -> TerrainData:
	match tile_id:
		TileId.Type.GRASS:
			return DataLibrary.get_terrain(&"plain")
		TileId.Type.DIRT:
			return DataLibrary.get_terrain(&"plain")
		TileId.Type.WATER:
			return DataLibrary.get_terrain(&"water")
		TileId.Type.ROCK:
			return DataLibrary.get_terrain(&"wall")
		TileId.Type.RUIN:
			return DataLibrary.get_terrain(&"plain")
		TileId.Type.TREE:
			return DataLibrary.get_terrain(&"plain")
		_:
			return DataLibrary.get_terrain(&"plain")
