class_name PlanningT3LiveHeadlessChecklistTest
extends RefCounted

## Headless mirror of every checkpoint in docs/qa/planning/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md.
## Failure labels use checklist IDs (UNDO-01, K1-02, SWAP-07, EXEC-01, …).

const _BowlingAdvance := preload("res://tests/harness/planning_bowling_advance_mimic_test.gd")


static func run_all(failures: Array[String]) -> void:
	print("[SUITE] t3_live_headless_checklist")
	PlanningLiveParityHarness.run_bible_multi_knight_session(failures)
	PlanningLiveParityHarness.run_swap_session_mirror(failures)
	PlanningLiveParityHarness.run_aoe_cleave_session_mirror(failures)
	_BowlingAdvance.run_all(failures)
	PlanningLiveParityHarness.run_wait_all_tiles_off(failures)
	PlanningLiveParityHarness.run_charge_strike_stand_handoff(failures)
	print("[SKIP] MP-COOP: second client is out of scope for this runner")
