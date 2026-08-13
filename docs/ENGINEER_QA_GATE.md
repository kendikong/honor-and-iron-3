# Engineer QA Gate

**Scope:** `core/factory/classes/engineer_factory.gd` against `class_abilities.txt` §12, using [`CLASS_QA_BIBLE.md`](CLASS_QA_BIBLE.md).

**LOCK:** `NO` — automated bar 31/31 PASS; owner sign-off still required per [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md).

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
| `engineer_recall` | Movement | `tests/skills/engineer_recall_scenario.gd` | PASS |
| `engineer_dismantle` | Active | `tests/skills/engineer_dismantle_scenario.gd` | PASS |
| `engineer_sludge_bomb` | Active | `tests/skills/engineer_sludge_bomb_scenario.gd` | PASS |
| `engineer_construct_turret` | Active | `tests/skills/engineer_construct_turret_scenario.gd` | PASS |
| `engineer_frag_bomb` | Active | `tests/skills/engineer_frag_bomb_scenario.gd` | PASS |
| `engineer_magnetic_mine` | Active | `tests/skills/engineer_magnetic_mine_scenario.gd` | PASS |
| `engineer_tesla_barricade` | Active | `tests/skills/engineer_tesla_barricade_scenario.gd` | PASS |
| `engineer_flak_cannon` | Active | `tests/skills/engineer_flak_cannon_scenario.gd` | PASS |
| `engineer_wrench_smack` | Active | `tests/skills/engineer_wrench_smack_scenario.gd` | PASS |
| `engineer_emp_grenade` | Active | `tests/skills/engineer_emp_grenade_scenario.gd` | PASS |
| `engineer_rocket_launcher` | Active | `tests/skills/engineer_rocket_launcher_scenario.gd` | PASS |
| `engineer_scrap_shield` | Active | `tests/skills/engineer_scrap_shield_scenario.gd` | PASS |
| `engineer_manual_detonation` | Active | `tests/skills/engineer_manual_detonation_scenario.gd` | PASS |
| `engineer_overdrive_injection` | Active | `tests/skills/engineer_overdrive_injection_scenario.gd` | PASS |
| `engineer_barbed_wire` | Active | `tests/skills/engineer_barbed_wire_scenario.gd` | PASS |

### Passives

| Factory id | Scenario | Tier 1 |
|---|---|---|
| `blueprint_tread` | `tests/passives/blueprint_tread_scenario.gd` | PASS |
| `turret_syndrome` | `tests/passives/turret_syndrome_scenario.gd` | PASS |
| `automation` | `tests/passives/automation_scenario.gd` | PASS |
| `master_builder` | `tests/passives/master_builder_scenario.gd` | PASS |
| `reinforced_constructs` | `tests/passives/reinforced_constructs_scenario.gd` | PASS |
| `shield_generator` | `tests/passives/shield_generator_scenario.gd` | PASS |
| `blast_shielding` | `tests/passives/blast_shielding_scenario.gd` | PASS |
| `explosive_expert` | `tests/passives/explosive_expert_scenario.gd` | PASS |
| `chain_reaction` | `tests/passives/engineer_chain_reaction_scenario.gd` | PASS |
| `shrapnel` | `tests/passives/shrapnel_scenario.gd` | PASS |
| `expanded_blast` | `tests/passives/expanded_blast_scenario.gd` | PASS |
| `scrap_mechanic` | `tests/passives/scrap_mechanic_scenario.gd` | PASS |
| `recycling_protocol` | `tests/passives/recycling_protocol_scenario.gd` | PASS |
| `overclock` | `tests/passives/overclock_scenario.gd` | PASS |
| `overclocked_maintenance` | `tests/passives/overclocked_maintenance_scenario.gd` | PASS |
| `field_technician` | `tests/passives/field_technician_scenario.gd` | PASS |

**Summary:** 31 / 31 `PASS` · 0 `HARNESS_ONLY` · 0 `PLANNED`.

## Scenario contract

Each row cites its Bible clause, names its global owner, delegates to the Engineer harness with Layer A/B/C proof, and routes active execution through `AbilitySystem`, `Simulator`, and the shared planning contract. Shaped rows include `GridSystem.get_affected_tiles` footprint proof. Meta-critic manifest: `docs/engineer_meta_critic_manifest.json`.

## Commands

```powershell
.\scripts\run_engineer_qa_gate.ps1
.\scripts\run_engineer_live_qa.ps1
```
