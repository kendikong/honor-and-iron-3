class_name JuggernautScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Unstoppable Tread — moving over traps destroys them for 0 damage.
## [+] destroying a trap grants SHIELD 1.
## Globals: TerrainSystem.apply_landing trap destroy path.


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Scenarios.run_juggernaut(failures)

