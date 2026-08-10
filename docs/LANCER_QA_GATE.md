# Lancer QA Gate

**Scope:** Class validation for `Lancer` — Push movement skill, 13 active skills, 15 promotion passives (`class_abilities.txt`). **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Lancer LOCK):** 100% matrix rows **PASS** + `run_lancer_qa_gate.ps1` PASS + `run_lancer_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

**Owner QA sign-off:** **NOT PASS**

---

## Gate status (honest — 2026-08-09)

| Field | Value |
|-------|-------|
| **Owner sign-off** | **NOT PASS** |
| **LOCK** | **NO** — owner manual + gauntlet ≥95 remain |
| **Summary** | **29 / 29** meta-critic `PASS` · **0** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | `tests/lancer_class_scenario.gd` → `lancer_qa_harness.gd` (data contract, sim execution matrices, passive triggers) + movement smoke + `tests/live_lancer_class_test.gd` |
| **Manifest** | `docs/lancer_meta_critic_manifest.json` |

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_lancer_qa_gate.ps1` | **PASS** (automated) |
| **2 — Live** | `.\scripts\run_lancer_live_qa.ps1` | **PASS** (automated) |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required for feel/pixels |

---

## Meta-critic

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. **Manifest:** `docs/lancer_meta_critic_manifest.json`.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md). Harness resolves skills through `Simulator` with modular bridge contract + shape/footprint smoke.

---

## Coverage matrix (`lancer_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PASS` | Meta-critic approved — Bible clause + sim asserts via `lancer_qa_harness.gd` |

### Movement + actives

| Factory id | Type | Scenario / harness | Tier 1 | Notes |
|------------|------|-------------------|--------|-------|
| `lancer_push` | Movement | `tests/lancer_class_scenario.gd` | PASS | PUSH + Canto; `run_push_smoke` |
| `lancer_piercing_charge` | Active | `tests/lancer_class_scenario.gd` | PASS | DASH pierce; active execution matrix |
| `lancer_sweeping_halberd` | Active | `tests/lancer_class_scenario.gd` | PASS | ARC DAMAGE; shape contract |
| `lancer_vaulting_leap` | Active | `tests/lancer_class_scenario.gd` | PASS | TELEPORT + DAMAGE sim |
| `lancer_run_down` | Active | `tests/lancer_class_scenario.gd` | PASS | Pursuit DAMAGE |
| `lancer_rallying_cry` | Active | `tests/lancer_class_scenario.gd` | PASS | AOE_CROSS ally buff |
| `lancer_flanking_maneuver` | Active | `tests/lancer_class_scenario.gd` | PASS | PRE_MOVE L-route; planning smoke |
| `lancer_brace` | Active | `tests/lancer_class_scenario.gd` | PASS | ADD_STATUS_SELF brace |
| `lancer_harpoon_toss` | Active | `tests/lancer_class_scenario.gd` | PASS | PULL + DAMAGE |
| `lancer_glorious_charge` | Active | `tests/lancer_class_scenario.gd` | PASS | Paired DASH; live + sim |
| `lancer_pole_vault` | Active | `tests/lancer_class_scenario.gd` | PASS | TELEPORT_CASTER polearm |
| `lancer_line_breaker` | Active | `tests/lancer_class_scenario.gd` | PASS | DASH line break |
| `lancer_spear_wall` | Active | `tests/lancer_class_scenario.gd` | PASS | ARC CREATE_HAZARD |
| `lancer_meteor_drop` | Active | `tests/lancer_class_scenario.gd` | PASS | AOE_CROSS landing |

### Passives

| Factory id | Passive | Scenario / harness | Tier 1 | Notes |
|------------|---------|-------------------|--------|-------|
| `kinetic_charge` | Kinetic Charge | `tests/lancer_class_scenario.gd` | PASS | `run_passive_runtime_smoke` |
| `unstoppable_mass` | Unstoppable Mass | `tests/lancer_class_scenario.gd` | PASS | Collision mass |
| `canto` | Canto | `tests/lancer_class_scenario.gd` | PASS | Post-attack MOVE |
| `frontline_defense` | Frontline Defense | `tests/lancer_class_scenario.gd` | PASS | Adjacent DEF |
| `flanking_strike` | Flanking Strike | `tests/lancer_class_scenario.gd` | PASS | Flank bonus |
| `plunging_attack` | Plunging Attack | `tests/lancer_class_scenario.gd` | PASS | Height damage |
| `crashing_impact` | Crashing Impact | `tests/lancer_class_scenario.gd` | PASS | Landing collision |
| `pole_plant` | Pole Plant | `tests/lancer_class_scenario.gd` | PASS | Planted reach |
| `spear_drop` | Spear Drop | `tests/lancer_class_scenario.gd` | PASS | Drop damage |
| `springboard` | Springboard | `tests/lancer_class_scenario.gd` | PASS | Ally launch |
| `sweet_spot` | Sweet Spot | `tests/lancer_class_scenario.gd` | PASS | Range band bonus |
| `reach_advantage` | Reach Advantage | `tests/lancer_class_scenario.gd` | PASS | Reach extension |
| `disengage` | Disengage | `tests/lancer_class_scenario.gd` | PASS | Retreat MOVE |
| `zone_of_control` | Zone of Control | `tests/lancer_class_scenario.gd` | PASS | Adjacent control |
| `leverage` | Leverage | `tests/lancer_class_scenario.gd` | PASS | PUSH synergy |

Registry: `tests/lancer_scenario_registry.gd` + `tests/lancer_class_scenario.gd`.

---

## Commands

```powershell
.\scripts\run_lancer_qa_gate.ps1
.\scripts\run_lancer_live_qa.ps1
```
