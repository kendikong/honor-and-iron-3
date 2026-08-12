# Rogue QA Gate

**Scope:** `core/factory/classes/rogue_factory.gd` against `class_abilities.txt` § Rogue, using the universal contract in [`CLASS_QA_BIBLE.md`](CLASS_QA_BIBLE.md).

**LOCK:** `NO` — this first pass provides per-row scenarios and shared-system smoke coverage, but the meta-critic must still promote each row after deeper Bible-clause trigger proofs and live overlay evidence.

## Required tiers

| Tier | Command | Status |
|---|---|---|
| 1 — headless | `.\scripts\run_rogue_qa_gate.ps1` | Required |
| 2 — live planning | `.\scripts\run_rogue_live_qa.ps1` | Required for LOCK |
| Manual | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required for feel/pixel checks |

## Global systems fidelity

- Actives use factory `EffectData`/`AbilityModule`, `AbilitySystem`, timeline AP/MP, targeting flags, and `Simulator`.
- Movement and preview use `MovementSystem`, shared grid geometry, commit slots, and simulator parity; no Rogue-specific presentation path is allowed.
- Passive rows are data assertions until their shared trigger contracts are promoted; no passive row is marked LOCK from a modifier read alone.
- Shape rows must prove affected tile sets through `GridSystem.get_affected_tiles` in headless and the planning overlay at hover in live QA.
- No production `ability.id` branch is added for Rogue behavior.

## Coverage matrix

### Movement + actives

| Factory id | Type | Scenario | Tier 1 |
|---|---|---|---|
| `rogue_slip_past` | Movement | `tests/skills/rogue_slip_past_scenario.gd` | HARNESS_ONLY |
| `rogue_shadow_step` | Active | `tests/skills/rogue_shadow_step_scenario.gd` | HARNESS_ONLY |
| `rogue_kidney_strike` | Active | `tests/skills/rogue_kidney_strike_scenario.gd` | HARNESS_ONLY |
| `rogue_smoke_bomb` | Active | `tests/skills/rogue_smoke_bomb_scenario.gd` | HARNESS_ONLY |
| `rogue_evasive_strike` | Active | `tests/skills/rogue_evasive_strike_scenario.gd` | HARNESS_ONLY |
| `rogue_grappling_hook` | Active | `tests/skills/rogue_grappling_hook_scenario.gd` | HARNESS_ONLY |
| `rogue_switcheroo` | Active | `tests/skills/rogue_switcheroo_scenario.gd` | HARNESS_ONLY |
| `rogue_blindside` | Active | `tests/skills/rogue_blindside_scenario.gd` | HARNESS_ONLY |
| `rogue_throat_slit` | Active | `tests/skills/rogue_throat_slit_scenario.gd` | HARNESS_ONLY |
| `rogue_amnesia_dust` | Active | `tests/skills/rogue_amnesia_dust_scenario.gd` | HARNESS_ONLY |
| `rogue_death_mark` | Active | `tests/skills/rogue_death_mark_scenario.gd` | HARNESS_ONLY |
| `rogue_lethal_flourish` | Active | `tests/skills/rogue_lethal_flourish_scenario.gd` | HARNESS_ONLY |
| `rogue_shadow_swap` | Active | `tests/skills/rogue_shadow_swap_scenario.gd` | HARNESS_ONLY |
| `rogue_kidnap` | Active | `tests/skills/rogue_kidnap_scenario.gd` | HARNESS_ONLY |
| `rogue_shuriken_volley` | Active | `tests/skills/rogue_shuriken_volley_scenario.gd` | HARNESS_ONLY |
| `rogue_poison_flask` | Active | `tests/skills/rogue_poison_flask_scenario.gd` | HARNESS_ONLY |

### Passives

| Factory id | Scenario | Tier 1 |
|---|---|---|
| `pass` | `tests/passives/pass_scenario.gd` | HARNESS_ONLY |
| `backstab` | `tests/passives/backstab_scenario.gd` | HARNESS_ONLY |
| `blink_mastery` | `tests/passives/blink_mastery_scenario.gd` | HARNESS_ONLY |
| `lethal_position` | `tests/passives/lethal_position_scenario.gd` | HARNESS_ONLY |
| `shadow_strike` | `tests/passives/shadow_strike_scenario.gd` | HARNESS_ONLY |
| `killing_intent` | `tests/passives/killing_intent_scenario.gd` | HARNESS_ONLY |
| `shadow_clone` | `tests/passives/shadow_clone_scenario.gd` | HARNESS_ONLY |
| `phase_shift` | `tests/passives/phase_shift_scenario.gd` | HARNESS_ONLY |
| `blink_strike` | `tests/passives/blink_strike_scenario.gd` | HARNESS_ONLY |
| `shadow_meld` | `tests/passives/shadow_meld_scenario.gd` | HARNESS_ONLY |
| `shadow_slip` | `tests/passives/shadow_slip_scenario.gd` | HARNESS_ONLY |
| `miasma_spreader` | `tests/passives/miasma_spreader_scenario.gd` | HARNESS_ONLY |
| `panic_cascade` | `tests/passives/panic_cascade_scenario.gd` | HARNESS_ONLY |
| `debuff_overload` | `tests/passives/debuff_overload_scenario.gd` | HARNESS_ONLY |
| `mind_static` | `tests/passives/mind_static_scenario.gd` | HARNESS_ONLY |
| `board_scrambler` | `tests/passives/board_scrambler_scenario.gd` | HARNESS_ONLY |

**Summary:** 0 / 32 `PASS` · 32 `HARNESS_ONLY` · 0 `PLANNED`.

## Scenario contract

Every row cites its Bible behavior, calls the production harness, checks base and upgrade data, and routes active execution through `AbilitySystem`. A row may become `PASS` only after its exact effect/status/position outcome and, for shaped abilities, live overlay footprint are asserted.

## Registry

`tests/rogue_scenario_registry.gd` and `tests/rogue_qa_runner.gd` are authoritative for row enumeration. `RogueQaGate.tscn` is the Tier 1 entry point.
