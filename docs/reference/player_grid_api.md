# PlayerGrid API (Phase 10)

Tactics-ready export of the **Player Grid** (logical terrain). Visual decoration on `TileMapLayer` nodes is not included — only logical `TileId` per cell.

## Tile IDs

| `TileId.Type` | Value | Walkable | Notes |
|---------------|-------|----------|-------|
| `GRASS` | 0 | yes | Default fill |
| `WATER` | 1 | no | Blocks movement |
| `DIRT` | 2 | yes | Paths / worn ground |
| `TREE` | 3 | partial | Anchor cell only; **trunk** blocks at render center + 2 south (see overlay) |
| `RUIN` | 4 | no | Structure obstacle |
| `ROCK` | 5 | no | Obstacle (not walkable) |

Walk rules live in `scripts/walkability.gd` + `scripts/tree_gameplay.gd` — **walkable:** `GRASS`, `DIRT` only, minus overlay blocks from live TileMap layers:

- **80×96 trees:** single cell at trunk foot row (+ shadow nudge).
- **32×32 props:** stump/boulder 1×1 upper-west; bush 1×2 west column; tall plant walkable.

Pass `TreeLayer` + `OverlayLayer` into `Walkability.is_walkable` / `CharacterGridMover`.

**Debug:** F5 test map → **K** toggles walkability overlay (blue=logical, red=trunk, green=prop walkable spill, magenta=prop block).

## Runtime API

### `PlayerGrid`

```gdscript
var grid := PlayerGrid.new(32, 32, TileId.Type.GRASS)
var t := grid.get_cell(Vector2i(4, 7))
grid.set_cell(Vector2i(4, 7), TileId.Type.WATER)
```

### `Walkability`

```gdscript
Walkability.is_walkable(grid, Vector2i(3, 5), tree_layer, overlay_layer)
Walkability.is_walkable_tile(TileId.Type.GRASS)
Walkability.find_spawn_cell(grid, Vector2i(16, 16), tree_layer, overlay_layer)
```

### `CharacterGridMover`

Uses `Walkability.is_walkable` for WASD / arrow grid steps (16 px per cell, 8-way; diagonal steps take √2× longer).

## Export format (JSON)

Written by `PlayerGrid.to_export_dict()` / `save_export()`.

```json
{
  "version": 1,
  "width": 32,
  "height": 32,
  "seed": 123456789,
  "tile_enum": ["GRASS", "WATER", "DIRT", "TREE", "RUIN", "ROCK"],
  "tile_ids": [0, 0, 1, 3, ...],
  "walkable": [true, true, false, false, ...]
}
```

- **`tile_ids`:** row-major flat array, length `width * height`, index `y * width + x`.
- **`walkable`:** optional parallel bool mask (derived from `Walkability`).
- **`seed`:** map generator seed at export time (`-1` if unknown).

### Load export

```gdscript
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
var grid: PlayerGrid = PlayerGrid.from_export_dict(data)
```

## In-game export

**F5** test map → press **E** → writes `user://player_grid_export.json` and prints path to Output.

## Provenance (optional)

`PlayerGridProvenance` stores per-cell repair/generator history for debugging — not required for tactics import. See `scripts/player_grid_provenance.gd`.

## Related files

| File | Role |
|------|------|
| `scripts/player_grid.gd` | Data grid + export |
| `scripts/walkability.gd` | Movement rules |
| `scripts/tile_id.gd` | Enum + names |
| `scripts/map_generator.gd` | Procedural fill |
| `scripts/lpc/character_grid_mover.gd` | Player-style grid actor |
