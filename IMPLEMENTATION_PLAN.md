# Honor & Iron 3 — Implementation Plan

**ACTIVE (2026-08-16):** Convert Extra Rules into real modules / layers.

**Binding matrix:** [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](docs/design/EXTRA_RULES_TO_MODULES_PLAN.md)  
**Module bible:** [`docs/design/ability-data.md`](docs/design/ability-data.md) — header, modules, keywords, layers, gates, targeting  
**Skill bible:** `class_abilities.txt` — every Active / Reposition line is law

**Bibles stay in context.** Chat summaries, compaction, and handoff notes are **not** skill text. After any summarization, **reread** `class_abilities.txt` (that skill’s line + upgrade) and `docs/design/ability-data.md` (the module home) before converting. Do not author from memory of this chat.

Extra Rules was a leftover-bag rename. That pass is **rejected**. Chat tables are not a substitute. Agents must execute the on-disk matrix.

---

## What to do

Convert every Extra Rule into the skill-module bible: header, module primary (including MOVE / JUMP / TELEPORT landing verbs), keyword, layer + condition, gate, targeting / Condition, or a **new EffectType / StatusType / LayerCondition**. Then **delete** that skill’s Extra Rules **and leftover `modifiers` keys** in the same change.

**Cheat (forbidden):** empty Extra Rules while combat still runs the old leftover key. That is how the last pass failed.

Combat must read header / module / keyword / layer / gate / targeting / typed fields — not Extra Rules and not `effect.modifiers["harvested_key"]`.

**DELETE Motion Mode.** `GameEnums.MotionMode`, the Class Editor dropdown, factory stamps, and combat reads of `module.motion_mode` all go. Landing is dest EffectType only (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, …). Do not convert leftovers into Motion Mode.

### Done for one skill (all required)

1. Changelog quotes the **skill bible** line + upgrade from `class_abilities.txt`.
2. Names **family** + **home** (header / type / keyword / layer / gate / targeting / field).
3. That skill’s `extras` empty (base and upgrade). No `_add_extra` on that factory skill.
4. No leftover Extra Rule keys on that skill’s `effect.modifiers`.
5. `CONVERTED_SKILL_IDS` in `tests/extra_rules_conversion_contract.gd` includes that id.
6. Class gate + live **PASS**.

No bible quote in the changelog → the conversion did not happen.

---

## Phases

| Phase | Work | Exit |
|-------|------|------|
| **ER-1** | Shared punches: use existing `GRANT_AP` / `GRANT_SCRAP` / `PAIRED_MOVE`; finish CREATE_HAZARD / SPAWN knobs; header once-per-turn / spend-all-MP; add missing types only when the matrix says **new** | Types exist; Extra Rules not used for those punches |
| **ER-2** | Convert class by class (Knight → Bruiser → Lancer → Archer → Mercenary → Monk → Rogue → Beast Rider → Cleric → Mage → Engineer → Shaman). One skill: bible quote → Solution → extras **and** leftover keys gone → add id to `CONVERTED_SKILL_IDS` → class gate + live **PASS** | Every matrix row converted; contract test PASS |
| **ER-3** | **DELETE** Extra Rules (`AbilityExtraRule`, Extra Rules UI) **and Motion Mode** (`GameEnums.MotionMode`, editor dropdown, factory `motion_mode`, combat `module.motion_mode` reads) | Grep `_add_extra` / Extra Rules / `MotionMode` / `motion_mode` on class skills = 0 |

Do **not** start ER-2 until the owner names the first skill or says proceed from Knight.

---

## Conversion law

| Home | Use when |
|------|----------|
| Header | Cost, once-per-turn, skip-Action, delay |
| Module primary | The verb. Pick a **family** in the conversion plan (Attack, Movement (Self), Forced Movement, Move someone, Hazard, Summon, Status, Heal, Shield, Stance, Resource). Types grow inside a family. Riders are fields/layers, not new families. |
| Keyword | TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO |
| Layer + condition | Extra punch on the same targets |
| Gate | Whether a module runs |
| Targeting / Condition | Who you may click |
| Typed field on an existing punch | Hazard / spawn knobs, bounce, … |
| New EffectType / StatusType / LayerCondition | Only if nothing above fits. Grow the dropdown. |

**Forbidden:** new Extra Rules, leftover bags, harvesting keys, `if ability.id == …`, calling Extra Rules “modules,” converting into **Motion Mode**.  
**Out of scope:** passives (until owner asks).

### Module primary families (reference)

Locked names. Full add-rules and Extra Rule mapping: conversion plan. Module shape: `ability-data.md`. Skill lines: `class_abilities.txt`.

| Family | Opening verb |
|--------|----------------|
| **Attack** | Hurt (ATK / MAG ATK) |
| **Movement (Self)** | You change tiles (MOVE / DASH / JUMP / TELEPORT) |
| **Forced Movement** | They slide (PUSH / PULL) |
| **Move someone** | You put a body on a tile (swap, carry, usher, throw-behind, drag) |
| **Hazard** | The tile keeps doing something |
| **Summon** | You make a unit or object |
| **Status** | Apply or strip a named condition (no hit) |
| **Heal** | Restore HP |
| **Shield** | Grant over-HP |
| **Stance** | You set yourself up this turn |
| **Resource** | Grant/refund AP, Scrap, later currencies |

Watch for later split: Link, Scrap, Destroy — only if they become their own verb pile.

---

## QA

After each class: `.\scripts\run_<class>_qa_gate.ps1` **and** `.\scripts\run_<class>_live_qa.ps1`.  
Converted-skill extras: headless `res://tests/run_ability_module_bridge_test.gd` (includes `extra_rules_conversion_contract`).  
Planning/commit edits: `.\scripts\run_planning_qa_gate.ps1`.  
Sim/core: `.\scripts\run_regression_tests.ps1`.
