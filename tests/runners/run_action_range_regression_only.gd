extends SceneTree

## =============================================================================
## NOTE / MANDATE ON SWAP TESTS:
## Runs ActionRangeRegression WITHOUT swap tests by default.
## Swap tests must only be run when specifically investigating or fixing swap!
## Pass `--include-swap` to include swap tests, or `--swap-only` to run only swap tests.
## Dedicated swap acceptance suite: scripts/qa/run_swap_planning_acceptance.ps1
## =============================================================================

func _initialize() -> void:
	var failures: Array[String] = []
	var suite: GDScript = load("res://tests/harness/action_range_regression_test.gd") as GDScript
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var include_swap: bool = "--include-swap" in user_args
	var swap_only: bool = "--swap-only" in user_args

	if swap_only:
		suite.run_swap_tests(failures)
	else:
		suite.run_all(failures, include_swap)

	if failures.is_empty():
		print("[PASS] ActionRangeRegression tests passed.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
