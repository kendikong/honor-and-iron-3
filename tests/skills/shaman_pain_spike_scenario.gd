extends RefCounted

## Bible: shaman_pain_spike — Bloodweaver linked follow-up contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_pain_spike", failures)
