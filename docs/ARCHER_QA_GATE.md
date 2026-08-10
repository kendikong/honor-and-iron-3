# Archer QA Gate

**Scope:** Class validation — every Archer **active skill**, **movement skill**, and **passive** in `core/factory/classes/archer_factory.gd` per `class_abilities.txt` § Archer. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Archer LOCK):** 100% matrix rows **PASS** (meta-critic approved) + `run_archer_qa_gate.ps1` PASS + `run_archer_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

**Owner QA sign-off:** **NOT PASS** — see [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md).

---

## Gate status (honest — 2026-08-09)

| Field | Value |
|-------|-------|
| **Owner sign-off** | **NOT PASS** |
| **LOCK** | **NO** |
| **Summary** | **0 / 31** meta-critic `PASS` · **31** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | Per-row scenarios via `tests/archer_scenario_registry.gd` → `archer_qa_harness_scenarios.gd` / `archer_qa_harness_passives.gd` + movement planning smoke + `tests/live_archer_class_test.gd` (overlay footprint parity on shaped skills) |
| **Automated green** | Tier 1 headless harness **PASS** · Tier 2 live **PASS** (16 skills incl. Sidestep) · matrix promotion to `PASS` still requires meta-critic |

**Headless gate green does not mean Archer LOCK.** Next: meta-critic row promotion + `[+]` sim depth on remaining actives.

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_archer_qa_gate.ps1` | **PASS** (automated) — per-skill sim + movement smoke |
| **2 — Live** | `.\scripts\run_archer_live_qa.ps1` → `tests/live_archer_class_test.gd` | **PASS** (automated) — preview/commit + `LiveOverlayQaMixin` blast-at-hover on AOE/LINE/ARC |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Owner still required for feel until matrix `PASS` |

---

## Meta-critic

Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. Harness depth improved (sim in/out tiles, movement smoke, live overlay parity) but rows remain **`HARNESS_ONLY`** until gauntlet-critic promotes each row to `PASS`.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity.

**Archer reminders:**

| Bible | Global shape | QA must assert |
|-------|--------------|----------------|
| Volley `AOE 3x3` | `AOE_SQUARE` size 1 | Units in/out of blast at `target_coord` (Tier 1 sim + Tier 2 overlay) |
| Explosive `AOE 1` | `AOE_CROSS` size 1 | Cross tiles in/out (Tier 1 sim) |
| Suppressing Fire `ARC` | `ARC` | `GridSystem.get_affected_tiles` + hazard resolve (Tier 1) |
| Piercing `LINE` | `LINE` size 4 | Line multi-target damage (Tier 1 sim) |
| Sidestep | PRE_MOVE `MOVE` TILE | Planning pre-column commit + sim relocate (movement smoke + live) |

---

## Coverage matrix (`archer_factory.gd`)

### Movement + actives

| Factory id | Scenario file | Tier 1 | Notes |
|------------|---------------|--------|-------|
| `archer_sidestep` | `tests/skills/archer_sidestep_scenario.gd` | HARNESS_ONLY | Sim MOVE + planning premove smoke |
| `archer_power_shot` | `tests/skills/archer_power_shot_scenario.gd` | HARNESS_ONLY | Sim single-target damage |
| `archer_volley` | `tests/skills/archer_volley_scenario.gd` | HARNESS_ONLY | Sim AOE in/out tiles |
| `archer_pinning_arrow` | `tests/skills/archer_pinning_arrow_scenario.gd` | HARNESS_ONLY | Sim ROOT apply |
| `archer_piercing_shot` | `tests/skills/archer_piercing_shot_scenario.gd` | HARNESS_ONLY | Sim LINE multi-hit |
| `archer_toxic_spore_arrow` | `tests/skills/archer_toxic_spore_arrow_scenario.gd` | HARNESS_ONLY | Ability-used smoke; needs status tile proof |
| `archer_grapple_arrow` | `tests/skills/archer_grapple_arrow_scenario.gd` | HARNESS_ONLY | Sim PULL displacement |
| `archer_explosive_arrow` | `tests/skills/archer_explosive_arrow_scenario.gd` | HARNESS_ONLY | Sim CROSS in/out |
| `archer_hunters_mark` | `tests/skills/archer_hunters_mark_scenario.gd` | HARNESS_ONLY | Sim status apply |
| `archer_repelling_shot` | `tests/skills/archer_repelling_shot_scenario.gd` | HARNESS_ONLY | Sim PUSH |
| `archer_bear_trap` | `tests/skills/archer_bear_trap_scenario.gd` | HARNESS_ONLY | Sim hazard tile |
| `archer_suppressing_fire` | `tests/skills/archer_suppressing_fire_scenario.gd` | HARNESS_ONLY | ARC `get_affected_tiles` + resolve |
| `archer_caltrop_trap` | `tests/skills/archer_caltrop_trap_scenario.gd` | HARNESS_ONLY | Hazard smoke; needs tile proof |
| `archer_parting_shot` | `tests/skills/archer_parting_shot_scenario.gd` | HARNESS_ONLY | Sim damage |
| `archer_scouts_eye` | `tests/skills/archer_scouts_eye_scenario.gd` | HARNESS_ONLY | Ability-used smoke |

### Passives

| Factory id | Scenario file | Tier 1 | Notes |
|------------|---------------|--------|-------|
| `lightfoot` | `tests/passives/lightfoot_scenario.gd` | HARNESS_ONLY | Steady Aim range sim |
| `overwatch` | `tests/passives/overwatch_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `high_ground` | `tests/passives/high_ground_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `patient_hunter` | `tests/passives/patient_hunter_scenario.gd` | HARNESS_ONLY | Vantage Anchor STURDY+STEALTH sim |
| `true_sight` | `tests/passives/true_sight_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `piercing_momentum` | `tests/passives/piercing_momentum_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `camouflage` | `tests/passives/camouflage_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `area_denial` | `tests/passives/area_denial_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `caltrop_expert` | `tests/passives/caltrop_expert_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `zone_control` | `tests/passives/zone_control_scenario.gd` | HARNESS_ONLY | Modifier contract |
| `sticky_mud` | `tests/passives/sticky_mud_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `fletching_hoarder` | `tests/passives/fletching_hoarder_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `prey_sighted` | `tests/passives/prey_sighted_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `barrage` | `tests/passives/barrage_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `target_painter` | `tests/passives/target_painter_scenario.gd` | HARNESS_ONLY | Modifier smoke |
| `rapid_fire` | `tests/passives/rapid_fire_scenario.gd` | HARNESS_ONLY | Modifier smoke |

Registry: `tests/archer_scenario_registry.gd` (31 rows, one scenario file each).

---

## Commands

```powershell
.\scripts\run_archer_qa_gate.ps1 -GodotPath "<godot.exe>"
.\scripts\run_archer_live_qa.ps1 -GodotPath "<godot.exe>"
```
