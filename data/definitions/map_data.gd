class_name MapData
extends Resource

## Purpose: Associates a human-readable name, description, and an optional
## thumbnail colour with an EncounterData, so the BattleSetup UI can display
## map selection cards without embedding display logic in EncounterData itself.
## Responsibilities: Hold display metadata; reference the encounter resource.
## Dependencies: EncounterData.
## Lifecycle: immutable; loaded by BattleSetup at scene start.

@export var display_name: String = ""
@export var map_description: String = ""

## Accent colour shown on the map card in the battle setup UI.
@export var card_color: Color = Color(0.2, 0.3, 0.5)

@export var encounter: EncounterData
