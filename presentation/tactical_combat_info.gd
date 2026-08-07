class_name TacticalCombatInfo
extends RefCounted

## Deprecated alias â€” use CombatUiFormatters.

const HEX_DIM: String = CombatUiFormatters.HEX_DIM
const HEX_TILE: String = CombatUiFormatters.HEX_TILE
const HEX_INTENT: String = CombatUiFormatters.HEX_INTENT
const HEX_DEATH: String = CombatUiFormatters.HEX_DEATH


static func facing_name(facing: int) -> String:
	return CombatUiFormatters.facing_name(facing)


static func reason_text(code: String) -> String:
	return CombatUiFormatters.reason_text(code)


static func tile_info(board: BoardState, coord: Vector2i) -> String:
	return CombatUiFormatters.tile_info(board, coord)


static func unit_info(board: BoardState, unit: UnitState, move_uses_run: bool = false) -> String:
	return CombatUiFormatters.unit_info(board, unit, move_uses_run)


static func summarize_intents(board: BoardState, phase: int, intent_units: Dictionary) -> String:
	return CombatUiFormatters.summarize_intents(board, phase, intent_units)


static func describe_action(board: BoardState, action: TimelineAction) -> String:
	return CombatUiFormatters.describe_action(board, action)


static func class_symbol(unit: UnitState) -> String:
	return CombatUiFormatters.class_symbol(unit)


static func action_symbol_text(board: BoardState, action: TimelineAction, unit: UnitState) -> String:
	return CombatUiFormatters.action_symbol_text(board, action, unit)
