# Mercenary QA Gate

**Scope:** Complete Mercenary factory, innate, Pullback, 15 active skills, 15
promotion passives, upgrades, Simulator resolution, and planning intent parity
from `class_abilities.txt` § Mercenary.

**End state:** 32 / 32 matrix rows are individually exercised by Tier 1,
per-row scenario contracts, Tier 2 planning, and the shared planning gate.
Owner sign-off remains **NOT PASS** until manual review is recorded in
`docs/CLASS_QA_SIGNOFF.md`.

## Three tiers

| Tier | Runner | Proof |
|---|---|---|
| 1 — Headless | `.\scripts\run_mercenary_qa_gate.ps1` | Factory data, modules/layers, upgrades, Simulator |
| 2 — Live | `.\scripts\run_mercenary_live_qa.ps1` | Preview slots, overlay targets, commit ratification, Simulator parity |
| Planning | `.\scripts\run_planning_qa_gate.ps1` | Shared global planning regression |

## Global systems fidelity

- **Rule A — data ownership:** every skill is authored as `AbilityData` with
  ordered `AbilityModule` entries; extra effects on the same targets are
  `AbilityLayer` entries.
- **Rule B — one truth path:** planning uses
  `_build_commit_slots_at_cell` → `_finalize_commit_slots` →
  `preview_commit_valid` / `CombatDirector.commit_from_slots` → `Simulator`.
- No Mercenary `ability.id` branch is added to simulation or presentation.

## Coverage matrix

| Factory id | Type | Scenario file | Tier 1 |
|---|---|---|---|
| `predatory_momentum` | Innate | `tests/passives/predatory_momentum_scenario.gd` | PASS |
| `mercenary_pullback` | Reposition | `tests/skills/mercenary_pullback_scenario.gd` | PASS |
| `mercenary_swift_strike` | Active | `tests/skills/mercenary_swift_strike_scenario.gd` | PASS |
| `mercenary_defense_strike` | Active | `tests/skills/mercenary_defense_strike_scenario.gd` | PASS |
| `mercenary_blade_storm` | Active | `tests/skills/mercenary_blade_storm_scenario.gd` | PASS |
| `mercenary_caltrop_toss` | Active | `tests/skills/mercenary_caltrop_toss_scenario.gd` | PASS |
| `mercenary_feint` | Active | `tests/skills/mercenary_feint_scenario.gd` | PASS |
| `mercenary_riposte_strike` | Active | `tests/skills/mercenary_riposte_strike_scenario.gd` | PASS |
| `mercenary_sever` | Active | `tests/skills/mercenary_sever_scenario.gd` | PASS |
| `mercenary_second_wind` | Active | `tests/skills/mercenary_second_wind_scenario.gd` | PASS |
| `mercenary_tactical_retreat` | Active | `tests/skills/mercenary_tactical_retreat_scenario.gd` | PASS |
| `mercenary_executioners_blade` | Active | `tests/skills/mercenary_executioners_blade_scenario.gd` | PASS |
| `mercenary_precision_strike` | Active | `tests/skills/mercenary_precision_strike_scenario.gd` | PASS |
| `mercenary_flank_and_run` | Active | `tests/skills/mercenary_flank_and_run_scenario.gd` | PASS |
| `mercenary_hamstring` | Active | `tests/skills/mercenary_hamstring_scenario.gd` | PASS |
| `mercenary_acrobatic_vault` | Active | `tests/skills/mercenary_acrobatic_vault_scenario.gd` | PASS |
| `mercenary_duelists_challenge` | Active | `tests/skills/mercenary_duelists_challenge_scenario.gd` | PASS |
| `calculated_strike` | Passive | `tests/passives/calculated_strike_scenario.gd` | PASS |
| `weapon_master` | Passive | `tests/passives/weapon_master_scenario.gd` | PASS |
| `dual_wield_momentum` | Passive | `tests/passives/dual_wield_momentum_scenario.gd` | PASS |
| `precision_edge` | Passive | `tests/passives/precision_edge_scenario.gd` | PASS |
| `duelists_focus` | Passive | `tests/passives/duelists_focus_scenario.gd` | PASS |
| `tactical_versatility` | Passive | `tests/passives/tactical_versatility_scenario.gd` | PASS |
| `swift_feet` | Passive | `tests/passives/swift_feet_scenario.gd` | PASS |
| `hit_and_run` | Passive | `tests/passives/hit_and_run_scenario.gd` | PASS |
| `evasive` | Passive | `tests/passives/evasive_scenario.gd` | PASS |
| `flanking_maneuver` | Passive | `tests/passives/flanking_maneuver_scenario.gd` | PASS |
| `dirty_fighting` | Passive | `tests/passives/dirty_fighting_scenario.gd` | PASS |
| `executioner` | Passive | `tests/passives/executioner_scenario.gd` | PASS |
| `blood_scent` | Passive | `tests/passives/blood_scent_scenario.gd` | PASS |
| `ruthless` | Passive | `tests/passives/ruthless_scenario.gd` | PASS |
| `coup_de_grace` | Passive | `tests/passives/coup_de_grace_scenario.gd` | PASS |

## Commands

```powershell
.\scripts\run_mercenary_qa_gate.ps1
.\scripts\run_mercenary_live_qa.ps1
.\scripts\run_planning_qa_gate.ps1
```
