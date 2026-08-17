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
| **ER-2** | Convert class by class (Knight → … → Shaman). Skip the three **Rework skill** rows (Action **ally** relocates: Glorious Charge, Meat Shield, Shadow Swap). One skill: bible quote → Solution → extras **and** leftover keys gone → add id to `CONVERTED_SKILL_IDS` → class gate + live **PASS** | Every convert-able matrix row converted; the three ally-relocate rows remain Rework |
| **ER-3** | **DELETE** Extra Rules (`AbilityExtraRule`, Extra Rules UI) **and Motion Mode** (`GameEnums.MotionMode`, editor dropdown, factory `motion_mode`, combat `module.motion_mode` reads) | Grep `_add_extra` / Extra Rules / `MotionMode` / `motion_mode` on class skills = 0 |

ER-2 is authorized from Knight in the current owner directive; continue in the listed class order.

---

## Rollout checklist — update this section, not memory

**Status rule:** `[x]` means the implementation, conversion contract, and required QA evidence are complete. `[ ]` means the row is still open. A factory that merely loads is not a converted row. Rework rows remain intentionally open until their Action ally-relocate design changes.

### ER-1 — shared typed homes

- [ ] `GRANT_AP` is authored as Resource/layer data and no class skill uses an Extra Rule for it.
- [ ] `GRANT_SCRAP` is authored as Resource/layer data and no class skill uses an Extra Rule for it.
- [ ] `PAIRED_MOVE` is wired for legal Pre-Move ally movement only; it is not used for Glorious Charge on Action.
- [ ] Pull-yourself, carry/place-unit, and drag-target verbs have shared EffectType/module paths.
- [ ] `CREATE_HAZARD` has typed terrain, duration, status, entry, spread, and reaction fields.
- [ ] `SPAWN` has typed HP%, placement, turret, construct, and detonation fields.
- [ ] Header fields cover once-per-turn, skip-Action, spend-all-MP, HP cost, and delayed resolution.
- [ ] Required StatusType and LayerCondition additions are implemented and consumed by shared systems.
- [ ] `run_ability_module_bridge_test.gd` proves the shared homes without Extra Rule fallback.

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
| Bruiser | Meat Shield | ☐ | ☐ | ☐ | ☐ | Rework: Action ally relocation |
| Bruiser | Frenzy | ☑ | ☑ | ☑ | ☑ | Typed kill AP field; gates pass; independent audit pass |
| Bruiser | Guttural Roar | ☑ | ☑ | ☑ | ☑ | Typed board-item/collision fields; gates pass; independent audit pass |
| Bruiser | Headbutt | ☑ | ☑ | ☑ | ☑ | Typed max-HP damage field; gates pass; independent audit pass |
| Bruiser | Blood Boil | ☑ | ☑ | ☑ | ☑ | Fully module-authored HP/resource profile; gates pass; independent audit pass |
| Bruiser | Violent Collision | ☑ | ☑ | ☑ | ☑ | Typed recast field + collision layer; gates pass; independent audit pass |
| Bruiser | Crimson Whirlwind | ☑ | ☑ | ☑ | ☑ | Typed target-count heal field; gates pass; independent audit pass |
| Bruiser | Belly Flop | ☑ | ☑ | ☑ | ☑ | Landing PUSH layer; gates pass; independent audit pass |
| Bruiser | Breaching Dash | ☑ | ☑ | ☑ | ☑ | PIERCE keyword; gates pass; independent audit pass |
| Bruiser | Reactive Adrenaline | ☑ | ☑ | ☑ | ☑ | Dedicated passive scenario + upgrade proof; shared turn-start passive path; independent audit pass |
| Archer | Sidestep | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Volley | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Power Shot | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Piercing Shot | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Grapple Arrow | ☐ | ☐ | ☐ | ☐ | Pull-yourself destination |
| Archer | Explosive Arrow | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Hunter’s Mark | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Repelling Shot | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Bear Trap | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Caltrops | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Suppressing Fire | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Parting Shot | ☐ | ☐ | ☐ | ☐ |  |
| Archer | Scout’s Eye | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Push | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Polearm range-band rule | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Rallying Cry status timing | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Wraparound / Flanking Maneuver | ☐ | ☐ | ☐ | ☐ | L-path destination |
| Lancer | Glorious Charge | ☐ | ☐ | ☐ | ☐ | Rework: Action ally relocation |
| Lancer | Pole Vault | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Line Breaker | ☐ | ☐ | ☐ | ☐ |  |
| Lancer | Spear Wall | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Blink | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Ice Shard | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Chain Lightning | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Arcane Push | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Teleport | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Meteor | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Black Hole | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Time Warp | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Mana Shield | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Disintegrate | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Elemental Surge | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Earth Spike | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Density Shift | ☐ | ☐ | ☐ | ☐ |  |
| Mage | Arcane Barrage | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Guardian Step | ☐ | ☐ | ☐ | ☐ | Spend remaining MP |
| Cleric | Holy Light | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Smite | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Cleansing Aura | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Sanctuary | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Divine Hammer | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Life Link | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Prayer of Fortitude | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Resurrection | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Consecrate Ground | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Holy Wrath | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Divine Guidance | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Shield of Faith | ☐ | ☐ | ☐ | ☐ |  |
| Cleric | Martyr’s Chains | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Pullback | ☐ | ☐ | ☐ | ☐ | Pre-Move paired movement |
| Mercenary | Swift Strike | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Defense Strike | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Blade Storm | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Caltrop Toss | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Feint | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Riposte | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Sever | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Second Wind | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Tactical Retreat | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Executioner’s Blade | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Precision Strike | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Flank & Run | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Hamstring | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Acrobatic Vault | ☐ | ☐ | ☐ | ☐ |  |
| Mercenary | Duelist’s Challenge | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Leap | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Scorching Kick | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Thunder Palm | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Yin-Yang Flurry | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Chakra Shift | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Phase Throw | ☐ | ☐ | ☐ | ☐ | Enemy swap on Action is legal |
| Monk | Flying Crane Kick | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Spirit Palm | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Mantra of Peace | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Inner Fire | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Void Step | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Cyclone Sweep | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Updraft | ☐ | ☐ | ☐ | ☐ |  |
| Monk | Geyser Strike | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Slip Past | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Shadow Step | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Kidney Strike | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Smoke Bomb | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Grappling Hook | ☐ | ☐ | ☐ | ☐ | OR choice |
| Rogue | Switcheroo | ☐ | ☐ | ☐ | ☐ | Enemy swap on Action is legal |
| Rogue | Shadow Swap | ☐ | ☐ | ☐ | ☐ | Rework: Action ally relocation |
| Rogue | Blindside | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Throat Slit | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Amnesia Dust | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Death Mark | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Lethal Flourish | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Kidnap | ☐ | ☐ | ☐ | ☐ | Enemy swap + push on Action |
| Rogue | Shuriken Volley | ☐ | ☐ | ☐ | ☐ |  |
| Rogue | Poison Flask | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Reposition | ☐ | ☐ | ☐ | ☐ | Ally-step destination |
| Beast Rider | Pounce | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Feral Drag | ☐ | ☐ | ☐ | ☐ | Enemy drag on Action is legal |
| Beast Rider | Maul | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Bestial Roar | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Raking Claws | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Rest and Recover | ☐ | ☐ | ☐ | ☐ | Spend remaining MP |
| Beast Rider | Intimidate | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Fetch / Snatch | ☐ | ☐ | ☐ | ☐ | Condition: CON ≤ STR |
| Beast Rider | Savage Bite | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Run Down | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Defensive Posture | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Airlift | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Tail Swipe | ☐ | ☐ | ☐ | ☐ |  |
| Beast Rider | Gore | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Recall | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Dismantle | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Sludge Bomb | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Construct Turret | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Frag Bomb | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Magnetic Mine | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Tesla Barricade | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Flak Cannon | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Wrench Smack | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | EMP Grenade | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Rocket Launcher | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Scrap Shield | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Manual Detonation | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Overdrive Injection | ☐ | ☐ | ☐ | ☐ |  |
| Engineer | Barbed Wire | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Usher | ☐ | ☐ | ☐ | ☐ | Ally-step destination |
| Shaman | Curse of Weakness | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Healing Totem | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Flame Totem | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Earthbind Totem | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Bloodlust | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Hex | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Voodoo Link | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Terrify | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Miasma | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Bone Spear | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Sympathetic Bond | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Soul Siphon | ☐ | ☐ | ☐ | ☐ |  |
| Shaman | Pain Spike | ☐ | ☐ | ☐ | ☐ |  |

**Matrix completion rule:** check a skill’s four columns only after the skill-level conversion contract, class gate/live proof, Bible audit, and independent quality re-audit are all recorded. The three Action ally-relocate rows remain unchecked until rewritten.

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
- [ ] `bruiser_meat_shield` remains open as Action ally-relocate rework.

#### 3. Lancer

- [ ] `lancer_push`
- [ ] `lancer_piercing_charge` / Polearm range-band rule
- [ ] `lancer_rallying_cry` status timing row
- [ ] `lancer_flanking_maneuver` / Wraparound
- [ ] `lancer_pole_vault`
- [ ] `lancer_line_breaker`
- [ ] `lancer_spear_wall`
- [ ] Lancer class gate: `run_lancer_qa_gate.ps1`.
- [ ] Lancer live gate: `run_lancer_live_qa.ps1`.
- [ ] `lancer_glorious_charge` remains open as Action ally-relocate rework.

#### 4. Archer

- [ ] `archer_sidestep`
- [ ] `archer_volley`
- [ ] `archer_power_shot`
- [ ] `archer_piercing_shot`
- [ ] `archer_grapple_arrow`
- [ ] `archer_explosive_arrow`
- [ ] `archer_hunters_mark`
- [ ] `archer_repelling_shot`
- [ ] `archer_bear_trap`
- [ ] `archer_caltrop_trap`
- [ ] `archer_suppressing_fire`
- [ ] `archer_parting_shot`
- [ ] `archer_scouts_eye`
- [ ] Archer class gate: `run_archer_qa_gate.ps1`.
- [ ] Archer live gate: `run_archer_live_qa.ps1`.

#### 5. Mercenary

- [ ] `mercenary_pullback`
- [ ] `mercenary_swift_strike`
- [ ] `mercenary_defense_strike`
- [ ] `mercenary_blade_storm`
- [ ] `mercenary_caltrop_toss`
- [ ] `mercenary_feint`
- [ ] `mercenary_riposte_strike`
- [ ] `mercenary_sever`
- [ ] `mercenary_second_wind`
- [ ] `mercenary_tactical_retreat`
- [ ] `mercenary_executioners_blade`
- [ ] `mercenary_precision_strike`
- [ ] `mercenary_flank_and_run`
- [ ] `mercenary_hamstring`
- [ ] `mercenary_acrobatic_vault`
- [ ] `mercenary_duelists_challenge`
- [ ] Mercenary class gate: `run_mercenary_qa_gate.ps1`.
- [ ] Mercenary live gate: `run_mercenary_live_qa.ps1`.

#### 6. Monk

- [ ] `monk_leap`
- [ ] `monk_scorching_kick`
- [ ] `monk_thunder_palm`
- [ ] `monk_yin_yang_flurry`
- [ ] `monk_chakra_shift`
- [ ] `monk_phase_throw`
- [ ] `monk_flying_crane_kick`
- [ ] `monk_spirit_palm`
- [ ] `monk_mantra_of_peace`
- [ ] `monk_inner_fire`
- [ ] `monk_void_step`
- [ ] `monk_cyclone_sweep`
- [ ] `monk_updraft`
- [ ] `monk_geyser_strike`
- [ ] Monk class gate: `run_monk_qa_gate.ps1`.
- [ ] Monk live gate: `run_monk_live_qa.ps1`.

#### 7. Rogue

- [ ] `rogue_slip_past`
- [ ] `rogue_shadow_step`
- [ ] `rogue_kidney_strike`
- [ ] `rogue_smoke_bomb`
- [ ] `rogue_grappling_hook`
- [ ] `rogue_switcheroo`
- [ ] `rogue_blindside`
- [ ] `rogue_throat_slit`
- [ ] `rogue_amnesia_dust`
- [ ] `rogue_death_mark`
- [ ] `rogue_lethal_flourish`
- [ ] `rogue_kidnap`
- [ ] `rogue_shuriken_volley`
- [ ] `rogue_poison_flask`
- [ ] Rogue class gate: `run_rogue_qa_gate.ps1`.
- [ ] Rogue live gate: `run_rogue_live_qa.ps1`.
- [ ] `rogue_shadow_swap` remains open as Action ally-relocate rework.

#### 8. Beast Rider

- [ ] `beast_reposition`
- [ ] `beast_pounce`
- [ ] `beast_feral_drag`
- [ ] `beast_maul`
- [ ] `beast_bestial_roar`
- [ ] `beast_raking_claws`
- [ ] `beast_rest_recover`
- [ ] `beast_intimidate`
- [ ] `beast_fetch`
- [ ] `beast_savage_bite`
- [ ] `beast_run_down`
- [ ] `beast_defensive_posture`
- [ ] `beast_airlift`
- [ ] `beast_tail_swipe`
- [ ] `beast_gore`
- [ ] Beast Rider class gate: `run_beast_rider_qa_gate.ps1`.
- [ ] Beast Rider live gate: `run_beast_rider_live_qa.ps1`.

#### 9. Cleric

- [ ] `cleric_guardian_step`
- [ ] `cleric_holy_light`
- [ ] `cleric_smite`
- [ ] `cleric_cleansing_aura`
- [ ] `cleric_sanctuary`
- [ ] `cleric_divine_hammer`
- [ ] `cleric_life_link`
- [ ] `cleric_prayer_of_fortitude`
- [ ] `cleric_resurrection`
- [ ] `cleric_consecrate_ground`
- [ ] `cleric_holy_wrath`
- [ ] `cleric_divine_guidance`
- [ ] `cleric_shield_of_faith`
- [ ] `cleric_martyrs_chains`
- [ ] Cleric class gate: `run_cleric_qa_gate.ps1`.
- [ ] Cleric live gate: `run_cleric_live_qa.ps1`.

#### 10. Mage

- [ ] `mage_blink`
- [ ] `mage_ice_shard`
- [ ] `mage_chain_lightning`
- [ ] `mage_arcane_push`
- [ ] `mage_teleport`
- [ ] `mage_meteor`
- [ ] `mage_black_hole`
- [ ] `mage_time_warp`
- [ ] `mage_mana_shield`
- [ ] `mage_disintegrate`
- [ ] `mage_elemental_surge`
- [ ] `mage_earth_spike`
- [ ] `mage_density_shift`
- [ ] `mage_arcane_barrage`
- [ ] Mage class gate: `run_mage_qa_gate.ps1`.
- [ ] Mage live gate: `run_mage_live_qa.ps1`.

#### 11. Engineer

- [ ] `engineer_recall`
- [ ] `engineer_dismantle`
- [ ] `engineer_sludge_bomb`
- [ ] `engineer_construct_turret`
- [ ] `engineer_frag_bomb`
- [ ] `engineer_magnetic_mine`
- [ ] `engineer_tesla_barricade`
- [ ] `engineer_flak_cannon`
- [ ] `engineer_wrench_smack`
- [ ] `engineer_emp_grenade`
- [ ] `engineer_rocket_launcher`
- [ ] `engineer_scrap_shield`
- [ ] `engineer_manual_detonation`
- [ ] `engineer_overdrive_injection`
- [ ] `engineer_barbed_wire`
- [ ] Engineer class gate: `run_engineer_qa_gate.ps1`.
- [ ] Engineer live gate: `run_engineer_live_qa.ps1`.

#### 12. Shaman

- [ ] `shaman_usher`
- [ ] `shaman_curse_of_weakness`
- [ ] `shaman_healing_totem`
- [ ] `shaman_flame_totem`
- [ ] `shaman_earthbind_totem`
- [ ] `shaman_bloodlust`
- [ ] `shaman_hex`
- [ ] `shaman_voodoo_link`
- [ ] `shaman_terrify`
- [ ] `shaman_miasma`
- [ ] `shaman_bone_spear`
- [ ] `shaman_sympathetic_bond`
- [ ] `shaman_soul_siphon`
- [ ] `shaman_pain_spike`
- [ ] Shaman class gate: `run_shaman_qa_gate.ps1`.
- [ ] Shaman live gate: `run_shaman_live_qa.ps1`.

### ER-3 — legacy deletion

- [ ] Zero class-factory `_add_extra` / `_add_extras_from_dict` calls.
- [ ] Zero class-skill leftover Extra Rule keys in `EffectData.modifiers`.
- [ ] `CONVERTED_SKILL_IDS` contains every converted skill and the bridge contract passes.
- [ ] Delete `AbilityExtraRule` and the Class Editor Extra Rules UI.
- [ ] Delete `GameEnums.MotionMode` and module/editor/factory Motion Mode fields.
- [ ] Remove combat reads of `module.motion_mode` and all compatibility inference.
- [ ] Run full grep exit check: `_add_extra`, `AbilityExtraRule`, `MotionMode`, `motion_mode` = zero on class skills.
- [ ] Run final planning QA and full deterministic regression.

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
**Blocked until rewritten (skip in ER-2):** Glorious Charge, Meat Shield, Shadow Swap.  
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
