# Honor & Iron 3 — Implementation Plan

**ACTIVE (2026-08-16):** Convert Extra Rules into real modules / layers.

**Binding matrix:** [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](docs/design/EXTRA_RULES_TO_MODULES_PLAN.md)  
**Module bible:** [`docs/design/ability-data.md`](docs/design/ability-data.md)  
**Skill text:** `class_abilities.txt`

Extra Rules was a leftover-bag rename. That pass is **rejected**. Chat tables are not a substitute. Agents must execute the on-disk matrix.

---

## What to do

Convert every Extra Rule into the skill-module bible: header, module primary (including MOVE / JUMP / TELEPORT landing verbs), keyword, layer + condition, gate, targeting / Condition, or a **new EffectType / StatusType / LayerCondition**. Then **delete** that skill’s Extra Rules in the same change.

Combat reads those fields. Extra Rules is not a destination.

**DELETE Motion Mode.** `GameEnums.MotionMode`, the Class Editor dropdown, factory stamps, and combat reads of `module.motion_mode` all go. Landing is dest EffectType only (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, …). Do not convert leftovers into Motion Mode.

---

## Phases

| Phase | Work | Exit |
|-------|------|------|
| **ER-1** | Shared punches: use existing `GRANT_AP` / `GRANT_SCRAP` / `PAIRED_MOVE`; finish CREATE_HAZARD / SPAWN knobs; header once-per-turn / spend-all-MP; add missing types only when the matrix says **new** | Types exist; Extra Rules not used for those punches |
| **ER-2** | Convert class by class (Knight → Bruiser → Lancer → Archer → Mercenary → Monk → Rogue → Beast Rider → Cleric → Mage → Engineer → Shaman). One skill: implement Solution → extras empty → class gate + live **PASS** | Every matrix row converted |
| **ER-3** | **DELETE** Extra Rules (`AbilityExtraRule`, Extra Rules UI) **and Motion Mode** (`GameEnums.MotionMode`, editor dropdown, factory `motion_mode`, combat `module.motion_mode` reads) | Grep `_add_extra` / Extra Rules / `MotionMode` / `motion_mode` on class skills = 0 |

Do **not** start ER-2 until the owner names the first skill or says proceed from Knight.

---

## Conversion law

| Home | Use when |
|------|----------|
| Header | Cost, once-per-turn, skip-Action, delay |
| Module primary | The verb. Pick a **family** (`ability-data.md` §2.2): Hit, Heal/Shield, Status, Walk, Jump, Teleport, Dash/Swap, Together, Control, Board, Grant. Do not grow a flat dump. |
| Keyword | TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO |
| Layer + condition | Extra punch on the same targets |
| Gate | Whether a module runs |
| Targeting / Condition | Who you may click |
| Typed field on an existing punch | Hazard / spawn knobs, bounce, … |
| New EffectType / StatusType / LayerCondition | Only if nothing above fits. Grow the dropdown. |

**Forbidden:** new Extra Rules, leftover bags, harvesting keys, `if ability.id == …`, calling Extra Rules “modules,” converting into **Motion Mode**.  
**Out of scope:** passives (until owner asks).

---

## QA

After each class: `.\scripts\run_<class>_qa_gate.ps1` **and** `.\scripts\run_<class>_live_qa.ps1`.  
Planning/commit edits: `.\scripts\run_planning_qa_gate.ps1`.  
Sim/core: `.\scripts\run_regression_tests.ps1`.
