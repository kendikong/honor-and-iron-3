class_name BeastTerminalVelocityScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Terminal Velocity — Drop/PUSH/PULL collision adds WPN true damage and VULNERABLE; [+] Drop STAGGER.
## Globals: PhysicsSystem collision lifecycle and CombatSystem unmitigated damage.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"terminal_velocity", failures)
