class_name AbilityLayer
extends Resource

## Purpose: Extra effect on the same targets as its parent module (ability-data.md §5).
## Responsibilities: Hold EffectData payload + activation condition.
## Dependencies: EffectData, GameEnums.
## Lifecycle: authored on AbilityModule; immutable at runtime.

@export var effect: EffectData = null
@export var condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION
