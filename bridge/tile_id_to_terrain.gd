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
			return DataLibrary.get_terrain(&"wall")
		TileId.Type.ROCK:
			return DataLibrary.get_terrain(&"wall")
		TileId.Type.RUIN:
			return DataLibrary.get_terrain(&"wall")
		TileId.Type.TREE:
			return DataLibrary.get_terrain(&"plain")
		_:
			return DataLibrary.get_terrain(&"plain")


static func tile_id_for_terrain(terrain: TerrainData) -> int:
	if terrain == null:
		return TileId.Type.GRASS
	match terrain.id:
		&"water", &"frozen":
			return TileId.Type.WATER
		&"dirt":
			return TileId.Type.DIRT
		&"forest", &"tall_grass":
			return TileId.Type.TREE
		&"wall", &"rock", &"ruin", &"castle":
			return TileId.Type.ROCK
		_:
			return TileId.Type.GRASS
