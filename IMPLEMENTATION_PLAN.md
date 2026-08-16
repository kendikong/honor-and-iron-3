# Honor & Iron 3 — Implementation Plan

**ACTIVE (2026-08-16):** Convert Extra Rules into real modules / layers.

**Binding matrix:** [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](docs/design/EXTRA_RULES_TO_MODULES_PLAN.md)  
**Module bible:** [`docs/design/ability-data.md`](docs/design/ability-data.md)  
**Skill text:** `class_abilities.txt`

Extra Rules was a leftover-bag rename. That pass is **rejected**. Chat tables are not a substitute. Agents must execute the on-disk matrix.

---

## What to do

Convert every Extra Rule into the skill-module bible: header, module primary (including MOVE / JUMP / TELEPORT landing verbs), keyword, layer + condition, gate, targeting / Condition, or a **new EffectType / StatusType / LayerCondition**. Then **delete** that skill’s Extra Rules in the same change.

**Do not use Motion Mode.** Landing is the dest effect (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, …). Motion Mode was a leftover dropdown.

Combat reads those fields. Extra Rules is not a destination.

---

## Phases

| Phase | Work | Exit |
|-------|------|------|
| **ER-1** | Shared punches: use existing `GRANT_AP` / `GRANT_SCRAP` / `PAIRED_MOVE`; finish CREATE_HAZARD / SPAWN knobs; header once-per-turn / spend-all-MP; add missing types only when the matrix says **new** | Types exist; Extra Rules not used for those punches |
| **ER-2** | Convert class by class (Knight → Bruiser → Lancer → Archer → Mercenary → Monk → Rogue → Beast Rider → Cleric → Mage → Engineer → Shaman). One skill: implement Solution → extras empty → class gate + live **PASS** | Every matrix row converted |
| **ER-3** | Delete `AbilityExtraRule` and Extra Rules UI | Grep `_add_extra` / Extra Rules on class skills = 0 |

Do **not** start ER-2 until the owner names the first skill or says proceed from Knight.

---

## Conversion law

| Home | Use when |
|------|----------|
| Header | Cost, once-per-turn, skip-Action, delay |
| Module primary | The verb, including landing (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `PAIRED_MOVE`, `GRANT_AP`, …) |
| Keyword | TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO |
| Layer + condition | Extra punch on the same targets |
| Gate | Whether a module runs |
| Targeting / Condition | Who you may click |
| Typed field on an existing punch | Hazard / spawn knobs, bounce, … |
| New EffectType / StatusType / LayerCondition | Only if nothing above fits. Grow the dropdown. |

**Forbidden:** new Extra Rules, leftover bags, harvesting keys, `if ability.id == …`, calling Extra Rules “modules,” converting into **Motion Mode**.  
**Out of scope:** passives (until owner asks).  
**Owner open:** Tactical Retreat backwards; Adrenaline Surge skip-Action.

---

## QA

After each class: `.\scripts\run_<class>_qa_gate.ps1` **and** `.\scripts\run_<class>_live_qa.ps1`.  
Planning/commit edits: `.\scripts\run_planning_qa_gate.ps1`.  
Sim/core: `.\scripts\run_regression_tests.ps1`.
