# Lancer QA Gate

**Scope:** Class validation for `Lancer` — Push movement skill, 13 active skills, 15 promotion passives (`class_abilities.txt`). **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Lancer LOCK):** 100% matrix rows **PASS** + `run_lancer_qa_gate.ps1` PASS + `run_lancer_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

---

## Gate status (honest — 2026-08-08)

| Field | Value |
|-------|-------|
| **LOCK** | **NO** |
| **Summary** | **0 / 29** meta-critic `PASS` · **29** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | `tests/lancer_class_scenario.gd` → `lancer_qa_harness.gd` (data contract, shape smoke, push/polearm matrices) + `tests/live_lancer_class_test.gd` |
| **What is missing** | Per-skill scenarios (`tests/skills/lancer_*_scenario.gd`), ARC/AOE tile asserts, live overlay footprint |

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_lancer_qa_gate.ps1` | **HARNESS_ONLY** |
| **2 — Live** | `.\scripts\run_lancer_live_qa.ps1` | **HARNESS_ONLY** |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required until matrix `PASS` |

---

## Meta-critic

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. Executable matrices in `lancer_qa_harness.gd` resolve skills through `Simulator` but **do not** meet per-row Bible + footprint contract.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md). Shape smoke in harness checks `AOE_CROSS`, `AOE_SQUARE`, `ARC` enums only — **not** per-skill sim/live tile sets.

---

## Coverage matrix (all rows **HARNESS_ONLY** until scenario files land)

### Movement + actives

| Factory id | Target scenario | Notes |
|------------|-----------------|-------|
| `lancer_push` | `tests/skills/lancer_push_scenario.gd` | Push + Canto — harness smoke only |
| `lancer_piercing_charge` | `tests/skills/lancer_piercing_charge_scenario.gd` | |
| `lancer_sweeping_halberd` | `tests/skills/lancer_sweeping_halberd_scenario.gd` | ARC footprint not tile-asserted |
| `lancer_vaulting_leap` | `tests/skills/lancer_vaulting_leap_scenario.gd` | |
| `lancer_run_down` | `tests/skills/lancer_run_down_scenario.gd` | |
| `lancer_rallying_cry` | `tests/skills/lancer_rallying_cry_scenario.gd` | AOE ally buff |
| `lancer_flanking_maneuver` | `tests/skills/lancer_flanking_maneuver_scenario.gd` | L-route planning |
| `lancer_brace` | `tests/skills/lancer_brace_scenario.gd` | |
| `lancer_harpoon_toss` | `tests/skills/lancer_harpoon_toss_scenario.gd` | |
| `lancer_glorious_charge` | `tests/skills/lancer_glorious_charge_scenario.gd` | Paired charge |
| `lancer_pole_vault` | `tests/skills/lancer_pole_vault_scenario.gd` | |
| `lancer_line_breaker` | `tests/skills/lancer_line_breaker_scenario.gd` | |
| `lancer_spear_wall` | `tests/skills/lancer_spear_wall_scenario.gd` | ARC hazard line |
| `lancer_meteor_drop` | `tests/skills/lancer_meteor_drop_scenario.gd` | |

### Passives (15 rows — all **HARNESS_ONLY**)

See `tests/lancer_qa_harness.gd` `run_passive_runtime_smoke` — trigger matrix exists but **no** per-passive scenario files with Bible headers. Target: `tests/passives/<id>_scenario.gd` each.

Registry: `tests/lancer_scenario_registry.gd` + `tests/lancer_class_scenario.gd` (monolithic — to split).

---

## Commands

```powershell
.\scripts\run_lancer_qa_gate.ps1
.\scripts\run_lancer_live_qa.ps1
```
