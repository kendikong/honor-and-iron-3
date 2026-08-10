# Class QA Bible

**Authority:** This document is the **single specification** for how every Bible class is validated in automated QA.  
**Per-class instances:** `docs/<CLASS>_QA_GATE.md` (matrix + status) · `scripts/run_<class>_qa_gate.ps1` (runner)  
**Mechanics source:** `class_abilities.txt` § class + `core/factory/classes/<class>_factory.gd`  
**Quality reference:** Knight headless fixture suite (`tests/skills/shield_bash_scenario.gd`, `tests/knight_qa_harness.gd`) and Knight/Bruiser live depth (`tests/live_*_class_test.gd`) — **depth bar**, not a different product.

**Not in scope:** Gameplay-core planning/UI (`docs/PLANNING_QA_GATE.md`). Class QA does **not** modify `live_planning_scene_test.gd`.

---

## 0. Owner summary (plain language)

| If this is green… | You can trust… | You still cannot trust… |
|-------------------|----------------|------------------------|
| **`run_<class>_qa_gate.ps1` PASS** | Every factory row has a scenario file; manifest aligned; headless runner did not crash; movement smoke ran | Every skill is fully proven — rows can still be `HARNESS_ONLY` mislabeled `PASS` until meta-critic approves |
| **Matrix row `PASS` (meta-critic approved)** | That skill/passive has Bible + sim + required planning proof per this bible | Pixels, animation feel, audio |
| **`run_<class>_live_qa.ps1` PASS** | Scripted TestBattle cases: preview, overlay, commit, sim parity for included actives | Every matrix row — live is breadth sample; **headless per-row scenarios are completeness** |
| **`CLASS_QA_SIGNOFF` PASS** | Owner accepted class LOCK | — |

**One sentence:** Headless per-row scenarios are the **completeness** owner; live is the **depth spot-check** on the real scene; F5 is still for feel.

**Knight today:** Knight scenarios are the **best existing examples** of planning depth (Tier A/B) and passive sim — but some Knight rows predate full Layer A editor asserts. New work and promotions to `PASS` must meet **this bible**, not copy older sparse `_sim_contract` patterns without upgrade.

---

## 1. What you are building

One **headless class QA suite** per Bible class that:

1. Runs **every factory row** — every active, movement skill, and passive in `<class>_factory.gd`.
2. Proves **every authored line** that affects behavior — skill header, each module, each layer, each keyword, base and `[+]` upgrade.
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

### Layer A — Data contract (skill editor fidelity)

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

### 8.1 Machine enforcement (target — gate scripts should implement)

| Check | Method |
|-------|--------|
| Scenario file exists for each `PASS` row | `Test-MatrixScenarioFiles` in `qa_gate_matrix_helpers.ps1` |
| Manifest score / approval | `Test-ManifestScore` |
| Thin delegate ban | Fail if `run_all` body is only `_H.run_ability_row` / `run_single_ability` / `factory_passive != null` without local asserts |
| Minimum structure | Each active scenario references `_data_contract` or `_sim_contract` **and** `_planning_proof` or `_phase` or `run_planning_commit_smoke` |
| Shaped skills | Scenario or harness calls footprint helper (`GridSystem.get_affected_tiles` in/out) |
| Shared Layer A helper (PLANNED) | `assert_module_editor_fidelity(ability, module_index, expected: Dictionary)` gated by `ModuleAuthoringRules` |

Until thin-delegate detection ships, treat **green gate + shallow file** as `HARNESS_ONLY`, never `PASS`.

---

## 9. Global systems (mandatory)

Copy enforcement from `docs/KNIGHT_QA_GATE.md` § Global systems fidelity:

- **Rule A:** Factory data + `AbilitySystem` / passive triggers — no per-skill production branches.  
- **Rule B:** Bible-exact keywords — no SWAP for behind-placement, etc.  
- **Preview = commit:** Layer C exists to enforce `move-preview-intent-truth.mdc`.  

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

**Class LOCK:** 100% rows `PASS` (or documented `N/A`) + `run_<class>_qa_gate.ps1` exit 0 + `run_<class>_live_qa.ps1` exit 0 + manifest ≥ 88 + owner sign-off in `docs/CLASS_QA_SIGNOFF.md`.

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
GOAL: Universal class QA spec — headless per-row completeness, editor fidelity, planning fixture, live depth bar
BAR: docs/CLASS_QA_BIBLE.md exists; §0 owner summary; Layers A/B/C; anti-patterns; LOCK includes live; links from _CLASS_QA_GATE_TEMPLATE.md
PASS_THRESHOLD: 85
RULES: class-qa-knight-bar.mdc, global-systems-first.mdc, move-preview-intent-truth.mdc
ARTIFACT: this file, docs/KNIGHT_QA_GATE.md, tests/skills/shield_bash_scenario.gd
```

---

*Version: 2026-08-09 — owner mandate: single headless class suite, editor-fidelity, Knight-depth thoroughness, no per-skill drag/undo requirement. Revised after gauntlet critic round 1 (76/100).*
