# Engineer QA Gate

**Scope:** `core/factory/classes/engineer_factory.gd` against `class_abilities.txt` §12, using [`CLASS_QA_BIBLE.md`](CLASS_QA_BIBLE.md).

**LOCK:** `NO` — Tier 1 harness is implemented and green; Tier 2 live overlay/commit coverage is still required before any LOCK claim.

## Required tiers

| Tier | Command | Requirement |
|---|---|---|
| 1 — headless | `.\scripts\run_engineer_qa_gate.ps1` | Factory matrix, per-row scenarios, Simulator outcomes, and shaped tile contracts |
| 2 — live | `.\scripts\run_engineer_live_qa.ps1` | TestBattle factory load, preview overlay, commit slots, and Simulator parity |
| Manual | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Animation, pixel, feel, and performance checks |

## Global systems fidelity

- Authored modules and passive modifiers are interpreted by `AbilitySystem`, `CombatSystem`, `MovementSystem`, `EngineerSystems`, and `Simulator`.
- Construct spawn HP uses the existing `UnitData.construct_scaling_percent` path; Engineer bonuses are applied in `EngineerSystems.on_spawned`.
- Shape scenarios use `GridSystem.get_affected_tiles`; no Engineer-specific overlay geometry exists.
- Preview and execution must continue through the shared planning slots and `Simulator`; no Engineer ID branch is permitted in presentation.

## Coverage matrix

### Movement + actives

| Factory id | Type | Scenario | Tier 1 |
|---|---|---|---|
| `engineer_recall` | Movement | `tests/skills/engineer_recall_scenario.gd` | HARNESS_ONLY |
| `engineer_dismantle` | Active | `tests/skills/engineer_dismantle_scenario.gd` | HARNESS_ONLY |
| `engineer_sludge_bomb` | Active | `tests/skills/engineer_sludge_bomb_scenario.gd` | HARNESS_ONLY |
| `engineer_construct_turret` | Active | `tests/skills/engineer_construct_turret_scenario.gd` | HARNESS_ONLY |
| `engineer_frag_bomb` | Active | `tests/skills/engineer_frag_bomb_scenario.gd` | HARNESS_ONLY |
| `engineer_magnetic_mine` | Active | `tests/skills/engineer_magnetic_mine_scenario.gd` | HARNESS_ONLY |
| `engineer_tesla_barricade` | Active | `tests/skills/engineer_tesla_barricade_scenario.gd` | HARNESS_ONLY |
| `engineer_flak_cannon` | Active | `tests/skills/engineer_flak_cannon_scenario.gd` | HARNESS_ONLY |
| `engineer_wrench_smack` | Active | `tests/skills/engineer_wrench_smack_scenario.gd` | HARNESS_ONLY |
| `engineer_emp_grenade` | Active | `tests/skills/engineer_emp_grenade_scenario.gd` | HARNESS_ONLY |
| `engineer_rocket_launcher` | Active | `tests/skills/engineer_rocket_launcher_scenario.gd` | HARNESS_ONLY |
| `engineer_scrap_shield` | Active | `tests/skills/engineer_scrap_shield_scenario.gd` | HARNESS_ONLY |
| `engineer_manual_detonation` | Active | `tests/skills/engineer_manual_detonation_scenario.gd` | HARNESS_ONLY |
| `engineer_overdrive_injection` | Active | `tests/skills/engineer_overdrive_injection_scenario.gd` | HARNESS_ONLY |
| `engineer_barbed_wire` | Active | `tests/skills/engineer_barbed_wire_scenario.gd` | HARNESS_ONLY |

### Passives

| Factory id | Scenario | Tier 1 |
|---|---|---|
| `blueprint_tread` | `tests/passives/blueprint_tread_scenario.gd` | HARNESS_ONLY |
| `turret_syndrome` | `tests/passives/turret_syndrome_scenario.gd` | HARNESS_ONLY |
| `automation` | `tests/passives/automation_scenario.gd` | HARNESS_ONLY |
| `master_builder` | `tests/passives/master_builder_scenario.gd` | HARNESS_ONLY |
| `reinforced_constructs` | `tests/passives/reinforced_constructs_scenario.gd` | HARNESS_ONLY |
| `shield_generator` | `tests/passives/shield_generator_scenario.gd` | HARNESS_ONLY |
| `blast_shielding` | `tests/passives/blast_shielding_scenario.gd` | HARNESS_ONLY |
| `explosive_expert` | `tests/passives/explosive_expert_scenario.gd` | HARNESS_ONLY |
| `chain_reaction` | `tests/passives/engineer_chain_reaction_scenario.gd` | HARNESS_ONLY |
| `shrapnel` | `tests/passives/shrapnel_scenario.gd` | HARNESS_ONLY |
| `expanded_blast` | `tests/passives/expanded_blast_scenario.gd` | HARNESS_ONLY |
| `scrap_mechanic` | `tests/passives/scrap_mechanic_scenario.gd` | HARNESS_ONLY |
| `recycling_protocol` | `tests/passives/recycling_protocol_scenario.gd` | HARNESS_ONLY |
| `overclock` | `tests/passives/overclock_scenario.gd` | HARNESS_ONLY |
| `overclocked_maintenance` | `tests/passives/overclocked_maintenance_scenario.gd` | HARNESS_ONLY |
| `field_technician` | `tests/passives/field_technician_scenario.gd` | HARNESS_ONLY |

**Summary:** 0 / 31 `PASS` · 31 `HARNESS_ONLY` · 0 `PLANNED`.

## Scenario contract

Each row cites its Bible clause, names its global owner, delegates to the Engineer harness, checks base and upgrade data, and routes active execution through `AbilitySystem` and `Simulator`. Shaped rows include a `GridSystem.get_affected_tiles` contract. Rows remain `HARNESS_ONLY` until live overlay/commit proof and meta-critic review are recorded.

## Commands

```powershell
.\scripts\run_engineer_qa_gate.ps1
.\scripts\run_engineer_live_qa.ps1
```
