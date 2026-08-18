# Bruiser QA Gate

**Scope:** **Class validation** — every Bruiser **active skill**, **movement skill**, and **passive** in `core/factory/classes/bruiser_factory.gd` behaves per `class_abilities.txt` § Bruiser. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state:** every coverage row is **PASS** (meta-critic approved), and both automated tiers pass.

**Runner:** `scripts/run_bruiser_qa_gate.ps1` — cloned from Knight gate; **does not** invoke or modify `run_planning_qa_gate.ps1`. Each run writes **`qa_bruiser_gate_canonical.txt`** (authoritative stdout snapshot for gauntlet-critic BAR).

**P3 clone authority:** [`docs/design/knight-template.md`](design/knight-template.md) · [`docs/KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md)

---

## Gate status (honest — 2026-08-16)

| Field | Value |
|-------|-------|
| **Automated matrix** | **32 PASS**; planning smoke covers all actives |
| **Tier 1** | PASS — converted rows plus dedicated passive scenarios |
| **Tier 2** | PASS — converted actives through preview/commit/simulation |
| **Reworked** | `bruiser_meat_shield` is Pre-Move ally SWAP with same-turn INTERCEPT |

---

## Three tiers

| Tier | Runner | Gate status |
|------|--------|-------------|
| **1 — Headless scenarios** | `.\scripts\run_bruiser_qa_gate.ps1` | **PASS** (automated) — 32 PASS and `GridSystem.get_affected_tiles` geometry on ARC/AOE |
| **2 — Live Bruiser acceptance** | `.\scripts\run_bruiser_live_qa.ps1` → `tests/live_bruiser_class_test.gd` | **PASS** (automated) — all converted actives; self-AOE + ARC blast overlay at hover |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per ability | Required for feel/pixels Tier 1 cannot see |

**Only Tier 1+2 matrix `PASS` + owner row in `CLASS_QA_SIGNOFF.md` + gauntlet-critic ≥88 blocks Bruiser LOCK.**

---

## Meta-critic (owner proxy)

Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic — judge Bible adherence, global systems fidelity (Rules A/B), test adequacy, coverage, and fix target (`implementation` \| `qa_test` \| `fixture` \| `coverage_matrix`).

**Forbidden:** Using planning QA PASS as Bruiser sign-off. **Forbidden:** Changing `live_planning_scene_test.gd` for Bruiser coverage.

---

## Global systems fidelity (mandatory — implementation + QA)

**Parent rules:** `.cursor/rules/global-systems-first.mdc`, `.cursor/rules/skill-global-rules.mdc`. Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity.

### Rule A — Prefer shared global systems (reduce heuristics)

| Layer | Use (not reinvent) |
|-------|---------------------|
| **Actives** | `EffectType` / `EffectData` in factory data · `AbilitySystem` · timeline · AP/MP · targeting modes |
| **Passives** | Shared passive trigger hooks — data-driven meta on `PassiveData` |
| **Planning** | Commit slots · `Simulator` — one truth path; overlay blast via `AbilitySystem.planning_blast_tiles_at_target` → `GridSystem.get_affected_tiles` |
| **QA** | Assert through production resolution — **no** parallel test-only skill logic or per-id branches |

### Rule B — Bible-exact keywords only

Map Bible text to a global keyword **only when semantics match exactly**. **Authority order:** `class_abilities.txt` → `EffectType` / factory data.

### QA + meta-critic enforcement

1. Scenario header cites Bible clause **and** names global effect(s) or passive trigger.
2. Asserts verify outcome through shared resolution (sim events, board positions, status stacks).
3. **Meta-critic FAIL (`implementation`)** when wrong effect type or per-skill production branch.
4. **Meta-critic FAIL (`qa_test`)** when scenario omits named global effect/trigger or live ARC/AOE lacks `get_affected_tiles` / overlay footprint parity.

**Bruiser-specific reminders:**

| Bible intent | Wrong global | Right approach |
|--------------|--------------|----------------|
| **Suplex:** behind caster placement | `SWAP` | `THROW_BEHIND` (`bruiser_suplex`) |
| **Meat Shield:** swap with ally | `TELEPORT` | `SWAP` + `INTERCEPT` |
| **Violent Collision:** dash + recast on hit | single `MOVE` | `DASH` + `violent_collision_recast` modifier |
| **Push Through:** move into occupied tile | `SWAP` | `MOVE_INTO_AND_PUSH` |

---

## Coverage matrix (authoritative — `bruiser_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file yet |
| `HARNESS_ONLY` | Scenario runs green but **fails meta-critic contract** |
| `PASS` | Meta-critic approved — Bible clause + base + `[+]` when data has `upgraded_modules` |
| `N/A` | Owner deferral with target phase |

**Summary (honest):** Tier 1 sim + **planning commit smoke** on all 16 actives (Knight Tier B — click path, no drag/undo).

### Planning coverage tiers (Knight-bar clone — no drag/undo)

| Tier | Meaning | Bruiser actives |
|------|---------|-----------------|
| **B — commit smoke** | `run_planning_commit_smoke` — select, hover, slot parity, no preview jump | Most actives |
| **B — awaiting smoke** | Two-click arm + target | violent_collision, breaching_dash |
| **B — ally smoke** | Ally-target commit | Deferred rows are excluded from the runner |

Registry: `tests/bruiser_planning_smoke_registry.gd` via `bruiser_qa_runner.gd`.

### Movement + actives

| Bible / factory id | Type | Scenario file | Tier 1 | Notes |
|--------------------|------|---------------|--------|-------|
| `bruiser_push_through` | Movement | `tests/skills/bruiser_push_through_scenario.gd` | PASS | MOVE_INTO_AND_PUSH; `[+]` cost 1 MOV + STR on push |
| `bruiser_charge_strike` | Active | `tests/skills/bruiser_charge_strike_scenario.gd` | PASS | MOVE 2 + DAMAGE 3 + PUSH 1; `[+]` GHOST + terrain bonus |
| `bruiser_concussion_blow` | Active | `tests/skills/bruiser_concussion_blow_scenario.gd` | PASS | RANGE 1 ATK 2 PUSH 1; object STAGGER; `[+]` mutual STAGGER on enemy collision |
| `bruiser_cleave` | Active | `tests/skills/bruiser_cleave_scenario.gd` | PASS | RANGE 1 ARC ATK 2; `[+]` BLEED (WPN-scaled) on all arc targets |
| `bruiser_suplex` | Active | `tests/skills/bruiser_suplex_scenario.gd` | PASS | RANGE 1 ATK 4 THROW_BEHIND (not SWAP); `[+]` bonus_dmg_per_10_hp |
| `bruiser_adrenaline_surge` | Active | `tests/skills/bruiser_adrenaline_surge_scenario.gd` | PASS | SELF spend 5 HP +MOV/+STR next turn; 0 AP if 2+ adjacent; `[+]` Pre-Move skip Action |
| `bruiser_earthshatter` | Active | `tests/skills/bruiser_earthshatter_scenario.gd` | PASS | RANGE 1 ARC ATK 2 + destroy; `[+]` ATK per destroy |
| `bruiser_meat_shield` | Active | `tests/skills/bruiser_meat_shield_scenario.gd` | PASS | Pre-Move ally SWAP + same-turn INTERCEPT; `[+]` RANGE 3 and +2 STR per interception |
| `bruiser_frenzy` | Active | `tests/skills/bruiser_frenzy_scenario.gd` | PASS | RANGE 1 ATK 1 x3; `[+]` on-kill +1 AP |
| `bruiser_guttural_roar` | Active | `tests/skills/bruiser_guttural_roar_scenario.gd` | PASS | AOE PUSH + DEF debuff; `[+]` item push/collision |
| `bruiser_headbutt` | Active | `tests/skills/bruiser_headbutt_scenario.gd` | PASS | Mutual DAMAGE + STAGGER; `[+]` % Max HP bonus |
| `bruiser_blood_boil` | Active | `tests/skills/bruiser_blood_boil_scenario.gd` | PASS | SELF HP; next-turn attacks gain ATK +2 + BLEED WPN; `[+]` ATK +4 |
| `bruiser_violent_collision` | Active | `tests/skills/bruiser_violent_collision_scenario.gd` | PASS | DASH bulldoze + recast; `[+]` STAGGER on collision |
| `bruiser_crimson_whirlwind` | Active | `tests/skills/bruiser_crimson_whirlwind_scenario.gd` | PASS | AOE DAMAGE; `[+]` heal per hit |
| `bruiser_belly_flop` | Active | `tests/skills/bruiser_belly_flop_scenario.gd` | PASS | 1 AP; RANGE 2 JUMP + AOE_CROSS ATK 2 on landing; `[+]` PUSH 1 |
| `bruiser_breaching_dash` | Active | `tests/skills/bruiser_breaching_dash_scenario.gd` | PASS | DASH + destroy cover; `[+]` next attack PIERCE |

### Passives (trigger-based)

| Factory id | Passive | Scenario file | Tier 1 | Trigger setup |
|------------|---------|---------------|--------|----------------|
| `cellular_regeneration` | Cellular Regeneration | `tests/passives/cellular_regeneration_scenario.gd` | PASS | Turn start + adjacent enemy count |
| `reactive_adrenaline` | Reactive Adrenaline | `tests/passives/reactive_adrenaline_scenario.gd` | PASS | Adjacent enemies convert heal to SHIELD; STR/DEF scaling |
| `blood_for_blood` | Blood for Blood | `tests/passives/blood_for_blood_scenario.gd` | PASS | Damaged last turn → BLEED on attack |
| `adrenaline_junkie` | Adrenaline Junkie | `tests/passives/adrenaline_junkie_scenario.gd` | PASS | Missing HP → MOV/STR; `[+]` DEF |
| `enraged` | Enraged | `tests/passives/enraged_scenario.gd` | PASS | Debuff/hazard count → STR; `[+]` MOV |
| `last_stand` | Last Stand | `tests/passives/last_stand_scenario.gd` | PASS | HP &lt; 25% → STR/DEF |
| `colossal_mass` | Colossal Mass | `tests/passives/colossal_mass_scenario.gd` | PASS | Max HP → STR scaling |
| `overwhelming_bulk` | Overwhelming Bulk | `tests/passives/overwhelming_bulk_scenario.gd` | PASS | HP vs target Max HP → PIERCE; `[+]` PUSH |
| `thrill_of_pain` | Thrill of Pain | `tests/passives/thrill_of_pain_scenario.gd` | PASS | On damage → next attack buff |
| `momentum_of_titan` | Momentum of the Titan | `tests/passives/momentum_of_titan_scenario.gd` | PASS | PUSH collision % Max HP damage |
| `scar_tissue` | Scar Tissue | `tests/passives/scar_tissue_scenario.gd` | PASS | Physical damage reduction scaling |
| `momentum_transfer` | Momentum Transfer | `tests/passives/momentum_transfer_scenario.gd` | PASS | PUSH collision → HEAL; `[+]` STR |
| `crowd_breaker` | Crowd Breaker | `tests/passives/crowd_breaker_scenario.gd` | PASS | Adjacent enemy STR + splash |
| `juggernaut` | Unstoppable Tread | `tests/passives/juggernaut_scenario.gd` | PASS | Trap destroy; `[+]` SHIELD |
| `battering_ram` | Battering Ram | `tests/passives/battering_ram_scenario.gd` | PASS | PUSH +1 tile; `[+]` wall STAGGER |
| `unstoppable_force` | Unstoppable Force | `tests/passives/unstoppable_force_scenario.gd` | PASS | STAGGER/ROOT immune + SHIELD on resist |

**Gate rule:** All factory rows must be `PASS`. Gate script **fails** until then.

Registry: `tests/bruiser_scenario_registry.gd` + `tests/bruiser_qa_runner.gd` (32 factory rows, including the dedicated Reactive Adrenaline row).

---

## Scenario contract (per row)

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Scenario contract — cite Bible + global effect in header; assert base + `[+]` via `Simulator` / planning harness where applicable.

**Promotion:** `PLANNED` → `HARNESS_ONLY` → `PASS` only after meta-critic approves adequacy for that row.

---

## Gauntlet handoff stub (current)

```text
GOAL: Bruiser Knight-bar — 31/31 matrix PASS + Tier 1+2 automated green + gauntlet-critic ≥88
BAR: qa_bruiser_gate_canonical.txt Tier 1+2 PASS; live_bruiser_class_test.gd ARC/self-AOE overlay; headless get_affected_tiles on ARC/AOE actives
PASS_THRESHOLD: 88 (LOCK target 95 + owner sign-off)
RULES: skill-global-rules.mdc, global-systems-first.mdc, class-qa-knight-bar.mdc
ARTIFACT: docs/BRUISER_QA_GATE.md, qa_bruiser_gate_canonical.txt, docs/bruiser_meta_critic_manifest.json
```
