# Monk QA Gate

**Scope:** validation of every Monk active, movement skill, innate trait, and promotion passive from `class_abilities.txt` §5. This gate is separate from the gameplay-core planning gate.

**Current status:** `NO LOCK`. The factory and Tier 1 harness are implemented; rows remain `HARNESS_ONLY` until each passive trigger and every movement/shape preview contract is promoted by meta-critic review.

## Three tiers

| Tier | Runner | Current result |
|---|---|---|
| 1 — Headless scenarios | `.\scripts\run_monk_qa_gate.ps1` | PASS |
| 2 — Live acceptance | `.\scripts\run_monk_live_qa.ps1` | PASS — load/registration smoke |
| Manual | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required before owner sign-off |

## Global systems fidelity

### Rule A — Shared owners

Monk data uses `AbilityModule`, `EffectData`, `MotionMode`, `LayerCondition`, `Simulator`, and the shared planning slot path. No Monk-specific `ability.id` branch was added to production systems. The modifier names in the factory are explicit contracts for shared hooks still being completed.

### Rule B — Bible-exact primitives

| Bible intent | Authored primitive |
|---|---|
| Leap over an occupied one-tile obstacle | `TELEPORT_CASTER` + `MotionMode.VAULT_OVER` |
| Phase Throw exchanges positions | `EffectType.SWAP` |
| Push/collision skills | `EffectType.PUSH` |
| Terrain creation | `EffectType.CREATE_HAZARD` with elemental surface metadata |
| AOE/ARC geometry | `GridSystem.get_affected_tiles` |

### Rule C — Preview equals commit

Active-row planning scenarios call `ClassScenarioPlanningContract` where the generic fixture is safe. Leap uses selection-only coverage because the generic fixture cannot author a vault obstacle; dash, collision, ally-adjacent teleport, and several shape rows remain `HARNESS_ONLY` until dedicated fixture layouts exist.

## Coverage matrix

### Innate and movement

| Factory id | Bible row | Scenario | Tier 1 |
|---|---|---|---|
| `way_of_the_weaver` | Innate trait | `tests/passives/way_of_the_weaver_scenario.gd` | HARNESS_ONLY |
| `monk_leap` | Reposition | `tests/skills/monk_leap_scenario.gd` | HARNESS_ONLY |

### Avatar actives

| Factory id | Bible row | Scenario | Tier 1 |
|---|---|---|---|
| `monk_scorching_kick` | Scorching Kick | `tests/skills/monk_scorching_kick_scenario.gd` | HARNESS_ONLY |
| `monk_thunder_palm` | Thunder Palm | `tests/skills/monk_thunder_palm_scenario.gd` | HARNESS_ONLY |
| `monk_chakra_shift` | Chakra Shift | `tests/skills/monk_chakra_shift_scenario.gd` | HARNESS_ONLY |
| `monk_flying_crane_kick` | Flying Crane Kick | `tests/skills/monk_flying_crane_kick_scenario.gd` | HARNESS_ONLY |
| `monk_mantra_of_peace` | Mantra of Peace | `tests/skills/monk_mantra_of_peace_scenario.gd` | HARNESS_ONLY |
| `monk_inner_fire` | Inner Fire | `tests/skills/monk_inner_fire_scenario.gd` | HARNESS_ONLY |
| `monk_geyser_strike` | Geyser Strike | `tests/skills/monk_geyser_strike_scenario.gd` | HARNESS_ONLY |

### Mystic and Windwalker actives

| Factory id | Bible row | Scenario | Tier 1 |
|---|---|---|---|
| `monk_yin_yang_flurry` | Yin-Yang Flurry | `tests/skills/monk_yin_yang_flurry_scenario.gd` | HARNESS_ONLY |
| `monk_phase_throw` | Phase Throw | `tests/skills/monk_phase_throw_scenario.gd` | HARNESS_ONLY |
| `monk_spirit_palm` | Spirit Palm | `tests/skills/monk_spirit_palm_scenario.gd` | HARNESS_ONLY |
| `monk_soul_punch` | Soul Punch | `tests/skills/monk_soul_punch_scenario.gd` | HARNESS_ONLY |
| `monk_hundred_fists` | Hundred Fists | `tests/skills/monk_hundred_fists_scenario.gd` | HARNESS_ONLY |
| `monk_void_step` | Void Step | `tests/skills/monk_void_step_scenario.gd` | HARNESS_ONLY |
| `monk_cyclone_sweep` | Cyclone Sweep | `tests/skills/monk_cyclone_sweep_scenario.gd` | HARNESS_ONLY |
| `monk_updraft` | Updraft | `tests/skills/monk_updraft_scenario.gd` | HARNESS_ONLY |

### Passives

| Factory id | Scenario | Tier 1 | Trigger status |
|---|---|---|---|
| `elemental_attunement` | `tests/passives/elemental_attunement_scenario.gd` | HARNESS_ONLY | Surface attack fixture pending |
| `chakra_burn` | `tests/passives/chakra_burn_scenario.gd` | HARNESS_ONLY | Hazard-hit fixture pending |
| `elemental_harmony` | `tests/passives/elemental_harmony_scenario.gd` | HARNESS_ONLY | Adjacent surface fixture pending |
| `catalyst` | `tests/passives/catalyst_scenario.gd` | HARNESS_ONLY | Surface stat fixture pending |
| `elemental_shield` | `tests/passives/elemental_shield_scenario.gd` | HARNESS_ONLY | Terrain-created fixture pending |
| `weavers_resonance` | `tests/passives/weavers_resonance_scenario.gd` | HARNESS_ONLY | Weave-consumption fixture pending |
| `mind_over_matter` | `tests/passives/mind_over_matter_scenario.gd` | HARNESS_ONLY | Damage-scaling fixture pending |
| `inner_peace` | `tests/passives/inner_peace_scenario.gd` | HARNESS_ONLY | Zero-MOV fixture pending |
| `zen_defense` | `tests/passives/zen_defense_scenario.gd` | HARNESS_ONLY | Empty-adjacency fixture pending |
| `perfect_form` | `tests/passives/perfect_form_scenario.gd` | HARNESS_ONLY | Turn-boundary fixture pending |
| `vaulting_strike` | `tests/passives/vaulting_strike_scenario.gd` | HARNESS_ONLY | Vault fixture pending |
| `flowing_ki` | `tests/passives/flowing_ki_scenario.gd` | HARNESS_ONLY | Crossed-enemy fixture pending |
| `evasive_acrobat` | `tests/passives/evasive_acrobat_scenario.gd` | HARNESS_ONLY | Pass-through fixture pending |
| `momentum_transfer` | `tests/passives/monk_momentum_transfer_scenario.gd` | HARNESS_ONLY | Movement-distance fixture pending |
| `light_step` | `tests/passives/light_step_scenario.gd` | HARNESS_ONLY | Trap/difficult-terrain fixture pending |

**Matrix summary:** `0 PASS` · `32 HARNESS_ONLY` · `0 PLANNED`  
**LOCK:** prohibited until all rows are `PASS`, both class suites pass, and owner sign-off is recorded.

## Commands

```powershell
.\scripts\run_monk_qa_gate.ps1
.\scripts\run_monk_live_qa.ps1
```
