# QA Suspension (Owner Mandate)

**Status: RE-ENABLED** (owner, 2026-08-30) — `QA_SUSPENDED.flag` removed after Planning SSOT architecture milestone (Attempt 9).

## What is blocked

- Planning QA gate (`run_planning_qa_gate.ps1`)
- Planning SSOT structural gates
- Class Tier 1 / Tier 2 live QA
- Sim/bridge regression (`run_regression_tests.ps1`)
- Swap acceptance, T3 mimic, scene acceptance, full QA, background class tests
- **Agents must not run any of the above** until re-enabled

## Sentinel file

While `docs/qa/QA_SUSPENDED.flag` exists, every QA script exits immediately with:

`[QA SUSPENDED] Automated QA is disabled until planning SSOT architecture is 100% compliant.`

## Re-enable (owner only)

1. Confirm architecture is **100% compliant** (not "mostly" or "structurally").
2. Delete `docs/qa/QA_SUSPENDED.flag`.
3. Tell the agent in chat: **"QA is re-enabled"** or **"planning SSOT is 100% compliant — run QA"**.

Until all three, QA stays off.

## Rule override

`.cursor/rules/qa-suspended-until-planning-ssot-compliant.mdc` wins over `qa-after-gameplay-changes.mdc` and class QA run mandates while this flag exists.
