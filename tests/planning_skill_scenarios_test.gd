class_name PlanningSkillScenariosTest
extends RefCounted

## Canonical 7-phase checklist runner â€” one scenario file per skill/economy slice.
## This is the owner checklist contract; partial slot-only tests are not sufficient.


static func run_all(failures: Array[String]) -> void:
	## Legacy alias â€” Knight class QA owns Tier 1 scenarios (not planning QA gate).
	KnightQaRunner.run_all(failures)
