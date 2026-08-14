# Beast Rider QA Gate

Source of truth: `class_abilities.txt` §6 and `docs/CLASS_QA_BIBLE.md`.
This gate covers Layer A data fidelity, Layer B deterministic simulation, and
Layer C planning intent/commit parity. The factory uses `BeastRiderFactory`;
runtime behavior remains in `AbilitySystem`, `MovementSystem`, `CombatSystem`,
`Simulator`, `GridSystem`, and `TerrainSystem`.

## Tier requirements

| Tier | Automated proof | Gate |
|---|---|---|
| 1 | 17 active/movement scenarios, 16 passive scenarios, base/upgrade profiles, deterministic outcome checks | `run_beast_rider_qa_gate.ps1` |
| 2 | TestBattle factory loads every Beast Rider active skill with all passives enabled | `run_beast_rider_live_qa.ps1` |
| 3 | Owner visual check: split Gallop path, Reposition opposite-side landing, shaped red overlays, landing/push animation, no preview/commit jump | Manual F5 checklist |

## Meta-critic contract

Every row has one scenario file. Active rows must contain Layer A, Layer B,
Layer C planning proof, and an upgrade simulation. Passive rows must contain
data fidelity plus a runtime trigger/outcome proof. Shaped rows must additionally
prove the shared `GridSystem.get_affected_tiles` footprint and preview red tiles.
Movement rows must prove blue reachable tiles and pre/post timing where applicable.

## Coverage matrix

| Factory row | Scenario | Status | Bible proof |
|---|---|---|---|
| `beast_reposition` | `tests/skills/beast_reposition_scenario.gd` | PASS | 2 MOV opposite-side reposition; [+] RANGE 2 |
| `beast_pounce` | `tests/skills/beast_pounce_scenario.gd` | PASS | MOVE 3, ATK 3, adjacent landing; [+] PUSH |
| `beast_feral_drag` | `tests/skills/beast_feral_drag_scenario.gd` | PASS | CON gate, remaining MOV drag; [+] redirect |
| `beast_maul` | `tests/skills/beast_maul_scenario.gd` | PASS | dragged-target ATK 2; [+] trap multiplier |
| `beast_bestial_roar` | `tests/skills/beast_bestial_roar_scenario.gd` | PASS | CONE 3 PUSH 2 FEAR; [+] DEF debuff |
| `beast_raking_claws` | `tests/skills/beast_raking_claws_scenario.gd` | PASS | ARC ATK 2 BLEED WPN; [+] PULL |
| `beast_rest_recover` | `tests/skills/beast_rest_recover_scenario.gd` | PASS | 1 AP/all MOV HEAL 1 DEF +5; [+] CLEANSE |
| `beast_intimidate` | `tests/skills/beast_intimidate_scenario.gd` | PASS | AOE 2 lower-HP STAGGER; [+] PURGE |
| `beast_fetch` | `tests/skills/beast_fetch_scenario.gd` | PASS | RANGE 4 item/corpse pull; [+] light ally pull |
| `beast_savage_bite` | `tests/skills/beast_savage_bite_scenario.gd` | PASS | ATK 4 BLEED/POISON gate; [+] SHIELD 2 |
| `beast_run_down` | `tests/skills/beast_run_down_scenario.gd` | PASS | DASH 3 ATK 2 pass PUSH; [+] BLEED WPN |
| `beast_thrash` | `tests/skills/beast_thrash_scenario.gd` | PASS | ATK 1 x3; [+] BLEED each hit |
| `beast_defensive_posture` | `tests/skills/beast_defensive_posture_scenario.gd` | PASS | INTERCEPT 50%, DEF +2; [+] PUSH attacker |
| `beast_airlift` | `tests/skills/beast_airlift_scenario.gd` | PASS | ally pickup/drop phases; [+] ally ATK +1 |
| `beast_tail_swipe` | `tests/skills/beast_tail_swipe_scenario.gd` | PASS | 3x3 ATK 1 PUSH 2; [+] collision STAGGER |
| `beast_gore` | `tests/skills/beast_gore_scenario.gd` | PASS | RANGE 1 ATK 2 PUSH 1; BLEED ATK+2; [+] VULNERABLE |
| `beast_meteor_drop` | `tests/skills/beast_meteor_drop_scenario.gd` | PASS | RANGE 2 jump and adjacent ATK 2; [+] VULNERABLE |
| `gallop` | `tests/passives/gallop_scenario.gd` | PASS | split pre/post standard MOV; [+] ATK/DEF |
| `isolation_tactics` | `tests/passives/isolation_tactics_scenario.gd` | PASS | isolated target ATK +2; [+] moved-tile ATK |
| `terminal_velocity` | `tests/passives/terminal_velocity_scenario.gd` | PASS | collision WPN true damage/VULNERABLE; [+] STAGGER |
| `snatch_and_grab` | `tests/passives/snatch_and_grab_scenario.gd` | PASS | grappling RANGE 2; [+] RANGE 3 |
| `safe_landing` | `tests/passives/safe_landing_scenario.gd` | PASS | zero hazard landing, 3x3 PUSH 1; [+] PUSH 2 |
| `aerial_superiority` | `tests/passives/aerial_superiority_scenario.gd` | PASS | grounded melee DEF +2; [+] ROOT immunity |
| `mount_resilience` | `tests/passives/mount_resilience_scenario.gd` | PASS | ranged reduction DEF/2+1; [+] +2 |
| `beasts_instinct` | `tests/passives/beasts_instinct_scenario.gd` | PASS | miss/0 damage STR/AP; [+] SHIELD |
| `territorial` | `tests/passives/territorial_scenario.gd` | PASS | adjacent entry ATK 1; [+] ATK 2 |
| `intimidating_presence` | `tests/passives/intimidating_presence_scenario.gd` | PASS | permanent -DEF/-MOVE RANGE 2; [+] RANGE 3 |
| `dive_bomber` | `tests/passives/dive_bomber_scenario.gd` | PASS | 4+ moved attack ATK +2; [+] threshold 3 |
| `pack_hunter` | `tests/passives/pack_hunter_scenario.gd` | PASS | isolated follow-up bite, 50% DEF ignore; [+] ATK 2 |
| `blood_scent` | `tests/passives/beast_blood_scent_scenario.gd` | PASS | Blood Trail: +MOV and PIERCE toward BLEED; [+] +2 MOV |
| `vantage_striker` | `tests/passives/vantage_striker_scenario.gd` | PASS | difficult terrain immunity and hazard ATK; [+] +2 |
| `predatory_drive` | `tests/passives/predatory_drive_scenario.gd` | PASS | BLEED WPN on BLEED/isolated; [+] POISON |
| `furious_charge` | `tests/passives/furious_charge_scenario.gd` | PASS | straight 3+ next-attack PUSH 1; [+] PUSH 2 |

## Tier 3 owner checklist

- [ ] F5: Gallop can commit a pre-action move, action, and post-action move; the
  last preview remains the committed path and facing.
- [ ] F5: Reposition shows the moved unit landing on the empty opposite-side tile.
- [ ] F5: Pounce, Bestial Roar, Raking Claws, Intimidate, Tail Swipe, Gore, and Meteor
  Drop red overlays match their Bible footprints.
- [ ] F5: airborne landing, hazard immunity, PUSH collisions, and post-action
  animation contain no shader/material/runtime errors.

## Gate record

Last automated result: PASS — Tier 1 33-row harness and Tier 2 factory/live suite.
Owner visual Tier 3 remains a manual presentation check and is not represented
as an automated PASS.
