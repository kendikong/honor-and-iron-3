class_name BruiserPushThroughScenarioTest
extends RefCounted

const _BruiserQaHarness := preload("res://tests/bruiser_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B

## Bible: Push Through â€” move into adjacent ally-occupied tile, PUSH ally 1 forward; [+] cost 1 MOV + STR on push.
## Globals: EffectType.MOVE_INTO_AND_PUSH; upgraded_movement_point_cost; buff_on_push modifier in PhysicsSystem.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_push_through")


static func _sim_contract(failures: Array[String]) -> void:
		_BruiserQaHarness.run_push_through_base(failures)
		_BruiserQaHarness.run_push_through_non_adjacent(failures)
		_BruiserQaHarness.run_push_through_blocked(failures)
		_BruiserQaHarness.run_push_through_empty_tile(failures)
		_BruiserQaHarness.run_push_through_rejects_enemy(failures)
		_BruiserQaHarness.run_push_through_upgrade(failures)
		_BruiserQaHarness.run_push_through_upgrade_next_attack(failures)
