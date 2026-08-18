# AbilityData — Modular Skill Design Bible

**Status:** `ACTIVE` — module authoring bible. Start at §0.
**Audience:** Project owner (readable) + implementers (authoring + conversion)  
**Authority chain:** `class_abilities.txt` (skill lines, keywords, economy) → **this doc** (header / modules / keywords / layers / gates) → `AbilitySystem` / planning / sim
**Conversion work:** `docs/design/EXTRA_RULES_TO_MODULES_PLAN.md` and `IMPLEMENTATION_PLAN.md` track migration and legacy cleanup; they do not add authoring concepts.

### How to read this doc

| If you need… | Read |
|--------------|------|
| Owner one-pager | **§0** + locked table below |
| Module vs layer / new click | **§0** module-vs-layer table · §2.5 · §5 |
| Relocate an **ally** on Action | Locked table + **Global rules** (allies queue in the same player execution; enemies act after) |
| Authoring a skill | §0 → §1 → §2 → §6 → §10 examples |
| Anim / tags | §7 |
| Converting an existing skill | `docs/design/EXTRA_RULES_TO_MODULES_PLAN.md` |

**Conflict precedence:** Skill bible → this authoring contract → shared systems. Chat summaries are not authority. After any summarization, reread `class_abilities.txt` and this doc.

### Owner decisions (locked)

| Topic | Decision |
|-------|----------|
| MOVE 0 | Illegal; editor greys out options that do nothing |
| Undo | **Not** part of AbilityData — planning/timeline only |
| Trampling packaging | MOVE + **TRAMPLE** keyword + separate **PUSH** layer |
| Upgrades | **Separate** `modules` and `upgraded_modules` (full profiles; upgraded may diverge a lot) |
| Refactor scope | All **current** movesets in the project (factories/class library/readers) — not uncoded future classes |
| Planner column | Rename economy `kind` → **`planner_group`**: `PRE_MOVE` or `ACTION` (post-move steps = `ON_POST` modules inside an ACTION skill) |
| Classification / anim | **Tags** (e.g. attack, movement) — not overloaded “movement skill” naming |
| Basic positioning | Today’s MP Swap / Push Through style skills → **basic positioning** (`planner_group = PRE_MOVE`), distinct from “has a MOVE effect” |
| Module vs layer | **New module = new player click.** Layers = extra punches on that module’s already-chosen targets. Complicated one-click results = multiple layers, not a fake second module. |
| Relocate an ally on Action | Player Actions resolve together — do not pair-move / swap / carry / usher an **ally** on Action. **Enemy** displacement is legal on Action (they act after the full player plan+execution): PUSH, PULL, throw/Suplex, enemy swap, drag, and similar Forced Movement. The reworked Meat Shield and Shadow Swap are Pre-Move swaps; Glorious Charge is an enemy-focused Action charge. |

---

## 0. Normative summary (v1 target)

One skill card =

1. **Header:** `planner_group` + **tags** + **cost once** + presentation + `modules` / `upgraded_modules`  
2. **Each module:** primary effect + range + shape + tile/unit flags + optional **keywords** + **layers** + **gate**  
3. **Same click extras** → layers (stack as many as the punch needs) · **New player click** → new module · **Path hits** → TRAMPLE/BULLDOZE keywords (not micro-checkboxes)

| `planner_group` | Column | Cost | Action slot |
|-----------------|--------|------|-------------|
| `PRE_MOVE` | Pre-Move | **MP** | No — basic positioning |
| `ACTION` | Action | **AP** (0 OK) | Yes — may include `ON_PRE` / `ON_POST` modules |

**Canonical tags (v1):** `attack` · `movement` · `positioning` · `spell` · `heal` (optional). Multi-tag OK.

**AUTO anim:** DASH→`SUPER_RUN` · BULLDOZE→`RUN` · MOVE+TRAMPLE→`RUN` · other MOVE→`WALK` · else attack/spell/positioning rules in §7.1.

**Explicitly out of AbilityData:** undo/cancel UX, passives, enemy-turn reactions.

---

## Goal

Define how a skill is authored and understood so that:

1. You can read a skill as **header + ordered modules** and know what it does.
2. Creative skills (move then attack, attack then canto, dash + trample, multi-aim, etc.) are **composed from modules**, not one-off code.
3. Preview, commit, and execution share **one meaning** of the skill (move preview = intent truth).
4. Later refactor of `AbilityData` / class library / factories has a single written target.

---

## Big picture (read this first)

A skill is **not** one RANGE number + a bag of effects.

```
SKILL
├── Header          → planner_group, tags, cost (once), presentation, modules + upgraded_modules
└── Modules[]       → ordered steps (like mini-skills in a sequence)
    ├── Primary effect + aim (range, shape, tile/unit, values)
    ├── Keywords[]  → bundled packages (TRAMPLE, BULLDOZE, …)
    ├── Layers[]    → extra effects on THAT module’s targets (same aim)
    └── Gate        → whether this module runs (Always / if kill / …)
```

**Mental model**

| Piece | Means |
|-------|--------|
| **Header** | Planner column (`planner_group`), identity **tags**, cost once, presentation |
| **Module** | One step with **its own player click** (aim). No new click → not a new module. |
| **Keyword** | Bible package on a module (passthrough+hit, etc.) — prefer over micro-layers |
| **Layer** | Extra effect on the **same targets** as its parent module (the click you already made) |
| **Gate** | Condition that decides if this **module** activates at all |

**Module vs layer (absolute)**

| Question | Answer |
|----------|--------|
| Does the player **click again** (new unit, new tile, second pick)? | **New module.** Dual-pick = two modules. |
| Same click, more punches (PUSH after the hit, STAGGER if they collide, GRANT AP on kill, a second hit on the **same** body)? | **Layers** on that module. Stack as many as you need. |
| One click’s result is complicated? | Still **layers**, not a second module that secretly reuses the first aim. |
| Path hits while **you** walk? | **Keyword** (TRAMPLE / BULLDOZE) on the move module — not extra clicks. |

Do **not** author a second module whose only job is “also affect the first module’s target.” That is a layer. Authors never pick “same as module N” for that. (`SAME_AS_MODULE_N` is internal, gated recast only — Violent Collision.)

---

## Global rules this design must respect

From Master Bible / project rules (do not bypass silently):

- **Timeline columns:** Pre-Move → Action → Post-Move (no hidden 4th column).
- **One Action** per unit per turn for class skills (unless Bible says otherwise).
- **Simultaneous execution:** Player Actions resolve together. Enemy actions wait until after the full player plan and execution.
- **Ally relocate on Action:** Do not pair-move, swap, carry, or usher an **ally** on Action — they already queued Walk/Attack/Skill. Ally relocates belong in **Pre-Move**.
- **Enemy displacement on Action:** Legal. Forced Movement (PUSH, PULL, throw/Suplex, and similar), enemy SWAP, drag. Enemies have not acted yet.
- **Reworked relocation skills:** Meat Shield and Shadow Swap are legal Pre-Move ally swaps. Glorious Charge is a legal enemy-focused Action charge; it no longer pairs an ally.
- **Preview == commit** — modules define what planning shows; commit ratifies that picture.
- **Data over per-skill code** — new behavior = new shared effect/keyword/condition, not `if ability.id == …`.
- **Sim never plays art** — presentation keys/anims are forwarded; Nodes stay out of simulation.

If a skill needs a **new** global rule, stop and get owner approval (Global Rules First).

---

## 1. Skill header

Authored once per skill. Modules do **not** each pay AP/MP or pick a second “class vs movement” identity.

| Field | Purpose |
|-------|---------|
| **id** | Stable id (`bruiser_charge_strike`, …) |
| **display_name** | Player-facing name |
| **planner_group** | Timeline column only: `PRE_MOVE` (basic positioning — MP, no Action slot) or `ACTION` (AP class skills / basic attack; may contain `ON_POST` modules). Replaces old `AbilityKind` for class-library cards. Universal Run/Wait stay system actions. |
| **tags** | Classification set for identity + AUTO anim (see §7): e.g. `attack`, `movement`, `positioning`, `spell`. A skill may have several (Trampling Advance: attack + movement). |
| **cost** | See **Cost block** below (not only a bare integer) |
| **uses_per_combat** | Max uses this fight (`-1` = unlimited) |
| **turn_flags** | Optional: `ENDS_TURN`, `DELAY_TURNS` (defer until needed) |
| **modules** | Base skill steps |
| **upgraded_modules** | Full upgraded profile (separate list; may diverge a lot from base) |
| **upgrade_description** | Player-facing [+] text |
| **presentation_key** | Opaque key for VFX/SFX bank |
| **presentation_anim** | Override: `AUTO` (default — derive from §7 rules) or forced `ATTACK` / `SPELL` / `WALK` / `RUN` / `SUPER_RUN` / `NONE` |
| **tooltip / keyword line** | Derived for UI from modules when possible |
| **notes (editor only)** | Designer comments; ignored by sim |

### Cost block (header)

Same structure for every skill — fill the fields the skill needs:

| Field | Options / meaning |
|-------|-------------------|
| **primary_resource** | `AP`, `MP`, or `HP` (Bible flat HP spend) |
| **primary_value** | Non-negative integer |
| **cost_modifier** | Optional: `NONE`, `ZERO_IF_ADJACENT_ENEMIES_GTE_N` (Adrenaline Surge) |
| **secondary_cost** | Optional second pay (e.g. AP skill that also spends HP) — same shape |

**Coupling (editor enforces):**  
- `planner_group = PRE_MOVE` → primary cost resource **MP** (not AP).  
- `planner_group = ACTION` → primary cost resource **AP** (HP may be primary or secondary for self-spend skills).  

Examples: basic attack → AP 0; Swap → MP 1; Blood Boil → AP 1 + HP 5 (or HP primary if authored that way); Adrenaline Surge → AP 1 with `ZERO_IF_ADJACENT_ENEMIES_GTE_2`.  
`ALL_REMAINING` MP — **not in current movesets**; defer.

### Planner group → timeline

| planner_group | Timeline | Consumes Action slot? | Typical cost |
|---------------|----------|------------------------|--------------|
| `PRE_MOVE` | Pre-Move | No | MP — **basic positioning** (Swap, Push Through, …) |
| `ACTION` | Action (+ optional Post-Move modules) | Yes | AP (0 for basic attack) |

**Tags ≠ planner group.**  
- Swap: `planner_group = PRE_MOVE`, tags `{positioning}` (and maybe `movement`).  
- Trampling Advance: `planner_group = ACTION`, tags `{attack, movement}`.  
- Shield Bash: `planner_group = ACTION`, tags `{attack}`.

**Module phase** (`ON_PRE` / `ON_ACTION` / `ON_POST`) is set per module **inside** an ACTION skill when the skill walks then strikes then canto-moves. That does not change `planner_group` (the card still sits in Action).

### Cost rules

- Cost is charged **once** when the skill is committed/used (header), not per module.
- An ACTION skill may include move modules; that does **not** add a second AP cost unless the header cost block says so.
- Basic positioning cards (`planner_group = PRE_MOVE` + MP) never consume the Action slot.
- **Universal walk MP** still obeys Bible “pre **or** post, not split.” Skill MOVE modules are skill-owned steps, not a second split of that universal pool.

### Structure vs vocabulary

The **structure** (header → modules → keywords → layers → gates) is fixed.  
**Dropdown / option lists** (effects, conditions, filters, cost modifiers) grow as the Bible needs them — same fields, more choices. Filling gaps means adding options, not inventing a new architecture. Landing is a destination `EffectType`.

### Typed authoring vs compiled effect payloads

Factories and the class editor author behavior through typed `AbilityModule` / `AbilityLayer`
fields. `AbilityModuleBridge` may compile those fields into `EffectData.modifiers` because
the shared `AbilitySystem` and simulator consume one normalized effect payload at runtime.
That dictionary is a compiled execution boundary, not an authoring escape hatch: new
skills must add a typed owner and bridge mapping, never write an unowned modifier key.

---

## 2. Module (one step)

Modules run in **order**. Default: each module is a **new aim**. Optional **aim binding** can reuse or auto-pick targets (see §2.5).

### 2.1 Execution phase

When this step runs relative to the turn columns:

| Phase | Typical use |
|-------|-------------|
| `ON_PRE` | Skill-owned walk/dash before the main hit (**not** the same as header `planner_group = PRE_MOVE`) |
| `ON_ACTION` | Main strike / buff / primary effect |
| `ON_POST` | Canto-like move after the action (including “if kill, move again”) |

Default: if omitted → `ON_ACTION` (or infer: gated post-move → `ON_POST`). Prefer **explicit** phase only on multi-step ACTION skills.  
Naming note: header **`planner_group`** = which timeline column the **card** uses; module **phase** = when that step runs inside the skill.

### 2.2 Primary effect (families)

What this module *is*. One `EffectType` field. Families are **owner-locked** in [`docs/design/EXTRA_RULES_TO_MODULES_PLAN.md`](EXTRA_RULES_TO_MODULES_PLAN.md). Skill verb comes from `class_abilities.txt`. Do not split Movement (Self) into Walk vs Jump vs Teleport.

**Add rule:** new verb → new **type** in a family. Rider → field / layer / keyword. New family only if nothing here fits.

| Family | Opening verb | Types now | Not a new primary |
|--------|--------------|-----------|-------------------|
| **Attack** | Hurt (`ATK` / `MAG ATK`) | DAMAGE, DAMAGE_SELF, EXPLODE, RANGED_EXPLODE | Bounce, unmitigated, %HP, ignore-resist = fields |
| **Heal** | Restore HP | HEAL | Revive % = field. On-kill HEAL = layer |
| **Shield** | Grant over-HP | ARMOR_UP | Scrap / missing-HP shield = fields / layers |
| **Status** | Apply or strip a named condition | ADD_STATUS, ADD_STATUS_SELF, REMOVE_STATUS, CLEANSE, PURGE | LINK / WITHER / BLOODLUST / MANA_SHIELD / MARK = StatusType |
| **Movement (Self)** | You change tiles | MOVE / JUMP / TELEPORT dests, DASH, MOVE_INTO_AND_PUSH | L-path, vault-only, GHOST, facing, pull-yourself-to-wall = fields or dest types here |
| **Forced Movement** | They are displaced by your punch | PUSH, PULL, THROW_BEHIND | Push/pull are examples. Throw/Suplex/drag-the-target and similar belong here. **Legal on Action** (enemies act after player execution). |
| **Move someone** | You put a body on a tile (usually an ally) | SWAP, PAIRED_MOVE | Pre-Move ally swaps include Pullback, Usher, Knight Swap, Airlift, Meat Shield, and Shadow Swap. Enemy SWAP on Action is legal. Glorious Charge uses the Movement (Self) DASH family instead. |
| **Hazard** | The tile keeps doing something | CREATE_HAZARD, CHANGE_TERRAIN, DESTROY_OBSTACLE | Smoke, caltrops, mines = knobs |
| **Summon** | You make a unit or object | SPAWN | HP%, turret ATK, overclock = knobs |
| **Stance** | You set yourself up this turn | ADD_STATUS_SELF / arm-next | Phalanx, Feint, Mana Shield, Brace |
| **Resource** | Grant/refund AP, Scrap, later currencies | GRANT_AP, GRANT_SCRAP, REFUND_AP_ON_CC | On-kill AP = layer |
| **Convert off** | Not a family | TRAMPLE, BULLDOZE, PUSH_STAGGER_*, PULL_VULNERABLE_*, PUSH_CHAIN_* | Keywords / layers |

Keywords (TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO) are a **separate module field** (§6), not a primary family.

**Player choice (OR)** — still inside the module, not a new system:  
`resolution_choice`: `NONE` \| `PICK_ONE_OF_EFFECTS` (e.g. Grappling Hook: **Movement (Self)** pull-yourself **or** **Forced Movement** pull-them). Planner shows the choice; commit stores which branch was picked.

### 2.3 Min / max range + LOS

- Inclusive Manhattan range from the **range origin** (see §3).
- Examples: `0–0` (self), `1–1` (melee), `1–3`, `2–2`, `0–unlimited` (**GLOBAL**).
- **requires_los**: default on; off when GLOBAL or Bible says otherwise.
- Editor greys out illegal bands. **MOVE: min ≥ 1** (MOVE 0 disabled — does nothing). Self skills use `0–0`, not MOVE.

**Important:** RANGE is **per module**. Move 2 and attack range 4 are different modules — never one overloaded field.

### 2.4 Targeting shape + size

| Shape | Notes |
|-------|--------|
| SINGLE | One tile / one unit |
| AOE square (e.g. 3×3) | Size = side length |
| AOE cross / diamond | Size = radius |
| ARC | Sweep; size rules per Bible |
| CONE / LINE (skewer) | Directional; size = length |
| HAZARD_LINE | Suppressing Fire / Spear Wall style lines |

Editor shows only shapes valid for the primary effect (MOVE → typically SINGLE destination).

### 2.5 Aim binding + targeting mode

**Aim binding** (engine, not author-facing):

| Binding | Meaning |
|---------|---------|
| `NEW_AIM` (default) | This module owns its own player aim |
| `SAME_AS_MODULE_N` | Internal only — gated recast (Violent Collision). Same-target extras are **layers**, not a second module. |
| `RULE_PICK` | Auto-pick by rule + params when a current skill needs it |

Authors never pick “same as module N”. If two effects share one aim, the second is a **layer** on the first module. A new player click is a new module with `NEW_AIM`. **New module demands new targeting.** No new click → add a layer (or a keyword), not a module.

**Tile mode**

- Player aims a **tile** (empty or occupied per dest EffectType / checkboxes).
- Invokes **two-phase awaiting** when destination confirm is required.
- Checkboxes: **affect allies on tiles?** / **affect enemies on tiles?**
- Optional: **allow occupied destination** (Push Through).

**Unit mode**

- Player aims a **unit** only; empty tile = invalid.
- Checkboxes: **ally valid?** / **enemy valid?** / **self valid?** as applicable.

**Self vs skip caster (not the same checkbox)**

| Checkbox | Job |
|----------|-----|
| **Self** | May you **click yourself** as the aim? Blood Boil, Second Wind, self-buffs. |
| **Skip caster in blast** (`EXCLUDE_CASTER`) | When the **shape resolves** (aura, diamond, ally AOE), do **not apply** the punch to you even if your tile is inside it. Defensive Formation. You often click a tile or an ally, not yourself — unchecking Self does not skip you in the blast. |

Do not put Skip caster on the same “who can I click” row as Self/Ally/Enemy.

**Target filters** (validity checklist on the same module — **Condition** category + sub-option, not a long niche list):

| Condition | Sub-option | Bible use |
|-----------|------------|-----------|
| HP | Below % of max · Below caster HP | Executioner’s Blade, Hex (below 100%), Intimidate |
| Status | Any debuff · Specific status (and optional OR) · Not acted | Terrify, Savage Bite, Amnesia Dust |
| Stat | Target CON ≤ caster STR | Feral Drag |
| Occupant | Ally construct · Adjacent construct · Item or corpse · Ally corpse · Dragged enemy | Detonate / Overdrive, Recall, Fetch, Ancestral Spirit, Maul |

Add **sub-options** when a new Bible click-lock appears. Do **not** add a new top-level Condition for one skill.

### 2.6 Effect values + duration + scaling

- Magnitude(s) for the primary effect.
- **Duration** when status / timed buff.
- **Scaling**: STR / MAG / NONE / WPN / caster DEF / Max HP % / missing HP / per-tile-moved / per-target-hit.
- Optional **self_also** for Headbutt-style self + target.

### 2.7 Module gate (does this module run?)

Checked at **this module’s resolution time**, using the board **after earlier modules** of this skill.

| Gate examples | Meaning |
|---------------|---------|
| Always | Always runs (if skill itself was legal) |
| If killed enemy | Enemy reached 0 HP from earlier steps of this skill |
| If damage dealt | Earlier step dealt damage |
| If collided | Motion collided (Violent Collision → second MOVE) |
| If adjacent to enemy / ally | Actor adjacency at check time |
| If isolated | No allies adjacent |
| If no move this turn yet | Actor has not spent movement before this skill |
| … | **Add rows here as Bible needs — same gate field** |

**Planning (gated modules — normative):**

1. Player may aim every module that needs an aim, including gated follow-ups.  
2. Preview runs the same gate logic as sim.  
3. If the gate **would pass**, the follow-up aim is **required** and shown as active intent.  
4. If the gate **would fail**, the follow-up aim is inactive (not part of commit intent).  
5. On resolve: gate fails → module skipped; gate passes with missing/invalid aim → **fail loud** (do not invent a destination).

This is the Violent Collision rule (DASH + BULLDOZE, then MOVE if collided).

**Typed metadata queries are not execution.** `AbilitySystem.ability_has_effect()`
is an ungated presentation/metadata scan of the active typed module profile. It may
report an effect on a gated follow-up so UI and authoring checks can describe the
full profile, but it never activates that module, changes its aim, or bypasses its
gate. Execution remains owned by the ordered module runtime and its gate checks.

---

## 3. Range origin

**Default:** RANGE is measured from the **actor’s current position after all earlier modules** of this skill have applied (so after a move module, the next module’s range is from the **new** tile).

**Optional override (per module):**

| Origin | Use |
|--------|-----|
| Actor (default) | Normal skills |
| Last targeted tile | Effects measured from the tile aimed by a previous module |
| Last targeted unit’s tile | Spotter-style / ally-origin skills |

If unspecified → Actor default.

---

## 4. Destination vs path (movement modules)

For MOVE / DASH / charge-like modules:

| Concept | What it is |
|---------|------------|
| **Destination** | Where the actor **stops** — what min/max range + tile aim describe |
| **Path** | Tiles **passed through** on the way |

Layers with conditions like **when moved through enemy** or keywords like **TRAMPLE** apply to **path** (and/or collision), not only the end tile.

Non-movement modules ignore this section.

---

## 5. Layers (same-target extras)

Layers belong to **one module**. They use that module’s targets (including path targets when the layer condition says so). They do **not** get their own player click.

Each layer has:

| Field | Purpose |
|-------|---------|
| **Effect** | Damage, push, pull, status, heal, … |
| **Values / duration** | As applicable |
| **Activation condition** | When the layer fires |

If a **single effect on a single target** is complicated, use **multiple layers** on that module (DAMAGE + PUSH + STAGGER-if-collision, or ATK + ON_KILL GRANT_AP). That is still one click.

**Multi-hit:** Prefer a damage layer (or hit_count on the primary damage) on the **same** module — not a second module — when targets are the same.

**Layer condition examples** (same idea as module gates — grow the list):

| Condition | Typical use |
|-----------|-------------|
| At resolution | Always with the module’s hit |
| When damage dealt | Push only if the hit connected |
| When moved through enemy | Path hit (trample push, etc.) |
| On collision | Bowling / bulldoze end or ram |
| On chain collision | Bowling [+]: rammed enemy hits another |
| On kill | Bonus on that target / spawn decoy |
| On land | After jump/teleport arrival |
| Per tile moved | Trampling [+] SHIELD per tile |
| Per target hit | Crimson Whirlwind [+] HEAL per hit |
| If already adjacent at cast | Shield Slam bonus ATK |
| If from behind / not acted yet / has status | Facing & state checks |

---

## 6. Keywords as bundled layers

Some Bible terms are **packages** so authors do not assemble five checkboxes every time.

| Keyword | Intent (author-facing) | Expands to (engine) |
|---------|------------------------|---------------------|
| **TRAMPLE** | Passthrough + attack-on-move-through | Pass-through flag + ON_PASS damage (amount on keyword) |
| **BULLDOZE** | Passthrough + collision package | Pass-through + ON_COLLISION damage/push (amounts on keyword) |
| **GHOST** (during move) | Pass terrain/units per Bible | Movement flag for that module |
| **PIERCE** | Ignore DEF/MAG on this hit | Damage flag |
| **CANTO** (full refund) | Unit/passive full MOV refund after action | Status/passive; skill-granted partial canto = `ON_POST` MOVE module with fixed range |

Do **not** split TRAMPLE/BULLDOZE into passthrough + damage micro-checkboxes. Extra Bible bits beyond the keyword (e.g. Trampling’s PUSH, Bowling [+] chain) are **separate layers**, not a dismantled keyword.

---

## 7. Presentation (animation / VFX / SFX)

Simulation stays headless. Presentation reads events + ability presentation fields.

| Level | What to author |
|-------|----------------|
| **Skill header** | `presentation_key`, `presentation_anim` (`AUTO` or override) |
| **Tags** | Drive AUTO when anim is AUTO |

No gameplay legality may depend on animation length or art existing.

### 7.1 AUTO rules (tags + modules)

| Priority | Condition (modules / tags / keywords) | Anim |
|----------|----------------------------------------|------|
| 0 | `presentation_anim` override ≠ AUTO | That override |
| 1 | Primary **DASH** | `SUPER_RUN` |
| 2 | Keyword/effect **BULLDOZE** | `RUN` |
| 3 | **MOVE** + keyword **TRAMPLE** (and not DASH) | `RUN` (Trampling / charge-walk package) |
| 4 | **MOVE** without TRAMPLE/BULLDOZE/DASH | `WALK` (includes move-then-strike skills’ motion event) |
| 5 | No motion package; tag `attack` **or** damage/push/pull/explode; not basic-positioning-only | `ATTACK` |
| 6 | Else (buffs, heals, pure utility) | `SPELL` |
| 7 | Basic positioning (`planner_group = PRE_MOVE`) with no override | `WALK` |

**Trampling Advance:** MOVE + TRAMPLE → priority **3** → `RUN`.  
**Example A (move then strike):** MOVE without TRAMPLE → priority **4** → `WALK` for the motion-facing event; multi-module sequencing may still play ATTACK on the strike module later (§7.3).

### 7.2 Sequencing

Multi-module ACTION skills may play move anim for the move module, then attack/cast for the strike module, in module order. If sequencing is not ready, one header anim for the whole skill is acceptable.

---

## 8. Upgrades

Two **full** module lists on the same skill id:

- **`modules`** — base  
- **`upgraded_modules`** — upgraded profile, authored separately (may change range, shapes, keywords, whole steps — not required to start from a clone of base)

Also keep `upgrade_description` for the player-facing [+] line.  
Scalar `upgraded_range_tiles`-style fields go away once both profiles are modular.

---

## 9. Planning, preview, and commit

| Concern | Rule |
|---------|------|
| Aim order | Modules that need player aim are selected in module order |
| Tile modules | Two-phase awaiting when destination confirm is required |
| Unit modules | Invalid on empty tile |
| Gated modules | Preview sim decides visibility/legality of that aim |
| Commit | Ratifies the full multi-module intent already shown — no silent rewrite |

Compound skills (move + attack + conditional post-move) still appear as **one** skill card; planner may show multiple ghosts/paths that belong to that one commit.  
**Undo / step cancel** is planning UX — not specified here.

---

## 10. Worked examples

### Example A — Move, hit, canto-if-kill

```
Header:
  planner_group: ACTION
  tags: attack, movement
  cost: 1 AP
  presentation_anim: AUTO

Module 1 — phase ON_PRE
  Effect: MOVE
  Range: 1–2 (min 1)
  Shape: SINGLE, mode: TILE
  Gate: Always

Module 2 — phase ON_ACTION
  Effect: ATK damage 2
  Range: 1–1
  Shape: SINGLE, mode: UNIT, enemy only
  Gate: Always
  Layer: PUSH 2 — when damage dealt

Module 3 — phase ON_POST
  Effect: MOVE
  Range: 1–2 (min 1)
  Shape: SINGLE, mode: TILE
  Gate: If killed enemy
```

### Example B — AoE then conditional heal (two aims)

```
Header:
  planner_group: ACTION
  tags: attack
  cost: 1 AP

Module 1 — ON_ACTION
  Effect: ATK damage 2
  Range: 0–4
  Shape: AOE 3×3, mode: TILE
  Affect enemies on tiles: yes
  Gate: Always
  Layer: Apply STAGGER — at resolution

Module 2 — ON_ACTION
  Effect: HEAL 2
  Range: 0–4
  Shape: SINGLE, mode: UNIT, ally (and/or self)
  Gate: If killed enemy (from earlier module of this skill)
```

Each module has its **own** aim → this is not “two hits on the same AoE targets”; the heal is a second targeting pass.

### Example C — Trampling Advance

```
Header:
  planner_group: ACTION
  tags: attack, movement
  cost: 1 AP
  presentation_anim: AUTO  → RUN (MOVE + TRAMPLE)

Module 1 — ON_ACTION
  Effect: MOVE
  Range: max 2 (min 1)
  Shape: SINGLE, mode: TILE
  Keywords: TRAMPLE 2
  Layer: PUSH 1 — when moved through enemy
  Gate: Always
```

Destination = end tile. Path ATK from **TRAMPLE**; push as its own layer.  
**Migration note:** today’s factory also sets `movement_point_cost = 2` while keeping AP — target authorship is **AP only** + `planner_group = ACTION` (Bible class skill, not basic positioning).

### Example D — Bowling Charge

```
Header:
  planner_group: ACTION
  tags: attack, movement
  cost: 1 AP
  presentation_anim: AUTO  → SUPER_RUN (DASH)

Module 1 — ON_ACTION
  Effect: DASH
  Range: 1–3 (min 1)
  Shape: dash-line / TILE
  Keywords: BULLDOZE (ATK 3, PUSH 2 per Bible)
  Gate: Always
```

### Example E — Swap (basic positioning)

```
Header:
  planner_group: PRE_MOVE
  tags: positioning
  cost: 1 MP
  presentation_anim: AUTO  → WALK

Module 1 — ON_ACTION
  Effect: SWAP
  Range: 1–1
  Shape: SINGLE, mode: UNIT, ally only
  Gate: Always
```

### Example F — Violent Collision (gated follow-up)

```
Header:
  planner_group: ACTION
  tags: attack, movement
  cost: 1 AP
  presentation_anim: AUTO  → SUPER_RUN (DASH)

Module 1 — ON_ACTION
  Effect: DASH
  Range: 1–3 (min 1)
  Shape: dash-line
  Keywords: BULLDOZE (amounts per factory)
  Gate: Always

Module 2 — ON_ACTION
  Effect: MOVE
  Range: 1–2 (min 1)
  Shape: SINGLE, mode: TILE
  Gate: If collided (from module 1)
```

Planning uses §2.7 gated-aim rules. Upgrade layer: STAGGER on collision.

---

## 11. Validation rules (editor + runtime)

Fail loud; do not silently “fix up” intent. **Grey out** illegal combos in the class library (don’t offer MOVE 0, ARC on SWAP, AP on PRE_MOVE, etc.).

1. Header `planner_group` + cost present; cost resource matches planner_group (§1).  
2. Tags: at least one recommended; unknown tag ids rejected.  
3. At least one module in `modules`; if upgrade exists, `upgraded_modules` non-empty and valid.  
4. Each module: effect + legal range + legal shape + legal tile/unit mode for that effect.  
5. MOVE/DASH: min range ≥ 1; destination rules match the dest **EffectType** (MOVE / JUMP / TELEPORT / DASH / MOVE_INTO_AND_PUSH / …).  
6. Keywords only on modules that support them (path packages on Movement (Self)); known keyword ids only.  
7. Unit mode: ≥1 of self/ally/enemy when required.  
8. Gate / layer condition ids known.  
9. `presentation_anim` is a known enum value.

---





## 12. Outside this system (on purpose)

These are **not** AbilityData module problems — they live elsewhere:

| Item | Where it belongs |
|------|------------------|
| Passives | Passive / trait system |
| Enemy-turn reactions / ZoC interrupts | Reaction / status triggers (a skill may **ARM_REACTION**, but the interrupt isn’t a planned module) |
| Mimic / cast another unit’s skill | Ability-as-value (rare; approve if ever needed) |

Everything else called out in Bible skill lines (OR choice, vault dests, HP cost, filters, rule-pick targets, delay/ends turn, next-attack grants, ally-origin range, etc.) is expressed by **adding options to the fields above**.

---

## 13. Authoring checklist

Use this document to author a skill; use the implementation and conversion plans for migration work.

1. Header: `planner_group`, tags, cost, uses, presentation, and base/upgraded profiles.
2. Each module: ordered phase, primary effect, range, shape, targeting, keywords, layers, and gate.
3. Use a new module only for a new player click; use layers for extra effects on the same targets.
4. Use `TRAMPLE` / `BULLDOZE` for path packages and explicit layers for extra collision or landing effects.
5. Keep preview, commit, and simulation on the same ordered module intent.
6. Reject illegal combinations loudly; do not silently rewrite a player’s aim.
7. Add a field or option to the shared schema when the skill bible needs new vocabulary; do not add a skill-specific branch.

---

## 14. Owner quick reference

Start at **§0**. Author: `planner_group` + tags + cost → `modules` / `upgraded_modules` → per module effect, range, shape, tile/unit, keywords, layers, gate → AUTO anim unless override.

- Column ≠ tags; basic positioning ≠ “has MOVE”  
- MOVE min ≥ 1; grey out useless options  
- **New click = new module.** Same click extras = layers (stack them). No fake second module.  
- **Don’t relocate an ally on Action.** Enemy displacement (Forced Movement, enemy swap, drag) is legal — they act after your execution. Reworked forms: Pre-Move Meat Shield/Shadow Swap swaps and enemy-focused Action Glorious Charge.
- After move, range from new tile  
- Path hits = TRAMPLE/BULLDOZE keywords 

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-16 | Trimmed migration inventories and audit history out of the authoring bible. Legacy cleanup and per-skill conversion remain in the implementation/conversion plans. |
| 2026-08-16 | Kept the normative module contract: header, ordered modules, primary families, range, targeting, gates, layers, keywords, upgrades, preview/commit, examples, and validation. |
| 2026-08-16 | Clarified ally Action queue conflicts versus legal enemy displacement during the same player execution. |
