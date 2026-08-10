class_name ScarTissueScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Scar Tissue — reduce physical damage by 1 per 20 Max/missing HP.
## [+] reduce damage by an additional 1.
## Globals: incoming physical mitigation via deal_damage.


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Scenarios.run_scar_tissue(failures)

