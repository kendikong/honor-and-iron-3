#!/usr/bin/env python3
"""Build Godot LPC catalog JSON from ULPC sheet_definitions."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHEETS = (
    ROOT
    / "Universal-LPC-Spritesheet-Character-Generator-master"
    / "Universal-LPC-Spritesheet-Character-Generator-master"
    / "sheet_definitions"
)
SPARSE_SHEETS = ROOT / "_lpc_sparse" / "spritesheets"
OUT = ROOT / "resources" / "character" / "lpc_catalog.json"

# Empty set = include all sheet_definitions (subject to filters below).
INCLUDE_IDS: set[str] = set()

BODY_TYPES = ["male", "female", "teen", "child", "muscular", "pregnant"]
SKIN_RECOLORS = [
    "light",
    "amber",
    "olive",
    "taupe",
    "bronze",
    "brown",
    "black",
    "lavender",
    "blue",
    "zombie",
    "green",
]
HAIR_RECOLORS = [
    "black",
    "blonde",
    "light_brown",
    "dark_brown",
    "red",
    "gray",
    "white",
    "pink",
    "blue",
    "green",
    "violet",
]
CLOTH_RECOLORS = [
    "white",
    "gray",
    "black",
    "blue",
    "navy",
    "green",
    "red",
    "maroon",
    "brown",
    "leather",
]

FILL_CHANCES: dict[str, float] = {
    "body": 1.0,
    "head": 1.0,
    "hair": 0.92,
    "legs": 0.88,
    "shoes": 0.85,
    "clothes": 0.8,
    "hat": 0.22,
    "armour": 0.12,
    "hairextl": 0.35,
    "hairextr": 0.35,
    "ponytail": 0.25,
    "sleeves": 0.2,
    "jacket": 0.18,
    "vest": 0.15,
    "belt": 0.12,
    "ears": 0.08,
    "tail": 0.06,
    "wings": 0.04,
    "horns": 0.05,
    "expression": 0.1,
    "nose": 0.05,
    "weapon": 0.15,
    "shield": 0.1,
}
ACCESSORY_DEFAULT_FILL = 0.08


def item_id_from_path(path: Path) -> str:
    return path.stem


def top_prefix(path_prefix: str) -> str:
    return path_prefix.strip("/").split("/")[0] if path_prefix else ""


def has_walk_png(paths: dict[str, str], variants: list[str]) -> bool:
    if not SPARSE_SHEETS.is_dir():
        return True
    for prefix in paths.values():
        dir_path = SPARSE_SHEETS / prefix.strip("/")
        if (dir_path / "walk.png").is_file():
            return True
        for variant in variants:
            if (dir_path / "walk" / f"{variant}.png").is_file():
                return True
        # Some items like weapons might not have walk, but have slash
        if (dir_path / "slash.png").is_file():
            return True
        for variant in variants:
            if (dir_path / "slash" / f"{variant}.png").is_file():
                return True
    return False


def extract_recolor_block(recolors: object) -> dict | None:
    if not isinstance(recolors, dict):
        return None
    if "material" in recolors:
        return recolors
    for value in recolors.values():
        if isinstance(value, dict) and value.get("material"):
            return value
    return None


def recolor_kind_for(data: dict, block: dict | None) -> str:
    if block is None:
        return "none"
    material = block.get("material")
    if material == "body" or data.get("match_body_color"):
        return "skin"
    if material == "hair":
        return "hair"
    if material in ("cloth", "metal"):
        return "cloth"
    return "none"


def load_item(path: Path, require_walk: bool) -> dict | None:
    data = json.loads(path.read_text(encoding="utf-8"))
    iid = item_id_from_path(path)
    if iid.startswith("meta_"):
        return None
    if INCLUDE_IDS and iid not in INCLUDE_IDS:
        return None

    layer_1 = data.get("layer_1", {})
    layer_2 = data.get("layer_2", {})
    paths: dict[str, str] = {}
    for bt in BODY_TYPES:
        if bt in layer_1:
            paths[bt] = layer_1[bt]
    bg_paths: dict[str, str] = {}
    for bt in BODY_TYPES:
        if bt in layer_2:
            bg_paths[bt] = layer_2[bt]
    if not paths:
        return None
    recolors = data.get("recolors")
    block = extract_recolor_block(recolors)
    recolor_kind = recolor_kind_for(data, block)
    palette_base = str(block.get("base", "")) if block else ""
    variants: list[str] = []
    if isinstance(recolors, dict) and "variants" in recolors:
        variants = list(recolors.get("variants") or [])
    elif isinstance(data.get("variants"), list):
        variants = list(data.get("variants"))

    if require_walk and not has_walk_png(paths, variants):
        return None

    item: dict = {
        "id": iid,
        "name": data.get("name", iid),
        "type_name": data.get("type_name", ""),
        "z_pos": int(layer_1.get("zPos", 0)),
        "paths": paths,
        "recolor_kind": recolor_kind,
        "variants": variants,
        "required_body_types": list(paths.keys()),
        "match_body_color": bool(data.get("match_body_color", False)),
    }
    if palette_base:
        item["palette_base"] = palette_base
    if bg_paths:
        item["bg_paths"] = bg_paths
    return item


def fill_chance_for(slot: str) -> float:
    if slot in FILL_CHANCES:
        return FILL_CHANCES[slot]
    if slot in ("body", "head"):
        return 1.0
    return ACCESSORY_DEFAULT_FILL


def main() -> None:
    parser = argparse.ArgumentParser(description="Build lpc_catalog.json from ULPC definitions")
    parser.add_argument(
        "--require-walk",
        action="store_true",
        default=True,
        help="Only include items with walk.png under _lpc_sparse (default: on)",
    )
    parser.add_argument(
        "--no-require-walk",
        action="store_false",
        dest="require_walk",
        help="Include all sheet_definitions regardless of sparse PNG presence",
    )
    args = parser.parse_args()

    # Load existing catalog to preserve manual tags
    existing_tags = {}
    if OUT.exists():
        try:
            with OUT.open('r', encoding='utf-8') as f:
                old_cat = json.load(f)
                for slot_data in old_cat.get("slots", {}).values():
                    for old_item in slot_data.get("items", []):
                        iid = old_item.get("id")
                        if iid:
                            existing_tags[iid] = {
                                "tags": old_item.get("tags", []),
                                "requires_tags": old_item.get("requires_tags", []),
                                "excludes_tags": old_item.get("excludes_tags", [])
                            }
        except Exception as e:
            print(f"Failed to load existing catalog for tag preservation: {e}")

    items: list[dict] = []
    for path in sorted(SHEETS.rglob("*.json")):
        item = load_item(path, args.require_walk)
        if item:
            iid = item["id"]
            if iid in existing_tags:
                old = existing_tags[iid]
                for k in ["tags", "requires_tags", "excludes_tags"]:
                    if old[k]:
                        item[k] = old[k]
            items.append(item)

    by_slot: dict[str, list[dict]] = {}
    for item in items:
        slot = item["type_name"]
        by_slot.setdefault(slot, []).append(item)

    catalog = {
        "version": 2,
        "body_types": BODY_TYPES,
        "skin_recolors": SKIN_RECOLORS,
        "hair_recolors": HAIR_RECOLORS,
        "cloth_recolors": CLOTH_RECOLORS,
        "slots": {
            slot: {
                "required": slot in ("body", "head"),
                "fill_chance": fill_chance_for(slot),
                "items": sorted(slot_items, key=lambda x: x["id"]),
            }
            for slot, slot_items in sorted(by_slot.items())
        },
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    print(
        f"Wrote {OUT} ({len(items)} items, {len(by_slot)} slots, "
        f"require_walk={args.require_walk})"
    )


if __name__ == "__main__":
    main()
