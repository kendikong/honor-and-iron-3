class_name TileInspectorReport
extends RefCounted

## Formats PlayerGrid + render provenance into inspector BBCode (cached per map).

static var _report_by_cell: Dictionary = {}


static func invalidate_cache() -> void:
	_report_by_cell.clear()


static func warm_cache(
	grid: PlayerGrid,
	logical: PlayerGridProvenance,
	render: MapRenderProvenance,
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
) -> void:
	invalidate_cache()
	if grid == null:
		return
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			_report_by_cell[_cell_key(pos)] = _build_bbcode_uncached(
				pos, grid, logical, render, ground, overlay, vfx,
			)


static func build_bbcode(
	pos: Vector2i,
	grid: PlayerGrid,
	logical: PlayerGridProvenance,
	render: MapRenderProvenance,
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
	locked: bool,
) -> String:
	var key: String = _cell_key(pos)
	var base: String = _report_by_cell.get(key, "")
	if base.is_empty():
		base = _build_bbcode_uncached(pos, grid, logical, render, ground, overlay, vfx)
		_report_by_cell[key] = base
	if not locked:
		return base
	return _append_locked_tag(base)


static func build_phantom_bbcode(
	pos: Vector2i,
	render: MapRenderProvenance,
	phantom: TileMapLayer,
	locked: bool,
) -> String:
	var base: String = _build_phantom_bbcode_uncached(pos, render, phantom)
	if not locked:
		return base
	return _append_locked_tag(base)


static func _append_locked_tag(base: String) -> String:
	const TAG: String = " [color=#f0c060](locked)[/color]"
	var newline_idx: int = base.find("\n")
	if newline_idx < 0:
		return base + TAG
	return base.substr(0, newline_idx) + TAG + base.substr(newline_idx)


static func _cell_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func _build_bbcode_uncached(
	pos: Vector2i,
	grid: PlayerGrid,
	logical: PlayerGridProvenance,
	render: MapRenderProvenance,
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
) -> String:
	var parts: PackedStringArray = []
	parts.append("[b]Cell (%d, %d)[/b]" % [pos.x, pos.y])
	parts.append("")
	parts.append(_section_logical(pos, grid, logical))
	parts.append("")
	parts.append(_section_ground(pos, render, ground))
	parts.append("")
	parts.append(_section_overlay(pos, render, overlay))
	parts.append("")
	parts.append(_section_vfx(pos, render, vfx))
	return "\n".join(parts)


static func _build_phantom_bbcode_uncached(
	pos: Vector2i,
	render: MapRenderProvenance,
	phantom: TileMapLayer,
) -> String:
	var parts: PackedStringArray = []
	parts.append("[b]Phantom cell (%d, %d)[/b]" % [pos.x, pos.y])
	parts.append(
		"[color=#88ccff]Off-map extension â€” visual peering halo only, not in PlayerGrid.[/color]"
	)
	parts.append("")
	parts.append(_section_phantom_logical(pos, render))
	parts.append("")
	parts.append(_section_phantom_layer(pos, render, phantom))
	return "\n".join(parts)


static func _section_phantom_logical(pos: Vector2i, render: MapRenderProvenance) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#8ec8ff][b]â”€â”€ PlayerGrid (logic) â”€â”€[/b][/color]")
	lines.append("[color=#888]No logical cell â€” gameplay ignores this coordinate.[/color]")
	var recorded: Dictionary = render.phantom_at(pos) if render != null else {}
	if recorded.is_empty():
		return "\n".join(lines)
	var logical_type: int = int(recorded.get("logical_type", TileId.Type.GRASS))
	var extends_from: Vector2i = recorded.get("extends_from", Vector2i.ZERO)
	lines.append(
		"[i]Extends in-map (%d, %d) â€” [b]%s[/b][/i]"
		% [extends_from.x, extends_from.y, TileId.type_name(logical_type)]
	)
	return "\n".join(lines)


static func _section_phantom_layer(
	pos: Vector2i,
	render: MapRenderProvenance,
	phantom: TileMapLayer,
) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#7ec8e8][b]â”€â”€ PhantomLayer â”€â”€[/b][/color]")
	var recorded: Dictionary = render.phantom_at(pos) if render != null else {}
	var live: Dictionary = _read_layer_cell(phantom, pos)
	if recorded.is_empty() and live.is_empty():
		lines.append("[color=#888]Empty[/color]")
		return "\n".join(lines)
	if not recorded.is_empty():
		lines.append(_format_render_entry(recorded))
	elif not live.is_empty():
		lines.append(_format_live_cell(live))
		lines.append("[color=#888]No provenance recorded for this phantom.[/color]")
	return "\n".join(lines)


static func _section_logical(pos: Vector2i, grid: PlayerGrid, logical: PlayerGridProvenance) -> String:
	var tile_id: int = grid.get_cell(pos)
	var lines: PackedStringArray = []
	lines.append("[color=#8ec8ff][b]â”€â”€ PlayerGrid (logic) â”€â”€[/b][/color]")
	lines.append(
		"[b]%s[/b] â€” %s"
		% [TileId.type_abbrev(tile_id), TileId.type_name(tile_id)]
	)
	var steps: Array = logical.get_steps(pos) if logical != null else []
	if steps.is_empty():
		if tile_id == TileId.Type.GRASS:
			lines.append(
				"[color=#888]Default grass fill â€” never modified by generator/repair.[/color]"
			)
		else:
			lines.append("[color=#888]No generator history (manual edit or pre-provenance map).[/color]")
	else:
		lines.append("[i]How it got here:[/i]")
		for i: int in range(steps.size()):
			var step: Dictionary = steps[i]
			var is_last: bool = i == steps.size() - 1
			var prefix: String = "â†’ " if is_last else "  Â· "
			var type_name: String = TileId.type_name(int(step["type"]))
			lines.append(
				"%s[color=#c8c8c8]%s[/color]: %s â€” %s"
				% [prefix, str(step["step"]), type_name, str(step["detail"])]
			)
	return "\n".join(lines)


static func _section_ground(
	pos: Vector2i,
	render: MapRenderProvenance,
	ground: TileMapLayer,
) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#9ad89a][b]â”€â”€ GroundLayer â”€â”€[/b][/color]")
	var recorded: Dictionary = render.ground_at(pos) if render != null else {}
	var live: Dictionary = _read_layer_cell(ground, pos)
	if recorded.is_empty() and live.is_empty():
		lines.append("[color=#888]Empty[/color]")
		return "\n".join(lines)

	if not recorded.is_empty():
		lines.append(_format_render_entry(recorded))
		var steps: Array = recorded.get("steps", [])
		if steps.size() > 1:
			lines.append("[i]Paint pipeline:[/i]")
			for i: int in range(steps.size()):
				var step: Dictionary = steps[i]
				lines.append(
					"  %d. %s â€” %s"
					% [i + 1, str(step["reason"]), str(step["detail"])]
				)
	elif not live.is_empty():
		lines.append(_format_live_cell(live))
		lines.append("[color=#888]No provenance recorded for this cell.[/color]")
	return "\n".join(lines)


static func _section_overlay(
	pos: Vector2i,
	render: MapRenderProvenance,
	overlay: TileMapLayer,
) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#d4b0ff][b]â”€â”€ OverlayLayer â”€â”€[/b][/color]")
	var entries: Array[Dictionary] = (
		render.overlay_entries_affecting(pos) if render != null else [] as Array[Dictionary]
	)
	var live: Dictionary = _read_layer_cell(overlay, pos)

	if entries.is_empty() and live.is_empty():
		lines.append("[color=#888]Nothing on overlay at this cell[/color]")
		return "\n".join(lines)

	var spillovers: Array[Dictionary] = []
	var anchors: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry.get("is_spillover", false):
			spillovers.append(entry)
		elif entry.get("is_anchor", false):
			anchors.append(entry)

	if not spillovers.is_empty():
		lines.append("[color=#f0c080][i]Large sprite covers this cell (what you usually see):[/i][/color]")
		for entry: Dictionary in spillovers:
			var anchor: Vector2i = entry["anchor"]
			var footprint: Vector2i = entry["footprint_cells"]
			lines.append(
				"From anchor (%d,%d) â€” %s (%dÃ—%d)"
				% [anchor.x, anchor.y, _overlay_short_label(entry), footprint.x, footprint.y]
			)
			lines.append(_format_overlay_anchor(entry, true))

	if not anchors.is_empty():
		if not spillovers.is_empty():
			lines.append("[i]16Ã—16 overlay anchor (may be hidden under large sprite):[/i]")
		for entry: Dictionary in anchors:
			lines.append(_format_overlay_anchor(entry))

	if not live.is_empty() and entries.is_empty():
		lines.append(_format_live_cell(live))
		lines.append("[color=#888]Live tile present but no provenance anchor (legacy run).[/color]")
	return "\n".join(lines)


static func _section_vfx(
	pos: Vector2i,
	render: MapRenderProvenance,
	vfx: TileMapLayer,
) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#80d4f0][b]â”€â”€ VFXLayer â”€â”€[/b][/color]")
	var recorded: Dictionary = render.vfx_at(pos) if render != null else {}
	var live: Dictionary = _read_layer_cell(vfx, pos)
	if recorded.is_empty() and live.is_empty():
		lines.append("[color=#888]Empty[/color]")
	elif not recorded.is_empty():
		lines.append(_format_render_entry(recorded))
	elif not live.is_empty():
		lines.append(_format_live_cell(live))
	return "\n".join(lines)


static func _overlay_short_label(entry: Dictionary) -> String:
	var source_id: int = int(entry["source_id"])
	var atlas: Vector2i = entry["atlas"]
	match source_id:
		TileSetFactory.SOURCE_PROPS_32:
			var idx: int = clampi(atlas.x, 0, TileCatalog.PROPS_32_LABELS.size() - 1)
			return TileCatalog.PROPS_32_LABELS[idx]
		TileSetFactory.SOURCE_TREES:
			var tidx: int = clampi(atlas.x, 0, TileCatalog.TREE_80_LABELS.size() - 1)
			return TileCatalog.TREE_80_LABELS[tidx]
		_:
			return "overlay"


static func _format_render_entry(entry: Dictionary) -> String:
	var source_id: int = int(entry["source_id"])
	var atlas: Vector2i = entry["atlas"]
	var local_id: int = int(entry.get("local_id", -1))
	var desc: String = TileCatalog.describe_source_tile(source_id, atlas, local_id)
	return (
		"%s\n[color=#aaa]Reason:[/color] %s\n[color=#aaa]Detail:[/color] %s"
		% [desc, str(entry.get("reason", "?")), str(entry.get("detail", ""))]
	)


static func _format_overlay_anchor(entry: Dictionary, indent: bool = false) -> String:
	var prefix: String = "  " if indent else ""
	var source_id: int = int(entry["source_id"])
	var atlas: Vector2i = entry["atlas"]
	var footprint: Vector2i = entry["footprint_cells"]
	var desc: String = TileCatalog.describe_overlay_source(source_id, atlas)
	var fp: String = "%dÃ—%d cells" % [footprint.x, footprint.y]
	return (
		"%s[b]%s[/b] (footprint %s)\n%s[color=#aaa]Reason:[/color] %s\n%s[color=#aaa]Detail:[/color] %s"
		% [
			prefix,
			desc,
			fp,
			prefix,
			str(entry.get("reason", "?")),
			prefix,
			str(entry.get("detail", "")),
		]
	)


static func _format_live_cell(live: Dictionary) -> String:
	return TileCatalog.describe_source_tile(
		int(live["source_id"]),
		live["atlas"],
		int(live.get("local_id", -1)),
	)


static func _read_layer_cell(layer: TileMapLayer, pos: Vector2i) -> Dictionary:
	if layer == null or layer.get_cell_source_id(pos) == -1:
		return {}
	var source_id: int = layer.get_cell_source_id(pos)
	var atlas: Vector2i = layer.get_cell_atlas_coords(pos)
	var local_id: int = -1
	if source_id == TileSetFactory.SOURCE_FOREST:
		local_id = atlas.x + atlas.y * 16
	return {
		"source_id": source_id,
		"atlas": atlas,
		"local_id": local_id,
	}
