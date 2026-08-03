class_name AbilityKeyword
extends Resource

## Purpose: Named Bible keyword package on a module (TRAMPLE, BULLDOZE, …).
## Responsibilities: Hold keyword id + amounts; AbilitySystem expands to engine behavior.
## Dependencies: GameEnums.
## Lifecycle: authored on AbilityModule; immutable at runtime.

@export var keyword_id: GameEnums.AbilityKeywordId = GameEnums.AbilityKeywordId.NONE
## Primary magnitude (TRAMPLE damage, BULLDOZE collision base, …).
@export var amount: int = 0
## Secondary magnitude (BULLDOZE push distance, etc.).
@export var push_amount: int = 0
## When true, compile emits a legacy EffectType.TRAMPLE/BULLDOZE row (Bowling / Trampling).
## When false, keyword stays as modifiers on the motion primary (Violent Collision style).
@export var emit_as_effect: bool = false
