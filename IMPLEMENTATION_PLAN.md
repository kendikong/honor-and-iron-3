# Honor & Iron 3 — Implementation Plan

**ACTIVE (2026-08-16):** Convert Extra Rules into real modules / layers.

**Binding matrix:** [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](docs/design/EXTRA_RULES_TO_MODULES_PLAN.md)  
**Module bible:** [`docs/design/ability-data.md`](docs/design/ability-data.md) — header, modules, keywords, layers, gates, targeting  
**Skill bible:** `class_abilities.txt` — every Active / Reposition line is law

**Document boundaries:** `ability-data.md` explains how to author modules. The binding matrix explains how each existing leftover maps into that model. This plan owns migration order and legacy deletion, including Motion Mode.

**Bibles stay in context.** Chat summaries, compaction, and handoff notes are **not** skill text. After any summarization, **reread** `class_abilities.txt` (that skill’s line + upgrade) and `docs/design/ability-data.md` (the module home) before converting. Do not author from memory of this chat.

Extra Rules was a leftover-bag rename. That pass is **rejected**. Chat tables are not a substitute. Agents must execute the on-disk matrix.

---

## What to do

Convert every Extra Rule into the skill-module bible: header, module primary (including MOVE / JUMP / TELEPORT landing verbs), keyword, layer + condition, gate, targeting / Condition, or a **new EffectType / StatusType / LayerCondition**. Then **delete** that skill’s Extra Rules **and leftover `modifiers` keys** in the same change.

**Cheat (forbidden):** empty Extra Rules while combat still runs the old leftover key. That is how the last pass failed.

Combat must read header / module / keyword / layer / gate / targeting / typed fields — not Extra Rules and not `effect.modifiers["harvested_key"]`.

**Legacy cleanup:** `GameEnums.MotionMode`, the Class Editor dropdown, factory stamps, and combat reads of `module.motion_mode` are removed in ER-3. Landing is authored as a destination `EffectType` (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, …).

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
| **ER-1** | Shared punches: use existing `GRANT_AP` / `GRANT_SCRAP` / `PAIRED_MOVE` (**Pre-Move only** — not Glorious Charge on Action); finish CREATE_HAZARD / SPAWN knobs; header once-per-turn / spend-all-MP; add missing types only when the matrix says **new** | Types exist; Extra Rules not used for those punches |
| **ER-2** | Convert class by class (Knight → … → Shaman). Rework any unsafe Action ally relocate into a legal Pre-Move ally swap or enemy-focused Action module, then convert it. One skill: bible quote → Solution → extras **and** leftover keys gone → add id to `CONVERTED_SKILL_IDS` → class gate + live **PASS** | Every active matrix row converted and gated |
| **ER-3** | **DELETE** Extra Rules (`AbilityExtraRule`, Extra Rules UI) **and Motion Mode** (`GameEnums.MotionMode`, editor dropdown, factory `motion_mode`, combat `module.motion_mode` reads) | Grep `_add_extra` / Extra Rules / `MotionMode` / `motion_mode` on class skills = 0 |

ER-2 is authorized from Knight in the current owner directive; continue in the listed class order.

---

## Rollout checklist — update this section, not memory

**Status rule:** `[x]` means the implementation, conversion contract, and required QA evidence are complete. `[ ]` means the row is still open. A factory that merely loads is not a converted row.

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

### ER-2 — authoritative skill quality matrix

| Class | Skill | Real modules/layers | QA tested + confirmed working | Bible accuracy audit | Redundant quality audit | Notes |
|---|---|:---:|:---:|:---:|:---:|---|
| Knight | Defensive Formation | ☑ | ☑ | ☑ | ☑ | Independent audit cross-checks scenario contract, Tier-1 sim, and live [+] overlay/commit/sim; shared paths remain single-owner |
| Bruiser | Push Through | ☑ | ☑ | ☑ | ☑ | Typed `buff_on_push`; Tier-1/live gates pass; independent audit pass |
| Bruiser | Charge Strike | ☑ | ☑ | ☑ | ☑ | Typed occupied-tile bonus + GHOST keyword; Tier-1/live gates pass; independent audit pass |
| Bruiser | Concussion Blow | ☑ | ☑ | ☑ | ☑ | Typed collision layer flags; Tier-1/live gates pass; independent audit pass |
| Bruiser | Cleave | ☑ | ☑ | ☑ | ☑ | Layered BLEED profile; Tier-1/live gates pass; independent audit pass |
| Bruiser | Suplex | ☑ | ☑ | ☑ | ☑ | Typed HP-scaling bonus; enemy throw on Action is legal; gates pass; independent audit pass |
| Bruiser | Adrenaline Surge | ☑ | ☑ | ☑ | ☑ | Pre-Move self status; gates pass; independent audit pass |
| Bruiser | Earthshatter | ☑ | ☑ | ☑ | ☑ | Destroy-object layer; gates pass; independent audit pass |
| Bruiser | Meat Shield | ☑ | ☑ | ☑ | ☑ | Reworked as Pre-Move ally SWAP with same-turn INTERCEPT; scenario and class gates pass |
| Bruiser | Frenzy | ☑ | ☑ | ☑ | ☑ | Typed kill AP field; gates pass; independent audit pass |
| Bruiser | Guttural Roar | ☑ | ☑ | ☑ | ☑ | Typed board-item/collision fields; gates pass; independent audit pass |
| Bruiser | Headbutt | ☑ | ☑ | ☑ | ☑ | Typed max-HP damage field; gates pass; independent audit pass |
| Bruiser | Blood Boil | ☑ | ☑ | ☑ | ☑ | Fully module-authored HP/resource profile; gates pass; independent audit pass |
| Bruiser | Violent Collision | ☑ | ☑ | ☑ | ☑ | Typed recast field + collision layer; gates pass; independent audit pass |
| Bruiser | Crimson Whirlwind | ☑ | ☑ | ☑ | ☑ | Typed target-count heal field; gates pass; independent audit pass |
| Bruiser | Belly Flop | ☑ | ☑ | ☑ | ☑ | Landing PUSH layer; gates pass; independent audit pass |
| Bruiser | Breaching Dash | ☑ | ☑ | ☑ | ☑ | PIERCE keyword; gates pass; independent audit pass |
| Bruiser | Reactive Adrenaline | ☑ | ☑ | ☑ | ☑ | Dedicated passive scenario + upgrade proof; shared turn-start passive path; independent audit pass |
| Archer | Sidestep | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Volley | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Power Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Pinning Arrow | ☑ | ☑ | ☑ | ☑ | Typed module/layer conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Piercing Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Toxic Spore Arrow | ☑ | ☑ | ☑ | ☑ | Typed module conversion; upgraded adjacent POISON proof and direct conversion contract pass |
| Archer | Grapple Arrow | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass; pull-self destination preserved |
| Archer | Explosive Arrow | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Hunter’s Mark | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Repelling Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Bear Trap | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Caltrops | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Suppressing Fire | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Parting Shot | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Archer | Scout’s Eye | ☑ | ☑ | ☑ | ☑ | Typed module conversion; Tier 1/2 gates and direct conversion contract pass |
| Lancer | Push | ☑ | ☑ | ☑ | ☑ | Typed ally-target and upgraded once-per-turn/buff fields; conversion contract pass |
| Lancer | Piercing Charge | ☑ | ☑ | ☑ | ☑ | Typed trampled-terrain upgrade and polearm reach fields; conversion contract pass |
| Lancer | Sweeping Halberd | ☑ | ☑ | ☑ | ☑ | Typed collision layer; conversion contract pass |
| Lancer | Vaulting Leap | ☑ | ☑ | ☑ | ☑ | Typed DEF/armor upgrade fields; conversion contract pass |
| Lancer | Impale / Run Down | ☑ | ☑ | ☑ | ☑ | Typed conditional damage and kill movement fields; conversion contract pass |
| Lancer | Rallying Cry | ☑ | ☑ | ☑ | ☑ | Typed next-turn movement and TRAMPLE fields; conversion contract pass |
| Lancer | Wraparound / Flanking Maneuver | ☑ | ☑ | ☑ | ☑ | L-path motion metadata + GHOST keyword; conversion contract pass |
| Lancer | Brace | ☑ | ☑ | ☑ | ☑ | Typed attacker stagger field; conversion contract pass |
| Lancer | Harpoon Toss | ☑ | ☑ | ☑ | ☑ | Typed pull-until-adjacent/rooted fields; conversion contract pass |
| Lancer | Glorious Charge | ☑ | ☑ | ☑ | ☑ | Reworked as shared DASH + enemy Action attack; scenario and class gates pass |
| Lancer | Pole Vault | ☑ | ☑ | ☑ | ☑ | Typed vault restriction and landing collision fields; conversion contract pass |
| Lancer | Line Breaker | ☑ | ☑ | ☑ | ☑ | Typed line-break and passed-enemy fields; conversion contract pass |
| Lancer | Spear Wall | ☑ | ☑ | ☑ | ☑ | Typed terrain/status/duration fields; conversion contract pass |
| Lancer | Meteor Drop | ☑ | ☑ | ☑ | ☑ | Modular landing layer; conversion contract pass |
| Mage | Blink | ☑ | ☑ | ☑ | ☑ | Typed module/layer fields; conversion contract pass |
| Mage | Fireball | ☑ | ☑ | ☑ | ☑ | Typed terrain/reaction layer fields; conversion contract pass |
| Mage | Ice Shard | ☑ | ☑ | ☑ | ☑ | Typed module/layer fields; conversion contract pass |
| Mage | Chain Lightning | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Arcane Push | ☑ | ☑ | ☑ | ☑ | Typed layer fields; conversion contract pass |
| Mage | Teleport | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Meteor | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Black Hole | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Time Warp | ☑ | ☑ | ☑ | ☑ | Modular layer conversion; conversion contract pass |
| Mage | Mana Shield | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Disintegrate | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Gravity Well | ☑ | ☑ | ☑ | ☑ | Modular status layer conversion; conversion contract pass |
| Mage | Elemental Surge | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Earth Spike | ☑ | ☑ | ☑ | ☑ | Typed module/layer fields; conversion contract pass |
| Mage | Density Shift | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Mage | Arcane Barrage | ☑ | ☑ | ☑ | ☑ | Typed module fields; conversion contract pass |
| Cleric | Guardian Step | ☑ | ☑ | ☑ | ☑ | Typed movement fields; Tier 1 + live gate + critic pass |
| Cleric | Holy Light | ☑ | ☑ | ☑ | ☑ | Typed module fields; Tier 1 + live gate + critic pass |
| Cleric | Smite | ☑ | ☑ | ☑ | ☑ | Typed module fields; Tier 1 + live gate + critic pass |
| Cleric | Cleansing Aura | ☑ | ☑ | ☑ | ☑ | Typed module fields; Tier 1 + live gate + critic pass |
| Cleric | Sanctuary | ☑ | ☑ | ☑ | ☑ | Start-turn STEALTH/STURDY/SHIELD 1; typed entry PUSH 1 proof |
| Cleric | Blinding Ray | ☑ | ☑ | ☑ | ☑ | Typed LINE module; Tier 1 + live gate + critic pass |
| Cleric | Divine Hammer | ☑ | ☑ | ☑ | ☑ | Typed module fields; Tier 1 + live gate + critic pass |
| Cleric | Life Link | ☑ | ☑ | ☑ | ☑ | Typed link fields; Tier 1 + live gate + critic pass |
| Cleric | Prayer of Fortitude | ☑ | ☑ | ☑ | ☑ | Typed layer fields; Tier 1 + live gate + critic pass |
| Cleric | Resurrection | ☑ | ☑ | ☑ | ☑ | Typed revive fields; Tier 1 + live gate + critic pass |
| Cleric | Consecrate Ground | ☑ | ☑ | ☑ | ☑ | Typed terrain fields; Tier 1 + live gate + critic pass |
| Cleric | Holy Wrath | ☑ | ☑ | ☑ | ☑ | Typed debuff/push fields; Tier 1 + live gate + critic pass |
| Cleric | Divine Guidance | ☑ | ☑ | ☑ | ☑ | Typed AP/movement fields; Tier 1 + live gate + critic pass |
| Cleric | Shield of Faith | ☑ | ☑ | ☑ | ☑ | Flat SHIELD 3 + INTERCEPT proof; Tier 1 + live gate + critic pass |
| Cleric | Martyr’s Chains | ☑ | ☑ | ☑ | ☑ | Typed link/blind fields; Tier 1 + live gate + critic pass |
| Mercenary | Pullback | ☑ | ☑ | ☑ | ☑ | Pre-Move paired movement; conversion contract and Tier 1/2 gates pass |
| Mercenary | Swift Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Defense Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Blade Storm | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Caltrop Toss | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Feint | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Riposte | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Sever | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Second Wind | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Tactical Retreat | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Executioner’s Blade | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Precision Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Flank & Run | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Hamstring | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Acrobatic Vault | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Mercenary | Duelist’s Challenge | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Monk | Leap | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Scorching Kick | ☑ | ☑ | ☑ | ☑ | Typed conversion, AOE/live proof + critic pass |
| Monk | Thunder Palm | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Yin-Yang Flurry | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Chakra Shift | ☑ | ☑ | ☑ | ☑ | Typed conversion, burst sim proof + critic pass |
| Monk | Phase Throw | ☑ | ☑ | ☑ | ☑ | Enemy swap on Action is legal; movement/live proof + critic pass |
| Monk | Flying Crane Kick | ☑ | ☑ | ☑ | ☑ | Typed conversion, movement/live proof + critic pass |
| Monk | Spirit Palm | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Soul Punch | ☑ | ☑ | ☑ | ☑ | Typed conversion, MAG targeting + timed steal proof + critic pass |
| Monk | Hundred Fists | ☑ | ☑ | ☑ | ☑ | Typed conversion, next-turn penalty proof + critic pass |
| Monk | Mantra of Peace | ☑ | ☑ | ☑ | ☑ | Typed conversion, AOE/live proof + critic pass |
| Monk | Inner Fire | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Void Step | ☑ | ☑ | ☑ | ☑ | Typed conversion, movement/live proof + critic pass |
| Monk | Cyclone Sweep | ☑ | ☑ | ☑ | ☑ | Typed conversion, ARC footprint/live proof + critic pass |
| Monk | Updraft | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Monk | Geyser Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Slip Past | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Shadow Step | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Kidney Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Smoke Bomb | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Evasive Strike | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Grappling Hook | ☑ | ☑ | ☑ | ☑ | OR choice; typed conversion and critic pass |
| Rogue | Switcheroo | ☑ | ☑ | ☑ | ☑ | Enemy swap on Action is legal; typed conversion and critic pass |
| Rogue | Shadow Swap | ☑ | ☑ | ☑ | ☑ | Reworked as Pre-Move ally SWAP with same-turn DEF layer; scenario and class gates pass |
| Rogue | Blindside | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Throat Slit | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Amnesia Dust | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Death Mark | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Lethal Flourish | ☑ | ☑ | ☑ | ☑ | Typed conversion, Tier 1 + live gate + critic pass |
| Rogue | Kidnap | ☑ | ☑ | ☑ | ☑ | Enemy swap + push on Action; typed conversion and critic pass |
| Rogue | Shuriken Volley | ☑ | ☑ | ☑ | ☑ | Typed conversion, shaped/live proof + critic pass |
| Rogue | Poison Flask | ☑ | ☑ | ☑ | ☑ | Typed conversion, shaped/live proof + critic pass |
| Beast Rider | Reposition | ☑ | ☑ | ☑ | ☑ | Ally-step destination; typed conversion |
| Beast Rider | Pounce | ☑ | ☑ | ☑ | ☑ | Typed conversion and movement proof |
| Beast Rider | Feral Drag | ☑ | ☑ | ☑ | ☑ | Enemy drag on Action is legal; typed conversion |
| Beast Rider | Maul | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Bestial Roar | ☑ | ☑ | ☑ | ☑ | Typed conversion and cone proof |
| Beast Rider | Raking Claws | ☑ | ☑ | ☑ | ☑ | Typed conversion and ARC proof |
| Beast Rider | Thrash | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Rest and Recover | ☑ | ☑ | ☑ | ☑ | Spend remaining MP; typed conversion |
| Beast Rider | Intimidate | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Fetch / Snatch | ☑ | ☑ | ☑ | ☑ | Condition: CON ≤ STR; typed conversion |
| Beast Rider | Savage Bite | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Run Down | ☑ | ☑ | ☑ | ☑ | Typed conversion and movement proof |
| Beast Rider | Defensive Posture | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Airlift | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Beast Rider | Tail Swipe | ☑ | ☑ | ☑ | ☑ | Typed conversion and collision proof |
| Beast Rider | Gore | ☑ | ☑ | ☑ | ☑ | Typed conversion |
| Engineer | Recall | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Dismantle | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Sludge Bomb | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Construct Turret | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Frag Bomb | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Magnetic Mine | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Tesla Barricade | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Flak Cannon | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Wrench Smack | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | EMP Grenade | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Rocket Launcher | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Scrap Shield | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Manual Detonation | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Overdrive Injection | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Engineer | Barbed Wire | ☑ | ☑ | ☑ | ☑ | Typed conversion; conversion contract and Tier 1/2 gates pass |
| Shaman | Usher | ☑ | ☑ | ☑ | ☑ | Ally-step destination |
| Shaman | Curse of Weakness | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Healing Totem | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Flame Totem | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Earthbind Totem | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Bloodlust | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Hex | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Voodoo Link | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Terrify | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Miasma | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Bone Spear | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Ancestral Spirit | ☑ | ☑ | ☑ | ☑ | Typed corpse-spawn conversion; scenario and class gates pass |
| Shaman | Totem Guard | ☑ | ☑ | ☑ | ☑ | Typed totem guard conversion; scenario and class gates pass |
| Shaman | Sympathetic Bond | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Soul Siphon | ☑ | ☑ | ☑ | ☑ |  |
| Shaman | Pain Spike | ☑ | ☑ | ☑ | ☑ |  |

**Matrix completion rule:** check a skill’s four columns only after the skill-level conversion contract, class gate/live proof, Bible audit, and independent quality re-audit are all recorded. The former Action ally-relocate rows are now legal reworked forms and are included in the checked set.

### ER-2 — class QA command index (secondary)

#### 1. Knight

- [x] `knight_defensive_formation` — `exclude_caster` typed targeting field; conversion contract, Knight gate, and Knight live QA pass.
- [x] Knight class gate: `run_knight_qa_gate.ps1`.
- [x] Knight live gate: `run_knight_live_qa.ps1`.

#### 2. Bruiser

- [x] `bruiser_push_through`
- [x] `bruiser_charge_strike`
- [x] `bruiser_concussion_blow`
- [x] `bruiser_cleave`
- [x] `bruiser_suplex`
- [x] `bruiser_adrenaline_surge`
- [x] `bruiser_earthshatter`
- [x] `bruiser_frenzy`
- [x] `bruiser_guttural_roar`
- [x] `bruiser_headbutt`
- [x] `bruiser_blood_boil`
- [x] `bruiser_violent_collision`
- [x] `bruiser_crimson_whirlwind`
- [x] `bruiser_belly_flop`
- [x] `bruiser_breaching_dash`
- [x] `reactive_adrenaline`
- [x] Bruiser class gate: `run_bruiser_qa_gate.ps1`.
- [x] Bruiser live gate: `run_bruiser_live_qa.ps1`.
- [x] `bruiser_meat_shield` Pre-Move rework scenario and conversion contract — PASS.

#### 3. Lancer

- [x] `lancer_push`
- [x] `lancer_piercing_charge` / Polearm range-band rule
- [x] `lancer_sweeping_halberd`
- [x] `lancer_vaulting_leap`
- [x] `lancer_run_down`
- [x] `lancer_rallying_cry` status timing row
- [x] `lancer_flanking_maneuver` / Wraparound
- [x] `lancer_brace`
- [x] `lancer_harpoon_toss`
- [x] `lancer_pole_vault`
- [x] `lancer_line_breaker`
- [x] `lancer_spear_wall`
- [x] `lancer_meteor_drop`
- [x] Lancer class gate: `run_lancer_qa_gate.ps1` — PASS.
- [x] Lancer live gate: `run_lancer_live_qa.ps1` — PASS.
- [x] `lancer_glorious_charge` DASH + enemy Action rework scenario and conversion contract — PASS.

#### 4. Archer

- [x] `archer_sidestep`
- [x] `archer_volley`
- [x] `archer_power_shot`
- [x] `archer_pinning_arrow`
- [x] `archer_piercing_shot`
- [x] `archer_toxic_spore_arrow`
- [x] `archer_grapple_arrow`
- [x] `archer_explosive_arrow`
- [x] `archer_hunters_mark`
- [x] `archer_repelling_shot`
- [x] `archer_bear_trap`
- [x] `archer_caltrop_trap`
- [x] `archer_suppressing_fire`
- [x] `archer_parting_shot`
- [x] `archer_scouts_eye`
- [x] Archer class gate: `run_archer_qa_gate.ps1` — PASS.
- [x] Archer live gate: `run_archer_live_qa.ps1` — PASS.
- [x] Archer direct Extra Rules conversion contract — PASS.

#### 5. Mercenary

- [x] `mercenary_pullback`
- [x] `mercenary_swift_strike`
- [x] `mercenary_defense_strike`
- [x] `mercenary_blade_storm`
- [x] `mercenary_caltrop_toss`
- [x] `mercenary_feint`
- [x] `mercenary_riposte_strike`
- [x] `mercenary_sever`
- [x] `mercenary_second_wind`
- [x] `mercenary_tactical_retreat`
- [x] `mercenary_executioners_blade`
- [x] `mercenary_precision_strike`
- [x] `mercenary_flank_and_run`
- [x] `mercenary_hamstring`
- [x] `mercenary_acrobatic_vault`
- [x] `mercenary_duelists_challenge`
- [x] Mercenary class gate: `run_mercenary_qa_gate.ps1` — PASS.
- [x] Mercenary live gate: `run_mercenary_live_qa.ps1` — PASS.
- [x] Mercenary active upgrade proof and typed contracts — PASS.
- [x] Harsh gauntlet critic — PASS, 86/100.

#### 6. Monk

- [x] `monk_leap`
- [x] `monk_scorching_kick`
- [x] `monk_thunder_palm`
- [x] `monk_yin_yang_flurry`
- [x] `monk_chakra_shift`
- [x] `monk_phase_throw`
- [x] `monk_flying_crane_kick`
- [x] `monk_spirit_palm`
- [x] `monk_soul_punch`
- [x] `monk_hundred_fists`
- [x] `monk_mantra_of_peace`
- [x] `monk_inner_fire`
- [x] `monk_void_step`
- [x] `monk_cyclone_sweep`
- [x] `monk_updraft`
- [x] `monk_geyser_strike`
- [x] Monk class gate: `run_monk_qa_gate.ps1` — PASS, including typed conversion/schema contracts.
- [x] Monk live gate: `run_monk_live_qa.ps1` — PASS; harsh critic PASS (86/100).

#### 7. Rogue

- [x] `rogue_slip_past`
- [x] `rogue_shadow_step`
- [x] `rogue_kidney_strike`
- [x] `rogue_smoke_bomb`
- [x] `rogue_evasive_strike`
- [x] `rogue_grappling_hook`
- [x] `rogue_switcheroo`
- [x] `rogue_blindside`
- [x] `rogue_throat_slit`
- [x] `rogue_amnesia_dust`
- [x] `rogue_death_mark`
- [x] `rogue_lethal_flourish`
- [x] `rogue_kidnap`
- [x] `rogue_shuriken_volley`
- [x] `rogue_poison_flask`
- [x] Rogue class gate: `run_rogue_qa_gate.ps1` — PASS with conversion contracts.
- [x] Rogue live gate: `run_rogue_live_qa.ps1` — PASS; harsh critic PASS (89/100).
- [x] `rogue_shadow_swap` Pre-Move rework scenario and conversion contract — PASS.

#### 8. Beast Rider

- [x] `beast_reposition`
- [x] `beast_pounce`
- [x] `beast_feral_drag`
- [x] `beast_maul`
- [x] `beast_bestial_roar`
- [x] `beast_raking_claws`
- [x] `beast_rest_recover`
- [x] `beast_intimidate`
- [x] `beast_fetch`
- [x] `beast_savage_bite`
- [x] `beast_run_down`
- [x] `beast_thrash`
- [x] `beast_defensive_posture`
- [x] `beast_airlift`
- [x] `beast_tail_swipe`
- [x] `beast_gore`
- [x] Beast Rider class gate: `run_beast_rider_qa_gate.ps1` — PASS (32/32 matrix; Tier 1 + AOE).
- [x] Beast Rider live gate: `run_beast_rider_live_qa.ps1` — PASS.

#### 9. Cleric

- [x] `cleric_guardian_step`
- [x] `cleric_holy_light`
- [x] `cleric_smite`
- [x] `cleric_cleansing_aura`
- [x] `cleric_sanctuary`
- [x] `cleric_blinding_ray`
- [x] `cleric_divine_hammer`
- [x] `cleric_life_link`
- [x] `cleric_prayer_of_fortitude`
- [x] `cleric_resurrection`
- [x] `cleric_consecrate_ground`
- [x] `cleric_holy_wrath`
- [x] `cleric_divine_guidance`
- [x] `cleric_shield_of_faith`
- [x] `cleric_martyrs_chains`
- [x] Cleric class gate: `run_cleric_qa_gate.ps1`.
- [x] Cleric live gate: `run_cleric_live_qa.ps1`.

#### 10. Mage

- [x] `mage_blink`
- [x] `mage_fireball`
- [x] `mage_ice_shard`
- [x] `mage_chain_lightning`
- [x] `mage_arcane_push`
- [x] `mage_teleport`
- [x] `mage_meteor`
- [x] `mage_black_hole`
- [x] `mage_time_warp`
- [x] `mage_mana_shield`
- [x] `mage_disintegrate`
- [x] `mage_gravity_well`
- [x] `mage_elemental_surge`
- [x] `mage_earth_spike`
- [x] `mage_density_shift`
- [x] `mage_arcane_barrage`
- [x] Mage class gate: `run_mage_qa_gate.ps1`.
- [x] Mage live gate: `run_mage_live_qa.ps1`.

#### 11. Engineer — converted; gauntlet PASS (87/100)

- [x] `engineer_recall`
- [x] `engineer_dismantle`
- [x] `engineer_sludge_bomb`
- [x] `engineer_construct_turret`
- [x] `engineer_frag_bomb`
- [x] `engineer_magnetic_mine`
- [x] `engineer_tesla_barricade`
- [x] `engineer_flak_cannon`
- [x] `engineer_wrench_smack`
- [x] `engineer_emp_grenade`
- [x] `engineer_rocket_launcher`
- [x] `engineer_scrap_shield`
- [x] `engineer_manual_detonation`
- [x] `engineer_overdrive_injection`
- [x] `engineer_barbed_wire`
- [x] Engineer class gate: `run_engineer_qa_gate.ps1` — PASS.
- [x] Engineer live gate: `run_engineer_live_qa.ps1` — PASS.
- [x] Engineer typed schema contract and Extra Rules conversion contract — PASS.
- [x] Harsh gauntlet critic — PASS, 87/100.

#### 12. Shaman

- [x] `shaman_usher`
- [x] `shaman_curse_of_weakness`
- [x] `shaman_healing_totem`
- [x] `shaman_flame_totem`
- [x] `shaman_earthbind_totem`
- [x] `shaman_bloodlust`
- [x] `shaman_hex`
- [x] `shaman_voodoo_link`
- [x] `shaman_terrify`
- [x] `shaman_miasma`
- [x] `shaman_bone_spear`
- [x] `shaman_ancestral_spirit`
- [x] `shaman_totem_guard`
- [x] `shaman_sympathetic_bond`
- [x] `shaman_soul_siphon`
- [x] `shaman_pain_spike`
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
Converted-skill extras: headless `res://tests/run_ability_module_bridge_test.gd` (includes `extra_rules_conversion_contract`).  
Planning/commit edits: `.\scripts\run_planning_qa_gate.ps1`.  
Sim/core: `.\scripts\run_regression_tests.ps1`.
