# Cloud / Automation prompt — B6-REOPEN finish LOCK

Copy into a **Cloud Agent** or **Automation** (single repo: `kendikong/honor-and-iron-3`, branch `master`).

```text
You are B6-REOPEN lead. Spec: docs/design/00-gauntlet-loop-cursor.md + docs/design/runs/B6-REOPEN.md + docs/design/LOCAL_CLOUD_SYNC.md

GOAL: Bruiser LOCK — 31/31 matrix PASS, gate exit 0, full-matrix gauntlet-critic ≥95, docs/design/bruiser-template.md → LOCKED.

CURRENT STATE (do not regress):
- Matrix 25/31 PASS in docs/BRUISER_QA_GATE.md + docs/bruiser_meta_critic_manifest.json
- Remaining HARNESS_ONLY (deepened, harness was green locally):
  bruiser_guttural_roar, bruiser_crimson_whirlwind, blood_for_blood,
  momentum_transfer, battering_ram, unstoppable_force

LOOP until STOP_ON:
1. Run .\scripts\run_bruiser_qa_gate.ps1 (if Godot missing in env: use qa_bruiser_gate_canonical.txt as last BAR evidence and note Infrastructure risk; prefer installing Godot).
2. For each remaining HARNESS_ONLY row: spawn fresh gauntlet-critic Task (readonly) — never self-grade.
3. Critic PASS ≥88 → append approved_rows in manifest + flip matrix row to PASS + update workbench.md score banner (SELF-GRADED: no (subagent)).
4. Critic FAIL → deepen largest gap in harness → re-gate → re-critic same row (max 4 rounds/row).
5. When 31/31: full-matrix critic ≥95, gate exit 0, bruiser-template.md → LOCKED, STOP_CONDITION_MET: yes in workbench.md.
6. Commit each promotion wave; push if possible; open PR if Cloud workflow requires it.

FORBIDDEN: self-grade; promote without critic PASS; planning QA edits; Knight regression.

If workbench STOP_CONDITION_MET is already yes: exit without changes.
```

## Automation tip

Trigger: cron every **20–30 min**. Same prompt. Stops cleanly when workbench says done.
