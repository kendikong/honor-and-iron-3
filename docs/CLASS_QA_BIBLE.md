# Class QA Bible

**Authority:** This document is the **single specification** for how every Bible class is validated in automated QA.  
**Per-class instances:** `docs/<CLASS>_QA_GATE.md` (matrix + status) · `scripts/run_<class>_qa_gate.ps1` (runner)  
**Mechanics source:** `class_abilities.txt` § class + `core/factory/classes/<class>_factory.gd`  
**Quality reference:** Knight headless fixture suite (`tests/skills/shield_bash_scenario.gd`, `tests/knight_qa_harness.gd`) and Knight/Bruiser live depth (`tests/live_*_class_test.gd`) — **depth bar**, not a different product.

**Not in scope:** Gameplay-core planning/UI (`docs/PLANNING_QA_GATE.md`). Class QA does **not** modify `live_planning_scene_test.gd`.

---

## 0. Owner summary (plain language)

**Why this bible exists:** Class QA must catch skills that **look fine in automated tests but fail in F5** — wrong damage, wrong tiles, broken move preview, commit that jumps away from what the player saw. Every factory row, **including rows already marked PASS**, must be written or re-audited to this bar. A green gate script exit code is not enough if the scenario only checks metadata, `ABILITY_USED`, or a Manhattan range bubble. **Regression rule:** if a skill breaks tomorrow, the matching scenario or live case must fail before manual play finds it.

| If this is green… | You can trust… | You still cannot trust… |
|-------------------|----------------|------------------------|
| **`run_<class>_qa_gate.ps1` PASS** | Every factory row has a scenario file; manifest aligned; headless runner did not crash; movement smoke ran | Every skill is fully proven — rows can still be `HARNESS_ONLY` mislabeled `PASS`; scenarios that pass shallow regex but fail TestBattle or show wrong red/blue tiles |
| **Matrix row `PASS` (meta-critic approved)** | That skill/passive has Bible + sim + required planning proof per this bible | Pixels, animation feel, audio |
| **`run_<class>_live_qa.ps1` PASS** | Scripted TestBattle cases: preview, overlay, commit, sim parity for included actives | Every matrix row — live is breadth sample; **headless per-row scenarios are completeness** |
| **`CLASS_QA_SIGNOFF` PASS** | Owner accepted class LOCK | — |

**LEGACY PASS:** Knight owner sign-off predates some bible rules; existing Knight matrix PASS rows are grandfathered until re-audited — not the template for new classes.

**One sentence:** Headless per-row scenarios are the **completeness** owner; live is the **depth spot-check** on the real scene; F5 is still for feel.

**Knight today:** Knight scenarios are the **best existing examples** of planning depth (Tier A/B) and passive sim — but some Knight rows predate full Layer A editor asserts. New work and promotions to `PASS` must meet **this bible**, not copy older sparse `_sim_contract` patterns without upgrade.

---

## 1. What you are building

One **headless class QA suite** per Bible class that:

1. Runs **every factory row** — every active, movement skill, and passive in `<class>_factory.gd`.
2. Proves **every editor field that applies** to that skill — per `ModuleAuthoringRules` (active fields only; greyed/inactive fields are out of scope) — plus every Bible-meaningful `legacy_modifiers` key, for skill header, each module, each layer, each keyword, base and `[+]` upgrade.
3. Uses the **production planning path** where the skill is player-facing (fixture harness → slots → commit → sim) — not a parallel test-only skill implementation.
4. Is **thorough enough** that a green gate means you do **not** need to F5-hand-test every skill to trust the class.

**Knight `KNIGHT_QA_GATE.md` is a filled-in instance of this bible for one class.** New classes clone **this bible**, not a shortened summary.

---

## 2. Delivery shape (one runner, many scenarios)

| Piece | Path | Role |
|-------|------|------|
| **Gate doc** | `docs/<CLASS>_QA_GATE.md` | Coverage matrix, planning tier per skill, honest `PASS` / `HARNESS_ONLY` / `PLANNED` |
| **Gate script** | `scripts/run_<class>_qa_gate.ps1` | Matrix + manifest enforcement, AOE contract, invokes headless runner |
| **Runner** | `tests/<class>_qa_runner.gd` | Loops registry; movement smoke; factory shell |
| **Registry** | `tests/<class>_scenario_registry.gd` | Maps `factory_id` → scenario script |
| **Harness** | `tests/<class>_qa_harness.gd` | Shared boards, sim helpers, planning smoke entry points |
| **Per row** | `tests/skills/<id>_scenario.gd` or `tests/passives/<id>_scenario.gd` | **All proof for that row** |
| **Fixture** | `ClassPlanningChecklistHarness` + `PlanningChecklistHarness` | Headless wired director/input/overlay — **no TestBattle window** |
| **Manifest** | `docs/<class>_meta_critic_manifest.json` | Meta-critic row approval; gate fails if matrix `PASS` exceeds manifest |

**Forbidden as sole coverage:** one monolithic `*_class_scenario.gd`, harness loop without per-row files, or `factory_passive != null` / `ABILITY_USED` only.

---

## 3. Three proof layers (every active / movement skill)

Each scenario must include **all layers that apply** to that skill. Skipping a layer requires an explicit `N/A` note in the gate matrix with reason.

### Layer A scope (what “every editor line” means)

**Authority:** `data/definitions/module_authoring_rules.gd` — same rules the Class Editor uses to show/hide fields.

| Rule | Meaning for QA |
|------|----------------|
| Field visible/active in editor for this module | **Must assert** in `_data_contract` |
| Field greyed / excluded by `ModuleAuthoringRules` | **Do not assert** — out of scope |
| `legacy_modifiers` key cited in Bible or scenario header | **Must assert** outcome or value |
| Header `modules[]` is source of truth | Assert modules; `effects[]` cross-check optional during migration |

**Adequacy levels (matrix honesty):**

| Level | When | Layer A requirement |
|-------|------|---------------------|
| **FULL** | New `PASS` rows; any row touched in a fix pass | Every applicable module field + layers + keywords |
| **STANDARD** | Tier B actives without module migration | Header costs + primary module aim/range/shape/targeting + Bible modifiers |
| **LEGACY** | Pre-bible Knight rows not yet re-audited | May stay `HARNESS_ONLY` until upgraded; **cannot** promote to `PASS` without FULL |

---

Assert factory/`AbilityData` matches what the class editor would show — **before** sim or planning.

**Skill header (ability-data §1):**

| Editor field | Assert |
|--------------|--------|
| `id`, `display_name` | Registered on class unit |
| `planner_group` | PRE_MOVE / ACTION / POST_MOVE column |
| `tags` | attack / movement / heal / … as Bible |
| `primary_resource`, `primary_value` | AP/MP/NONE + cost |
| `secondary_resource`, `secondary_value` | When Bible specifies |
| `cost_modifier`, `cost_modifier_n` | When used |
| `upgraded_primary_value`, `upgraded_secondary_value` | When `[+]` changes cost |
| `uses` / combat limits | When non-default |

**Per module** (`AbilityModule` — every row in Modules panel):

| Editor field | Assert |
|--------------|--------|
| `execution_phase` | ON_PRE / ON_ACTION / ON_POST |
| `primary_type` | DAMAGE, MOVE, PUSH, HEAL, … |
| `amount`, `scaling_stat` | When type uses them |
| `status_type`, `status_duration` | When type applies status |
| `spawn_unit_id` | SPAWN modules |
| `motion_mode` | When primary is motion (MOVE/DASH/SWAP/…) |
| `min_range`, `max_range` | Range band |
| `requires_los` | LOS on/off per `ModuleAuthoringRules` |
| `range_origin` | ACTOR / AIM / … |
| `target_shape`, `target_shape_size` | SINGLE, AOE, ARC, LINE, … |
| `aim_binding`, `aim_module_index` | NEW_AIM vs SAME_AS_MODULE_N |
| `targeting_flags` | Self / Ally / Enemy / Tile / Dash line — **each checked bit** |
| `gate` | ALWAYS, IF_KILL, IF_COLLIDED, … |
| `keywords[]` | Each keyword id + amount |
| `layers[]` | See Layer A2 |
| `bonus_if_adjacent_at_cast`, `def_debuff_before_damage` | DAMAGE-only typed fields |
| `legacy_modifiers` | Bible-critical keys only (name in scenario header) |

**Layer A2 — Each `AbilityLayer` on a module:**

| Field | Assert |
|-------|--------|
| `effect` (`EffectData.type`, `amount`, `scaling_stat`, …) | Layer primitive |
| `condition` (`GameEnums.LayerCondition`) | IF_* gate matches editor |
| `effect.modifiers` | Bible-critical keys only |

**Header fields also in Layer A when non-default:** `kind`, `action_point_cost`, `movement_point_cost`, `range_tiles` (legacy mirror), `presentation_key`, `presentation_anim`, `uses` limits.

**Keywords:** each `AbilityKeyword` — `keyword_id`, `amount`, `emit_as_effect` per `ModuleAuthoringRules`.

**Migration:** When factory still exposes compiled `effects[]`, scenarios assert **modules[]** as source of truth; legacy `effects[]` cross-check optional until row is module-native.

**Rule:** If the skill has **N modules**, the scenario names and asserts **all N** in base; repeat for `upgraded_modules` when `[+]` exists.

**Reference:** `data/definitions/module_authoring_rules.gd` — inactive fields must not be relied on; active fields must be asserted.

### Layer B — Simulation resolution (outcomes)

Prove behavior through **`Simulator` + `AbilitySystem`** on a deterministic board — units in and out of effect, wrong team excluded.

| Check | Required when |
|-------|----------------|
| `AbilitySystem.can_use` / reject illegal target | All targeted skills |
| `ABILITY_USED` (or equivalent) | All actives |
| Damage/heal amounts on **expected units only** | DAMAGE / HEAL |
| Status applied / not applied | Status effects |
| Position change (PUSH/PULL/SWAP/MOVE/TELEPORT) | Displacement |
| Tile terrain / hazard / spawn | CREATE_HAZARD, SPAWN, terrain skills |
| **Footprint** — `GridSystem.get_affected_tiles` in vs out | Any non-SINGLE shape |
| **Base** tier | Always |
| **`[+]` upgrade** tier | When `upgraded_modules` or `upgraded_effects` differ — extra outcome asserted (not “upgrade string non-empty”) |

**Passives:** Layer B only — but must **fire the real trigger** (collision, melee hit, lethal, adjacent count, turn start, etc.). Stat/metadata read without trigger is **HARNESS_ONLY**.

### Layer C — Planning fixture (preview = commit path)

Headless **production** stack: `ClassPlanningChecklistHarness.wire_board` → `PlanningChecklistHarness` select/hover/commit → `assert_slots_match_preview_commit` → `assert_commit_no_jump`.

**Owner exceptions (this bible):**

- **Not required:** full selection-mode sweep per skill  
- **Not required:** drag-mode E2E per skill  
- **Not required:** undo test per skill  

**Still required** when the skill uses that column:

| Skill uses | Planning proof |
|------------|----------------|
| PRE_MOVE module or movement skill | Premove hover, path/preview from projected stand, timeline PRE column |
| POST_MOVE module | Postmove preview + commit slot in POST column |
| MOVE (any) | **Blue move tiles** — legal reach from projected stand matches overlay; illegal tiles not blue (`docs/PLANNING_SKILL_QA_CHECKLIST.md` blue rules) |
| ACTION with range from stand | Red tile contract at stand + hover stand |
| MOVE + skill combo | Tier A or B: ghost/path + skill red re-anchor |
| SWAP / positioning | Slot parity; swap may shift position preview post-commit (documented) |

**Planning tiers** (assign per row in gate doc):

| Tier | Name | Minimum |
|------|------|---------|
| **A** | Full checklist | Phases 1–7 per `docs/PLANNING_SKILL_QA_CHECKLIST.md` (select, hover empty, pathing, hover target, commit, execute, premove+skill) |
| **B** | Commit smoke | Select → hover legal cell → `slots_for_hover` → `assert_slots_match_preview_commit` → `assert_commit_no_jump` → optional timeline column assert |
| **C** | Intent only | Select + economy/timeline contract OR sim-only intent E2E (e.g. bowling charge) |

**Default for new actives:** Tier **B** minimum. Tier **A** for movement+skill composites and flagship skills. Tier **C** only when planning adds no signal beyond sim.

**Shaped skills (AOE / ARC / LINE / CONE):** Layer C must include **red tile set** at hover vs `GridSystem.get_affected_tiles` — not Manhattan range bubble alone (`docs/PLANNING_SKILL_QA_CHECKLIST.md`, `run_aoe_footprint_qa_gate.ps1`).

---

## 4. Per-skill scenario file contract

Every `tests/skills/<factory_id>_scenario.gd` (or `tests/passives/<id>_scenario.gd`) **must**:

```gdscript
## Bible: <one-line clause from class_abilities.txt>
## Globals: <EffectType / trigger hooks named>
## Modules: <M0 ON_ACTION DAMAGE range 1-1 …> [+ upgraded delta summary]
## Planning tier: A | B | C
## Data/Sim delegate: <optional — path::function e.g. bruiser_qa_harness_scenarios.gd::run_charge_strike>
```

**`run_all(failures)` must call, in order:**

1. `_data_contract(failures)` — Layer A (+ A2 per module/layer)  
   - *Knight legacy name:* `_sim_contract` — same layer  
2. `_sim_base(failures)` — Layer B base  
3. `_sim_upgrade(failures)` — Layer B `[+]` when factory has upgrade (else skip with comment)  
4. `_planning_proof(failures)` — Layer C per assigned tier  
   - *Knight legacy shape:* `_phase1` … `_phase7` inside `_planning_proof` or as separate calls — equivalent to Tier **A**  
   - *Tier B:* `run_planning_commit_smoke` / harness helper — equivalent to `_planning_proof`

**Owner exceptions (global — not per skill):** full selection-mode sweep, drag-mode E2E, and undo tests are **not** required on every skill. Tier **A** flagship scenarios (e.g. Knight shield bash) **may** include drag in pathing phase without violating this rule.

```gdscript
# FORBIDDEN as sole content:
_H.run_ability_row(&"cleric_smite", failures)
_H.factory_passive(&"overwatch") != null
```

Delegate only to harness **functions that themselves satisfy Layers A–C** for that id (Knight `run_bash_base_sim` + phases pattern).

### 4.1 Shared harness API (normative)

Class harnesses **should** expose (names may be class-prefixed; behavior must match):

| API | Layer | Behavior |
|-----|-------|----------|
| `assert_module_editor_fidelity(failures, ability, module_index, expected: Dictionary)` | A | For each key in `expected`, assert module field; skip keys where `ModuleAuthoringRules` says field inactive |
| `assert_layer_fidelity(failures, module, layer_index, expected: Dictionary)` | A2 | `effect.type`, `amount`, `condition`, critical modifiers |
| `assert_upgrade_modules_differ(failures, ability, fields: Array)` | A | Base vs `upgraded_modules` differ on named fields |
| `run_sim_ability(failures, board_setup, ability_id, expect: Dictionary)` | B | Single `Simulator.simulate_player_turn`; assert events in `expect` |
| `run_planning_commit_smoke(failures, class_id, ability_id, actor, target)` | C Tier B | `ClassPlanningChecklistHarness.wire_board` → slot parity → no jump |
| `run_single_passive(failures, passive_id)` | B | Dispatch **one** passive block with real trigger — not full-class smoke loop |

**Gold scenario references (read before authoring):**

| Pattern | Scenario file | Layers A+B owner |
|---------|---------------|------------------|
| Tier A (7-phase + sim in scenario) | `tests/skills/shield_bash_scenario.gd` | In scenario (`_sim_contract` + `_phase*`) |
| Tier B (sim in harness + planning in scenario) | `tests/skills/bruiser_charge_strike_scenario.gd` | `tests/bruiser_qa_harness_scenarios.gd::run_charge_strike` — scenario **must** cite delegate in header |
| Passive trigger sim | `tests/passives/collision_retaliator_scenario.gd` | `bruiser_qa_harness_scenarios.gd` or inline |
| Per-passive dispatch | `tests/passives/lancer_kinetic_charge_scenario.gd` | `lancer_qa_harness.gd` `run_single_passive` block |

**Delegate rule:** A one-line `run_all` is **valid** when the header names the harness function that implements Layers A+B, and §8.2 shallow check passes. Invalid when header is missing or harness function is metadata-only.

---

## 5. Passive scenario contract

| Requirement | Detail |
|-------------|--------|
| Bible header | Clause + trigger name |
| Promotion | If passive is promotion-gated, scenario states loadout used |
| Trigger setup | Board state that fires hook in production |
| Base outcome | Sim event or state change |
| `[+]` outcome | When `upgraded_description` / upgraded modifiers differ |
| Planning | **None** unless passive alters planning UI (rare); planning-phase passives (e.g. Overwatch) use **simulated planning boundary** or dedicated fixture — document in matrix |

**`run_single_passive(id)`** in harness is allowed **only** if each passive block is a full Layer B proof (Lancer pattern), not a shared 15× smoke loop.

### 5.1 Planning-boundary passive (Overwatch example)

Archer **Overwatch** fires from planning boundary (unspent AP), not a simple on-hit hook.

| Step | Proof |
|------|-------|
| Data contract | `overwatch` passive registered; modifiers document reaction |
| Trigger setup | Headless fixture: end planning with unspent AP OR harness calls production overwatch hook after move resolution |
| Sim outcome | Enemy entering LOS during resolution takes weapon-scaled damage; `overwatch_used` flag set |
| Planning | Optional Tier C slice on one class board — **not** required on every Archer skill; this row carries it |
| Matrix note | `Planning: boundary fixture` in gate doc |

Passives that only change stats with no combat trigger: assert stat/rule in sim when unit acts — metadata-only `!= null` remains **HARNESS_ONLY**.

---

## 6. Movement, premove, and postmove

If **any module** has `execution_phase` ON_PRE or ON_POST, or `planner_group` is PRE_MOVE / POST_MOVE:

1. **Data contract** asserts correct column and phase.
2. **Sim** proves MP/AP interaction when Bible specifies.
3. **Planning** proves:
   - Preview path/ghost from **projected** stand after prior commits
   - Red range re-anchors to hover stand
   - Commit places entries in **correct timeline column**
   - `assert_commit_no_jump` — last preview matches committed slots

**Movement-only skills** (Run, class movement): include in movement planning smoke **or** per-row scenario with Tier B minimum.

---

## 7. Live tests (depth bar, not duplicate matrix)

`tests/live_<class>_class_test.gd` proves **TestBattle + GdUnit** path: overlay at hover, commit, sim parity for scripted cases.

| Rule | Detail |
|------|--------|
| Live **depth** | Match Knight/Bruiser live thoroughness (preview, commit, shaped overlay) for cases included |
| Live **breadth** | Headless per-row scenarios are the **completeness** owner; live may batch high-risk actives |
| Live **does not replace** | Layer A/B/C headless proof for matrix `PASS` |
| Passives in live | Optional; headless trigger sim is required |

Green live with shallow headless is **FAIL** under this bible.

---

## 8. Matrix status (honest labels)

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file |
| `HARNESS_ONLY` | File runs green but **missing** Layer A, B, or required C per this bible |
| `PASS` | Meta-critic approved — all required layers for that row |
| `N/A` | Owner deferral with target phase + reason |

**Gate script must fail when:**

- `PASS` row missing scenario file  
- `PASS` count > meta-critic manifest approved count  
- Manifest `last_score` < threshold  
- Scenario file is a **thin delegate** (see §13)  
- Meta-critic has not approved row for `PASS` promotion  

**Promoting `HARNESS_ONLY` → `PASS`:** meta-critic only — not agent self-grade.

### 8.1 Machine enforcement (gate scripts)

| Check | Method | Status |
|-------|--------|--------|
| Scenario file exists for each `PASS` row | `Test-MatrixScenarioFiles` | **Shipped** (`qa_gate_matrix_helpers.ps1`) |
| Manifest score / approval | `Test-ManifestScore` | **Shipped** |
| Thin delegate ban | `Test-ScenarioContractShallow` — see §8.2 | **Shipped** |
| AOE shaped rows | `run_aoe_footprint_qa_gate.ps1` | **Shipped** |
| Layer A FULL per module | `assert_module_editor_fidelity` in harness | **Per-class rollout** |
| Active with PRE/POST modules but no premove/postmove Layer C | Detect `ON_PRE`/`ON_POST` modules without `movement_planning_smoke` or premove path | **PLANNED** (doc ban today — §13) |

Gate **must** call shipped helpers before Godot runner. Rows failing shallow contract cannot be matrix `PASS`.

### 8.2 Thin delegate detection (`Test-ScenarioContractShallow`)

A scenario file **fails** gate when:

| Condition | Example |
|-----------|---------|
| `run_all` is only `_H.run_ability_row` / `run_single_ability` **without** header delegate **and** without local Layer A/B | Cleric smite anti-pattern |
| `factory_passive(...) != null` without `Simulator` / `AbilitySystem` | Overwatch metadata anti-pattern |
| Active missing Layer A: no `_data_contract` / `_sim_contract` / `## Data/Sim delegate:` in header | — |
| Active missing Layer C: no `_planning_proof`, `_phase`, `PlanningChecklistHarness`, `ClassPlanningChecklistHarness`, or `run_planning_commit_smoke` | — |
| Passive missing sim: no `Simulator`, `AbilitySystem`, `run_single_passive`, or `_Scenarios.run_*` to harness with trigger | — |
| Header claims delegate but harness function is metadata-only | Fail at meta-critic |

**Layer A in file OR delegated:** Shallow check passes Layer A when scenario contains `_data_contract` / `_sim_contract` **or** header line `## Data/Sim delegate:` pointing at harness function that implements Layer A+B (reviewed at meta-critic).

**Exception:** matrix row marked `HARNESS_ONLY` or `PLANNED` — not checked for PASS promotion.

---

## 9. Global systems (mandatory)

### Rule A — Prefer shared global systems

Skills and passives ride **existing** global paths (`EffectType` / `AbilityModule`, passive triggers, `PlanningChecklistHarness`, `Simulator`). No parallel test-only skill logic. No per-skill production `if ability.id == …` when data can express behavior.

### Rule B — Bible-exact keywords (no “close enough”)

| Bible intent | Wrong global | Right approach |
|--------------|--------------|----------------|
| Behind-placement (Suplex) | `SWAP` | `THROW_BEHIND` / reposition effect |
| Exchange positions (Swap skill) | Teleport chain | `EffectType.SWAP` |
| PUSH into wall | `SWAP` / `TELEPORT` | `PUSH` + collision pipeline |
| Passive “on melee hit” | Poll HP in presentation | Shared on-hit passive trigger in sim |

**Authority order:** `class_abilities.txt` → `ModuleAuthoringRules` / `EffectType` → factory → scenario asserts.

### Rule C — Preview = commit

Layer C exists to enforce `.cursor/rules/move-preview-intent-truth.mdc`. `assert_commit_no_jump` is mandatory for Tier A and B actives.

**Meta-critic FAIL (`Fix target: implementation`)** when wrong effect type, per-skill branch, or passive tested without trigger.  
**Meta-critic FAIL (`Fix target: qa_test`)** when scenario omits named global effect even if implementation is correct.

### Decision tree (fix game vs fix QA)

```
BAR failed?
  yes → assert names Bible clause?
    yes → assert names correct global effect/trigger?
      yes → Fix implementation
      no  → Fix QA test (wrong effect asserted)
    no  → Fix QA test (add asserts, triggers, upgrade tier)
  no  → matrix row missing or scenario shallow (§8.2)?
    yes → Fix QA (deepen scenario or honest HARNESS_ONLY)
    no  → PASS candidate for that row
```

---

## 10. Meta-critic rubric (class row)

Score each matrix row before `PASS`:

| # | Question |
|---|----------|
| 1 | Bible clause cited and tested? |
| 2 | Every module + layer listed in header and contract-asserted? |
| 3 | Base sim proves named global effects? |
| 4 | `[+]` sim proves upgrade delta when data exists? |
| 5 | Planning tier met (A/B/C)? |
| 6 | Shaped skills: footprint in + out + red/overlay parity? |
| 7 | Passive: real trigger, not metadata? |

### 10.1 Binary row PASS checklist (all YES required)

- [ ] Scenario file exists at matrix path  
- [ ] Header cites Bible + globals + module summary + planning tier  
- [ ] Layer A: applicable editor fields asserted (FULL or STANDARD per §3)  
- [ ] Layer B: base sim with in/out targets where relevant  
- [ ] Layer B: `[+]` sim when upgrade data differs  
- [ ] Layer C: tier A/B/C met for actives (N/A documented for passives)  
- [ ] Shaped: footprint + red/overlay parity  
- [ ] `Test-ScenarioContractShallow` would pass  
- [ ] Meta-critic manifest row approved  

**Class LOCK (all classes, including Knight going forward):** 100% rows `PASS` (or documented `N/A`) + `run_<class>_qa_gate.ps1` exit 0 + `run_<class>_live_qa.ps1` exit 0 + manifest ≥ 88 + owner sign-off in `docs/CLASS_QA_SIGNOFF.md`.

**Knight today:** Owner sign-off PASS predates live runner; Knight matrix rows may be **LEGACY PASS** until re-audited against §8.2. New classes and Knight re-audits use **CLASS LOCK** above.

---

## 11. Commands

```powershell
# Headless class QA (required every factory/scenario change)
.\scripts\run_<class>_qa_gate.ps1

# Live depth check (required before owner sign-off; not a substitute for per-row headless)
.\scripts\run_<class>_live_qa.ps1

# Shaped footprint contract (wired into class gates)
.\scripts\run_aoe_footprint_qa_gate.ps1

# NOT class QA
.\scripts\run_planning_qa_gate.ps1
```

---

## 12. New class checklist

1. Read `class_abilities.txt` § class.  
2. Create `docs/<CLASS>_QA_GATE.md` from `docs/_CLASS_QA_GATE_TEMPLATE.md` — link **this bible**.  
3. List every `*_factory.gd` id in matrix; all start `PLANNED`.  
4. Add `tests/<class>_scenario_registry.gd`, `tests/<class>_qa_runner.gd`, `tests/<class>_qa_harness.gd`.  
5. For **each** factory row: add scenario file satisfying §4–5; assign planning tier.  
6. Copy `scripts/run_knight_qa_gate.ps1` → `run_<class>_qa_gate.ps1`; wire `qa_gate_matrix_helpers.ps1`.  
7. Run gate; fix until matrix honest; meta-critic per row; then owner sign-off.  

---

## 13. Anti-patterns (from project history — instant FAIL)

| Pattern | Why FAIL |
|---------|----------|
| Scenario would still PASS if skill effect or overlay were removed | Test does not defend behavior — the F5-broken / test-green failure mode |
| Matrix `PASS` with `factory_* != null` only | No behavior proof |
| Sim-only when skill has PRE/POST modules | Missing move preview / slots |
| `GridSystem` smoke disconnected from ability under test | Wrong geometry owner |
| Live overlay compared to range bubble only | Not Bible footprint |
| 15× passive full smoke in one harness call per passive file | Not isolated proof |
| Gate green without manifest alignment | Self-grade |
| Claiming LOCK while `CLASS_QA_SIGNOFF` NOT PASS | False sign-off |

---

## 14. Example mapping (`knight_shield_bash` — honest)

Knight shield bash is Tier **A** (7-phase). **Today** it strongly covers Layer B + C; Layer A is **partial** (effect-type probes, not every editor field). New classes must meet full §3; Knight rows should be re-audited when touched.

| Bible / editor aspect | Layer A (today) | Layer B | Layer C |
|-----------------------|-----------------|---------|---------|
| DAMAGE + PUSH in data | `ability_has_effect` DAMAGE, PUSH | `run_bash_base_sim` | — |
| `[+]` STAGGER on wall collision | `PUSH_STAGGER_ON_COLLISION` upgrade | `run_bash_wall_stagger_upgrade` | — |
| Range / red at stand | partial via red contract helpers | — | `assert_red_contract`, excludes OOB enemy |
| Select economy AP/MP | — | — | phase1 AP/MP + timeline empty |
| Premove + bash | — | — | phase7 premove then bash |
| Commit slots | — | — | phase5 `assert_slots_match_preview_commit` |

**Gold target:** add per-module asserts for `min_range`, `max_range`, `targeting_flags`, `aim_binding` to `_sim_contract` when promoting or editing this row.

---

## 15. Document hierarchy

```
class_abilities.txt          (what skills do)
docs/CLASS_QA_BIBLE.md       (how to prove it — this file)
docs/<CLASS>_QA_GATE.md      (per-class matrix + tier assignments)
docs/KNIGHT_QA_GATE.md       (Knight instance — reference implementation)
.cursor/rules/class-qa-knight-bar.mdc  (enforcement)
```

---

## 16. Gauntlet stub (this document)

```text
GOAL: Universal class QA bar for new AND existing rows — regression defense (skill works per Bible; preview/commit/red-blue tiles honest); reject shallow PASS; headless per-row completeness + live depth spot-check
BAR: docs/CLASS_QA_BIBLE.md — §0 owner summary; §3 Layer A scope; §4.1 harness API; §8.1–8.2 enforcement; §9 Rule A/B/C + decision tree; §10.1 binary checklist; gold references; KNIGHT_QA_GATE links here
PASS_THRESHOLD: 85
RULES: class-qa-knight-bar.mdc, global-systems-first.mdc, move-preview-intent-truth.mdc
ARTIFACT: docs/CLASS_QA_BIBLE.md, tests/skills/shield_bash_scenario.gd, tests/skills/bruiser_charge_strike_scenario.gd, scripts/qa_gate_matrix_helpers.ps1
```

### 16.1 Bible document rubric (gauntlet scores this file)

| # | Criterion | Max |
|---|-----------|-----|
| 1 | Owner can tell what green gate means (§0) | 15 |
| 2 | Layers A/B/C defined with applicability scope | 20 |
| 3 | Per-row contract + gold references + anti-patterns | 20 |
| 4 | Enforcement spec matches shipped helpers (§8) | 15 |
| 5 | Live vs headless vs Knight instance hierarchy clear | 10 |
| 6 | Exceptions (drag/undo/select) explicit | 10 |
| 7 | No internal contradictions (LOCK, LEGACY vs PASS) | 10 |

**PASS:** total ≥ 85 and no criterion below half its max.

---

*Version: 2026-08-09 rev 5 — owner-intent bar: regression defense, red/blue tiles, anti-shallow PASS. Knight instance: `KNIGHT_QA_GATE.md`. Shallow contract: `qa_gate_matrix_helpers.ps1`.*
