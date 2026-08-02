# Knight QA Gate

**Scope:** **Class validation** — every Knight **active skill**, **movement skill**, and **passive** in `core/factory/classes/knight_factory.gd` behaves per `class_abilities.txt` § Knight. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Knight LOCK):** 100% coverage matrix rows **PASS** (meta-critic approved) + `run_knight_qa_gate.ps1` PASS + meta-critic **≥ 88** on full matrix — then P6 clones this gate per class.

**Runner:** `scripts/run_knight_qa_gate.ps1` — mirrors planning gate structure; **does not** invoke or modify `run_planning_qa_gate.ps1`.

---

## Three tiers

| Tier | Runner | Gate status |
|------|--------|-------------|
| **1 — Headless scenarios** | `.\scripts\run_knight_qa_gate.ps1` (wraps `run_skill_scenarios_only.gd`) | **Required** — per-ability/passive scenarios via harness + sim |
| **2 — Live Knight acceptance** | `PLANNED — tests/live_knight_class_test.gd` (GdUnit4, TestBattle, multi-knight board) | Optional until Tier 1 complete; F5-class journeys |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per ability | Required for feel/pixels Tier 1 cannot see |

**Only Tier 1 blocks Knight LOCK.** Tier 2 packs multiple promotion loadouts on one large board (owner optimization — see §Fixture strategy).

---

## Meta-critic (owner proxy)

The **gauntlet-critic** on Knight work is **not** only “tests green.” It judges:

1. **Bible adherence** — does behavior match `class_abilities.txt` + data in `knight_factory.gd`?
2. **Global systems fidelity** — shared effects/triggers (Rule A)? Bible-exact keywords, not misused globals (Rule B)?
3. **Test adequacy** — does each scenario **prove** the Bible clauses it claims (base + `[+]` upgrade when implemented)?
4. **Coverage** — every matrix row has a scenario (or documented owner deferral)?
5. **Wrong owner** — failure in game vs failure in test design?

### Critic outputs (required)

| Field | Content |
|-------|---------|
| `SCORE` | /100 vs `PASS_THRESHOLD: 88` |
| `Largest gap` | Missing passive test, weak assert, untested upgrade, etc. |
| `Fix target` | `implementation` \| `qa_test` \| `fixture` \| `coverage_matrix` |
| `Evidence` | Bible excerpt + assert line + stdout |
| `Proposed infrastructure` | e.g. larger board, second knight on fixture, new `*_scenario.gd` |
| `Infrastructure` | `ADEQUATE` \| `INADEQUATE` |

### Decision tree (fix game vs fix QA)

```
BAR failed?
  yes → assert names Bible clause?
    yes → assert names correct global effect/trigger (Rule B)?
      yes → Fix implementation (data / AbilitySystem / effects)
      no  → Fix QA test (wrong effect asserted or header missing keyword)
    no  → Fix QA test (add asserts, triggers, upgrade tier)
  no  → critic: matrix row missing or scenario too shallow?
    yes → Fix QA (new scenario or deepen phases)
    no  → critic: per-skill branch or misused keyword in production?
    yes → Fix implementation (global systems fidelity Rule A/B)
    no  → PASS candidate for that ability row
```

**Forbidden:** Using planning QA PASS as Knight sign-off. **Forbidden:** Changing `live_planning_scene_test.gd` for Knight coverage.

---

## Global systems fidelity (mandatory — implementation + QA)

**Parent rules:** `.cursor/rules/global-systems-first.mdc`, `.cursor/rules/skill-global-rules.mdc`. This section **double-enforces** them for Knight work and every P6 clone.

### Rule A — Prefer shared global systems (reduce heuristics)

Skills and passives must ride **existing** global paths so future abilities reuse the same machinery:

| Layer | Use (not reinvent) |
|-------|---------------------|
| **Actives** | `EffectType` / `EffectData` in factory data · `AbilitySystem` · timeline · AP/MP · targeting modes |
| **Passives** | Shared passive trigger hooks (collision, melee hit, lethal, turn start, adjacent count, etc.) — data-driven meta on `PassiveData` |
| **Planning** | `PlanningChecklistHarness` · commit slots · `Simulator` — one truth path |
| **QA** | Assert through production resolution — **no** parallel “test-only” skill logic or per-id branches |

**Goal:** A new class skill should be **factory data + scenario**, not a new `if ability.id == …` branch in sim or presentation.

### Rule B — Bible-exact keywords only (no “close enough” globals)

Map Bible text to a global keyword **only when semantics match exactly**. If the Bible describes different behavior, use the **correct** shared effect — or add a **canonical** new effect in the global system (owner ⚠ exception if unavoidable). **Never** misuse a familiar keyword because it is “sort of similar.”

| Bible intent | Wrong global | Why | Right approach |
|--------------|--------------|-----|----------------|
| **Suplex:** move target to empty tile **behind** caster | `EffectType.SWAP` | SWAP = **exchange** positions; no forced behind placement | `THROW_BEHIND` / reposition effect (see `bruiser_suplex` in factory) |
| **Swap (movement skill):** exchange tiles with target/ally | Custom teleport or PUSH chain | Bible names swap | `EffectType.SWAP` in movement ability data |
| **PUSH 2** into wall | SWAP or TELEPORT | Displacement ≠ exchange | `PUSH` + collision pipeline |
| Passive: “on melee hit” | Poll HP every frame in presentation | Wrong owner / heuristic | Shared on-hit passive trigger in sim |

**Authority order:** `class_abilities.txt` clause → match to global definition (`ui/class_library_schema.gd` keyword hints, `EffectType` resolution) → factory `.tres` / `*_factory.gd`. Bible wins over convenience.

### QA + meta-critic enforcement

Scenarios must prove **both** rules:

1. **Scenario header** cites Bible clause **and** names expected global effect(s) or passive trigger (e.g. `EffectType.PUSH`, `collision_retaliator` on collision).
2. **Asserts** verify outcome through shared resolution (sim events, board positions, status stacks) — not a one-off test helper that bypasses `AbilitySystem` / passive pipeline.
3. **Meta-critic FAIL** (`Fix target: implementation`) when:
   - Wrong effect type for Bible text (SWAP used for behind-placement, etc.)
   - Per-skill branch in production code where data/effects could express it
   - Passive tested via stat read only — no real trigger fired
4. **Meta-critic FAIL** (`Fix target: qa_test`) when scenario does not assert the **named** global effect/trigger even though implementation is correct.

**Forbidden (implementation + QA):** Keyword shopping — picking SWAP/PUSH/PULL because the test is easier. **Forbidden:** New heuristics that the next skill cannot reuse without another special case.

---

## Coverage matrix (authoritative — `knight_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file yet |
| `HARNESS_ONLY` | Scenario runs green but **fails meta-critic contract** (no Bible header, no base/`[+]` sim asserts) |
| `PASS` | Meta-critic approved — Bible clause + base + `[+]` when data has `upgraded_effects` |
| `N/A` | Owner deferral with target phase (not used in MVP) |

**Summary (honest):** **18 / 30** factory rows meta-critic `PASS` · **12** `HARNESS_ONLY` · **0** `PLANNED` · run-economy slice separate (harness only). **Manifest:** `docs/knight_meta_critic_manifest.json` — gate fails if matrix PASS exceeds manifest.

### Owner no-regression (do not modify without explicit approval)

| Factory id | Reason |
|------------|--------|
| `knight_bowling_charge` | Owner-verified correct — DASH / chain-push behavior |
| `knight_trampling_advance` | Owner-verified correct — MOVE / TRAMPLE / PUSH path |

Do **not** weaken, replace, or “simplify” harness/scenario/production paths for these skills during K3-LOCK matrix work. Matrix may stay `HARNESS_ONLY` until owner requests promotion; **correctness &gt; coverage row status**.

### Movement + actives

| Bible / factory id | Type | Scenario file | Tier 1 | Notes |
|--------------------|------|---------------|--------|-------|
| `knight_swap` | Movement | `tests/skills/knight_swap_scenario.gd` | PASS | Sim base + `[+]` DEF/SHIELD (meta-critic 90) |
| `knight_shield_bash` | Active | `tests/skills/shield_bash_scenario.gd` | PASS | 7-phase + sim base PUSH/DAMAGE + `[+]` STAGGER |
| `knight_phalanx_stance` | Active | `tests/skills/phalanx_stance_scenario.gd` | PASS | Base/`[+]` sim + map-wide retaliation combo (meta-critic r11) |
| `knight_taunting_strike` | Active | `tests/skills/taunting_strike_scenario.gd` | PASS | ATK1/PULL1/TAUNT + `[+]` AOE PULL2 sim (meta-critic r16) |
| `knight_seismic_stomp` | Active | `tests/skills/seismic_stomp_scenario.gd` | PASS | AOE/PURGE/`[+]` CRACKED + terrain MP sim (meta-critic r15) |
| `knight_fortify` | Active | `tests/skills/fortify_scenario.gd` | PASS | Ally DEF base + `[+]` THORNS sim (meta-critic r6) |
| `knight_bowling_charge` | Active | `tests/skills/bowling_charge_scenario.gd` | HARNESS_ONLY | DASH only; no `[+]` chain-push sim |
| `knight_iron_grip` | Active | `tests/skills/iron_grip_scenario.gd` | PASS | ROOT + next-turn DEF halving + `[+]` AP refund sim (meta-critic r14) |
| `knight_redirect_strike` | Active | `tests/skills/redirect_strike_scenario.gd` | PASS | INTERCEPT 50% + mid-window persist + `[+]` DEF stack sim (meta-critic r17) |
| `knight_indomitable_will` | Active | `tests/skills/indomitable_will_scenario.gd` | HARNESS_ONLY | Base/`[+]` status sim; no 7-phase |
| `knight_retaliation_protocol` | Active | `tests/skills/retaliation_protocol_scenario.gd` | PASS | Counter base + `[+]` PUSH-on-counter sim (meta-critic r6) |
| `knight_shield_slam` | Active | `tests/skills/shield_slam_scenario.gd` | PASS | DAMAGE+PUSH base + `[+]` DEF-debuff events (meta-critic r6) |
| `knight_defensive_formation` | Active | `tests/skills/defensive_formation_scenario.gd` | HARNESS_ONLY | STURDY base + `[+]` ARMOR_UP sim; no 7-phase |
| `knight_chain_hook` | Active | `tests/skills/chain_hook_scenario.gd` | PASS | 7-phase + sim PULL/DAMAGE + `[+]` VULNERABLE |
| `knight_trampling_advance` | Active | `tests/skills/trampling_advance_scenario.gd` | HARNESS_ONLY | 7-phase + weak sim; empty factory `[+]` |
| *(economy)* | Run / MP | `tests/skills/run_economy_scenario.gd` | HARNESS_ONLY | Shared economy slice — not a Bible row |

### Passives (trigger-based — separate scenario shape)

| Factory id | Passive | Scenario file | Tier 1 | Trigger setup |
|------------|---------|---------------|--------|----------------|
| `collision_retaliator` | Collision Retaliator | `tests/passives/collision_retaliator_scenario.gd` | PASS | Collision damage + `[+]` bonus PUSH event |
| `thorny_carapace` | Thorny Carapace | `tests/passives/thorny_carapace_scenario.gd` | PASS | Base reflect+PUSH + `[+]` 100% reflect sim (meta-critic r6) |
| `concussive_shatter` | Concussive Shatter | `tests/passives/concussive_shatter_scenario.gd` | PASS | DEF debuff base + `[+]` VULNERABLE sim (meta-critic r6) |
| `kinetic_momentum` | Kinetic Momentum | `tests/passives/kinetic_momentum_scenario.gd` | PASS | SHIELD base + `[+]` MOV refund sim (meta-critic r6) |
| `stand_ground` | Stand Ground | `tests/passives/stand_ground_scenario.gd` | PASS | Counter 1 base + `[+]` counter 2 sim (meta-critic r6) |
| `indestructible_bastion` | Indestructible Bastion | `tests/passives/indestructible_bastion_scenario.gd` | PASS | Lethal->1 HP base + `[+]` STR sim (meta-critic r6) |
| `shield_mastery` | Shield Mastery | `tests/passives/shield_mastery_scenario.gd` | PASS | SHIELD 2 base + `[+]` SHIELD 3 sim (meta-critic r6) |
| `kinetic_armor` | Kinetic Armor | `tests/passives/kinetic_armor_scenario.gd` | HARNESS_ONLY | Mitigation base + `[+]` reduce-by-2 sim |
| `kinetic_converter` | Kinetic Converter | `tests/passives/kinetic_converter_scenario.gd` | PASS | STR+MOV base + `[+]` STR+2 sim (meta-critic r6) |
| `kinetic_redirection` | Kinetic Redirection | `tests/passives/kinetic_redirection_scenario.gd` | HARNESS_ONLY | Factory registration stub; no `[+]` PIERCE sim |
| `bulwark` | Bulwark | `tests/passives/bulwark_scenario.gd` | HARNESS_ONLY | DEF read; not trigger pipeline |
| `living_barricade` | Living Barricade | `tests/passives/living_barricade_scenario.gd` | HARNESS_ONLY | Ranged block base; no `[+]` ally DEF sim |
| `shield_wall` | Shield Wall | `tests/passives/shield_wall_scenario.gd` | HARNESS_ONLY | Aura DEF base; no `[+]` range-2 sim |
| `rallying_presence` | Rallying Presence | `tests/passives/rallying_presence_scenario.gd` | HARNESS_ONLY | +1 MOV base + `[+]` +2 MOV sim |
| `intercept_tactics` | Intercept Tactics | `tests/passives/intercept_tactics_scenario.gd` | HARNESS_ONLY | +2 DEF base + `[+]` +3 DEF sim |

**LOCK rule:** All factory rows `PASS` (or owner-documented `N/A`). Gate script **fails** until then.

Registry: `tests/knight_scenario_registry.gd` + `tests/knight_qa_runner.gd` (30 factory rows + economy slice).

---

## Scenario contract (per row)

Each `tests/skills/<id>_scenario.gd` (or `tests/passives/<id>_scenario.gd`) must:

1. Cite **Bible clause** in file header (one-line expected behavior).
2. Name **expected global effect(s) or passive trigger** in the same header (per § Global systems fidelity — Rule B).
3. Run **planning phases** where applicable (actives) or **sim-only trigger** (passives).
4. Assert **base** and **`[+]` upgrade** when `upgraded_effects` exist in factory data.
5. Assert outcomes via **`PlanningChecklistHarness` / headless `Simulator`** — no parallel preview path, no test-only skill logic.
6. Register in knight scenario registry (not planning QA legacy tier).

**Promotion:** `HARNESS_ONLY` → `PASS` only after meta-critic approves adequacy for that row.

Passive scenarios **must** set up the trigger (collision, melee hit, lethal, turn start) — stat-only reads are insufficient for critic PASS.

---

## Fixture strategy (critic may recommend)

| Pattern | When |
|---------|------|
| **Multi-knight board** | Several promotion loadouts on one `PlayerGrid` — parallel rows per boot |
| **Larger grid** | 12×8+ for pull/push chains, formation auras, trample corridors |
| **Packed triggers** | One scenario sequence: collision → melee → turn advance (deterministic) |
| **Promotion param** | `build_knight_fixture(promotion_loadout: Array[StringName])` (PLANNED helper) |

Critic optimization examples: *“Add knight at (2,2) with Stand Ground only; enemy push from (3,2)”* — valid `Proposed infrastructure`.

---

## Commands

```powershell
# Tier 1 (Knight class — target bar for LOCK)
.\scripts\run_knight_qa_gate.ps1

# Interim harness only (does not prove matrix PASS)
godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd

# Gameplay-core only (NOT Knight LOCK)
.\scripts\run_planning_qa_gate.ps1
```

---

## P6 clone checklist

1. Copy `docs/KNIGHT_QA_GATE.md` → `docs/<CLASS>_QA_GATE.md`
2. Replace matrix from `<class>_factory.gd` + Bible section
3. Copy `run_knight_qa_gate.ps1` → `run_<class>_qa_gate.ps1`
4. Same meta-critic rubric; different ability ids
5. Do **not** modify planning QA gate or `live_planning_scene_test.gd`

---

## Gauntlet stub (Knight QA gate doc — K3-doc companion)

```text
GOAL: Knight class QA spec — full factory matrix, global systems fidelity (Rule A/B), meta-critic contract, separate from planning QA
BAR: lint PASS (pillar knight-template); matrix lists all knight_factory ids; § Global systems fidelity present; decision tree present; gate script exists on disk
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc, move-preview-intent-truth.mdc
ARTIFACT: this file, docs/design/knight-template.md, core/factory/classes/knight_factory.gd, scripts/run_knight_qa_gate.ps1
```
