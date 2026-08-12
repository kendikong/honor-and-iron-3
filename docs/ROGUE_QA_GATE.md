# Rogue QA Gate

**Scope:** `core/factory/classes/rogue_factory.gd` against `class_abilities.txt` § Rogue, using the universal contract in [`CLASS_QA_BIBLE.md`](CLASS_QA_BIBLE.md).

**LOCK:** `NO` — Tier 1 + Tier 2 runners green and matrix 32/32 `PASS`; owner sign-off pending per [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md).

## Meta-critic (owner proxy)

The **gauntlet-critic** on Rogue work judges:

1. **Bible adherence** — behavior matches `class_abilities.txt` § Rogue + `rogue_factory.gd`
2. **Global systems fidelity** — shared `RogueSystems` hooks, `AbilitySystem`, timeline, no per-id branches
3. **Test adequacy** — each scenario proves Bible clauses (base + `[+]` when implemented)
4. **Coverage** — matrix row + Tier 1 scenario + live overlay/commit for actives; passive live pairing in `test_live_rogue_passive_overlay`
5. **Wrong owner** — game bug vs test design

| Field | Content |
| ----- | ------- |
| `SCORE` | /100 vs `PASS_THRESHOLD: 88` |
| `Largest gap` | Missing passive live, weak upgrade assert, Bible mismatch, etc. |
| `Fix target` | `implementation` \| `qa_test` \| `fixture` \| `coverage_matrix` |
| `Evidence` | Bible excerpt + assert + stdout / `reports/report_*` |
| `Infrastructure` | `ADEQUATE` \| `INADEQUATE` |

Manifest: [`docs/rogue_meta_critic_manifest.json`](rogue_meta_critic_manifest.json) — updated after each critic round ≥ 88.

## Required tiers

| Tier | Command | Status |
|---|---|---|
| 1 — headless | `.\scripts\run_rogue_qa_gate.ps1` | Required |
| 2 — live planning | `.\scripts\run_rogue_live_qa.ps1` | Required — `test_live_rogue_every_skill` + `test_live_rogue_passive_overlay` |
| Manual | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required for feel/pixel checks |

## Global systems fidelity

- Actives use factory `EffectData`/`AbilityModule`, `AbilitySystem`, timeline AP/MP, targeting flags, and `Simulator`.
- Movement and preview use `MovementSystem`, shared grid geometry, commit slots, and simulator parity; no Rogue-specific presentation path is allowed.
- Passive rows prove modifier keys, `_run_passive_trigger` sim outcomes, and `run_passive_upgrade_for` `[+]` branches in `tests/rogue_qa_harness.gd`; live pairing in `test_live_rogue_passive_overlay` re-runs Tier 1 trigger proof after commit.
- Shape rows must prove affected tile sets through `GridSystem.get_affected_tiles` in headless and the planning overlay at hover in live QA.
- No production `ability.id` branch is added for Rogue behavior.

## Coverage matrix

### Movement + actives

| Factory id | Type | Scenario | Tier 1 |
|---|---|---|---|
| `rogue_slip_past` | Movement | `tests/skills/rogue_slip_past_scenario.gd` | PASS |
| `rogue_shadow_step` | Active | `tests/skills/rogue_shadow_step_scenario.gd` | PASS |
| `rogue_kidney_strike` | Active | `tests/skills/rogue_kidney_strike_scenario.gd` | PASS |
| `rogue_smoke_bomb` | Active | `tests/skills/rogue_smoke_bomb_scenario.gd` | PASS |
| `rogue_evasive_strike` | Active | `tests/skills/rogue_evasive_strike_scenario.gd` | PASS |
| `rogue_grappling_hook` | Active | `tests/skills/rogue_grappling_hook_scenario.gd` | PASS |
| `rogue_switcheroo` | Active | `tests/skills/rogue_switcheroo_scenario.gd` | PASS |
| `rogue_blindside` | Active | `tests/skills/rogue_blindside_scenario.gd` | PASS |
| `rogue_throat_slit` | Active | `tests/skills/rogue_throat_slit_scenario.gd` | PASS |
| `rogue_amnesia_dust` | Active | `tests/skills/rogue_amnesia_dust_scenario.gd` | PASS |
| `rogue_death_mark` | Active | `tests/skills/rogue_death_mark_scenario.gd` | PASS |
| `rogue_lethal_flourish` | Active | `tests/skills/rogue_lethal_flourish_scenario.gd` | PASS |
| `rogue_shadow_swap` | Active | `tests/skills/rogue_shadow_swap_scenario.gd` | PASS |
| `rogue_kidnap` | Active | `tests/skills/rogue_kidnap_scenario.gd` | PASS |
| `rogue_shuriken_volley` | Active | `tests/skills/rogue_shuriken_volley_scenario.gd` | PASS |
| `rogue_poison_flask` | Active | `tests/skills/rogue_poison_flask_scenario.gd` | PASS |

### Passives

| Factory id | Scenario | Tier 1 |
|---|---|---|
| `pass` | `tests/passives/pass_scenario.gd` | PASS |
| `backstab` | `tests/passives/backstab_scenario.gd` | PASS |
| `blink_mastery` | `tests/passives/blink_mastery_scenario.gd` | PASS |
| `lethal_position` | `tests/passives/lethal_position_scenario.gd` | PASS |
| `shadow_strike` | `tests/passives/shadow_strike_scenario.gd` | PASS |
| `killing_intent` | `tests/passives/killing_intent_scenario.gd` | PASS |
| `shadow_clone` | `tests/passives/shadow_clone_scenario.gd` | PASS |
| `phase_shift` | `tests/passives/phase_shift_scenario.gd` | PASS |
| `blink_strike` | `tests/passives/blink_strike_scenario.gd` | PASS |
| `shadow_meld` | `tests/passives/shadow_meld_scenario.gd` | PASS |
| `shadow_slip` | `tests/passives/shadow_slip_scenario.gd` | PASS |
| `miasma_spreader` | `tests/passives/miasma_spreader_scenario.gd` | PASS |
| `panic_cascade` | `tests/passives/panic_cascade_scenario.gd` | PASS |
| `debuff_overload` | `tests/passives/debuff_overload_scenario.gd` | PASS |
| `mind_static` | `tests/passives/mind_static_scenario.gd` | PASS |
| `board_scrambler` | `tests/passives/board_scrambler_scenario.gd` | PASS |

**Summary:** 32 / 32 `PASS` · 0 `HARNESS_ONLY` · 0 `PLANNED`.

## Scenario contract

Every row cites its Bible behavior, calls the production harness, checks base and upgrade data, and routes active execution through `AbilitySystem`. A row may become `PASS` only after its exact effect/status/position outcome and, for shaped abilities, live overlay footprint are asserted.

## Registry

`tests/rogue_scenario_registry.gd` and `tests/rogue_qa_runner.gd` are authoritative for row enumeration. `RogueQaGate.tscn` is the Tier 1 entry point.
