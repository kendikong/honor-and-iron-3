@tool
extends EditorScript

## Editor utility â€” bake Mana Seed .tsx terrain metadata into TileSet .tres files.
##
## Run: open this script in the Godot script editor â†’ File â†’ Run (Ctrl+Shift+X).
## Outputs:
##   res://resources/tilesets/gentle_forest_v01.tres   (forest + wang terrains)
##   res://resources/tilesets/mana_seed_combined_v01.tres (all v01 sources)

const _C = preload("res://scripts/mana_seed_constants.gd")

const OUT_DIR: String = "res://resources/tilesets"
const FOREST_OUT: String = OUT_DIR + "/gentle_forest_v01.tres"
const COMBINED_OUT: String = OUT_DIR + "/mana_seed_combined_v01.tres"
const FOREST_TSX: String = _C.FOREST_TSX


func _run() -> void:
	_ensure_output_dir()

	var forest_result: Dictionary = ManaSeedTilesetBuilder.build_forest_tileset_from_tsx(FOREST_TSX)
	if forest_result.get("tile_set") == null:
		var parsed: Dictionary = forest_result.get("parsed", {})
		if parsed.is_empty():
			push_error("Import failed â€” could not parse %s" % FOREST_TSX)
		else:
			push_error(
				"Import failed â€” parsed %s but could not build atlas (image: %s)"
				% [FOREST_TSX, str(parsed.get("image_res_path", "?"))]
			)
		return

	_save_resource(forest_result["tile_set"], FOREST_OUT)
	print("=== Gentle Forest v01 ===")
	print(TsxTilesetParser.format_report(forest_result["parsed"]))
	print("Wang assignment stats: %s" % str(forest_result["stats"]))
	print("Saved: %s" % FOREST_OUT)

	var combined: TileSet = ManaSeedTilesetBuilder.build_combined_tileset()
	_save_resource(combined, COMBINED_OUT)
	print("\n=== Combined v01 TileSet ===")
	print("Sources: forest, waterfall, trees, sparkles, 32x32 props")
	print("Saved: %s" % COMBINED_OUT)
	print("\nTerrain overrides: scenes/terrain_peering_editor.tscn (F6) â€” wang patterns + Non-terrain tab")
	print("Done. Re-open test scene or restart game to use baked resources.")


func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func _save_resource(resource: Resource, path: String) -> void:
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("ResourceSaver.save failed for %s (error %d)" % [path, err])
