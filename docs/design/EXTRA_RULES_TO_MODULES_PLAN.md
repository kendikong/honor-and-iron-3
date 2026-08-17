# Extra Rules → Modules / Layers (binding conversion plan)

**Status:** `ACTIVE` — owner-locked 2026-08-16  
**Audience:** Every agent converting skills  
**Authority chain:** `class_abilities.txt` → `docs/design/ability-data.md` (§0–§11, §12.9) → **this doc** → `AbilitySystem` / planning / sim  
**Non-authority:** Extra Rules. Chat tables. “Combat still reads the key.”

This is the work order that was built in chat and then ignored. Extra Rules was a leftover-bag rename. This plan converts those riders into the module bible.

---

## Goal

Every class **skill** Extra Rule is gone. The skill is authored as header + modules + keywords + layers + gates + targeting / Condition + typed CREATE_HAZARD–SPAWN knobs. Combat reads those fields, not Extra Rules. Landing is a dest **EffectType** (`MOVE` / `JUMP` / `TELEPORT` family).

**DELETE Motion Mode.** Marked for deletion: `GameEnums.MotionMode`, Class Editor Motion Mode dropdown, factory `motion_mode` stamps, combat `module.motion_mode` reads. Dest EffectType owns landing. Do not convert leftovers into Motion Mode.

**Done for one skill:** that skill’s `AbilityModule.extras` is empty (base and upgrade), behavior matches Bible, class gate + live QA **PASS**.

**Done for the project:** no class skill uses Extra Rules; `AbilityExtraRule` deleted; **Motion Mode deleted**; factories have no `_add_extra` / leftover modifier / `motion_mode` stamps.

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
| **New EffectType / StatusType / LayerCondition** | Only if no row above fits. Grow the dest-effect / status / condition dropdown. Do **not** add Extra Rules or Motion Mode. |

**Forbidden**

- New Extra Rules, Custom Keys, leftover bags, `effect.modifiers["…"]` as authoring
- Harvesting leftover keys into an enum
- `if ability.id == …` in `AbilitySystem` / physics / planning
- Calling Extra Rules “typed modules”
- Converting leftovers into **Motion Mode**. **Motion Mode is marked for deletion** (ER-3). Do not add modes. Do not keep the dropdown.
- Passives in this plan (separate bag; owner must ask)

**Already done (do not redo as Extra Rules):** click **Condition** dropdown (Executioner's Blade HP, Hex, Terrify, Savage Bite, Fetch, Maul occupant, constructs, corpses, Amnesia Dust, Feral Drag CON, Intimidate HP). Those skills still appear below if they have *other* extras.

---

## How an agent must work

1. Open **this file**. Find the skill row.
2. Implement the **Solution** cell using the conversion law.
3. Delete that skill’s Extra Rules and layer leftover stamps **in the same change**.
4. Run that class’s gate + live QA. Report PASS/FAIL.
5. Do not start the next skill until this one has no extras.

If the Solution cell is wrong vs Bible, **stop and ask**. Do not invent Extra Rules.

---

## Shared punches to add or finish first (Phase ER-1)

These are reused across classes. Wire them as real types **before** class-by-class conversion where the skill needs them. Several already exist as `EffectType` and must be **used**, not re-bagged.

| Punch | Status | Home |
|-------|--------|------|
| GRANT_AP | **Exists** (`EffectType.GRANT_AP`) | Layer ON_KILL / module |
| GRANT_SCRAP | **Exists** (`EffectType.GRANT_SCRAP`) | Layer / module |
| PAIRED_MOVE | **Exists** (`EffectType.PAIRED_MOVE`) | Module primary (Glorious Charge, Pullback) |
| PULL_SELF_TO_TARGET | Missing (bible §12.7) | New effect or resolution_choice on PULL |
| Carry / place-unit (Airlift, Kidnap, Maul drop) | Missing | New effect family |
| Drag-while-walking (Feral Drag) | Missing | New effect |
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
| 3 | Lancer | PAIRED_MOVE, JUMP_TO_BEHIND, TRAMPLE, L-path on MOVE |
| 4 | Archer | CREATE_HAZARD knobs + GHOST + layers |
| 5 | Mercenary | PAIRED_MOVE, GRANT_AP, GHOST |
| 6 | Monk | ON_LAND / hazard knobs |
| 7 | Rogue | TELEPORT/SWAP + layers |
| 8 | Beast Rider | Carry/drag (new punches) |
| 9 | Cleric | LINK + hazard knobs |
| 10 | Mage | Bounce / reaction knobs |
| 11 | Engineer | SPAWN knobs + GRANT_SCRAP |
| 12 | Shaman | LINK / WITHER / totem SPAWN knobs |

Each class: convert every row below → extras empty → `run_<class>_qa_gate.ps1` **and** `run_<class>_live_qa.ps1` PASS.

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
| Suplex [+] | Extra damage per 10 HP | New field | Damage scales with HP. |
| Adrenaline Surge | 0 AP if 2+ adjacent enemies | Existing header | Cost header: 0 AP when 2+ adjacent. Not Extra Rules. |
| Adrenaline Surge [+] | Pre-Move / does not consume Action | Existing header | Planner group **PRE_MOVE**. Not Extra Rules. |
| Adrenaline Surge [+] | On kill, HEAL + SHIELD | Existing effect | HEAL and SHIELD on **ON_KILL**. |
| Earthshatter [+] | Buff per object destroyed | Existing layer | Buff after **DESTROY_OBSTACLE**. |
| Meat Shield [+] | +STR while intercepting | New field | Amount on **INTERCEPT**. |
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
| Grapple Arrow | Pull yourself to a wall | New effect | **PULL_SELF_TO_TARGET**. |
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
| Wraparound (Flanking Maneuver) | L-shaped move | New field on MOVE | L-path on **MOVE**. Not Motion Mode. |
| Wraparound | ×2 only from the side | New field | Side-only DAMAGE multiplier. |
| Wraparound [+] | GHOST | Existing keyword | **GHOST**. |
| Glorious Charge | You + ally charge; ally ATK 2 | Existing effect | **PAIRED_MOVE** + ally DAMAGE layer. |
| Glorious Charge [+] | Both gain AP on kill | Existing effect | **GRANT_AP** on **ON_KILL** for both. |
| Pole Vault | Jump obstacle/gap only, not enemies | New field | Restriction on **JUMP_TO_BEHIND**. Not VAULT_OVER Motion Mode. |
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
| Switcheroo | Swap tag | Existing effect | **SWAP**. |
| Switcheroo [+] | You inherit incoming attacks | New status | Inherit-hits status. |
| Blindside | STAGGER if they haven’t acted | New field | STAGGER if unacted. |
| Blindside [+] | +2 if already STAGGER | New field | Bonus vs STAGGER. |
| Throat Slit [+] | On kill, SILENCE adjacent | Existing effect | **SILENCE** on **ON_KILL**, adjacent. |
| Amnesia Dust | CONFUSION next turn | New field | Delay on the status. Click lock is Condition. |
| Death Mark [+] | On kill, refresh mark at 0 AP | New field | Refresh + 0 AP on **ON_KILL**. |
| Lethal Flourish | +2 if target debuffed | New field | Bonus if debuffed. |
| Lethal Flourish [+] | +1 AP on kill | Existing effect | **GRANT_AP** on **ON_KILL**. |
| Kidnap | Carry/swap special | New effect | Carry / place (Airlift family). |
| Kidnap [+] | STAGGER both on collision | Existing layer | STAGGER on **ON_COLLISION**. |
| Shuriken Volley [+] | PIERCE vs BLIND | New field | PIERCE if BLIND. |
| Poison Flask [+] | BLIND on entry | New field | On-enter on **CREATE_HAZARD**. |

### Beast Rider

| Skill | Leftover | Type | Solution |
|---|---|---|---|
| Reposition | Slide ally to opposite side | New effect | Dest **EffectType** for slide-ally-opposite. Not Motion Mode. |
| Pounce | Land adjacent | Existing effect | **MOVE_TOWARD** ends adjacent. |
| Pounce [+] | PUSH 1 on land | Existing layer | **PUSH** on **ON_LAND**. |
| Feral Drag | Drag for leftover MOV | New effect | Drag-while-you-walk. |
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
| Usher | Ally steps; you don’t | New effect | Dest **EffectType** for ally-step (you stay). Not Motion Mode. |
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

## Phase ER-3 — DELETE Extra Rules and Motion Mode

When every class skill row is converted:

1. Grep `_add_extra`, `AbilityExtraRule`, `extras.append` in factories → **zero**.
2. Delete `data/definitions/ability_extra_rule.gd` and Class Editor Extra Rules UI.
3. Combat must not read Extra Rule keys as authoring.
4. **DELETE Motion Mode:** remove `GameEnums.MotionMode`, Class Editor Motion Mode dropdown, every factory `motion_mode =` stamp, every combat / planning read of `module.motion_mode`. Grep `MotionMode` / `motion_mode` → **zero** (except this plan saying it is gone).
5. Wraparound L-path, Pole Vault, Reposition slide, Usher ally-step must already live on dest EffectType / MOVE-JUMP fields before this delete. Do not leave a Motion Mode peek.

---

## QA

| After | Run |
|-------|-----|
| Any class factory / skill conversion | `.\scripts\run_<class>_qa_gate.ps1` **and** `.\scripts\run_<class>_live_qa.ps1` |
| Planning / commit / overlay | `.\scripts\run_planning_qa_gate.ps1` (no `-LiveTier3` unless asked) |
| GRANT_AP / Simulator / AbilitySystem | `.\scripts\run_regression_tests.ps1` |

Fail → fix that skill. Do not mark the class converted.

---

## Passives

**Out of scope** until the owner asks. Same leftover problem; different table.
