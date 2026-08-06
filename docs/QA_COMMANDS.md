# QA Commands

Use the matching suite rather than running every test.

- Planning/preview/commit/input changes: `scripts/run_planning_qa_gate.ps1`.
- Swap-only iteration: `scripts/run_swap_planning_acceptance.ps1`, followed by
  the planning gate after Swap passes.
- Core simulation/bridge/combat changes: `scripts/run_regression_tests.ps1`.
- Headless integration mirror: `godot --headless --path . --script
  res://tests/run_multi_knight_integration.gd`.
- UI-only changes: run the Godot parser/editor check and perform the required
  manual visual check; they do not replace gameplay QA.

Authoritative scope and tier rules remain in `docs/PLANNING_QA_GATE.md` and
`.cursor/rules/qa-after-gameplay-changes.mdc`.
