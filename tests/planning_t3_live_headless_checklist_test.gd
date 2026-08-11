class_name PlanningT3LiveHeadlessChecklistTest
extends RefCounted

## Headless mirror of every checkpoint in docs/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md.
## Failure labels use checklist IDs (UNDO-01, K1-02, SWAP-07, EXEC-01, …).


static func run_all(failures: Array[String]) -> void:
	print("[SUITE] t3_live_headless_checklist")
	PlanningLiveParityHarness.run_bible_multi_knight_session(failures)
	PlanningLiveParityHarness.run_swap_session_mirror(failures)
