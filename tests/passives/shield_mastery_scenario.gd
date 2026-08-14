class_name ShieldMasteryScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Phalanx Deflection — frontal-lane mitigation stores Kinetic Energy (cap 2×DEF; [+] 3×DEF)
## Globals: CombatSystem + PhysicsSystem.is_frontal_lane


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_shield_mastery(failures)

