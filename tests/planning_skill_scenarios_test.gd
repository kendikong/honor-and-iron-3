class_name PlanningSkillScenariosTest
extends RefCounted

## Canonical 7-phase checklist runner — one scenario file per skill/economy slice.
## This is the owner checklist contract; partial slot-only tests are not sufficient.


static func run_all(failures: Array[String]) -> void:
	var suites: Array[Dictionary] = [
		{"name": "shield_bash", "runner": ShieldBashScenarioTest.run_all},
		{"name": "chain_hook", "runner": ChainHookScenarioTest.run_all},
		{"name": "trampling_advance", "runner": TramplingAdvanceScenarioTest.run_all},
		{"name": "run_economy", "runner": RunEconomyScenarioTest.run_all},
	]
	for suite: Dictionary in suites:
		print("[SCENARIO] %s" % suite.name)
		var runner: Callable = suite.runner as Callable
		runner.call(failures)
