# Archer QA Gate

**Scope:** Class validation — every Archer **active skill**, **movement skill**, and **passive** in `core/factory/classes/archer_factory.gd` per `class_abilities.txt` § Archer. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Archer LOCK):** 100% matrix rows **PASS** (meta-critic approved) + `run_archer_qa_gate.ps1` PASS + `run_archer_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

---

## Gate status (honest — 2026-08-08)

| Field | Value |
|-------|-------|
| **LOCK** | **NO** |
| **Summary** | **0 / 31** meta-critic `PASS` · **31** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | Monolithic `tests/archer_class_scenario.gd` → `archer_qa_harness.gd` (data contract, shape metadata smoke, “ability used” matrix) + `tests/live_archer_class_test.gd` (metadata + one commit per skill) |
| **What is missing** | Per-skill scenario files, sim tile-footprint asserts, live overlay blast-at-hover asserts, Knight-shaped meta-critic |

**Headless gate green does not mean Archer LOCK.** Upgrade path: one scenario per row → promote matrix → live footprint asserts.

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_archer_qa_gate.ps1` | **HARNESS_ONLY** — not Knight depth |
| **2 — Live** | `.\scripts\run_archer_live_qa.ps1` → `tests/live_archer_class_test.gd` | **HARNESS_ONLY** — no overlay tile-set / AOE footprint asserts |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Owner still required for feel until matrix `PASS` |

---

## Meta-critic

Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. Current harness **would FAIL** adequacy: no Bible headers per row, no base/`[+]` sim proof per skill, AOE checked via metadata not tile sets.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity.

**Archer reminders:**

| Bible | Global shape | QA must assert |
|-------|--------------|----------------|
| Volley `AOE 3x3` | `AOE_SQUARE` size 1 | 9 tiles at `target_coord`; units in/out |
| Explosive `AOE 1` | `AOE_CROSS` size 1 | 5-tile cross; not diagonals |
| Suppressing Fire `ARC` | `ARC` | 3-tile perpendicular sweep from aim |
| Piercing `LINE` | `LINE` size 4 | Line tile set from caster through range |

---

## Coverage matrix (`archer_factory.gd`)

### Movement + actives (all **HARNESS_ONLY** until scenario file exists)

| Factory id | Scenario file (target) | Tier 1 | Gap |
|------------|------------------------|--------|-----|
| `archer_sidestep` | `tests/skills/archer_sidestep_scenario.gd` | HARNESS_ONLY | No dedicated scenario |
| `archer_power_shot` | `tests/skills/archer_power_shot_scenario.gd` | HARNESS_ONLY | Harness metadata only |
| `archer_volley` | `tests/skills/archer_volley_scenario.gd` | HARNESS_ONLY | No 3×3 tile assert; red overlay not tested |
| `archer_pinning_arrow` | `tests/skills/archer_pinning_arrow_scenario.gd` | HARNESS_ONLY | ROOT break rules not scenario-proven |
| `archer_piercing_shot` | `tests/skills/archer_piercing_shot_scenario.gd` | HARNESS_ONLY | LINE footprint not asserted |
| `archer_toxic_spore_arrow` | `tests/skills/archer_toxic_spore_arrow_scenario.gd` | HARNESS_ONLY | |
| `archer_grapple_arrow` | `tests/skills/archer_grapple_arrow_scenario.gd` | HARNESS_ONLY | |
| `archer_explosive_arrow` | `tests/skills/archer_explosive_arrow_scenario.gd` | HARNESS_ONLY | No cross tile assert |
| `archer_hunters_mark` | `tests/skills/archer_hunters_mark_scenario.gd` | HARNESS_ONLY | |
| `archer_repelling_shot` | `tests/skills/archer_repelling_shot_scenario.gd` | HARNESS_ONLY | |
| `archer_bear_trap` | `tests/skills/archer_bear_trap_scenario.gd` | HARNESS_ONLY | |
| `archer_suppressing_fire` | `tests/skills/archer_suppressing_fire_scenario.gd` | HARNESS_ONLY | ARC + hazard line not tile-asserted |
| `archer_caltrop_trap` | `tests/skills/archer_caltrop_trap_scenario.gd` | HARNESS_ONLY | |
| `archer_parting_shot` | `tests/skills/archer_parting_shot_scenario.gd` | HARNESS_ONLY | |
| `archer_scouts_eye` | `tests/skills/archer_scouts_eye_scenario.gd` | HARNESS_ONLY | |

### Passives (all **HARNESS_ONLY**)

| Factory id | Scenario file (target) | Tier 1 |
|------------|------------------------|--------|
| `lightfoot` | `tests/passives/lightfoot_scenario.gd` | HARNESS_ONLY |
| `overwatch` | `tests/passives/overwatch_scenario.gd` | HARNESS_ONLY |
| `high_ground` | `tests/passives/high_ground_scenario.gd` | HARNESS_ONLY |
| `patient_hunter` | `tests/passives/patient_hunter_scenario.gd` | HARNESS_ONLY |
| `true_sight` | `tests/passives/true_sight_scenario.gd` | HARNESS_ONLY |
| `piercing_momentum` | `tests/passives/piercing_momentum_scenario.gd` | HARNESS_ONLY |
| `camouflage` | `tests/passives/camouflage_scenario.gd` | HARNESS_ONLY |
| `area_denial` | `tests/passives/area_denial_scenario.gd` | HARNESS_ONLY |
| `caltrop_expert` | `tests/passives/caltrop_expert_scenario.gd` | HARNESS_ONLY |
| `zone_control` | `tests/passives/zone_control_scenario.gd` | HARNESS_ONLY |
| `sticky_mud` | `tests/passives/sticky_mud_scenario.gd` | HARNESS_ONLY |
| `fletching_hoarder` | `tests/passives/fletching_hoarder_scenario.gd` | HARNESS_ONLY |
| `prey_sighted` | `tests/passives/prey_sighted_scenario.gd` | HARNESS_ONLY |
| `barrage` | `tests/passives/barrage_scenario.gd` | HARNESS_ONLY |
| `target_painter` | `tests/passives/target_painter_scenario.gd` | HARNESS_ONLY |
| `rapid_fire` | `tests/passives/rapid_fire_scenario.gd` | HARNESS_ONLY |

Registry today: `tests/archer_scenario_registry.gd` → single `archer_class_scenario.gd` (to be split per Knight model).

---

## Commands

```powershell
.\scripts\run_archer_qa_gate.ps1 -GodotPath "<godot.exe>"
.\scripts\run_archer_live_qa.ps1 -GodotPath "<godot.exe>"
```
