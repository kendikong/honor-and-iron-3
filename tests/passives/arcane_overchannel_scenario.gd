extends RefCounted

## Bible: arcane_overchannel — innate overchannel passive (factory contract).
const _H := preload("res://tests/mage_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_H.run_arcane_overchannel(failures)
