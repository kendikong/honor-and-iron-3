# How Tile Neighbor Matching Works (Mana Seed + Godot 4.7)

Plain-language guide for Phase 3 terrain. Read this before judging whether shores look "wrong."

---

## The idea in one sentence

**You don't pick edge tiles by hand — you tell Godot what terrain each cell is, and the TileSet picks the atlas tile whose edge/corner flags match the neighbors.**

---

## Three layers

| Layer | What it is | Example |
|-------|------------|---------|
| **PlayerGrid** | Logical data | `GRASS`, `WATER`, `DIRT` |
| **Terrain metadata** | Per-atlas-tile rules in TileSet | "tile #129 is water; top-right corner touches grass" |
| **GroundLayer** | Painted result | Actual `#129` shore sprite |

Our Auto-Decorator converts PlayerGrid → GroundLayer. Phase 3 uses Godot **TerrainSet 0** for dirt / elevation / water.

---

## Mana Seed Wang rules (from `gentle forest v01.tsx`)

Three terrain colors on grass:

| Wang value | Color in Tiled | Godot terrain | Visual role |
|------------|----------------|---------------|-------------|
| 0 | (none) | `-1` empty / grass | Open field |
| 1 | red | `TERRAIN_DIRT` (0) | Paths |
| 2 | green | `TERRAIN_ELEVATION` (1) | Rock cliffs / ledges |
| 3 | blue | `TERRAIN_WATER` (2) | Ponds + shores |

Each wang tile (e.g. `#129`) stores **8 corner/side flags** — what terrain sits on each edge of *that sprite*, not what's in the neighboring cell.

**Important:** Water shore tiles **look like brown rocky edges** — that's correct shoreline art, not grass cliff bugs.

---

## What Godot needs (two steps)

### 1. TileSet setup (`tile_set_factory.gd`)

For every wang tile in the `.tsx`:

- `terrain_set` + `terrain` (which family: dirt / elevation / water)
- `set_terrain_peering_bit()` on all 8 corners/sides (parsed from `wangid`)

Without peering bits, `set_cells_terrain_connect()` guesses and picks wrong sprites.

### 2. Paint pass (`auto_decorator.gd`)

```text
1. set_cells_terrain_connect(dirt_cells)   — dirt paths
2. set_cells_terrain_connect(water_cells) — ponds + shores
3. Paint #97/#98 only on GRASS/TREE cells still empty (deferred interiors)
4. Overlay scatter (weeds, crops) — does NOT peer; sits on top
```

Godot may also adjust cells adjacent to a terrain batch so borders agree.

---

## Tiles you should never random-roll as grass

| Local ID | Why |
|----------|-----|
| `#83`, `#99` | Elevation wang — cliff faces |
| `#0`–`#51` | Dirt wang — path edges |
| `#128`–`#179` | Water wang — shores / deep water |

Safe grass interiors: `#97`, `#98` (no terrain assignment). Overlay flora (`#90` flowers, etc.) never on GroundLayer.

Tree ground (not grass): `#29`, `#30`, `#47` — trunk/base art composed with overlay trees in the sample map.

---

## How to verify (with debug overlay **L**)

| Check | Good | Bad |
|-------|------|-----|
| Open grass | `GRS` + `#97`/`#98` | `GRS` + `#83`/`#99`/`#47` (tree base) |
| Open grass + flora | `GRS` + `#97`/`#98` ground; `#90` etc. on OverlayLayer | — |
| Water interior | `WAT` + `#145` | `WAT` + `#97` |
| Water at grass border | `WAT` + `#128`–`#179` | Random grass id on `WAT` |
| Dirt patch | `DRT` + `#0`–`#51` | Single `#4` stamped alone |

Compare procedural map to Phase 0 sample (`SampleMapLoader`) — shores should resemble sample pond edges.

---

## Visual assist checklist (for human eyes)

If shores still look wrong after peering-bit fix, report cells as:

```text
(x, y) — logical WAT/GRS — shows #id — looks like [cliff / grass / water / dirt]
```

We can then mark that atlas id in `tile_registry.md` as mis-tagged or missing peering data.

---

## Phase ownership

| Phase | Matching scope |
|-------|----------------|
| **3** | Grass / dirt / water wang (this doc) |
| **6** | Shoreline foam extends water edges |
| **9** | Elevation composites, 80×96 trees, rock walls |

---

## Bake TileSet in editor

1. Open `scripts/editor/import_mana_seed_tsx.gd`
2. **File → Run** (Ctrl+Shift+X)
3. Saves `resources/tilesets/gentle_forest_v01.tres` and `mana_seed_combined_v01.tres`

| Script | Role |
|--------|------|
| `tsx_tileset_parser.gd` | Parse `.tsx` header, image, wang colors/tiles |
| `mana_seed_terrain_peering.gd` | Wang index → terrain + peering bits |
| `mana_seed_tileset_builder.gd` | Build TileSet resources |
| `editor/import_mana_seed_tsx.gd` | EditorScript — bake `.tres` + console report |
