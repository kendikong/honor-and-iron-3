extends Node

## Passes SkirmishConfig from BattleSetup into TacticalCombat (scene-tree safe).

var _pending: SkirmishGenerator.SkirmishConfig = null


func set_pending(config: SkirmishGenerator.SkirmishConfig) -> void:
	_pending = config


func take_pending() -> SkirmishGenerator.SkirmishConfig:
	var config: SkirmishGenerator.SkirmishConfig = _pending
	_pending = null
	if config == null:
		config = SkirmishGenerator.SkirmishConfig.new()
	return config


func has_pending() -> bool:
	return _pending != null
