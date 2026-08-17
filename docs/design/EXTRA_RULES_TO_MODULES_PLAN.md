# Extra Rules → Modules / Layers (binding conversion plan)

**Status:** `ACTIVE` — owner-locked 2026-08-16  
**Audience:** Every agent converting skills  
**Authority chain:** **Skill bible** `class_abilities.txt` → **Module bible** `docs/design/ability-data.md` (§0–§11) → **this doc** → `AbilitySystem` / planning / sim
**Non-authority:** Extra Rules. Chat tables. Chat summaries. “Combat still reads the key.”

**Bibles stay in context (absolute).** After any chat summarization, compaction, or handoff, **reread** the skill line in `class_abilities.txt` and the matching module home in `docs/design/ability-data.md` before converting. Do not trust a summary for ATK/MOVE/PUSH text, targeting, or upgrades.

This is the work order that was built in chat and then ignored. Extra Rules was a leftover-bag rename. This plan converts those riders into the module bible.

---

## Goal

Every class **skill** Extra Rule is gone. The skill is authored as header + modules + keywords + layers + gates + targeting / Condition + typed CREATE_HAZARD–SPAWN knobs. Combat reads those fields, not Extra Rules. Landing is a dest **EffectType** (`MOVE` / `JUMP` / `TELEPORT` family).

Legacy cleanup is tracked in `IMPLEMENTATION_PLAN.md` ER-3. This matrix only maps skill content into the module model; landing uses destination `EffectType`s.

**Done for one skill (all required — missing any = not converted):**

1. Changelog quotes the skill line + upgrade from `class_abilities.txt`.
2. Names family + home.
3. No legacy Extra Rule storage remains on the base or upgrade modules. Factory authors typed module/layer fields.
4. No unowned leftover keys remain on that skill’s `effect.modifiers`.
5. Ability id is in `tests/extra_rules_conversion_contract.gd` `CONVERTED_SKILL_IDS`.
6. Behavior matches the skill bible. Class gate + live QA **PASS**.

**Cheat (the last failure):** delete Extra Rules but leave `modifiers["key"]` / combat still reading the bag. Forbidden.

**ER-3 exit target:** no class skill uses Extra Rules; the `AbilityExtraRule` resource and editor path are deleted; factories have no `_add_extra` or leftover authoring keys. Contract test: every converted skill has no unowned runtime keys. Motion cleanup is included in the same ER-3 task.

---

## Conversion law (absolute)

For each leftover / Extra Rule, pick **one** home from `ability-data.md`:

| Home | Use when |
|------|----------|
| **Header** | Cost, once-per-turn, skip-Action, delay, uses |
| **Module primary** | The verb, including landing (`MOVE`, `JUMP`, `TELEPORT`, `JUMP_TO_BEHIND`, `MOVE_TOWARD`, `MOVE_INTO_AND_PUSH`, `PAIRED_MOVE`, …) |
| **Keyword** | TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO |
| **Layer + condition** | Extra punch on the **same targets** (ON_KILL, ON_LAND, ON_COLLISION, WHEN_DAMAGE_DEALT, …) |
| **Gate** | Whether a **module** runs (IF_COLLIDED, IF_KILL, …) |
| **Targeting checkbox / Condition** | Who you may click (EXCLUDE_CASTER, ally, HP/status/occupant filter) |
| **Typed field on an existing punch** | Hazard terrain/duration/status, bounce count, HP% spawn, … |
| **New EffectType / StatusType / LayerCondition** | Only if no row above fits. Grow the dest-effect / status / condition dropdown. Do **not** add Extra Rules or legacy landing modes. |

**Forbidden**

- New Extra Rules, Custom Keys, leftover bags, `effect.modifiers["…"]` as authoring
- Harvesting leftover keys into an enum
- `if ability.id == …` in `AbilitySystem` / physics / planning
- Calling Extra Rules “typed modules”
- Relocating an **ally** on **Action**. Allies queue Walk/Attack/Skill in the same player execution. **Enemy** displacement is legal on Action (they act after the full player plan+execution): PUSH, PULL, throw/Suplex, enemy SWAP, drag. **Ally Action relocates to rewrite — do not convert:** Glorious Charge, Meat Shield, Shadow Swap.
- Passives in this plan (separate bag; owner must ask)

**Already done (do not redo as Extra Rules):** click **Condition** dropdown (Executioner's Blade HP, Hex, Terrify, Savage Bite, Fetch, Maul occupant, constructs, corpses, Amnesia Dust, Feral Drag CON, Intimidate HP). Those skills still appear below if they have *other* extras.

---

## Module primary families (owner-locked)

Reference only. **Skill bible** (`class_abilities.txt`) is the verb. **Module bible** (`ability-data.md`) is the home (header / module / keyword / layer / gate / targeting / field). This table is the Primary dropdown grouping so the list can grow.

**Add rule:** new *kind of verb* → new **type** in a family. Rider (bounce, GHOST, on-kill AP, hazard duration) → field / layer / keyword. New family only if nothing here is the verb. Split a family only when it is clearly two verbs (watch: Link, Scrap, Destroy).

| Family | Opening verb (skill bible) | Types now (module bible) | Incoming / not a new primary |
|--------|----------------------------|--------------------------|------------------------------|
| **Attack** | Hurt (`ATK` / `MAG ATK`) | DAMAGE, DAMAGE_SELF, EXPLODE, RANGED_EXPLODE | Bounce, unmitigated, %HP, ignore-resist = **fields** |
| **Movement (Self)** | You change tiles (`MOVE` / `DASH` / `JUMP` / `TELEPORT`) | MOVE / JUMP / TELEPORT dests, DASH, MOVE_INTO_AND_PUSH | L-path, vault-only, GHOST, facing, pull-yourself-to-wall = **fields** or dest types here |
| **Forced Movement** | They are displaced by your punch (`PUSH` / `PULL` / throw) | PUSH, PULL, THROW_BEHIND | Push/pull are examples. Throw/Suplex/drag-the-target belong here. **Legal on Action** (enemies act after player execution). |
| **Move someone** | You put a body on a tile (usually an ally) | SWAP, PAIRED_MOVE | Ally pair/swap/carry/usher on **Action** = rewrite (Glorious Charge, Meat Shield, Shadow Swap). Pre-Move: Pullback, Usher, Knight Swap, Airlift. Enemy SWAP on Action is legal. |
| **Hazard** | The tile keeps doing something | CREATE_HAZARD, CHANGE_TERRAIN, DESTROY_OBSTACLE | Smoke, caltrops, spear wall, sanctuary, mines = **knobs** |
| **Summon** | You make a unit or object | SPAWN | Construct HP%, turret ATK, overclock = **knobs** |
| **Status** | Apply or strip a named condition, no hit | ADD_STATUS, ADD_STATUS_SELF, REMOVE_STATUS, CLEANSE, PURGE | LINK / WITHER / BLOODLUST / MANA_SHIELD / MARK = **StatusType**. Link may split later. |
| **Heal** | Restore HP | HEAL | MAG HEAL, revive % = **fields**. On-kill HEAL = **layer** |
| **Shield** | Grant over-HP | ARMOR_UP | Scrap shield, missing-HP shield = **fields / layers** |
| **Stance** | You set yourself up this turn | (often ADD_STATUS_SELF / arm-next) | Phalanx, Feint, Mana Shield, Brace, Retaliation |
| **Resource** | Grant/refund AP, Scrap, later currencies | GRANT_AP, GRANT_SCRAP, REFUND_AP_ON_CC | On-kill AP = **layer**. Scrap verbs may split later. |
| **Convert off** | Not a real family | TRAMPLE, BULLDOZE, PUSH_STAGGER_*, PULL_VULNERABLE_*, PUSH_CHAIN_* | Keywords / layers. Do not add here |

Do not split **Movement (Self)** into Walk vs Jump vs Teleport families. Dest types stay in that family.

## Extra Rule categories (not a second primary list)

Every Extra Rule id belongs to **one** conversion home. Most are **not** new primaries. Confirm against the **skill bible** line before picking a family.

| Category | Extra Rule examples | Home |
|----------|---------------------|------|
| Targeting / Condition | `EXCLUDE_CASTER`, `ALLOW_FRIENDLY_TARGET` | Targeting checkbox or Condition dropdown |
| Header | `DOES_NOT_CONSUME_ACTION_SLOT`, `LIMIT_ONCE_PER_TURN`, `COST_ALL_MOVEMENT`, `SPEND_SELF_HP`, `DELAYED_NEXT_TURN` | Header |
| Keyword | `GHOST_MOVE`, `PIERCE`, `TRAMPLE_ATK`, `NEXT_ATTACK_PIERCE`, `IGNORE_ZOC` | Keyword field |
| Movement (Self) field | `L_SHAPE_MOVE`, `VAULT_OBSTACLE_OR_GAP_ONLY`, `PRESERVE_FACING`, `TELEPORT_VISIBLE`, `SHADOW_STEP`, `BLINK` | Field or dest type on **Movement (Self)** |
| Move someone (new type) | `AIRLIFT_*`, `KIDNAP`, `PAIRED_ALLY_CHARGE`, `PULLBACK`, `REPOSITION_OPPOSITE_SIDE`, `RELOCATE_SUBJECT_ONLY` | New type in **Move someone**. Kidnap = enemy SWAP (legal on Action) then PUSH. `PAIRED_ALLY_CHARGE` = ally relocate — Rework. |
| Forced Movement | `PULL_TO_CENTER`, `PULL_SURFACES`, `PUSH_BOARD_ITEMS`, `LANDING_ADJACENT_PUSH`, `PUSH`, `MINE_PULL`, `FERAL_DRAG`, `DRAG_REMAINING_MOVEMENT` | **Forced Movement** type or field. Throw/Suplex = `THROW_BEHIND`. Drag-the-target is legal on Action. Pull-yourself is **not** here. |
| Movement (Self) pull-yourself | `GRAPPLE_WALL_PULL_SELF` | Dest type in **Movement (Self)** |
| Player OR | `PULL_SELF_OR_TARGET`, `GRAPPLE_BIDIRECTIONAL` | `resolution_choice` (Movement (Self) pull-yourself **or** Forced Movement pull-them) |
| Attack field | `BONUS_DMG_*`, `BLEED_*`, `IGNORE_TARGET_MAGIC_PCT`, `RANGE_ONE_DAMAGE_MULTIPLIER` | Field on **Attack** |
| Heal / Shield field | `HEAL_PER_DEBUFF`, `REVIVE_*`, `SCRAP_SHIELD` | Field on **Heal** / **Shield** |
| StatusType | `BLOODLUST_*`, `MANA_SHIELD_*`, `WITHER`, `LINK_*`, `LIFE_LINK_*` | **Status** |
| Hazard knobs | `HAZARD_*`, `SMOKE_*`, `TRAP_*`, `MINE_*`, `TERRAIN_ID`, `SANCTUARY_*`, `HOLY_GROUND_*` | Typed fields on **Hazard** |
| Summon knobs | `CONSTRUCT_*`, `TURRET_ATTACK` | Typed fields on **Summon** |
| Layer ON_KILL | `ON_KILL_*`, `FRENZY_ON_KILL_AP`, `KILL_GRANT_AP` | Layer + **Heal** / **Shield** / **Resource** |
| Layer collision / land | `*_COLLISION_*`, `VIOLENT_COLLISION_RECAST`, `POUNCE_LAND_ADJACENT` | Layer or gate on **Movement (Self)** / **Forced Movement** |
| Resource | `GRANT_AP`, `ON_HIT_SCRAP`, `REFUND_SCRAP_*`, `NEXT_SKILL_ZERO_AP` | **Resource** or header |
| DELETE | Extra Rules themselves | ER-3 in `IMPLEMENTATION_PLAN.md` |

**Self vs skip caster:** Self = may click yourself. Skip caster in blast = aura/AOE does not apply to you. Not the same checkbox. `EXCLUDE_CASTER` Extra Rule → skip-caster blast checkbox, then delete.

---

## How an agent must work

0. **Reread the bibles.** Quote the skill line + upgrade from `class_abilities.txt` in the changelog **before** calling the skill converted. Module home in `docs/design/ability-data.md` §2.2. If this chat was summarized or compacted, do this **again**. Summaries are not the skill bible.
1. Open **this file**. Find the skill row. Pick the **family** from the locked table.
2. Implement the **Solution** cell using the conversion law. If the Solution cell is shorthand vs the skill bible, stop and ask — do not invent a leftover key.
3. Delete that skill’s Extra Rules **and** leftover Extra Rule keys on `effect.modifiers` **in the same change**. Factory has no `_add_extra` on that skill.
4. Add the ability id to `tests/extra_rules_conversion_contract.gd` `CONVERTED_SKILL_IDS`. Removing a legacy container while combat still reads an unowned key = cheat = not converted.
5. Run the conversion contract (via `res://tests/run_ability_module_bridge_test.gd`) **and** that class’s gate + live QA. Report PASS/FAIL.
6. Do not start the next skill until this one has no extras and is on `CONVERTED_SKILL_IDS`.

If the Solution cell is **Rework skill**, **stop**. Do not convert. Do not invent Extra Rules. Do not author from a chat summary. **New module = new player click.** Extra punches on the same click = layers. Do not relocate an **ally** on Action. Enemy Forced Movement / enemy SWAP / drag on Action is legal.

The conversion contract now checks every layer runtime key on converted skills against a typed module/layer owner. This keeps the category table auditable without retaining a legacy `AbilityExtraRule` taxonomy.

---

## Shared punches to add or finish first (Phase ER-1)

These are reused across classes. Wire them as real types **before** class-by-class conversion where the skill needs them. Several already exist as `EffectType` and must be **used**, not re-bagged.

| Punch | Status | Home |
|-------|--------|------|
| GRANT_AP | **Exists** (`EffectType.GRANT_AP`) | Layer ON_KILL / module |
| GRANT_SCRAP | **Exists** (`EffectType.GRANT_SCRAP`) | Layer / module |
| PAIRED_MOVE | **Exists** (`EffectType.PAIRED_MOVE`) | **Move someone** — **Pre-Move only** for allies (Pullback). Not Glorious Charge (Action **ally** relocate). |
| PULL_SELF_TO_TARGET | Missing (module bible §2.2) | **Movement (Self)** dest type (Grapple Arrow / Grappling Hook pull-yourself). Not Forced Movement. OR-choice with pull-them = `resolution_choice`. |
| Carry / place-unit (Airlift, Maul drop) | Missing | New type in **Move someone**. Airlift = Pre/Post (legal). Kidnap = enemy SWAP then PUSH — convert (legal on Action). |
| Drag-while-walking (Feral Drag) | Missing | New type in **Forced Movement**. Legal on Action (enemy). |
| CREATE_HAZARD knobs | Partially typed on module; still extras/layer bags | Typed fields on CREATE_HAZARD |
| SPAWN knobs (HP%, turret ATK, furthest-on-line) | Partial | Typed fields on SPAWN |
| Header once-per-turn / skip-Action / spend-all-MP | Partial (`once_per_turn`, `SPEND_ALL_MOVEMENT`) | Header |
| DELAY_TURNS | Named in ability-data; not fully wired | Header turn_flags |
| LINK / WITHER / BLOODLUST / MANA_SHIELD / MARK | Missing or leftover | New StatusType |
| New LayerCondition as needed | Grow the condition dropdown | Same as Condition work |

---

## Class conversion order (Phase ER-2)

Prove the method on the smallest leftover, then reuse punches.

| Order | Class | Why this order |
|-------|-------|----------------|
| 1 | Knight | One leftover (exclude-self). Method check. |
| 2 | Bruiser | Layers + GRANT_AP + IF_COLLIDED already named |
| 3 | Lancer | JUMP_TO_BEHIND, TRAMPLE, L-path on MOVE. **Glorious Charge blocked** (Action **ally** relocate). |
| 4 | Archer | CREATE_HAZARD knobs + GHOST + layers |
| 5 | Mercenary | Pullback **PAIRED_MOVE** (Pre-Move). GRANT_AP, GHOST |
| 6 | Monk | ON_LAND / hazard knobs. Phase Throw = enemy SWAP (legal on Action). |
| 7 | Rogue | TELEPORT + layers. Switcheroo / Kidnap = enemy (legal). **Shadow Swap blocked** (Action **ally** relocate). |
| 8 | Beast Rider | Airlift Pre/Post (legal). Feral Drag = Forced Movement (legal on Action). |
| 9 | Cleric | LINK + hazard knobs |
| 10 | Mage | Bounce / reaction knobs |
| 11 | Engineer | SPAWN knobs + GRANT_SCRAP |
| 12 | Shaman | LINK / WITHER / totem SPAWN knobs |

Each class: convert every row below **except Type = Rework skill** → extras empty → `run_<class>_qa_gate.ps1` **and** `run_<class>_live_qa.ps1` PASS. Rework rows: stop and leave them. Do not stamp PAIRED_MOVE / **ally** SWAP on Action. Enemy SWAP / THROW_BEHIND / drag on Action is legal.

---

## Matrix (binding)

Type = **existing what** or **new what**. Solution = the only legal conversion.

### Knight

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Defensive Formation | Don’t hit yourself in the aura | Existing targeting | Exclude-self checkbox. Delete Extra Rule / layer stamp. |

### Bruiser

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Push Through [+] | +1 STR after pushing | Existing layer | STR buff on PUSH. |
| Charge Strike [+] | GHOST while walking | Existing keyword | **GHOST**. |
| Charge Strike [+] | +2 ATK if you passed an occupied tile | New field | ATK bonus on DAMAGE if path went through occupied. |
| Concussion Blow | STAGGER if they hit an object | Existing layer | STAGGER on **ON_COLLISION**. |
| Concussion Blow [+] | STAGGER both if they hit a unit | Existing layer | Same collision layer, both units. |
| Cleave [+] | BLEED = WPN | Existing field | BLEED with weapon scaling. |
| Suplex | Throw target behind you | Existing effect | **THROW_BEHIND** / Forced Movement + ATK. Legal on Action (enemy). |
| Suplex [+] | Extra damage per 10 HP | New field | Damage scales with current HP. |
| Adrenaline Surge | 0 AP if 2+ adjacent enemies | Existing header | Cost header: 0 AP when 2+ adjacent. Not Extra Rules. |
| Adrenaline Surge [+] | Pre-Move / does not consume Action | Existing header | Planner group **PRE_MOVE**. Not Extra Rules. |
| Adrenaline Surge [+] | On kill, HEAL + SHIELD | Existing effect | HEAL and SHIELD on **ON_KILL**. |
| Earthshatter [+] | Buff per object destroyed | Existing layer | Buff after **DESTROY_OBSTACLE**. |
| Meat Shield | Swap with ally | **Rework skill** | Action **ally** relocate — they already queued. Do **not** convert as SWAP on Action. |
| Meat Shield [+] | +STR while intercepting | New field | After rework: amount on **INTERCEPT**. |
| Frenzy [+] | On kill, +1 AP | Existing effect | **GRANT_AP** on **ON_KILL**. |
| Guttural Roar [+] | Push items; item collision damage / VULNERABLE | New field | PUSH-hits-items flags. |
| Headbutt | True damage | New field | Unmitigated flag on DAMAGE. |
| Headbutt [+] | Extra % of max HP | New field | % HP on DAMAGE. |
| Violent Collision | Recast move if you collided | Existing gate | **IF_COLLIDED** + second MOVE module. |
| Violent Collision | STAGGER on collision | Existing layer | STAGGER on **ON_COLLISION**. |
| Crimson Whirlwind [+] | HEAL 1 per target hit | Existing layer | HEAL on **PER_TARGET_HIT**. |
| Breaching Dash [+] | Next attack PIERCE | Existing keyword | **PIERCE** on next attack. |

### Archer

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Sidestep | Keep facing; ignore ZOC | New field | Facing / ZOC flags on MOVE. |
| Sidestep [+] | Next ranged ATK +1 | New effect | Next-attack bonus (`GRANT_NEXT_ATTACK_MOD` or equivalent). |
| Volley | Trampled / difficult terrain | New field | Knobs on **CREATE_HAZARD**. |
| Power Shot [+] | Collision PIERCE + damage | Existing layer | Extra DAMAGE on PUSH **ON_COLLISION**. |
| Piercing Shot | Skewer line | Existing shape | LINE shape. |
| Piercing Shot [+] | Bounce 45° off walls | New field | Bounce on LINE. |
| Grapple Arrow | Pull yourself to a wall | New type | **Movement (Self)** dest (pull-yourself). Not Forced Movement. |
| Grapple Arrow [+] | Damage if you pass through | Existing keyword | **TRAMPLE** / path DAMAGE. |
| Explosive Arrow | Destroy terrain | Existing effect | **DESTROY_OBSTACLE**. |
| Explosive Arrow [+] | Ignite flammable | New field | Ignite on **CREATE_HAZARD**. |
| Hunter’s Mark | Allies +1 RANGE and PIERCE | New status | Mark that grants RANGE + PIERCE. |
| Hunter’s Mark [+] | Block stealth teleport | New field | On that status. |
| Repelling Shot | Can hit allies | Existing targeting | Ally checkbox. |
| Repelling Shot [+] | Allies take 0 | New field | Friendly-fire 0 on PUSH/DAMAGE. |
| Bear Trap / Caltrops / Suppressing Fire | Terrain, duration, on-enter ROOT/BLEED/damage | New field | Knobs on **CREATE_HAZARD**. |
| Parting Shot [+] | GHOST on the move | Existing keyword | **GHOST**. |
| Scout’s Eye | Strip STEALTH | Existing effect | **REMOVE_STATUS** STEALTH. |

### Lancer

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Push | Ally legal | Existing targeting | Ally checkbox. |
| Push [+] | Once per turn; +STR after push | Existing header + existing layer | `once_per_turn`; STR on PUSH. |
| Polearm RANGE 1 | 30% less damage at RANGE 1 | New field | Range-band damage cut (basics too). |
| Rally / similar | Status next turn | New field | Delay on ADD_STATUS. |
| Wraparound (Flanking Maneuver) | L-shaped move | New field on MOVE | L-path on **MOVE**. |
| Wraparound | ×2 only from the side | New field | Side-only DAMAGE multiplier. |
| Wraparound [+] | GHOST | Existing keyword | **GHOST**. |
| Glorious Charge | You + ally MOVE adjacent; each ATK 2 | **Rework skill** | Dual-pick = two modules. Relocating the ally on **Action** fights simultaneous queues. Do **not** convert as `PAIRED_MOVE` on Action. Wait for owner rework (Pre-Move relocate, or don’t move the ally). |
| Glorious Charge [+] | Both gain AP on kill | Existing effect | **GRANT_AP** on **ON_KILL** for both — after the rework, as layers on the ATK modules. |
| Pole Vault | Jump obstacle/gap only, not enemies | New field | Restriction on **JUMP_TO_BEHIND**. |
| Pole Vault [+] | PUSH + STAGGER beside landing | Existing layer | PUSH/STAGGER on **ON_LAND**. |
| Line Breaker | Path ATK | Existing keyword | **TRAMPLE**. |
| Line Breaker [+] | +1 per enemy passed | New field | Bonus per path hit. |
| Spear Wall | Terrain, ROOT, duration | New field | Knobs on **CREATE_HAZARD**. |

### Mage

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Blink | Teleport tag | Existing effect | **TELEPORT**. |
| Blink [+] | Leave elemental surface | Existing effect | **CREATE_HAZARD** on start tile. |
| Ice Shard | Fire reaction / slow max MOV 1 | New field | Reaction + MOV-cap on status/hazard. |
| Ice Shard [+] | Steam splash | New field | Same reaction knobs. |
| Chain Lightning | Bounce 2, RANGE 2, surface chain | New field | Bounce knobs on DAMAGE. |
| Chain Lightning [+] | Strike all on that surface | New field | Surface-spread on DAMAGE. |
| Arcane Push | Arcane trail | New field | Trail on **CREATE_HAZARD**. |
| Teleport | Must be visible | New field | LOS/visibility on TELEPORT. |
| Meteor | Hits next turn | New header flag | **DELAY_TURNS**. |
| Meteor [+] | Crater | Existing effect | **CHANGE_TERRAIN** / **CREATE_HAZARD**. |
| Black Hole | Pull to center | Existing effect | **PULL** toward center. |
| Black Hole [+] | Pull surfaces too | New field | PULL-hits-hazards. |
| Time Warp | +1 AP | Existing effect | **GRANT_AP**. |
| Time Warp [+] | Cooldown −1 | New field | Delay reduction. |
| Mana Shield | Spend MP as SHIELD | New status | **MANA_SHIELD**. |
| Disintegrate | Destroy corpse on kill | New field | On-kill destroy corpse. |
| Disintegrate [+] | +1 AP on kill | Existing effect | **GRANT_AP** on **ON_KILL**. |
| Elemental Surge | Utility / surge | New field | Surge package on a utility module. |
| Elemental Surge [+] | +1 AP | Existing effect | **GRANT_AP**. |
| Earth Spike | Spawn HP% | New field | HP% on **SPAWN**. |
| Earth Spike [+] | Adjacent damage on spawn | Existing layer | DAMAGE around spawn. |
| Density Shift | Utility terrain shift | New field | On **CHANGE_TERRAIN**. |
| Density Shift [+] | WEAKEN enemies | Existing effect | **ADD_STATUS** WEAKEN. |
| Arcane Barrage [+] | Ignore 25% MAG | New field | Ignore-resist % on DAMAGE. |

### Cleric

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Guardian Step | Costs all MOV | Existing header | Spend remaining MP (`SPEND_ALL_MOVEMENT`). |
| Guardian Step [+] | CLEANSE the ally | Existing effect | **CLEANSE** layer. |
| Holy Light | HEAL allies / MAG ATK enemies | Existing effect | HEAL layer + DAMAGE layer, different filters. |
| Smite [+] | SHIELD nearest ally for % of damage | New layer | SHIELD on another unit when you hit. |
| Cleansing Aura [+] | +STR per debuff cleansed | New field | Buff per CLEANSE. |
| Sanctuary | Terrain, duration, stealth/sturdy/shield | New field | Knobs on **CREATE_HAZARD**. |
| Sanctuary [+] | Enemies entering PUSH 1 | New field | On-enter PUSH on that hazard. |
| Divine Hammer | Construct HP%, adjacent ATK/PUSH | New field | Knobs on **SPAWN**. |
| Divine Hammer [+] | Holy aura | New field | On the spawn. |
| Life Link | Reduce ally damage; you take 2 | New status | **LINK**. Not a self-hit at cast. |
| Prayer of Fortitude [+] | STURDY counters melee | New field | Counter on **STURDY**. |
| Resurrection | Revive at 10% HP; spend 10 HP | New field + existing cost | Revive % on HEAL; HP cost on header. |
| Resurrection [+] | SHIELD 2 | Existing effect | **SHIELD** layer. |
| Consecrate Ground | Holy ground zone | New field | Knobs on **CREATE_HAZARD**. |
| Consecrate Ground [+] | DEF down | Existing effect | DEF debuff on that zone. |
| Holy Wrath | STAGGER if already debuffed | New field | STAGGER apply-if-debuffed. |
| Holy Wrath [+] | PUSH 2 | Existing effect | **PUSH** layer. |
| Divine Guidance | +1 AP; you MOV 0 next turn | Existing effect | **GRANT_AP** + MOV 0 status. |
| Shield of Faith [+] | Counter on INTERCEPT | New field | On **INTERCEPT**. |
| Martyr’s Chains | Link two enemies; shared MAG | New status | **LINK** + two aims. |
| Martyr’s Chains [+] | Shared BLIND | Existing effect | **BLIND** on the link. |

### Mercenary

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Pullback | Ally steps back with you | Existing effect | **PAIRED_MOVE**. |
| Pullback [+] | Ally +2 DEF; cost 1 MOV | Existing status + existing header | DEF layer; header cost. |
| Swift Strike [+] | +1 AP if already wounded | Existing effect | **GRANT_AP** if missing HP (layer condition). |
| Defense Strike [+] | No push mitigation; can’t gain SHIELD | New field | Flags on the hit. |
| Blade Storm | +2 if target next to an ally | New field | Adjacent-ally bonus on DAMAGE. |
| Blade Storm [+] | BLEED = WPN | Existing field | BLEED weapon scaling. |
| Caltrop Toss | Trap knobs; skip some on-enter | New field | Knobs on **CREATE_HAZARD**. |
| Feint | Next ATK +1 and PIERCE | Existing keyword + new effect | **PIERCE** + next-attack bonus. |
| Feint [+] | Target DEF −25% for 2 turns | Existing effect | DEF debuff layer. |
| Riposte | Bonus if they hit you last turn | New field | “If they attacked you” on DAMAGE. |
| Riposte [+] | DEF −2 | Existing effect | DEF debuff. |
| Sever | On kill, all allies HEAL 1 | Existing effect | **HEAL** on **ON_KILL**, all allies. |
| Sever [+] | All allies SHIELD 1 | Existing effect | **SHIELD** on **ON_KILL**. |
| Second Wind | +1 AP | Existing effect | **GRANT_AP**. |
| Second Wind [+] | Next skill 0 AP | New field | Next-skill cost 0. |
| Tactical Retreat | MOVE 3 + smoke on start tile | Existing effect | **MOVE** 3 (any tile). **CREATE_HAZARD** smoke on start tile. Not BACKWARDS. Bible has no backwards. |
| Tactical Retreat [+] | GHOST | Existing keyword | **GHOST**. |
| Executioner's Blade [+] | On kill +1 AP | Existing effect | **GRANT_AP** on **ON_KILL**. |
| Precision Strike | Ignore 50%/100% DEF if unacted | New field | DEF-ignore % if not acted. Not PIERCE. |
| Flank & Run | Next ATK +2 if ended next to enemy | New effect | Next-attack bonus if ended adjacent. |
| Flank & Run [+] | GHOST | Existing keyword | **GHOST**. |
| Hamstring | Max MOV 1 | Existing field | MOV cap on the status. |
| Hamstring [+] | Extra vs BLEED | New field | Bonus if BLEED. |
| Acrobatic Vault [+] | PIERCE | Existing keyword | **PIERCE**. |
| Duelist’s Challenge | Mark the target | New status | **MARK**. |
| Duelist’s Challenge [+] | Marked −2 DEF | Existing effect | DEF debuff on the mark. |

### Monk

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Leap [+] | Absorb the surface you land on | New field | Absorb on **ON_LAND**. |
| Scorching Kick | Fire surface | New field | Knobs on **CREATE_HAZARD**. |
| Scorching Kick [+] | Burning splash | New field | Splash on that hazard. |
| Thunder Palm | Chain across surfaces | New field | Surface-chain on DAMAGE. |
| Yin-Yang Flurry | First hit 0, then PIERCE | New field | Hit-count rules on DAMAGE. |
| Chakra Shift | Convert / burst | New field | Burst AOE knobs. |
| Phase Throw | Swap with enemy | Existing effect | **SWAP**. Legal on Action (enemy — they have not acted yet). |
| Phase Throw [+] | ROOT after swap | Existing effect | **ROOT** layer. |
| Flying Crane Kick | Stop at first enemy | New field | Dash stop rule. |
| Flying Crane Kick | Adjacent damage on landing | Existing layer | DAMAGE on **ON_LAND**. |
| Flying Crane Kick [+] | Absorb element on dash | New field | Absorb on DASH. |
| Spirit Palm | Collision splash | Existing layer | Splash on **ON_COLLISION**. |
| Mantra of Peace | WEAKEN | Existing effect | **WEAKEN**. |
| Inner Fire | Self fire / surface | New field | Hazard on self. |
| Void Step [+] | +MAG after landing | Existing layer | MAG buff on **ON_LAND**. |
| Cyclone Sweep [+] | −MOV on pushed | Existing effect | MOV debuff on PUSH. |
| Updraft [+] | BLIND if you pass over | New layer | BLIND when passing over. |
| Geyser Strike | Water surface | New field | Knobs on **CREATE_HAZARD**. |
| Geyser Strike [+] | Extra PUSH if on water | New field | Bonus if target on that terrain. |

### Rogue

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Slip Past | Through ally to tile behind | Existing effect | **TELEPORT_TO_BEHIND**. |
| Slip Past [+] | Ally +1 DEF | Existing effect | DEF buff layer. |
| Shadow Step | Teleport tag | Existing effect | **TELEPORT_ADJACENT_TO**. |
| Shadow Step [+] | +1 STR if behind | Existing layer | STR on **IF_FROM_BEHIND**. |
| Kidney Strike | −2 MOV; ROOT only from behind | Existing field + existing layer | MOV penalty; ROOT on **IF_FROM_BEHIND**. |
| Smoke Bomb | Smoke, duration, stealth vs outside | New field | Knobs on **CREATE_HAZARD**. |
| Smoke Bomb [+] | Allies HEAL 1/turn | New field | Pulse HEAL on that hazard. |
| Grappling Hook | Pull you **or** them | New field | OR-choice (`resolution_choice`). |
| Grappling Hook [+] | Trap collision ×2 | New field | Collision vs trap. |
| Switcheroo | Swap with enemy | Existing effect | **SWAP**. Legal on Action (enemy). |
| Switcheroo [+] | You inherit incoming attacks | New status | Inherit-hits status. |
| Shadow Swap | Swap with ally | **Rework skill** | Action **ally** relocate — they already queued. Do **not** convert as SWAP on Action. |
| Shadow Swap [+] | +1 DEF next turn | Existing effect | After rework: DEF layer. |
| Blindside | STAGGER if they haven’t acted | New field | STAGGER if unacted. |
| Blindside [+] | +2 if already STAGGER | New field | Bonus vs STAGGER. |
| Throat Slit [+] | On kill, SILENCE adjacent | Existing effect | **SILENCE** on **ON_KILL**, adjacent. |
| Amnesia Dust | CONFUSION next turn | New field | Delay on the status. Click lock is Condition. |
| Death Mark [+] | On kill, refresh mark at 0 AP | New field | Refresh + 0 AP on **ON_KILL**. |
| Lethal Flourish | +2 if target debuffed | New field | Bonus if debuffed. |
| Lethal Flourish [+] | +1 AP on kill | Existing effect | **GRANT_AP** on **ON_KILL**. |
| Kidnap | Swap then PUSH 2 | Existing effect | Enemy **SWAP** then **PUSH** layer. Legal on Action (enemy). |
| Kidnap [+] | STAGGER both on collision | Existing layer | STAGGER on **ON_COLLISION**. |
| Shuriken Volley [+] | PIERCE vs BLIND | New field | PIERCE if BLIND. |
| Poison Flask [+] | BLIND on entry | New field | On-enter on **CREATE_HAZARD**. |

### Beast Rider

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Reposition | Slide ally to opposite side | New effect | Dest **EffectType** for slide-ally-opposite. |
| Pounce | Land adjacent | Existing effect | **MOVE_TOWARD** ends adjacent. |
| Pounce [+] | PUSH 1 on land | Existing layer | **PUSH** on **ON_LAND**. |
| Feral Drag | Drag for leftover MOV | New effect | Drag-while-walk **Forced Movement**. Legal on Action (enemy). |
| Feral Drag [+] | Hits on you go to them | New status | Damage-sink. Not INTERCEPT. |
| Maul | Drop on adjacent empty | New effect | Place on clicked adjacent empty. Not THROW_BEHIND. |
| Maul | 0 AP, skip Action, 1/turn | Existing header | Once-per-turn / skip-Action. |
| Maul [+] | Trap damage ×2 | New field | On drop-onto-trap. |
| Bestial Roar FEAR | Only if already debuffed | New field | On FEAR apply. Not a click Condition. |
| Raking Claws [+] | PULL 1 before the hit | Existing effect | **PULL** layer before DAMAGE. |
| Rest and Recover | Costs all MOV | Existing header | Spend remaining MP. |
| Intimidate [+] | PURGE buffs | Existing effect | **PURGE** layer. |
| Fetch [+] | PULL light ally 2 | Existing Condition | **PULL** + **CON ≤ STR**. |
| Savage Bite [+] | SHIELD 2 on kill | Existing effect | **SHIELD** on **ON_KILL**. |
| Run Down | Side PUSH while dashing | New layer | PUSH when you pass *beside*. Not TRAMPLE. |
| Run Down | ATK 2 on the dash | Existing keyword | **TRAMPLE** amount 2. |
| Run Down [+] | BLEED on that PUSH | Existing effect | BLEED on the PUSH. |
| Defensive Posture [+] | PUSH the attacker on intercept | Existing layer | PUSH on **INTERCEPT**. |
| Airlift | Shared-tile pick up, then drop | New effect | Carry, then place. Pre/post timing already exists. |
| Airlift [+] | Ally +1 ATK | Existing effect | STR buff on drop. |
| Tail Swipe [+] | STAGGER on wall/object | Existing layer | STAGGER on **ON_COLLISION**. |
| Gore | Extra damage if BLEED | New field | Bonus if BLEED. |

### Engineer

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Recall [+] | OVERCLOCK on land | Existing status | **OVERCLOCK** on **ON_LAND**. |
| Dismantle | −25% DEF | Existing effect | DEF debuff. |
| Dismantle [+] | +1 Scrap on hit | Existing effect | **GRANT_SCRAP**. |
| Sludge Bomb [+] | Ignite the oil | New field | Ignite on **CREATE_HAZARD**. |
| Construct Turret | Spawn + turret ATK | New field | Knobs on **SPAWN**. |
| Construct Turret [+] | Damage around it on death | Existing layer | DAMAGE on death. |
| Frag Bomb | Ignite oil | New field | Ignite. |
| Frag Bomb [+] | Refund 1 AP if it destroys a construct | Existing effect | **GRANT_AP** on construct kill. |
| Magnetic Mine | Pull, damage, explode | New field | Knobs on **SPAWN**. |
| Magnetic Mine [+] | Absorb items/scrap | New field | On the mine. |
| Tesla Barricade | Wall spawn | New field | Knobs on **SPAWN**. |
| Tesla Barricade [+] | Detonation STAGGER | New field | On Manual Detonation vs this spawn. |
| Flak Cannon [+] | +ATK from scrap; BLEED | New field | Scrap scaling on DAMAGE. |
| Wrench Smack | Tag | Existing effect | DAMAGE. |
| Wrench Smack [+] | +1 STR | Existing effect | STR buff. |
| EMP Grenade | Extra vs mechanical bosses | New field | Boss/mechanical bonus. |
| EMP [+] | HEAL + OVERCLOCK friendly constructs | Existing effect | HEAL + **OVERCLOCK** on allies. |
| Rocket Launcher | Destroy terrain | Existing effect | **DESTROY_OBSTACLE**. |
| Rocket [+] | Instant-sacrifice construct | New field | Sacrifice spawn. |
| Scrap Shield | SHIELD × scrap | New field | Scrap multiplier on **SHIELD**. |
| Scrap Shield [+] | Explode when shield breaks | Existing effect | **EXPLODE** when SHIELD hits 0. |
| Manual Detonation | Skip Action / 1/turn | Existing header | Once-per-turn / skip-Action. |
| Manual Detonation [+] | Refund 1 Scrap | Existing effect | **GRANT_SCRAP**. |
| Overdrive | STR + OVERCLOCK + 2 true damage | Existing effect | All three exist; wire as layers. |
| Overdrive [+] | Scrap when it dies | Existing effect | **GRANT_SCRAP** on death. |
| Barbed Wire | Hazard knobs | New field | Knobs on **CREATE_HAZARD**. |
| Barbed Wire [+] | Adjacent +DEF | Existing effect | DEF aura on the hazard. |

### Shaman

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Usher | Ally steps; you don’t | New effect | Dest **EffectType** for ally-step (you stay). |
| Usher [+] | Can move a totem | New field | Allow-totem on that relocate. |
| Curse of Weakness | STR −2 / DEF −2 | Existing effect | Two status layers. |
| Curse [+] | No push mitigation | New field | On the curse. |
| Healing / Flame / Earthbind Totem | Kind, pulse, HP% | New field | Knobs on **SPAWN**. |
| Bloodlust | STR/DEF/MOV + HP/turn | New status | **BLOODLUST**. |
| Bloodlust [+] | Attacks apply BLEED | New field | On that status. |
| Hex | WITHER; bosses 25% | New status | **WITHER** (boss 25% is WITHER’s global rule). |
| Hex [+] | VULNERABLE | Existing effect | **VULNERABLE**. |
| Voodoo Link | Later hits leak WPN | New status | **LINK**. Two aims already exist. |
| Voodoo Link [+] | Shared PUSH | New field | On the link. |
| Terrify [+] | Boss FEAR fallback | New field | Custom boss fallback on FEAR. |
| Miasma [+] | POISON spreads on PUSH collision | Existing layer | POISON on **ON_COLLISION**. |
| Bone Spear | Spawn furthest on the line | New field | Spawn placement on **SPAWN**. |
| Bone Spear [+] | Lightning rod | New field | On the spawn. |
| Sympathetic Bond | Ally/enemy link; HEAL hurts the enemy | New status | **LINK** ally–enemy. |
| Sympathetic Bond [+] | Enemy damage HEALs ally | New field | On that link. |
| Soul Siphon | +1 per debuff | New field | Bonus per debuff on DAMAGE. |
| Soul Siphon [+] | HEAL 1 per debuff | Existing layer | HEAL per debuff. |
| Pain Spike | Also hit linked enemies | New field | On **LINK**. |
| Pain Spike [+] | BLIND linked | Existing effect | **BLIND** on linked. |

---

## Phase ER-3 — DELETE Extra Rules

When every class skill row is converted:

1. Grep `_add_extra`, `AbilityExtraRule`, `extras.append` in production code → **zero**.
2. Delete `data/definitions/ability_extra_rule.gd` and Class Editor Extra Rules UI.
3. Combat must not read Extra Rule keys as authoring.
4. Motion cleanup is complete: destination `EffectType` values and typed fields cover Wraparound, Pole Vault, Reposition slide, and Usher ally-step.

---

## QA

| After | Run |
|-------|-----|
| Any class factory / skill conversion | `.\scripts\run_<class>_qa_gate.ps1` **and** `.\scripts\run_<class>_live_qa.ps1` |
| Converted-skill extras / Extra Rule homes | Headless `res://tests/run_ability_module_bridge_test.gd` (includes `extra_rules_conversion_contract`) |
| Planning / commit / overlay | `.\scripts\run_planning_qa_gate.ps1` (no `-LiveTier3` unless asked) |
| GRANT_AP / Simulator / AbilitySystem | `.\scripts\run_regression_tests.ps1` |

Fail → fix that skill. Do not mark the class converted. Contract FAIL on a converted id = extras or leftover Extra Rule keys still present.

---

## Passives

**Out of scope** until the owner asks. Same leftover problem; different table.
