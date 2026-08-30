class_name PlanningHoverPreview
extends RefCounted

## Sealed hover intent — single carried SSOT from settle through ratify.
## Only created by CombatPlanningInput settle path; ratify copies slots only.

var valid: bool = false
var is_sealed: bool = false
var unit_id: int = -1
var hover_cell: Vector2i = Vector2i(-999999, -999999)
var revision_key: String = ""
var face_dir: int = -1
var slots: Dictionary = {}
var preview_paths: Dictionary = {}
var stand_origin: Vector2i = Vector2i(-999999, -999999)
var action_range_tiles: Array[Vector2i] = []
var blast_tiles: Array[Vector2i] = []
var blast_on_hover_layer: bool = false
var show_action_range: bool = false
var show_blast: bool = false
var phase: int = -1
var ability_index: int = -1


static func seal(
	p_unit_id: int,
	p_hover_cell: Vector2i,
	p_revision_key: String,
	p_slots: Dictionary,
	p_preview_paths: Dictionary,
	p_face_dir: int,
	p_move_origin: Vector2i,
	p_paint: Dictionary = {},
) -> PlanningHoverPreview:
	var bundle_script: GDScript = load("res://presentation/planning_hover_preview.gd") as GDScript
	var bundle: PlanningHoverPreview = bundle_script.new() as PlanningHoverPreview
	var geometry_err: String = validate_geometry(
		p_unit_id, p_slots, p_preview_paths, p_move_origin,
	)
	if geometry_err != "":
		push_error(geometry_err)
		return bundle
	bundle.unit_id = p_unit_id
	bundle.hover_cell = p_hover_cell
	bundle.revision_key = p_revision_key
	bundle.face_dir = p_face_dir
	bundle.slots = _duplicate_slots(p_slots)
	bundle.preview_paths = p_preview_paths.duplicate(true)
	bundle.stand_origin = p_paint.get("stand_origin", p_move_origin)
	bundle.action_range_tiles = _duplicate_coords(
		p_paint.get("action_range_tiles", []),
	)
	bundle.blast_tiles = _duplicate_coords(p_paint.get("blast_tiles", []))
	bundle.blast_on_hover_layer = bool(p_paint.get("blast_on_hover_layer", false))
	bundle.show_action_range = bool(p_paint.get("show_action_range", false))
	bundle.show_blast = bool(p_paint.get("show_blast", false))
	bundle.phase = int(p_paint.get("phase", -1))
	bundle.ability_index = int(p_paint.get("ability_index", -1))
	bundle.valid = true
	bundle.is_sealed = true
	return bundle


func can_ratify_at(cell: Vector2i, ratify_unit_id: int) -> bool:
	return (
		is_sealed
		and valid
		and unit_id == ratify_unit_id
		and hover_cell == cell
		and not slots.is_empty()
	)


func matches_paint_context(
	cell: Vector2i,
	ratify_unit_id: int,
	expected_revision_key: String,
	expected_ability_index: int,
) -> bool:
	return (
		can_ratify_at(cell, ratify_unit_id)
		and revision_key == expected_revision_key
		and ability_index == expected_ability_index
	)


func duplicate_slots() -> Dictionary:
	return _duplicate_slots(slots)


static func move_waypoints_from_slots(p_slots: Dictionary) -> Array[Vector2i]:
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in p_slots.get(col, []):
			if raw is TimelineAction:
				var act: TimelineAction = raw as TimelineAction
				if act.type == GameEnums.ActionType.MOVE and not act.waypoints.is_empty():
					return act.waypoints.duplicate()
	return []


static func validate_geometry(
	p_unit_id: int,
	p_slots: Dictionary,
	p_preview_paths: Dictionary,
	p_move_origin: Vector2i,
) -> String:
	var slot_wps: Array[Vector2i] = move_waypoints_from_slots(p_slots)
	if slot_wps.is_empty():
		return ""
	var route: Array = p_preview_paths.get(p_unit_id, [])
	if route.is_empty():
		return (
			"SSOT BREAK: slots have move waypoints but preview_paths empty for unit %d"
			% p_unit_id
		)
	var dest: Vector2i = slot_wps[slot_wps.size() - 1]
	var leg: Array[Vector2i] = CombatPlanningPreview.destination_cells_from_route(
		route, p_move_origin, dest,
	)
	if leg != slot_wps:
		return (
			"SSOT BREAK: preview_paths leg %s != slots waypoints %s"
			% [str(leg), str(slot_wps)]
		)
	return ""


static func _duplicate_slots(p_slots: Dictionary) -> Dictionary:
	var out: Dictionary = {"pre": [], "action": [], "post": []}
	for col: String in ["pre", "action", "post"]:
		var steps: Array = []
		for raw: Variant in p_slots.get(col, []):
			steps.append(raw)
		out[col] = steps
	if p_slots.has("invalid"):
		out["invalid"] = p_slots["invalid"]
	if p_slots.has("_noop"):
		out["_noop"] = p_slots["_noop"]
	if p_slots.has("_preview_validated"):
		out["_preview_validated"] = p_slots["_preview_validated"]
	return out


static func _duplicate_coords(raw_coords: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not raw_coords is Array:
		return out
	for raw: Variant in raw_coords:
		if raw is Vector2i:
			out.append(raw as Vector2i)
	return out
