# Tile Registry — Gentle Forest v01 (Phase 0)

Logical `TileID` values (Phase 1+) map to Mana Seed atlas regions on **gentle forest v01** (16×16 grid, 16 columns).

**Atlas path:** `Assets/Mana Seed/gentle sheets/gentle forest v01.png` (256×256)  
**Tiled source:** `gentle forest v01.tsx`  
**Palette:** v01 "rabite forest"

---

## Logical TileID → Representative Local Tile

| TileID | Role | Local tile ID | Atlas coords (x, y) | Notes |
|--------|------|---------------|---------------------|-------|
| GRASS | Opaque base fill | 98, 97 | — | GroundLayer — interior only (no Wang terrain) |
| TREE | 16×16 trunk / base | 29, 30, 31, 47 | — | Tree strip under 80×96 — **never** scatter as pebble |
| GRASS | Wang elevation fill | 83, 99 | — | **Do not** use as random grass — cliff/edge art |
| GRASS | Overlay decor | 91, 90 | — | OverlayLayer weed/moss scatter |
| GRASS | Flower scatter | 104, 105, 106 | (8, 6)–(10, 6) | OverlayLayer flowers — never sole ground |
| GRASS | Pebble scatter | 88, 89 | (8, 5), (9, 5) | Random overlay rocks that blend on open grass — **not** `#57` (log), `#74` (set piece) |
| GRASS | Crop scatter | — | props 0–3 | OverlayLayer 32×32 (~12% of scatter rolls) |
| TREE | Canopy fragment | 11–15, 27–28 | — | Overlay beside 80×96 tree — **never** scatter |
| DIRT | Path / dirt | 4, 21 | (4, 0), (5, 1) | Wang dirt-on-grass set |
| WATER | Water interior | 145 | (1, 9) | Full-water wang interior (Phase 2 fill) |
| WATER | Water edge | 129 | (1, 8) | Shoreline peering only (Phase 3) |
| RUIN | Stone / ruin | 107 | (11, 6) | PlayerGrid RUIN stamp / overlay prop from sample |
| ROCK | Rock elevation | 52 | (4, 3) | Elevation wang color |
| TREE | Tree stub | — | Overlay source 2 | 80×96 stub + moss neighbors via `EcologySeeder` |
| TREE | Moss base | 90, 91 | — | Overlay on adjacent GRASS only — weeds/flowers, not rocks |

---

## Wang Terrain Sets (Godot TerrainSet 0)

Mapped from `gentle forest v01.tsx` wang colors → `TileSetFactory` terrains:

| Terrain ID | Wang color name | Tiled color | Godot terrain index |
|------------|-----------------|-------------|---------------------|
| DIRT | dirt on grass | `#ff0000` | `TERRAIN_DIRT` (0) |
| ELEVATION | single elevation on grass | `#00ff00` | `TERRAIN_ELEVATION` (1) |
| WATER | water on grass | `#0000ff` | `TERRAIN_WATER` (2) |

Peering assigned via `ManaSeedTerrainPeering.apply_wangset_to_source()` from parsed `.tsx` (see `scripts/tsx_tileset_parser.gd`).

**Bake in editor:** run `scripts/editor/import_mana_seed_tsx.gd` (File → Run) → saves `resources/tilesets/*.tres`.

See **`docs/tile_terrain_peering.md`** for how neighbor matching works and how to verify with debug overlay **L**.

---

## Sample Map GID Ranges (Tiled global IDs)

| firstgid | Source | Godot source_id | Tile size |
|----------|--------|-----------------|-----------|
| 1 | gentle forest v01 | 0 | 16×16 |
| 257 | gentle waterfall A v01 | 1 | 16×16 |
| 317 | gentle trees 80x96 v01 | 2 | 80×96 |
| 319 | gentle water sparkles A v01 | 3 | 16×16 |
| 328 | gentle 32x32 v01 | 4 | 32×32 |

Flip flags: `scripts/tiled_gid.gd` (Tiled `0x80000000` H, `0x40000000` V, `0x20000000` D).

---

## Layer Routing

| Source | TileMapLayer |
|--------|--------------|
| Forest, waterfall | `GroundLayer` |
| Trees, 32×32 props | `OverlayLayer` |
| Sparkles | `VFXLayer` |
