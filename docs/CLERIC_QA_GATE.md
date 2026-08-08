# Cleric QA Gate

**Scope:** Class validation — Cleric factory, actives, passives (`class_abilities.txt`). **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**Owner QA sign-off:** **NOT PASS** — see [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md).

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

---

## Gate status (honest — 2026-08-08)

| Field | Value |
|-------|-------|
| **LOCK** | **NO** |
| **Owner sign-off** | **NOT PASS** |
| **Summary** | **0 / N** meta-critic `PASS` · harness + live smoke only |
| **What runs today** | `tests/cleric_qa_harness.gd`, `ClericQaGate.tscn`, `tests/live_cleric_class_test.gd` |
| **What is missing** | Knight-shaped gate doc matrix, per-skill scenario files, tile-footprint + overlay asserts |

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_cleric_qa_gate.ps1` | **NOT PASS** — upgrade required |
| **2 — Live** | `.\scripts\run_cleric_live_qa.ps1` | **NOT PASS** — upgrade required |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required until matrix `PASS` |

---

## Coverage matrix

**PLANNED** — populate from `cleric_factory.gd` when upgrading; all rows start **`HARNESS_ONLY`** until per-skill scenarios land. Clone structure from [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md).

---

## Commands

```powershell
.\scripts\run_cleric_qa_gate.ps1
.\scripts\run_cleric_live_qa.ps1
```
