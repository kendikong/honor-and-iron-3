# AbilityData — Modular Skill Design Bible

**Status:** `READY_FOR_REFACTOR` — owner-locked design authority for the AbilityData refactor (start at §0)  
**Audience:** Project owner (readable) + implementers (refactor checklist)  
**Authority chain:** `class_abilities.txt` (Master Bible keywords & economy) → **this doc** (AbilityData shape) → `AbilitySystem` / planning / sim (interpretation)  
**Non-authority:** Current flat `AbilityData` fields are **legacy** until refactor; when they conflict with this doc, **this doc wins** for the target design.

### How to read this doc

| If you need… | Read |
|--------------|------|
| Owner one-pager | **§0** + locked table below |
| Authoring a skill | §0 → §1 → §2 → §6 → §10 examples |
| Anim / tags | §7 |
| Code migration | §12 → §14 |
| History of audits | §16–§19 (not normative) |

**Conflict precedence (highest wins):** Locked table → **§0–§11** (normative) → Extra Rules conversion families in `docs/design/EXTRA_RULES_TO_MODULES_PLAN.md` (must match §2.2) → §12 migration notes → §14 checklist → §16+ audits. Chat summaries are **not** authority. After any summarization, reread `class_abilities.txt` and this doc.

### Owner decisions (locked)

| Topic | Decision |
|-------|----------|
| MOVE 0 | Illegal; editor greys out options that do nothing |
| Undo | **Not** part of AbilityData — planning/timeline only |
| Trampling packaging | MOVE + **TRAMPLE** keyword + separate **PUSH** layer |
| Upgrades | **Separate** `modules` and `upgraded_modules` (full profiles; upgraded may diverge a lot) |
| Refactor scope | All **current** movesets in the project (factories/class library/readers) — not uncoded Bible classes |
| Planner column | Rename economy `kind` → **`planner_group`**: `PRE_MOVE` or `ACTION` (post-move steps = `ON_POST` modules inside an ACTION skill) |
| Classification / anim | **Tags** (e.g. attack, movement) — not overloaded “movement skill” naming |
| Basic positioning | Today’s MP Swap / Push Through style skills → **basic positioning** (`planner_group = PRE_MOVE`), distinct from “has a MOVE effect” |

---

## 0. Normative summary (v1 target)

One skill card =

1. **Header:** `planner_group` + **tags** + **cost once** + presentation + `modules` / `upgraded_modules`  
2. **Each module:** primary effect + range + shape + tile/unit flags + optional **keywords** + **layers** + **gate**  
3. **Same target extras** → layers · **New player aim** → new module · **Path hits** → TRAMPLE/BULLDOZE keywords (not micro-checkboxes)

| `planner_group` | Column | Cost | Action slot |
|-----------------|--------|------|-------------|
| `PRE_MOVE` | Pre-Move | **MP** | No — basic positioning |
| `ACTION` | Action | **AP** (0 OK) | Yes — may include `ON_PRE` / `ON_POST` modules |

**Canonical tags (v1):** `attack` · `movement` · `positioning` · `spell` · `heal` (optional). Multi-tag OK.

**AUTO anim (target):** DASH→`SUPER_RUN` · BULLDOZE→`RUN` · MOVE+TRAMPLE→`RUN` · other MOVE→`WALK` · else attack/spell/positioning rules in §7.2.

**Must migrate now (current code):** Knight + Bruiser abilities, Swap / Push Through positioning, universals they use, class-library + sim/planning readers. Includes **Violent Collision** (gated second move).

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
| **Module** | One step: do an effect, with its own targeting, as if aiming a fresh skill |
| **Keyword** | Bible package on a module (passthrough+hit, etc.) — prefer over micro-layers |
| **Layer** | Extra effect on the **same targets** as its parent module (multi-hit, push-if-damage, …) |
| **Gate** | Condition that decides if this **module** activates at all |

**Double hit vs two targets**

| Intent | Authoring |
|--------|-----------|
| Two hits on the **same** target(s) | One module + a damage (or effect) **layer** |
| One hit each on **two different** targets | **Two modules**, each with its own aim |

---

## Global rules this design must respect

From Master Bible / project rules (do not bypass silently):

- **Timeline columns:** Pre-Move → Action → Post-Move (no hidden 4th column).
- **One Action** per unit per turn for class skills (unless Bible says otherwise).
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
**Dropdown / option lists** (effects, motion modes, conditions, filters, cost modifiers) grow as the Bible needs them — same fields, more choices. Filling gaps means adding options, not inventing a new architecture.

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
| **Forced Movement** | They slide | PUSH, PULL | Pull-to-center, push-items, collision STAGGER = fields / layers |
| **Move someone** | You put a body on a tile | SWAP, PAIRED_MOVE, THROW_BEHIND | Usher, slide-opposite, Airlift/Kidnap, Feral Drag = types here |
| **Hazard** | The tile keeps doing something | CREATE_HAZARD, CHANGE_TERRAIN, DESTROY_OBSTACLE | Smoke, caltrops, mines = knobs |
| **Summon** | You make a unit or object | SPAWN | HP%, turret ATK, overclock = knobs |
| **Stance** | You set yourself up this turn | ADD_STATUS_SELF / arm-next | Phalanx, Feint, Mana Shield, Brace |
| **Resource** | Grant/refund AP, Scrap, later currencies | GRANT_AP, GRANT_SCRAP, REFUND_AP_ON_CC | On-kill AP = layer |
| **Convert off** | Not a family | TRAMPLE, BULLDOZE, PUSH_STAGGER_*, PULL_VULNERABLE_*, PUSH_CHAIN_* | Keywords / layers |

Keywords (TRAMPLE, BULLDOZE, GHOST, PIERCE, CANTO) are a **separate module field** (§6), not a primary family.

**DELETE Motion Mode.** Landing is the dest type inside **Movement (Self)** or **Move someone**. Do not add modes. See conversion plan ER-3.

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

Authors never pick “same as module N”. If two effects share one aim, the second is a **layer** on the first module. A new player click is a new module with `NEW_AIM`.

**Tile mode**

- Player aims a **tile** (empty or occupied per motion mode / checkboxes).
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

Do not put Skip caster on the same “who can I click” row as Self/Ally/Enemy. Extra Rule `EXCLUDE_CASTER` converts to this blast checkbox, then is deleted.

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

Layers belong to **one module**. They use that module’s targets (including path targets when the layer condition says so).

Each layer has:

| Field | Purpose |
|-------|---------|
| **Effect** | Damage, push, pull, status, heal, … |
| **Values / duration** | As applicable |
| **Activation condition** | When the layer fires |

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

**Multi-hit:** Prefer a damage layer (or hit_count on the primary damage) on the **same** module — not a second module — when targets are the same.

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

### 7.1 How anim is assigned today (source of truth for AUTO)

From `AbilitySystem.execute` + `ability_uses_attack_animation` / spell helpers + factory defaults:

**A. Explicit override** — if `presentation_anim != AUTO`, use it (e.g. Trampling Advance factory forces `RUN`; positioning helpers force `WALK`).

**B. AUTO on `ABILITY_USED` event** (motion priority, current code order):

1. Effect **DASH** → `SUPER_RUN`  
2. Else effect **BULLDOZE** → `RUN`  
3. Else effect **MOVE** → `WALK`  
4. Else leave `AUTO` (presentation often treats unset as walk/idle path)

**C. Attack vs spellcast helpers** (director / drag preview — parallel to B):

- **Attack anim** if: not forced walk/run/spell/none; not positioning/`PRE_MOVE` kind; not self-only; and effects include DAMAGE / PUSH / PULL / EXPLODE / RANGED_EXPLODE.  
- **Spellcast** if: not a movement-effect skill, not positioning kind, and not attack (buffs/utility often land here).  
- Director: `WALK`/`RUN` on ability-used play with the move; `ATTACK` / `SPELL` / `SUPER_RUN` go down the attack/cast presentation path.

### 7.2 AUTO rules going forward (tags + modules)

**§7.1 = live code today.** **§7.2 = target** after refactor (not identical — trampling must AUTO to `RUN` without a factory override).

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

### 7.3 Sequencing

Multi-module ACTION skills may play move anim for the move module, then attack/cast for the strike module, in module order. v1 may keep one header anim for the whole skill if sequencing is not ready — same as today’s single `presentation_anim` on the ability.

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
5. MOVE/DASH: min range ≥ 1; destination rules match motion mode.  
6. Keywords only on modules that support them (motion); known keyword ids only.  
7. Unit mode: ≥1 of self/ally/enemy when required.  
8. Gate / layer condition ids known.  
9. `presentation_anim` is a known enum value.

---

## 12. Migration from current code (reuse / restructure / add)

Source of truth for “what exists today”: `data/definitions/ability_data.gd`, `effect_data.gd`, `core/game_enums.gd` (`EffectType`, `TargetShape`, `AbilityKind`, `TargetingFlags`, …), plus factory/`modifiers` usage in `AbilitySystem` / Bruiser–Knight factories.

For every category: **Reuse** = keep as-is or thin rename · **Restructure** = same idea, new home in header/module/layer · **Add** = missing option the modular design needs.

### 12.1 Skill header / identity

| Item | Today | Verdict |
|------|-------|---------|
| `id`, `display_name` | `AbilityData` | **Reuse** |
| `uses_per_combat` | `AbilityData` | **Reuse** |
| `upgrade_description` | `AbilityData` | **Reuse** |
| `presentation_key`, `presentation_anim` | `AbilityData` + `PresentationAnim` | **Reuse** on header; optional per-module override **Add** |
| `is_movement_skill` | Legacy mirror of `kind` | **Restructure** → drop; use `planner_group == PRE_MOVE` |
| `scaling_stat` (ability-level) | `AbilityData` | **Restructure** → live on damage/heal **module or layer** (effects already have `scaling_stat`) |
| Modular `modules[]` / `upgraded_modules[]` | Missing (flat `effects[]` / `upgraded_effects[]`) | **Add** two full module lists |

### 12.2 Planner group / tags (was AbilityKind)

| Item | Today | Verdict |
|------|-------|---------|
| `AbilityKind.CLASS_SKILL` | Exists | **Restructure** → `planner_group = ACTION` |
| `AbilityKind.MOVEMENT_SKILL` | “Movement skill” name | **Restructure** → `planner_group = PRE_MOVE` + tag `positioning` (**basic positioning**) |
| `AbilityKind.UNIVERSAL_RUN` / `WAIT` | Exists | **Reuse** as system actions (not class-library modular cards) |
| Basic attack | CLASS_SKILL + AP 0 | **Reuse** — `planner_group = ACTION`, AP 0; tag `attack` |
| Tags (`attack`, `movement`, …) | Implicit via effects/kind heuristics | **Add** explicit tag set on header |
| Module `execution_phase` | Not on abilities | **Add** when multi-step ACTION skills need it |
| `PlanningCommitFlow` / awaiting | Derived from TILE/move heuristics | **Reuse** machinery; feed module tile/motion |

### 12.3 Cost block

| Item | Today | Verdict |
|------|-------|---------|
| `action_point_cost` | `AbilityData` | **Reuse** inside cost block as AP value |
| `movement_point_cost` | `AbilityData` | **Reuse** inside cost block as MP value |
| HP spend | `EffectType.DAMAGE_SELF` as first effect (Blood Boil, Adrenaline Surge) | **Restructure** → header **secondary/primary HP cost** (keep DAMAGE_SELF only when the hit is part of combat fantasy, e.g. Headbutt) |
| `zero_ap_adjacent_enemies` | `EffectData.modifiers` | **Restructure** → cost_modifier `ZERO_IF_ADJACENT_ENEMIES_GTE_N` |
| `ALL_REMAINING` MP | Missing | **Defer** until a current moveset needs it |
| Dual cost (AP + HP) | Simulated by effects | **Add** when migrating skills that spend HP (Adrenaline Surge / Blood Boil) — not a global UI requirement on day one |

### 12.4 Range

| Item | Today | Verdict |
|------|-------|---------|
| `range_tiles` (max only) | Single int; also fallback walk length | **Restructure** → per-module `min_range` + `max_range`; **stop** MOVE fallback to this field |
| `upgraded_range_tiles` | Scalar override | **Restructure** → upgraded module profile |
| GLOBAL / ignore LOS | Heuristic / planning checks | **Add** `requires_los` + `max_range` unlimited (GLOBAL) on module |
| Range origin | Always actor at cast (mostly) | **Add** origin enum (actor / last tile / last unit tile) |
| DASH length | `EffectType.DASH` `amount` **and/or** `range_tiles` | **Restructure** → motion module min/max (or amount = max) only |

### 12.5 Targeting (who / tile vs unit)

| Item | Today | Verdict |
|------|-------|---------|
| `TargetingFlags` SELF/ALLY/ENEMY/TILE/DASH_LINE | Bitmask + editor checkboxes | **Reuse** as unit/tile checkboxes + dash-line shape/mode |
| `TargetingMode` legacy enum | Synced mirror | **Restructure** → derive from flags + tile/unit mode; keep sync helpers during migration |
| `can_target_self` | Legacy mirror | **Reuse** via SELF flag |
| Tile awaiting two-phase | `PlanningCommitFlow.AWAITING_TARGET` | **Reuse** behavior; driven by module tile/motion |
| Aim binding NEW / SAME / RULE_PICK | Missing (always one aim) | **Add** NEW_AIM default; SAME/RULE_PICK only if a current skill needs them |
| Target filters (HP%, debuff, …) | Mostly missing or hard-coded | **Defer** unless a current moveset skill needs them |
| Affect allies/enemies on tiles | Partial via flags + shape gather | **Restructure** → explicit tile-occupant checkboxes on module |

### 12.6 Shape

| Item | Today | Verdict |
|------|-------|---------|
| `TargetShape` SINGLE, AOE_SQUARE, AOE_CROSS, ARC, CONE, LINE, AOE_DIAMOND | `GameEnums` + `target_shape` / `target_shape_size` | **Reuse** on module |
| `upgraded_target_shape(_size)` | Scalar overrides | **Restructure** → upgraded modules |
| HAZARD_LINE | Not in enum (special-cased elsewhere) | **Add** shape or CREATE_HAZARD utility with line params |

### 12.7 Primary effects (`EffectType` → module primary / layer)

Map each current `EffectType` into the modular model:

| `EffectType` today | Modular home | Verdict |
|--------------------|--------------|---------|
| `DAMAGE` | Module primary or layer | **Reuse** |
| `DAMAGE_SELF` | Layer `self_also` / self target **or** header HP cost | **Restructure** (split cost vs combat self-hit) |
| `HEAL` | Module / layer | **Reuse** |
| `ARMOR_UP` (shield-ish) | Module / layer SHIELD | **Reuse** (name toward SHIELD in UI) |
| `PUSH`, `PULL` | Layer or primary control | **Reuse** |
| `SWAP` | Motion/primary | **Reuse** |
| `DASH` | Motion primary + mode | **Reuse** type; length → range |
| `MOVE` | Motion primary | **Reuse**; walk steps → module range (not ability `range_tiles`) |
| `TELEPORT_CASTER` | Motion JUMP/TELEPORT | **Reuse** / rename to motion mode |
| `TRAMPLE`, `BULLDOZE` | Keyword layers on motion module | **Reuse** as keywords (already engine-backed) |
| `MOVE_INTO_AND_PUSH` | Motion mode `INTO_OCCUPIED_PUSH` / `TO_TARGET_UNIT` | **Restructure** from effect-type into **motion mode** |
| `THROW_BEHIND` | Control primary/layer | **Reuse** |
| `ADD_STATUS`, `ADD_STATUS_SELF`, `REMOVE_STATUS` | Layer / primary status | **Reuse** |
| `CLEANSE`, `PURGE` | Utility / status family | **Reuse** |
| `DESTROY_OBSTACLE` | Utility layer (path or tile) | **Reuse** |
| `CHANGE_TERRAIN` | Utility | **Reuse** |
| `SPAWN` | Utility (+ `spawn_unit_id`) | **Reuse** |
| `EXPLODE`, `RANGED_EXPLODE` | Damage + shape / on-land | **Restructure** toward DAMAGE + shape or ON_LAND layer |
| `REFUND_AP_ON_CC` | Layer condition + GRANT_AP | **Restructure** out of EffectType into layer gate |
| `PUSH_STAGGER_ON_COLLISION`, `PULL_VULNERABLE_ON_ADJACENT`, `PUSH_CHAIN_COLLISION` | Layer conditions on PUSH/PULL | **Restructure** — these are **conditions**, not primaries |

**Add** as first-class primaries/utilities (today missing or only modifiers):  
`GRANT_AP`, `GRANT_NEXT_ATTACK_MOD`, `ARM_REACTION`, `CREATE_HAZARD`, `PULL_SELF_TO_TARGET` / choice bundle, `MOVE_OTHER`, `PAIRED_MOVE`, hit_count on DAMAGE.

### 12.8 `EffectData` fields → layer / module values

| Field | Today | Verdict |
|-------|-------|---------|
| `type`, `amount` | Core | **Reuse** on module/layer |
| `status_type`, `status_duration` | Status effects | **Reuse** |
| `scaling_stat` | Per effect | **Reuse** on module/layer |
| `spawn_unit_id` | SPAWN | **Reuse** |
| `bonus_if_adjacent_at_cast` | DAMAGE-only export | **Restructure** → layer condition `IF_ALREADY_ADJACENT` + bonus amount |
| `def_debuff_before_damage` | DAMAGE-only export | **Restructure** → layer (temp DEF debuff before damage) |
| `modifiers` Dictionary | Catch-all string keys | **Restructure** → typed layer conditions / flags / cost modifiers (see §12.9); retire ad-hoc keys over time |

### 12.9 Known `modifiers` keys → typed slots

These already work in sim/factories; modular design should **absorb** them as named layer/gate/cost fields (not keep a free-form dict as the long-term API):

| Modifier key (today) | Becomes |
|----------------------|---------|
| `ghost_move` | Motion flag / GHOST keyword on MOVE module |
| `bulldoze`, `push` (on DASH/MOVE) | BULLDOZE keyword amounts |
| `violent_collision_recast` | Module gate `IF_COLLIDED` + second MOVE module |
| `object_collision_stagger`, `enemy_collision_stagger_both`, `stagger_on_collision` | Layer condition on PUSH/collision |
| `zero_ap_adjacent_enemies` | Header cost_modifier |
| `bonus_dmg_from_terrain`, `bonus_dmg_per_10_hp`, `bonus_dmg_pct_max_hp` | Layer/scaling rules on DAMAGE |
| `weapon_scaled` | Scaling = WPN (or bleed X) |
| `heal_per_target_hit` | Layer condition `PER_TARGET_HIT` + HEAL |
| `frenzy_on_kill_ap` | Layer `ON_KILL` + GRANT_AP |
| `next_attack_pierce` | Utility `GRANT_NEXT_ATTACK_MOD` |
| `buff_per_destroyed_object` | Layer after DESTROY_OBSTACLE |
| `intercept_grant_str` | Status/INTERCEPT layer params |
| `push_board_items`, `item_collision_damage` | Layer flags on PUSH AoE |
| `damage_adjacent_on_landing` | Layer `ON_LAND` (Monk landing strike) |
| `exclude_caster` | Targeting checkbox |
| `buff_on_push` | Layer on PUSH (Push Through [+]) |

**Add** any Bible need not in this table as a **new named condition/flag**, not a new anonymous dict key.

### 12.10 Motion modes (mostly Add; some Restructure)

| Mode | Today | Verdict |
|------|-------|---------|
| Walk / dash / teleport to empty | `MOVE`, `DASH`, `TELEPORT_CASTER` + TILE | **Reuse** → mode `TO_EMPTY_TILE` |
| Into occupied + push (Push Through) | `MOVE_INTO_AND_PUSH` | **Restructure** → mode `INTO_OCCUPIED_PUSH` (current moveset) |
| Pass-through package | `TRAMPLE` / `BULLDOZE` effects | **Reuse** as keywords |
| Other exotic modes (vault, behind, ally-step, …) | Missing or one-off | **Defer** until those skills exist in the project |
| `MovementType` WALK/FLY/TELEPORT (unit locomotion) | Unit data, not ability | **Reuse** for unit; don’t confuse with skill motion mode |

### 12.11 Gates, layer conditions, OR choice

| Item | Today | Verdict |
|------|-------|---------|
| Ordered `effects[]` always all run | Flat list | **Restructure** → modules with gates; layers with conditions |
| On-kill / on-land / collision behavior | Scattered `modifiers` + special EffectTypes | **Restructure** into shared condition table |
| `resolution_choice` (OR) | Missing | **Defer** (no current moveset requires player OR) |
| Condition vocabulary | Implicit in code | **Add** ids needed by current skills (Always, IF_KILL, IF_COLLIDED, ON_LAND, when damage dealt, …) |

### 12.12 Status / presentation / upgrades

| Item | Today | Verdict |
|------|-------|---------|
| `StatusType` enum (incl. RETALIATION_*, CANTO, GHOST, …) | Rich | **Reuse** for ADD_STATUS layers; ARM_REACTION can apply these |
| `PresentationAnim` | Exists | **Reuse** |
| Upgraded parallel fields + `upgraded_effects` | Flat overrides | **Restructure** → full upgraded header+modules profile (transitional: keep generating upgraded_effects from modules) |

### 12.13 Path vs destination (engine)

| Item | Today | Verdict |
|------|-------|---------|
| Pass-through resolution | `PhysicsSystem` + TRAMPLE/BULLDOZE | **Reuse** |
| Destination aim | TILE / DASH_LINE | **Reuse** |
| Authoring clarity path vs end | Overloaded in one ability | **Restructure** docs + module layers (no need to throw away physics) |

### 12.14 Suggested resource split (refactor shape)

```
AbilityData                    ← header (id, planner_group, tags, cost, uses, presentation, modules[], upgraded_modules[])
AbilityModule                  ← NEW: phase, primary effect, motion/keywords, range, shape, targeting flags, layers, gate
EffectData + condition         ← REUSE as layer/primary payload; slim modifiers over time
GameEnums.EffectType           ← REUSE primaries; demote “modifier-only” types to conditions over time
```

### 12.15 Pain this removes (unchanged intent)

- One `range_tiles` for attack **and** move distance  
- Anonymous `modifiers` as the only extension point  
- Unclear multi-hit vs multi-target  
- No clean move-then-range / range-then-canto authorship  

**Migration note:** Prefer one cut to modular runtime; if a bridge is needed, generate flat `effects[]` from modules temporarily — do not keep two authoring UIs.

---

## 13. Outside this system (on purpose)

These are **not** AbilityData module problems — they live elsewhere:

| Item | Where it belongs |
|------|------------------|
| Passives | Passive / trait system |
| Enemy-turn reactions / ZoC interrupts | Reaction / status triggers (a skill may **ARM_REACTION**, but the interrupt isn’t a planned module) |
| Mimic / cast another unit’s skill | Ability-as-value (rare; approve if ever needed) |

Everything else called out in Bible skill lines (OR choice, vault modes, HP cost, filters, rule-pick targets, delay/ends turn, next-attack grants, ally-origin range, etc.) is expressed by **adding options to the fields above**, not by a second architecture.

---

## 14. Refactor checklist (when we implement)

Use this doc as the acceptance bar:

1. [ ] Data schema per §12.14: header (`planner_group`, tags, …) + `AbilityModule`; layers = EffectData + condition
2. [ ] Shared tables: gates, layer conditions, keywords; add filters/motion modes/OR only if a **current** skill needs them
3. [ ] Port §12.9 modifier keys → typed fields as skills are touched; stop new anonymous modifiers
4. [ ] Keyword expansion (TRAMPLE, BULLDOZE, GHOST, …) — reuse engine paths
5. [ ] Range: per-module range; MOVE min ≥ 1; delete MOVE→`range_tiles` fallback
6. [ ] AUTO anim per §7.2
7. [ ] Planning: multi-aim + gated-aim rules per §2.7 (`PlanningCommitFlow` reused); cover Violent Collision
8. [ ] Sim: modules in order; keywords; layers; gates; presentation events
9. [ ] Class library editor: grey out illegal options; dual module lists for upgrades
10. [ ] Migrate **all current** moveset factories/definitions + readers
11. [ ] QA: planning gate + regression
12. [ ] Remove `is_movement_skill` / old kind heuristics once `planner_group` + tags are live

---

## 15. Owner quick reference

Start at **§0**. Author: `planner_group` + tags + cost → `modules` / `upgraded_modules` → per module effect, range, shape, tile/unit, keywords, layers, gate → AUTO anim unless override.

- Column ≠ tags; basic positioning ≠ “has MOVE”  
- MOVE min ≥ 1; grey out useless options  
- New aim = new module; same-target extras = layer  
- After move, range from new tile  
- Path hits = TRAMPLE/BULLDOZE keywords 

---

## 16. Design audit (second pass)

Honest pass over this bible: what to leave alone, what to simplify, what must stay a **keyword**, what is still missing, what to defer.

### 16.1 Leave alone (do not “improve” into the modular model)

| Keep as-is | Why |
|------------|-----|
| Timeline columns Pre-Move / Action / Post-Move | Unchanged; `planner_group` only picks Pre-Move vs Action for the card |
| Universal Run / Wait as system actions | Not normal class-library modular cards |
| `TargetingFlags` bitmask + editor checkboxes | Modules reuse flags; don’t invent a second checkbox schema. |
| `TargetShape` + `target_shape_size` | Complete enough for current classes; add shapes only when a skill needs them. |
| `PlanningCommitFlow` / awaiting machinery | Keep; feed it clearer module data instead of rewriting commit UX. |
| Physics pass-through (TRAMPLE / BULLDOZE resolution) | Engine already correct — wrap with keywords, don’t re-specify physics in AbilityData. |
| `StatusType` catalog | Skills apply statuses; don’t rebuild status rules inside modules. |
| Passives / reactions | Stay outside AbilityData (ARM_REACTION = apply a status you already have). |
| Header `presentation_key` / `presentation_anim` | Enough for v1. Per-layer anim is noise. |
| Transitional `targeting_mode` sync helpers | Fine until flags-only authoring is universal. |

### 16.2 Simplify (doc is heavier than v1 needs)

| Simplify | Recommendation |
|----------|----------------|
| Old `AbilityKind` on cards | Replace with **`planner_group`** + **tags**; rename MOVEMENT_SKILL → basic positioning (`PRE_MOVE`). |
| Cost block | v1 = `action_point_cost` + `movement_point_cost` + optional HP cost + optional one cost_modifier. Defer `ALL_REMAINING` / fancy dual-cost UI until a skill needs it. |
| `min_range` everywhere | Max-first; **MOVE min ≥ 1** (MOVE 0 disabled). Expose other mins only when Bible needs bands (e.g. 2–3). |
| Module phase on every module | Default **`ON_ACTION`**. Set `ON_PRE` / `ON_POST` only on multi-step skills. |
| Aim binding on every module | Default **NEW_AIM** for multi-module; **same-target extras = layers** (don’t make authors pick SAME_AS_MODULE_N for push-after-damage). Add RULE_PICK / SAME only when needed. |
| `AbilityLayer` as a new Resource type | Prefer **`EffectData` + `condition` id** (and optional keyword id) so migration isn’t a full type explosion. |
| Motion mode laundry list | Ship with what factories already imply: empty-tile walk/dash/teleport, into-occupied push, pass-through keywords. Add vault/behind/ally-step when those classes are implemented. |
| Range origin “last unit tile” | Defer until a spotter-style skill is built. Default actor-after-prior-modules is enough. |
| `turn_flags` DELAY / ENDS_TURN | Defer unless a **current** moveset skill needs them. |
| Per-module presentation override | Defer; sequence from module primary effect if needed later. |
| Demote every modifier-`EffectType` in one go | Migrate when touching that skill. Don’t big-bang rename PUSH_STAGGER_* on day one. |

### 16.3 Keep as keywords (do not split for authors)

Author-facing keywords; engine may expand. Splitting into five checkboxes is worse UX and fights Bible keyword parity.

| Keyword | Keep bundled | Do **not** author as |
|---------|--------------|----------------------|
| **TRAMPLE X** | Passthrough + ATK X on move-through | Separate “ghost + damage on path + …” checkboxes |
| **BULLDOZE X** (push Y) | Passthrough + collision ATK/PUSH package | Separate dash flag + collision damage + push layers for the common case |
| **GHOST** (during this move) | Movement flag for the module | DIY terrain rules on the card |
| **PIERCE** | Damage flag / status | Its own EffectType primary |
| **CANTO** (full refund) | Passive/status | A skill “keyword” that reinvents post-move — skill partial canto = `ON_POST` MOVE module |

**Optional extra layers** when the Bible adds something beyond the keyword (e.g. Bowling [+] chain). Trampling Advance (locked): MOVE + **TRAMPLE 2** + **PUSH** layer — not passthrough/damage micro-checkboxes.

**Also prefer compact forms**

| Pattern | Prefer |
|---------|--------|
| Frenzy 3 hits | `DAMAGE` + `hit_count: 3` — not three damage layers |
| Shield Slam adjacent +ATK | Keep simple condition or existing `bonus_if_adjacent_at_cast` until a generic condition table exists |
| Iron Grip AP refund | One layered “refund AP if target has CC” (today’s EffectType/modifier) — don’t force GRANT_AP + hand-built gate for v1 |

### 16.4 Still missing / underspecified (open)

| Gap | Notes |
|-----|-------|
| **Class library / JSON schema** | Mapping modular resources ↔ `class_library_data.json` not written (implement with editor). |
| **Tooltip keyword order** | Suggest: planner cost → RANGE/MOVE/DASH → keywords → layers → gates. Finalize when building tooltip codegen. |
| **Multi-module anim sequencing** | §7.3: v1 may keep one header anim; improve later. |

**Resolved (do not re-open):** MOVE min ≥ 1; undo out of doc; separate upgrade modules; `planner_group` + tags; trampling = TRAMPLE + PUSH layer; Violent Collision gated-aim rule (§2.7 + Example F); OR/exotic vault deferred.

### 16.5 Recommended v1 slice (refactor scope)

**Scope:** every ability in **current** project movesets (Knight, Bruiser, universals used by them, class library readers/sim/planning). Not uncoded Bible classes.

1. Header: `planner_group`, `tags`, AP/MP (+ HP if needed), uses, presentation, `modules` + `upgraded_modules`.  
2. Each module: effect payload, range max (min ≥ 1 for MOVE), shape, targeting flags, keywords (TRAMPLE/BULLDOZE/GHOST), layers + conditions.  
3. Kill MOVE-distance fallback to ability `range_tiles`.  
4. AUTO anim per §7.2.  
5. Migrate all current factories/definitions; absorb worst `modifiers` as you touch each skill.  

Defer: OR choice, RULE_PICK, DELAY/ENDS_TURN, exotic motion modes, ally-origin range — unless a **current** moveset skill already needs them.

### 16.6 Audit verdict

| Question | Answer |
|----------|--------|
| Is the structure sound? | **Yes** — header + modules + layers + gates. |
| Is the doc over-specified for v1? | **Yes** — trim per §16.2–16.5. |
| Biggest authorship win? | Per-module range + keywords for charge skills + layers for same-target extras. |
| Biggest risk? | Building every dropdown before any skill migrates; or splitting TRAMPLE/BULLDOZE into micro-layers. |

---

## Changelog (doc)

| Date | Change |
|------|--------|
| 2026-08-02 | Initial DRAFT from owner modular design + planning/presentation/upgrade gaps filled for refactor readiness |
| 2026-08-02 | Clarified structure vs vocabulary; filled cost block, motion modes, aim binding, filters, OR choice, LOS/turn flags, expanded gates/layers — Bible gaps as options inside the same structure |
| 2026-08-02 | §12 Migration inventory: reuse / restructure / add vs live AbilityData, EffectData, EffectType, TargetingFlags, modifiers keys, planning enums |
| 2026-08-02 | §16 Second-pass audit: leave alone, simplify, keyword vs split, missing, v1 slice |
| 2026-08-02 | Locked owner decisions: planner_group, tags, basic positioning rename, anim rules from live AUTO, separate upgrade modules, current-moveset scope; undo out of doc |
| 2026-08-02 | §17 Doc QA pass: fixed stale CLASS_SKILL examples, MOVE 0 contradictions, anim priority table, checklist/quick-ref drift; renamed module phases ON_PRE/ON_ACTION/ON_POST |
| 2026-08-02 | §18 Audit pass 2: 7.1 vs 7.2, trampling AUTO scope, Violent Collision in-scope, migration/defer alignment, Example E Swap |
| 2026-08-02 | §19 Audit pass 3: §0 normative summary, precedence, cost↔planner coupling, gated-aim rule, Example F, validation grey-out, trampling AP-only migration note |
| 2026-08-02 | Status → READY_FOR_REFACTOR; push to origin |

---

## 19. Doc audit pass 3 (2026-08-02) — improve

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Doc hard to navigate; audits buried the normative target | High | Fixed — **§0** + read-order + precedence |
| 2 | Violent Collision planning still “TBD” while in scope | High | Fixed — §2.7 normative gated-aim + **Example F** |
| 3 | Cost could be AP on PRE_MOVE / MP on ACTION | Med | Fixed — editor coupling rules in §1 / §11 |
| 4 | Examples D/E out of order; no Violent Collision example | Med | Fixed — C→D→E→F |
| 5 | Trampling factory today charges MP+AP; doc said AP only without calling out migrate | Med | Fixed — Example C migration note |
| 6 | `ALL_REMAINING` in cost examples (not current moveset) | Low | Fixed — deferred |
| 7 | Tag vocabulary not listed | Low | Fixed — canonical tags in §0 |
| 8 | Validation didn’t stress grey-out / planner↔cost | Low | Fixed — §11 |

**Audit result:** Normative path is §0–§11. Open leftovers are tooltip order + JSON schema + optional multi-module anim polish — none block starting the refactor.  


---

## 17. Doc QA pass (2026-08-02)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Examples A/B/D still said `CLASS_SKILL` | High | Fixed |
| 2 | Example A / §2.3 still allowed MOVE `0–N` | High | Fixed — min ≥ 1 everywhere |
| 3 | §7.2 priority 3 (MOVE→WALK) fought trampling RUN exception | High | Fixed — integrated as priority 3 |
| 4 | Module phase name `PRE_MOVE` collided with `planner_group` | Med | Fixed — `ON_PRE` / `ON_ACTION` / `ON_POST` |
| 5 | §9 Cancel / undo language in AbilityData doc | Med | Fixed — removed; planning-only note |
| 6 | §14 checklist cited `AbilityLayer` + “Knight/Bruiser first” | Med | Fixed — EffectData+condition; all current movesets |
| 7 | §15 quick ref still said “type” not planner_group/tags | Med | Fixed |
| 8 | §6 “may split keywords” vs §16.3 “don’t split” | Med | Fixed — clarify PUSH as extra layer OK |
| 9 | Big picture omitted keywords; “one classification” stale | Low | Fixed |
| 10 | §16.4 listed locked items as “missing” | Low | Fixed — moved to resolved |

**QA result:** Internal contradictions from locked decisions cleared. Open gaps left only in §16.4 (implementation-time).  

---

## 18. Doc audit pass 2 (2026-08-02)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | §7.2 claimed “same as live code” but changed trampling AUTO | High | Fixed — §7.1 today vs §7.2 target |
| 2 | Priority “MOVE + tag attack → RUN” made Example A wrongly RUN | High | Fixed — RUN only for MOVE+TRAMPLE (or BULLDOZE/DASH rows) |
| 3 | Violent Collision is a **current** skill but treated like deferrable OR/vault | High | Fixed — called out in-scope in §16.4 |
| 4 | Migration §12 said Add OR / exotic modes / ALL_MOV while §16 deferred them | Med | Fixed — aligned to defer unless current skill needs |
| 5 | Keywords listed as a “primary effect family” | Med | Fixed — separate field |
| 6 | Stale “POST_MOVE modules” / “Default ACTION” phase names in header & §16.2 | Low | Fixed → `ON_POST` / `ON_ACTION` |
| 7 | No basic-positioning worked example | Low | Fixed — Example E Swap |
| 8 | Multi-module anim (move then strike) underspecified | Low | Noted in §16.4 / §7.2 Example A note |

**Audit result (pass 2):** Contradictions cleared; Violent Collision later specified in §19 / §2.7.  
