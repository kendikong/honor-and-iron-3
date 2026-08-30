class_name PlanningSettledPaint
extends RefCounted

## Sealed range + blast paint — settled with hover intent, read-only on overlay until next settle.

var valid: bool = false
var is_sealed: bool = false
var unit_id: int = -1
var hover_cell: Vector2i = Vector2i(-999999, -999999)
var revision_key: String = ""
var stand_origin: Vector2i = Vector2i(-999999, -999999)
var action_range_tiles: Array[Vector2i] = []
var blast_tiles: Array[Vector2i] = []


static func seal(
	director: CombatDirector,
	board: BoardState,
	planning_input,
	p_unit_id: int,
	p_hover_cell: Vector2i,
	p_revision_key: String,
) -> PlanningSettledPaint:
	var bundle_script: GDScript = load("res://presentation/planning_settled_paint.gd") as GDScript
	var bundle: PlanningSettledPaint = bundle_script.new() as PlanningSettledPaint
	if director == null or board == null or planning_input == null or p_unit_id < 0:
		return bundle
	if not board.is_in_bounds(p_hover_cell):
		return bundle
	var unit: UnitState = board.get_unit_by_id(p_unit_id)
	if unit == null:
		return bundle
	var selected_ability: int = director.selected_ability_index
	var stand: Vector2i = planning_input.action_range_intent_stand_cell(p_unit_id)
	var layer_plan: Dictionary = PlanningPreviewTiles.resolve_layer_origins(
		director, board, unit, selected_ability, planning_input, p_hover_cell,
	)
	var range_tiles: Array[Vector2i] = []
	var blast: Array[Vector2i] = []
	var phase: int = int(layer_plan.get("phase", PlanningPreviewTiles.PhaseKind.NON_MOVEMENT))
	var show_action_range: bool = bool(layer_plan.get("show_action_range", false))
	match phase:
		PlanningPreviewTiles.PhaseKind.MOVEMENT:
			var next_aim: Vector2i = layer_plan.get("next_aim_origin", Vector2i(-999999, -999999))
			if next_aim.x > -900000:
				range_tiles = _action_range_tiles(
					director, board, planning_input, unit, next_aim, p_hover_cell, selected_ability,
				)
		PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
			var locked_aim: Vector2i = layer_plan.get("locked_aim_origin", Vector2i(-999999, -999999))
			if locked_aim.x > -900000 and show_action_range:
				range_tiles = _action_range_tiles(
					director, board, planning_input, unit, locked_aim, p_hover_cell, selected_ability,
				)
	if bool(layer_plan.get("show_blast", false)):
		var blast_origin: Vector2i = layer_plan.get("blast_origin", Vector2i(-999999, -999999))
		if blast_origin.x > -900000:
			blast = _blast_tiles(
				director, board, planning_input, unit, blast_origin, p_hover_cell, selected_ability,
			)
	if stand.x < -900000 and range_tiles.is_empty() and blast.is_empty():
		return bundle
	bundle.unit_id = p_unit_id
	bundle.hover_cell = p_hover_cell
	bundle.revision_key = p_revision_key
	bundle.stand_origin = stand
	bundle.action_range_tiles = range_tiles
	bundle.blast_tiles = blast
	bundle.valid = true
	bundle.is_sealed = true
	return bundle


func matches_hover(p_unit_id: int, p_hover_cell: Vector2i) -> bool:
	return is_sealed and valid and unit_id == p_unit_id and hover_cell == p_hover_cell


static func _plan_board(director: CombatDirector, board: BoardState) -> BoardState:
	if director != null and director.projected_state != null:
		return director.projected_state
	return board


static func _action_range_tiles(
	director: CombatDirector,
	board: BoardState,
	planning_input,
	unit: UnitState,
	origin: Vector2i,
	hover_coord: Vector2i,
	selected_ability: int,
) -> Array[Vector2i]:
	var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
	var actor: UnitState = planning_input._proj_unit(unit.id) if planning_input != null else null
	if actor == null:
		actor = unit
	var plan_board: BoardState = _plan_board(director, board)
	var awaiting: TimelineAction = director.find_awaiting_action(unit.id) if director != null else null
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		var range_stand: Vector2i = origin
		if planning_input != null:
			var intent_stand: Vector2i = planning_input.action_range_intent_stand_cell(unit.id)
			if intent_stand.x > -900000:
				range_stand = intent_stand
		return AbilitySystem.planning_module_range_tiles(
			plan_board, awaiting, awaiting.awaiting_module_index, range_stand, hover_coord,
		)
	return AbilitySystem.planning_action_range_tiles(
		plan_board, actor, ability, origin, [], hover_coord,
	)


static func _blast_tiles(
	director: CombatDirector,
	board: BoardState,
	planning_input,
	unit: UnitState,
	action_range_origin: Vector2i,
	hover_coord: Vector2i,
	selected_ability: int,
) -> Array[Vector2i]:
	if not board.is_in_bounds(hover_coord):
		return []
	var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
	if ability == null and director != null:
		var awaiting: TimelineAction = director.find_awaiting_action(unit.id)
		if awaiting != null:
			ability = awaiting.ability
	if ability == null:
		return []
	var p_unit: UnitState = planning_input._proj_unit(unit.id) if planning_input != null else null
	var blast_actor: UnitState = p_unit if p_unit != null else unit
	var plan_board: BoardState = _plan_board(director, board)
	return AbilitySystem.planning_blast_tiles_at_target(
		plan_board, blast_actor, ability, action_range_origin, hover_coord,
	)
