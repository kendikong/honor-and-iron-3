extends RefCounted

## Bible: Way of the Weaver — physical damage empowers next magic; magical damage empowers next physical.
## Globals: shared damage-trigger weave stacks, next-attack modifiers, and shield trigger.
## Planning tier: C
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"way_of_the_weaver", failures)
