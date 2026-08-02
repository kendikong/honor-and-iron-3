class_name KnightBowlingChargeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Bowling Charge — DASH 3 | collision ATK/PUSH via BULLDOZE | [+] PUSH_CHAIN_COLLISION.
## Globals: DASH, BULLDOZE, PUSH_CHAIN_COLLISION via AbilitySystem / PhysicsSystem.
## Tier 1: sim contract + bowling planning intent E2E (Knight QA — not planning gate).


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_planning_bowling_run_contract(failures)
	_planning_bowling_waypoint_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_bowling_charge(failures)


static func _planning_bowling_run_contract(failures: Array[String]) -> void:
	PlanningIntentContractE2ETest._test_bowling_run_click_hides_red_across_refreshes(failures)


static func _planning_bowling_waypoint_contract(failures: Array[String]) -> void:
	PlanningIntentContractE2ETest._test_bowling_waypoint_run_center_hides_red(failures)
