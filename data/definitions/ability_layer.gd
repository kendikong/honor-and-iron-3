class_name AbilityLayer
extends Resource

## Purpose: Extra effect on the same targets as its parent module (ability-data.md Â§5).
## Responsibilities: Hold AbilityModule payload + activation condition.
## Dependencies: AbilityModule, GameEnums.
## Lifecycle: authored on AbilityModule; immutable at runtime.

@export var module: AbilityModule = null
@export var condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION
