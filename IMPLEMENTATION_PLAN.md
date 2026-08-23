# Honor & Iron 3 — Implementation Plan

**ACTIVE (2026-08-16):** Convert Extra Rules into real modules / layers.

**Binding matrix:** [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](docs/design/EXTRA_RULES_TO_MODULES_PLAN.md)  
**Module bible:** [`docs/design/ability-data.md`](docs/design/ability-data.md) — header, modules, keywords, layers, gates, targeting  
**Skill bible:** `class_abilities.txt` — every Active / Reposition line is law

**Document boundaries:** `ability-data.md` explains how to author modules. The binding matrix explains how each existing leftover maps into that model. This plan owns migration order and legacy deletion, including Motion Mode.

**Bibles stay in context.** Chat summaries, compaction, and handoff notes are **not** skill text. After any summarization, **reread** `class_abilities.txt` (that skill’s line + upgrade) and `docs/design/ability-data.md` (the module home) before converting. Do not author from memory of this chat.

Extra Rules was a leftover-bag rename. That pass is **rejected**. Chat tables are not a substitute. Agents must execute the on-disk matrix.

**Effect Knobs / typed extras are not a home (ABSOLUTE).** Moving a leftover into `AbilityModule` `@export` fields (Class Library “Effect Knobs”, “Typed Skill Fields”, or any similar UI bucket) is **the same cheat** as the Extra Rules bag — just a different drawer. **Forbidden:** new dump containers, renamed bags, editor-only hiding, or “we’ll wire it later” fields. Every leftover must land in a **real module primary**, **layer + condition**, **keyword**, **gate**, or **header** field that combat already reads — per the binding matrix **Solution** column. If the matrix says **layer**, you author a layer; you do **not** add a knob.

---

## What to do

Convert every Extra Rule into the skill-module bible: header, module primary (including MOVE / JUMP / TELEPORT landing verbs), keyword, layer + condition, gate, targeting / Condition, or a **new EffectType / StatusType / LayerCondition**. Then **delete** that skill’s Extra Rules **and leftover `modifiers` keys** in the same change.

**Cheat (forbidden — instant FAIL):**

| Cheat | Why it fails |
|-------|----------------|
| Empty Extra Rules while combat still reads `effect.modifiers["harvested_key"]` | First failed pass |
| Stuff leftovers into **Effect Knobs** / typed `@export` on `AbilityModule` | Second failed pass — **not conversion** |
| New `@export` or UI bucket instead of module/layer/keyword | Third form of the same dump |
| Matrix says **Existing layer** but you add a typed field | Bypasses the shape bar |
| Mark IMPLEMENTATION_PLAN ☑ or add to `CONVERTED_SKILL_IDS` while shape gate fails for that skill | False completion |

Combat must read **module primary / layer / keyword / gate / targeting / header** — not Extra Rules, not `effect.modifiers` harvest keys, and **not** bespoke typed-extra knobs unless the matrix explicitly says **New field** (ER-1 allowlist only).

**Legacy cleanup:** `GameEnums.MotionMode`, the Class Editor dropdown, factory stamps, and combat reads of `module.motion_mode` are removed in ER-3. Landing is authored as a destination `EffectType` (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, …).

### Done for one skill (all required)

1. Changelog quotes the **skill bible** line + upgrade from `class_abilities.txt`.
2. Names **family** + **home** (header / module primary / keyword / **layer + condition** / gate / targeting) — **not** Effect Knobs.
3. That skill’s `extras` empty (base and upgrade). No `_add_extra` on that factory skill.
4. No leftover Extra Rule keys on that skill’s `effect.modifiers`.
5. Factory is **Swap-shaped** (`knight_swap` gold standard): riders on **layers** or extra **modules**, not typed-extra dumps.
6. `run_layer_shape_conversion_gate.gd` — **no failures** for this skill id (use `--audit` to list debt; enforce mode must clear this skill before ☑).
7. `CONVERTED_SKILL_IDS` includes that id only after (5) and (6).
8. Class gate + live **PASS**.

No bible quote in the changelog → the conversion did not happen.  
Effect Knobs still set on that skill → the conversion did not happen.

---

## Phases

| Phase | Work | Exit |
|-------|------|------|
| **ER-1** | Shared punches: use existing `GRANT_AP` / `GRANT_SCRAP` / `PAIRED_MOVE` (**Pre-Move only** — not Glorious Charge on Action); finish CREATE_HAZARD / SPAWN knobs; header once-per-turn / spend-all-MP; add missing types only when the matrix says **new** | Types exist; Extra Rules not used for those punches |
| **ER-2** | Convert class by class (Knight → … → Shaman). One skill: bible quote → binding matrix **Solution** → **real module/layer/keyword** (never Effect Knobs dump) → extras **and** leftover keys gone → shape gate clear → `CONVERTED_SKILL_IDS` → class gate + live **PASS** | Every matrix row **shape-complete** (gate green per skill) |
| **ER-3** | **DELETE** Extra Rules (`AbilityExtraRule`, Extra Rules UI) **and Motion Mode** (`GameEnums.MotionMode`, editor dropdown, factory `motion_mode`, combat `module.motion_mode` reads) | Grep `_add_extra` / Extra Rules / `MotionMode` / `motion_mode` on class skills = 0 |

ER-2 is authorized from Knight in the current owner directive; continue in the listed class order.

---

## Rollout checklist — update this section, not memory

**Status rule:** `☑` in the matrix below means **ownership pass only** (extras empty, modifiers owned) — **not** “real modules/layers done.” A row is **truly complete** only when the shape gate passes for that skill and factory data matches the binding matrix **Solution** (no Effect Knobs for layer-mandate leftovers). `[ ]` means the row is still open.

### ER-1 — shared typed homes

- [x] `GRANT_AP` is authored as Resource/layer data and no class skill uses an Extra Rule for it.
- [x] `GRANT_SCRAP` is authored as typed module/layer data, serialized/editor-visible, and consumed by `AbilitySystem`.
- [x] `PAIRED_MOVE` is wired as a shared walk-motion type for legal Pre-Move ally movement; it is not used for Glorious Charge on Action.
- [x] Pull-yourself, carry/place-unit, and drag-target verbs use shared movement primitives plus typed module fields (`PULL`, `TELEPORT_CASTER`, `drop_adjacent`, `feral_drag`) rather than Extra Rules.
- [x] `CREATE_HAZARD` has typed terrain, duration, status, entry, spread, and reaction fields across module/layer data.
- [x] `SPAWN` has typed HP%, placement, turret, construct, and detonation fields across module/layer data.
- [x] Header/module economy fields cover once-per-turn, skip-Action, spend-all-MP, HP cost, and delayed resolution.
- [x] Required `StatusType` and `LayerCondition` additions are implemented and consumed by shared systems.
- [x] `run_ability_module_bridge_test.gd` proves the shared homes without Extra Rule fallback (PASS after ER-3 cleanup).

### ER-2 — class-by-class conversion

> **Shape gate (2026-08-22):** `docs/design/LAYER_SHAPE_CONVERSION_GATE.md` — ER-2 ☑ rows below are **frozen** until `run_layer_shape_conversion_gate.gd` passes per skill. **Effect Knobs / typed-extra dumps do not count as conversion.** Modifier-ownership PASS (`extra_rules_conversion_contract`) is **not** layer conversion.
>
> **Effect Knob audit (2026-08-22):** `run_layer_shape_conversion_gate.gd --audit` — **141** skills have active Effect Knobs → matrix **UNCHECKED** below. **31** rows still show ☑ (zero active knobs on factory probe — not “done” until shape gate + refactor). Class gate “PASS” lines in the index are **harness-only** until those skills re-pass shape bar.

### ER-2 — skill quality matrix (ownership pass — not shape-complete)

| Class | Skill | Ownership pass | QA tested + confirmed working | Bible accuracy audit | Redundant quality audit | Notes |
|---|---|:---:|:---:|:---:|:---:|---|
| Knight | Defensive Formation | ☑ | ☑ | ☑ | ☑ | Independent audit cross-checks scenario contract, Tier-1 sim, and live [+] overlay/commit/sim; shared paths remain single-owner |
| Bruiser | Push Through | ☑ | ☑ | ☑ | ☐ | Layer `buff_on_push` on upgrade (no module knob); Tier-1/live + Bruiser layer-shape gate PASS (2026-08-22). |
| Bruiser | Charge Strike | ☐ | ☐ | ☐ | ☐ | Typed occupied-tile bonus + GHOST keyword; Tier-1/live gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Concussion Blow | ☑ | ☑ | ☑ | ☑ | Typed collision layer flags; Tier-1/live gates pass; independent audit pass |
| Bruiser | Cleave | ☑ | ☑ | ☑ | ☑ | Layered BLEED profile; Tier-1/live gates pass; independent audit pass |
| Bruiser | Suplex | ☐ | ☐ | ☐ | ☐ | Typed HP-scaling bonus; enemy throw on Action is legal; gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Adrenaline Surge | ☐ | ☐ | ☐ | ☐ | Pre-Move self status; gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Earthshatter | ☑ | ☑ | ☑ | ☑ | Destroy-object layer; gates pass; independent audit pass |
| Bruiser | Meat Shield | ☑ | ☑ | ☑ | ☑ | Reworked as Pre-Move ally SWAP with same-turn INTERCEPT; scenario and class gates pass |
| Bruiser | Frenzy | ☑ | ☑ | ☑ | ☐ | ON_KILL GRANT_AP layer (no `frenzy_on_kill_ap` knob); Tier-1/live + layer-shape gate PASS (2026-08-22). |
| Bruiser | Guttural Roar | ☐ | ☐ | ☐ | ☐ | Typed board-item/collision fields; gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Headbutt | ☐ | ☐ | ☐ | ☐ | Typed max-HP damage field; gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Blood Boil | ☐ | ☐ | ☐ | ☐ | Fully module-authored HP/resource profile; gates pass; independent audit pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Bruiser | Violent Collision | ☑ | ☑ | ☑ | ☐ | IF_COLLIDED + second MOVE module (no `violent_collision_recast` knob); Tier-1/live + layer-shape gate PASS (2026-08-22). |
| Bruiser | Crimson Whirlwind | ☑ | ☑ | ☑ | ☐ | PER_TARGET_HIT HEAL layer on [+] (matrix); Tier-1/live + layer-shape gate PASS (2026-08-22). Bible “3+ targets HEAL 2” still deferred. |
| Bruiser | Belly Flop | ☑ | ☑ | ☑ | ☑ | Landing PUSH layer; gates pass; independent audit pass |
| Bruiser | Breaching Dash | ☑ | ☑ | ☑ | ☑ | PIERCE keyword; gates pass; independent audit pass |
| Bruiser | Reactive Adrenaline | ☑ | ☑ | ☑ | ☑ | Dedicated passive scenario + upgrade proof; shared turn-start passive path; independent audit pass |
| Archer | Sidestep | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Volley | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Power Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Pinning Arrow | ☐ | ☐ | ☐ | ☐ | Typed module/layer conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Piercing Shot | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Toxic Spore Arrow | ☐ | ☐ | ☐ | ☐ | Typed module conversion; upgraded adjacent POISON proof and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Grapple Arrow | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass; pull-self destination preserved **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Explosive Arrow | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Hunter’s Mark | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Repelling Shot | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Bear Trap | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Caltrops | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Suppressing Fire | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Archer | Parting Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Scout’s Eye | ☐ | ☐ | ☐ | ☐ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Push | ☐ | ☐ | ☐ | ☐ | Typed ally-target and upgraded once-per-turn/buff fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Piercing Charge | ☐ | ☐ | ☐ | ☐ | Typed trampled-terrain upgrade and polearm reach fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Sweeping Halberd | ☐ | ☐ | ☐ | ☐ | Typed collision layer; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Vaulting Leap | ☐ | ☐ | ☐ | ☐ | Typed DEF/armor upgrade fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Impale / Run Down | ☐ | ☐ | ☐ | ☐ | Typed conditional damage and kill movement fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Rallying Cry | ☐ | ☐ | ☐ | ☐ | Typed next-turn movement and TRAMPLE fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Wraparound / Flanking Maneuver | ☑ | ☑ | ☑ | ☑ | L-path motion metadata + GHOST keyword; conversion contract pass |
| Lancer | Brace | ☐ | ☐ | ☐ | ☐ | Typed attacker stagger field; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Harpoon Toss | ☐ | ☐ | ☐ | ☐ | Typed pull-until-adjacent/rooted fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Glorious Charge | ☐ | ☐ | ☐ | ☐ | Reworked as shared DASH + enemy Action attack; scenario and class gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Pole Vault | ☐ | ☐ | ☐ | ☐ | Typed vault restriction and landing collision fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Line Breaker | ☐ | ☐ | ☐ | ☐ | Typed line-break and passed-enemy fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Spear Wall | ☐ | ☐ | ☐ | ☐ | Typed terrain/status/duration fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Lancer | Meteor Drop | ☑ | ☑ | ☑ | ☑ | Modular landing layer; conversion contract pass |
| Mage | Blink | ☐ | ☐ | ☐ | ☐ | Typed module/layer fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Fireball | ☑ | ☑ | ☑ | ☑ | Typed terrain/reaction layer fields; conversion contract pass |
| Mage | Ice Shard | ☑ | ☑ | ☑ | ☑ | Typed module/layer fields; conversion contract pass |
| Mage | Chain Lightning | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Arcane Push | ☑ | ☑ | ☑ | ☑ | Typed layer fields; conversion contract pass |
| Mage | Teleport | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Meteor | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Black Hole | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Time Warp | ☑ | ☑ | ☑ | ☑ | Modular layer conversion; conversion contract pass |
| Mage | Mana Shield | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Disintegrate | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Gravity Well | ☑ | ☑ | ☑ | ☑ | Modular status layer conversion; conversion contract pass |
| Mage | Elemental Surge | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Earth Spike | ☐ | ☐ | ☐ | ☐ | Typed module/layer fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Density Shift | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mage | Arcane Barrage | ☐ | ☐ | ☐ | ☐ | Typed module fields; conversion contract pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Guardian Step | ☐ | ☐ | ☐ | ☐ | Typed movement fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Holy Light | ☐ | ☐ | ☐ | ☐ | Typed module fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Smite | ☐ | ☐ | ☐ | ☐ | Typed module fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Cleansing Aura | ☐ | ☐ | ☐ | ☐ | Typed module fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Sanctuary | ☐ | ☐ | ☐ | ☐ | Start-turn STEALTH/STURDY/SHIELD 1; typed entry PUSH 1 proof **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Blinding Ray | ☑ | ☑ | ☑ | ☑ | Typed LINE module; Tier 1 + live gate + critic pass |
| Cleric | Divine Hammer | ☐ | ☐ | ☐ | ☐ | Typed module fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Life Link | ☐ | ☐ | ☐ | ☐ | Typed link fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Prayer of Fortitude | ☑ | ☑ | ☑ | ☑ | Typed layer fields; Tier 1 + live gate + critic pass |
| Cleric | Resurrection | ☐ | ☐ | ☐ | ☐ | Typed revive fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Consecrate Ground | ☐ | ☐ | ☐ | ☐ | Typed terrain fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Holy Wrath | ☐ | ☐ | ☐ | ☐ | Typed debuff/push fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Divine Guidance | ☐ | ☐ | ☐ | ☐ | Typed AP/movement fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Cleric | Shield of Faith | ☑ | ☑ | ☑ | ☑ | Flat SHIELD 3 + INTERCEPT proof; Tier 1 + live gate + critic pass |
| Cleric | Martyr’s Chains | ☐ | ☐ | ☐ | ☐ | Typed link/blind fields; Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Pullback | ☐ | ☐ | ☐ | ☐ | Pre-Move paired movement; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Swift Strike | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Defense Strike | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Blade Storm | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Caltrop Toss | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Feint | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Riposte | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Sever | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Second Wind | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Tactical Retreat | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Executioner’s Blade | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Precision Strike | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Flank & Run | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Hamstring | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Acrobatic Vault | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Mercenary | Duelist’s Challenge | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Leap | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Scorching Kick | ☑ | ☑ | ☑ | ☑ | Typed conversion, AOE/live proof + critic pass |
| Monk | Thunder Palm | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Yin-Yang Flurry | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Chakra Shift | ☐ | ☐ | ☐ | ☐ | Typed conversion, burst sim proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Phase Throw | ☑ | ☑ | ☑ | ☑ | Enemy swap on Action is legal; movement/live proof + critic pass |
| Monk | Flying Crane Kick | ☐ | ☐ | ☐ | ☐ | Typed conversion, movement/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Spirit Palm | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Soul Punch | ☐ | ☐ | ☐ | ☐ | Typed conversion, MAG targeting + timed steal proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Hundred Fists | ☐ | ☐ | ☐ | ☐ | Typed conversion, next-turn penalty proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Mantra of Peace | ☐ | ☐ | ☐ | ☐ | Typed conversion, AOE/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Inner Fire | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Void Step | ☐ | ☐ | ☐ | ☐ | Typed conversion, movement/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Cyclone Sweep | ☐ | ☐ | ☐ | ☐ | Typed conversion, ARC footprint/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Updraft | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Monk | Geyser Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Slip Past | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Shadow Step | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Kidney Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Smoke Bomb | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Evasive Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Grappling Hook | ☐ | ☐ | ☐ | ☐ | OR choice; typed conversion and critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Switcheroo | ☐ | ☐ | ☐ | ☐ | Enemy swap on Action is legal; typed conversion and critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Shadow Swap | ☑ | ☑ | ☑ | ☑ | Reworked as Pre-Move ally SWAP with same-turn DEF layer; scenario and class gates pass |
| Rogue | Blindside | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Throat Slit | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Amnesia Dust | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Death Mark | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Lethal Flourish | ☐ | ☐ | ☐ | ☐ | Typed conversion, Tier 1 + live gate + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Kidnap | ☐ | ☐ | ☐ | ☐ | Enemy swap + push on Action; typed conversion and critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Shuriken Volley | ☐ | ☐ | ☐ | ☐ | Typed conversion, shaped/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Rogue | Poison Flask | ☐ | ☐ | ☐ | ☐ | Typed conversion, shaped/live proof + critic pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Reposition | ☐ | ☐ | ☐ | ☐ | Ally-step destination; typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Pounce | ☐ | ☐ | ☐ | ☐ | Typed conversion and movement proof **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Feral Drag | ☐ | ☐ | ☐ | ☐ | Enemy drag on Action is legal; typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Maul | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Bestial Roar | ☑ | ☑ | ☑ | ☑ | Typed conversion and cone proof |
| Beast Rider | Raking Claws | ☐ | ☐ | ☐ | ☐ | Typed conversion and ARC proof **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Thrash | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Rest and Recover | ☐ | ☐ | ☐ | ☐ | Spend remaining MP; typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Intimidate | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Fetch / Snatch | ☑ | ☑ | ☑ | ☑ | Condition: CON ≤ STR; typed conversion |
| Beast Rider | Savage Bite | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Run Down | ☐ | ☐ | ☐ | ☐ | Typed conversion and movement proof **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Defensive Posture | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Airlift | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Beast Rider | Tail Swipe | ☑ | ☑ | ☑ | ☑ | Typed conversion and collision proof |
| Beast Rider | Gore | ☐ | ☐ | ☐ | ☐ | Typed conversion **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Recall | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Dismantle | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Sludge Bomb | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Construct Turret | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Frag Bomb | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Magnetic Mine | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Tesla Barricade | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Flak Cannon | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Wrench Smack | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | EMP Grenade | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Rocket Launcher | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Scrap Shield | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Manual Detonation | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Overdrive Injection | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Engineer | Barbed Wire | ☐ | ☐ | ☐ | ☐ | Typed conversion; conversion contract and Tier 1/2 gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Usher | ☐ | ☐ | ☐ | ☐ | Ally-step destination **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Curse of Weakness | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Healing Totem | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Flame Totem | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Earthbind Totem | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Bloodlust | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Hex | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Voodoo Link | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Terrify | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Miasma | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Bone Spear | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Ancestral Spirit | ☐ | ☐ | ☐ | ☐ | Typed corpse-spawn conversion; scenario and class gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Totem Guard | ☐ | ☐ | ☐ | ☐ | Typed totem guard conversion; scenario and class gates pass **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Sympathetic Bond | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Soul Siphon | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |
| Shaman | Pain Spike | ☐ | ☐ | ☐ | ☐ |  **UNCHECKED (2026-08-22):** Effect Knobs active — not shape-complete. |

**Matrix completion rule (2026-08-22):** Check all four columns only after shape gate passes for that skill (**zero** active Effect Knobs unless matrix explicitly allows ER-1 **New field** only). Rows marked **UNCHECKED** had false PASS from ownership-only QA. Re-check after real module/layer refactor.

### ER-2 — class QA command index (secondary)

#### 1. Knight

- [x] `knight_defensive_formation` — `exclude_caster` typed targeting field; conversion contract, Knight gate, and Knight live QA pass.
- [x] Knight class gate: `run_knight_qa_gate.ps1`.
- [x] Knight live gate: `run_knight_live_qa.ps1`.

#### 2. Bruiser

- [ ] `bruiser_push_through` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_charge_strike` — **UNCHECKED:** Effect Knobs active.
- [x] `bruiser_concussion_blow`
- [x] `bruiser_cleave`
- [ ] `bruiser_suplex` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_adrenaline_surge` — **UNCHECKED:** Effect Knobs active.
- [x] `bruiser_earthshatter`
- [ ] `bruiser_frenzy` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_guttural_roar` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_headbutt` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_blood_boil` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_violent_collision` — **UNCHECKED:** Effect Knobs active.
- [ ] `bruiser_crimson_whirlwind` — **UNCHECKED:** Effect Knobs active.
- [x] `bruiser_belly_flop`
- [x] `bruiser_breaching_dash`
- [x] `reactive_adrenaline`
- [x] Bruiser class gate: `run_bruiser_qa_gate.ps1`.
- [x] Bruiser live gate: `run_bruiser_live_qa.ps1`.
- [x] `bruiser_meat_shield` Pre-Move rework scenario and conversion contract — PASS.

#### 3. Lancer

- [ ] `lancer_push` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_piercing_charge` / Polearm range-band rule — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_sweeping_halberd` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_vaulting_leap` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_run_down` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_rallying_cry` status timing row — **UNCHECKED:** Effect Knobs active.
- [x] `lancer_flanking_maneuver` / Wraparound
- [ ] `lancer_brace` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_harpoon_toss` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_pole_vault` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_line_breaker` — **UNCHECKED:** Effect Knobs active.
- [ ] `lancer_spear_wall` — **UNCHECKED:** Effect Knobs active.
- [x] `lancer_meteor_drop`
- [x] Lancer class gate: `run_lancer_qa_gate.ps1` — PASS.
- [x] Lancer live gate: `run_lancer_live_qa.ps1` — PASS.
- [ ] `lancer_glorious_charge` DASH + enemy Action rework scenario and conversion contract — PASS. — **UNCHECKED:** Effect Knobs active.

#### 4. Archer

- [ ] `archer_sidestep` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_volley` — **UNCHECKED:** Effect Knobs active.
- [x] `archer_power_shot`
- [ ] `archer_pinning_arrow` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_piercing_shot` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_toxic_spore_arrow` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_grapple_arrow` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_explosive_arrow` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_hunters_mark` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_repelling_shot` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_bear_trap` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_caltrop_trap` — **UNCHECKED:** Effect Knobs active.
- [ ] `archer_suppressing_fire` — **UNCHECKED:** Effect Knobs active.
- [x] `archer_parting_shot`
- [ ] `archer_scouts_eye` — **UNCHECKED:** Effect Knobs active.
- [x] Archer class gate: `run_archer_qa_gate.ps1` — PASS.
- [x] Archer live gate: `run_archer_live_qa.ps1` — PASS.
- [x] Archer direct Extra Rules conversion contract — PASS.

#### 5. Mercenary

- [ ] `mercenary_pullback` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_swift_strike` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_defense_strike` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_blade_storm` — **UNCHECKED:** Effect Knobs active.
- [x] `mercenary_caltrop_toss`
- [ ] `mercenary_feint` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_riposte_strike` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_sever` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_second_wind` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_tactical_retreat` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_executioners_blade` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_precision_strike` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_flank_and_run` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_hamstring` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_acrobatic_vault` — **UNCHECKED:** Effect Knobs active.
- [ ] `mercenary_duelists_challenge` — **UNCHECKED:** Effect Knobs active.
- [x] Mercenary class gate: `run_mercenary_qa_gate.ps1` — PASS.
- [x] Mercenary live gate: `run_mercenary_live_qa.ps1` — PASS.
- [x] Mercenary active upgrade proof and typed contracts — PASS.
- [x] Harsh gauntlet critic — PASS, 86/100.

#### 6. Monk

- [ ] `monk_leap` — **UNCHECKED:** Effect Knobs active.
- [x] `monk_scorching_kick`
- [ ] `monk_thunder_palm` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_yin_yang_flurry` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_chakra_shift` — **UNCHECKED:** Effect Knobs active.
- [x] `monk_phase_throw`
- [ ] `monk_flying_crane_kick` — **UNCHECKED:** Effect Knobs active.
- [x] `monk_spirit_palm`
- [ ] `monk_soul_punch` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_hundred_fists` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_mantra_of_peace` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_inner_fire` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_void_step` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_cyclone_sweep` — **UNCHECKED:** Effect Knobs active.
- [ ] `monk_updraft` — **UNCHECKED:** Effect Knobs active.
- [x] `monk_geyser_strike`
- [x] Monk class gate: `run_monk_qa_gate.ps1` — PASS, including typed conversion/schema contracts.
- [x] Monk live gate: `run_monk_live_qa.ps1` — PASS; harsh critic PASS (86/100).

#### 7. Rogue

- [ ] `rogue_slip_past` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_shadow_step` — **UNCHECKED:** Effect Knobs active.
- [x] `rogue_kidney_strike`
- [ ] `rogue_smoke_bomb` — **UNCHECKED:** Effect Knobs active.
- [x] `rogue_evasive_strike`
- [ ] `rogue_grappling_hook` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_switcheroo` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_blindside` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_throat_slit` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_amnesia_dust` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_death_mark` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_lethal_flourish` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_kidnap` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_shuriken_volley` — **UNCHECKED:** Effect Knobs active.
- [ ] `rogue_poison_flask` — **UNCHECKED:** Effect Knobs active.
- [x] Rogue class gate: `run_rogue_qa_gate.ps1` — PASS with conversion contracts.
- [x] Rogue live gate: `run_rogue_live_qa.ps1` — PASS; harsh critic PASS (89/100).
- [x] `rogue_shadow_swap` Pre-Move rework scenario and conversion contract — PASS.

#### 8. Beast Rider

- [ ] `beast_reposition` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_pounce` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_feral_drag` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_maul` — **UNCHECKED:** Effect Knobs active.
- [x] `beast_bestial_roar`
- [ ] `beast_raking_claws` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_rest_recover` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_intimidate` — **UNCHECKED:** Effect Knobs active.
- [x] `beast_fetch`
- [ ] `beast_savage_bite` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_run_down` — **UNCHECKED:** Effect Knobs active.
- [x] `beast_thrash`
- [ ] `beast_defensive_posture` — **UNCHECKED:** Effect Knobs active.
- [ ] `beast_airlift` — **UNCHECKED:** Effect Knobs active.
- [x] `beast_tail_swipe`
- [ ] `beast_gore` — **UNCHECKED:** Effect Knobs active.
- [x] Beast Rider class gate: `run_beast_rider_qa_gate.ps1` — PASS (32/32 matrix; Tier 1 + AOE).
- [x] Beast Rider live gate: `run_beast_rider_live_qa.ps1` — PASS.

#### 9. Cleric

- [ ] `cleric_guardian_step` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_holy_light` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_smite` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_cleansing_aura` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_sanctuary` — **UNCHECKED:** Effect Knobs active.
- [x] `cleric_blinding_ray`
- [ ] `cleric_divine_hammer` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_life_link` — **UNCHECKED:** Effect Knobs active.
- [x] `cleric_prayer_of_fortitude`
- [ ] `cleric_resurrection` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_consecrate_ground` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_holy_wrath` — **UNCHECKED:** Effect Knobs active.
- [ ] `cleric_divine_guidance` — **UNCHECKED:** Effect Knobs active.
- [x] `cleric_shield_of_faith`
- [ ] `cleric_martyrs_chains` — **UNCHECKED:** Effect Knobs active.
- [x] Cleric class gate: `run_cleric_qa_gate.ps1`.
- [x] Cleric live gate: `run_cleric_live_qa.ps1`.

#### 10. Mage

- [ ] `mage_blink` — **UNCHECKED:** Effect Knobs active.
- [x] `mage_fireball`
- [x] `mage_ice_shard`
- [ ] `mage_chain_lightning` — **UNCHECKED:** Effect Knobs active.
- [x] `mage_arcane_push`
- [ ] `mage_teleport` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_meteor` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_black_hole` — **UNCHECKED:** Effect Knobs active.
- [x] `mage_time_warp`
- [ ] `mage_mana_shield` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_disintegrate` — **UNCHECKED:** Effect Knobs active.
- [x] `mage_gravity_well`
- [ ] `mage_elemental_surge` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_earth_spike` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_density_shift` — **UNCHECKED:** Effect Knobs active.
- [ ] `mage_arcane_barrage` — **UNCHECKED:** Effect Knobs active.
- [x] Mage class gate: `run_mage_qa_gate.ps1`.
- [x] Mage live gate: `run_mage_live_qa.ps1`.

#### 11. Engineer — converted; gauntlet PASS (87/100)

- [ ] `engineer_recall` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_dismantle` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_sludge_bomb` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_construct_turret` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_frag_bomb` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_magnetic_mine` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_tesla_barricade` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_flak_cannon` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_wrench_smack` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_emp_grenade` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_rocket_launcher` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_scrap_shield` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_manual_detonation` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_overdrive_injection` — **UNCHECKED:** Effect Knobs active.
- [ ] `engineer_barbed_wire` — **UNCHECKED:** Effect Knobs active.
- [x] Engineer class gate: `run_engineer_qa_gate.ps1` — PASS.
- [x] Engineer live gate: `run_engineer_live_qa.ps1` — PASS.
- [x] Engineer typed schema contract and Extra Rules conversion contract — PASS.
- [x] Harsh gauntlet critic — PASS, 87/100.

#### 12. Shaman

- [ ] `shaman_usher` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_curse_of_weakness` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_healing_totem` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_flame_totem` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_earthbind_totem` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_bloodlust` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_hex` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_voodoo_link` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_terrify` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_miasma` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_bone_spear` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_ancestral_spirit` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_totem_guard` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_sympathetic_bond` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_soul_siphon` — **UNCHECKED:** Effect Knobs active.
- [ ] `shaman_pain_spike` — **UNCHECKED:** Effect Knobs active.
- [x] Shaman class gate: `run_shaman_qa_gate.ps1` — PASS.
- [x] Shaman live gate: `run_shaman_live_qa.ps1` — PASS.
- [x] Shaman conversion contracts and schema roundtrip — PASS; final gauntlet critic 87/100 — PASS.

### ER-3 — legacy deletion

ER-3 closes legacy-path deletion. ER-1 shared typed homes are now checked separately above and are backed by the expanded bridge/runtime contracts; the ER-3 gate still runs those contracts as part of regression.

- [x] Zero class-factory `_add_extra` / `_add_extras_from_dict` calls.
- [x] Zero class-skill leftover unowned runtime keys in `EffectData.modifiers`.
- [x] `CONVERTED_SKILL_IDS` contains every converted skill and the bridge contract passes.
- [x] Delete `AbilityExtraRule` and the Class Editor Extra Rules UI.
- [x] Delete `GameEnums.MotionMode` and module/editor/factory Motion Mode fields.
- [x] Remove combat reads of `module.motion_mode` and all compatibility inference.
- [x] Run full grep exit check: `_add_extra`, `AbilityExtraRule`, `MotionMode`, `motion_mode` = zero in production code.
- [x] Run final planning QA and full deterministic regression.

---

## Conversion law

| Home | Use when |
|------|----------|
| Header | Cost, once-per-turn, skip-Action, delay |
| Module primary | The verb. Pick a **family** in the conversion plan (Attack, Movement (Self), Forced Movement, Move someone, Hazard, Summon, Status, Heal, Shield, Stance, Resource). Types grow inside a family. Riders are fields/layers, not new families. |
| Keyword | TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO |
| Layer + condition | Extra punch on the **same click**. New click = new module. |
| Gate | Whether a module runs |
| Targeting / Condition | Who you may click |
| Typed field on an existing punch | Hazard / spawn knobs, bounce, … |
| New EffectType / StatusType / LayerCondition | Only if nothing above fits. Grow the dropdown. |

**Forbidden:** new Extra Rules, leftover bags, harvesting keys, `if ability.id == …`, calling Extra Rules “modules,” converting into **Motion Mode**, relocating an **ally** on **Action**. Enemy Forced Movement / enemy SWAP / drag on Action is legal.  
**Reworked and converted:** Glorious Charge uses shared DASH + enemy Action attack; Meat Shield and Shadow Swap use Pre-Move ally SWAP.
**Out of scope:** passives (until owner asks).

### Module primary families (reference)

Locked names. Full add-rules and Extra Rule mapping: conversion plan. Module shape: `ability-data.md`. Skill lines: `class_abilities.txt`.

| Family | Opening verb |
|--------|----------------|
| **Attack** | Hurt (ATK / MAG ATK) |
| **Movement (Self)** | You change tiles (MOVE / DASH / JUMP / TELEPORT) |
| **Forced Movement** | They are displaced (PUSH / PULL / THROW_BEHIND). Legal on Action. |
| **Move someone** | You put a body on a tile (swap, carry, usher). Ally on Action = rewrite. Enemy SWAP on Action is legal. |
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
Converted-skill extras: headless `res://tests/run_ability_module_bridge_runner.gd` (includes `extra_rules_conversion_contract`).  
**Layer shape (ER-2 anti-cheat):** `res://tests/run_layer_shape_conversion_gate.gd` (`--audit` for debt report).  
Planning/commit edits: `.\scripts\run_planning_qa_gate.ps1`.  
Sim/core: `.\scripts\run_regression_tests.ps1`.
