# AbilityData — Modular Skill Design Bible

**Status:** `DRAFT` — owner design authority for the future AbilityData refactor  
**Audience:** Project owner (readable) + implementers (refactor checklist)  
**Authority chain:** `class_abilities.txt` (Master Bible keywords & economy) → **this doc** (AbilityData shape) → `AbilitySystem` / planning / sim (interpretation)  
**Non-authority:** Current flat `AbilityData` fields are **legacy** until refactor; when they conflict with this doc, **this doc wins** for the target design.

### Owner decisions (locked)

| Topic | Decision |
|-------|----------|
| MOVE 0 | Illegal; editor greys out options that do nothing |
| Undo | **Not** part of AbilityData — planning/timeline only |
| Trampling packaging | MOVE + **TRAMPLE** keyword + separate **PUSH** layer |
| Upgrades | **Separate** base `modules[]` and upgraded `modules[]` (full profiles; upgraded may diverge a lot) |
| Refactor scope | All **current** movesets in the project (factories/class library/readers) — not uncoded Bible classes |
| Planner column | Rename economy `kind` → **`planner_group`**: `PRE_MOVE` or `ACTION` (post-move steps are modules inside an ACTION skill) |
| Classification / anim | **Tags** (e.g. attack, movement) — not overloaded “movement skill” naming |
| Basic positioning | Today’s MP Swap / Push Through style skills → **basic positioning** (`planner_group = PRE_MOVE`), distinct from “has a MOVE effect” |

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
├── Header          → identity, planner bucket, cost (once), presentation, limits
└── Modules[]       → ordered steps (like mini-skills in a sequence)
    ├── Primary effect + aim (range, shape, tile/unit, values)
    ├── Layers[]    → extra effects on THAT module’s targets (same aim)
    └── Gate        → whether this module runs (Always / if kill / …)
```

**Mental model**

| Piece | Means |
|-------|--------|
| **Header** | What the skill *is* for the planner and economy (one classification, one cost) |
| **Module** | One step: do an effect, with its own targeting, as if aiming a fresh skill |
| **Layer** | Extra effect on the **same targets** as its parent module (multi-hit, push-if-damage, trample, etc.) |
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
| **planner_group** | Timeline column only: `PRE_MOVE` (basic positioning — MP, no Action slot) or `ACTION` (AP class skills / basic attack; may contain POST_MOVE modules). Replaces old `AbilityKind` for class-library cards. Universal Run/Wait stay system actions. |
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
| **primary_resource** | `AP`, `MP`, `HP` (Bible flat HP spend), or `NONE` |
| **primary_value** | Integer, or special: `ALL_REMAINING` (e.g. Guardian Step spends all MOV) |
| **cost_modifier** | Optional rule that changes the paid cost: `NONE`, `ZERO_IF_<condition>` (e.g. Adrenaline Surge: 0 AP if adjacent to 2+ enemies) |
| **secondary_cost** | Optional extra pay (e.g. Time Warp: AP skill + spend HP) — same resource/value shape |

Examples: basic attack → AP 0; Swap → MP 1; Blood Boil → HP 5 (+ AP if the card also costs AP); Adrenaline Surge → AP 1 with modifier `ZERO_IF_ADJACENT_ENEMIES_GTE_2`.

### Planner group → timeline

| planner_group | Timeline | Consumes Action slot? | Typical cost |
|---------------|----------|------------------------|--------------|
| `PRE_MOVE` | Pre-Move | No | MP — **basic positioning** (Swap, Push Through, …) |
| `ACTION` | Action (+ optional Post-Move modules) | Yes | AP (0 for basic attack) |

**Tags ≠ planner group.**  
- Swap: `planner_group = PRE_MOVE`, tags `{positioning}` (and maybe `movement`).  
- Trampling Advance: `planner_group = ACTION`, tags `{attack, movement}`.  
- Shield Bash: `planner_group = ACTION`, tags `{attack}`.

**Module execution phase** (PRE_MOVE / ACTION / POST_MOVE) is still set per module **inside** an ACTION skill when the skill itself walks then strikes then canto-moves. That does not change `planner_group` (the card still sits in Action).

### Cost rules

- Cost is charged **once** when the skill is committed/used (header), not per module.
- A class skill may include move modules; that does **not** add a second AP cost unless the header cost block says so.
- Movement-skill cards (`PRE_MOVE` + MP cost) never consume the Action slot.
- **Universal walk MP** still obeys Bible “pre **or** post, not split.” Skill MOVE modules are skill-owned steps, not a second split of that universal pool.

### Structure vs vocabulary

The **structure** (header → modules → layers → gates) is fixed.  
**Dropdown / option lists** (effects, motion modes, conditions, filters, cost modifiers) grow as the Bible needs them — same fields, more choices. Filling gaps means adding options, not inventing a new architecture.

---

## 2. Module (one step)

Modules run in **order**. Default: each module is a **new aim**. Optional **aim binding** can reuse or auto-pick targets (see §2.5).

### 2.1 Execution phase

When this step runs relative to the turn columns:

| Phase | Typical use |
|-------|-------------|
| `PRE_MOVE` | Skill-owned walk/dash before the “main” hit |
| `ACTION` | Main strike / buff / primary effect |
| `POST_MOVE` | Canto-like move after the action (including “if kill, move again”) |

Default: if omitted, infer from effect (MOVE/DASH → often Pre or Post by gate; damage/heal → Action). Prefer **explicit** phase in the editor.

### 2.2 Primary effect (+ motion mode when motion)

What this module *is*. Families (grow the list; keep the field):

| Effect family | Examples |
|---------------|----------|
| Damage | ATK-based, MAG-based, fixed; optional hit_count for multi-hit |
| Heal / Shield | Mag heal, fixed/HP% heal, SHIELD; convert-missing-HP→SHIELD |
| Motion | MOVE, DASH, JUMP, TELEPORT, SWAP, MOVE_OTHER, PAIRED_MOVE (you + another) |
| Control | PUSH, PULL, THROW_BEHIND, PULL_SELF_TO_TARGET, PULL_TARGET_TO_SELF |
| Status | Apply / remove / PURGE / CLEANSE |
| Utility | CHANGE_TERRAIN, CREATE_HAZARD, DESTROY_OBSTACLE, SPAWN, GRANT_AP, GRANT_NEXT_ATTACK_MOD, ARM_REACTION |
| Keywords (bundles) | TRAMPLE, BULLDOZE (see §6) |

**Motion mode** (when primary effect is motion):

| Mode | Meaning |
|------|---------|
| `TO_EMPTY_TILE` | Normal walk/dash/jump/teleport destination |
| `TO_TARGET_UNIT` | Move into engagement with aimed unit (Swift Strike) |
| `ADJACENT_TO_TARGET` | Land adjacent to aimed unit (Shadow Step) |
| `BEHIND_TARGET` | Land behind aimed unit |
| `VAULT_OVER` | Jump over unit/obstacle to opposite empty tile |
| `INTO_OCCUPIED_PUSH` | Enter occupied tile and push occupant (Push Through) |
| `BACKWARDS` | Facing-constrained retreat (Tactical Retreat) |
| `SLIDE_TARGET_OPPOSITE` | Reposition: slide targeted unit to opposite side of you |
| `ALLY_STEP` | Usher: ally steps into empty adjacent (you may stay put) |

Editor greys out illegal shape/mode combos.

**Player choice (OR)** — still inside the module, not a new system:  
`resolution_choice`: `NONE` \| `PICK_ONE_OF_EFFECTS` (e.g. Grappling Hook: pull self **or** pull target). Planner shows the choice; commit stores which branch was picked.

### 2.3 Min / max range + LOS

- Inclusive Manhattan range from the **range origin** (see §3).
- Examples: `0–0` (self), `1–1` (melee), `1–3`, `2–2`, `0–unlimited` (**GLOBAL**).
- **requires_los**: default on; off when GLOBAL or Bible says otherwise.
- Some mins/maxes greyed out by effect (e.g. MOVE often `1–N` or `0–N` “up to N”).

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

**Aim binding** (how this module gets its targets):

| Binding | Meaning |
|---------|---------|
| `NEW_AIM` (default) | Player aims again — two different targets |
| `SAME_AS_MODULE_N` | Reuse targets from module N — second effect, same aim |
| `RULE_PICK` | Auto-pick by rule + params (e.g. highest HP enemy in R3 — Board Scrambler) |

**Tile mode**

- Player aims a **tile** (empty or occupied per motion mode / checkboxes).
- Invokes **two-phase awaiting** when destination confirm is required.
- Checkboxes: **affect allies on tiles?** / **affect enemies on tiles?**
- Optional: **allow occupied destination** (Push Through).

**Unit mode**

- Player aims a **unit** only; empty tile = invalid.
- Checkboxes: **ally valid?** / **enemy valid?** / **self valid?** as applicable.

**Target filters** (validity checklist on the same module — add rows as needed):

| Filter examples | Bible use |
|-----------------|-----------|
| HP below % | Executioner’s Blade |
| Has at least one debuff | Bestial Roar, Terrify |
| Target current HP &lt; caster Max HP | Hex |
| Already damaged | Swift Strike [+] |
| Has status X | vs BLEED, etc. |
| Not acted yet this round | Precision Strike style |

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

**Planning:** Preview uses the same sim rules. If a gated module would not run, its aim is inactive/cleared. If preview shows the gate will pass, that module’s aim is required up front.

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
| **CANTO** (full refund) | Unit/passive full MOV refund after action | Status/passive; skill-granted partial canto = POST_MOVE module with fixed range |

Authors may **split** a keyword into separate layers when a skill needs only part of the bundle. Default: keep the keyword for simplicity.

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

### 7.2 AUTO rules going forward (tags + modules — same priorities)

Keep the **same priority order** as live code; express inputs with tags/modules instead of `AbilityKind` heuristics:

| Priority | Condition (modules / tags / keywords) | Anim |
|----------|----------------------------------------|------|
| 0 | `presentation_anim` override ≠ AUTO | That override |
| 1 | Primary/keyword **DASH** | `SUPER_RUN` |
| 2 | Keyword/effect **BULLDOZE** | `RUN` |
| 3 | **MOVE** / walk motion (tag `movement` without dash/bulldoze) | `WALK` (factories may still override to `RUN` for charge-likes) |
| 4 | Tag `attack` **or** damage/push/pull/explode effects, and not basic-positioning-only | `ATTACK` |
| 5 | Else (buffs, heals, pure utility) | `SPELL` |
| 6 | Basic positioning (`planner_group = PRE_MOVE`, tag `positioning`) with no override | `WALK` |

**Multi-tag example — Trampling Advance:** tags `{attack, movement}`, modules MOVE + TRAMPLE + PUSH. AUTO from table → MOVE implies WALK, but charge identity wants RUN → **set override `RUN`** (matches current factory) or treat “MOVE + TRAMPLE/offensive” as RUN in a single documented exception: *offensive walk package → RUN*. Prefer that exception so AUTO works without a manual override:

- If MOVE/walk **and** (TRAMPLE or BULLDOZE or tag `attack`) and not DASH → **`RUN`**  
- Else if MOVE only (reposition) → **`WALK`**

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
| Cancel | Follows timeline column rules; Pre-Move live apply/cancel unchanged in spirit |

Compound skills (move + attack + conditional post-move) still appear as **one** skill card; planner may show multiple ghosts/paths that belong to that one commit.

---

## 10. Worked examples

### Example A — Move, hit, canto-if-kill

```
Header: CLASS_SKILL, cost 1 AP, anim ATTACK

Module 1 — phase PRE_MOVE
  Effect: MOVE
  Range: 1–2 (or 0–2 “up to 2”)
  Shape: SINGLE, mode: TILE
  Gate: Always

Module 2 — phase ACTION
  Effect: ATK damage 2
  Range: 1–1
  Shape: SINGLE, mode: UNIT, enemy only
  Gate: Always
  Layer: PUSH 2 — when damage dealt

Module 3 — phase POST_MOVE
  Effect: MOVE
  Range: 1–2
  Shape: SINGLE, mode: TILE
  Gate: If killed enemy
```

### Example B — AoE then conditional heal (two aims)

```
Header: CLASS_SKILL, cost 1 AP

Module 1 — ACTION
  Effect: ATK damage 2
  Range: 0–4
  Shape: AOE 3×3, mode: TILE (or unit+aoe per editor rules)
  Affect enemies on tiles: yes
  Gate: Always
  Layer: Apply STAGGER — at resolution

Module 2 — ACTION
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
  presentation_anim: AUTO  → RUN (MOVE + TRAMPLE/offensive rule)

Module 1 — ACTION
  Effect: MOVE
  Range: max 2 (min 1 — MOVE 0 disabled)
  Shape: SINGLE, mode: TILE
  Keywords: TRAMPLE 2
  Layer: PUSH 1 — when moved through enemy
  Gate: Always
```

Destination = end tile. Path ATK from **TRAMPLE**; push as its own layer (owner choice B).

### Example D — Bowling Charge

```
Header: CLASS_SKILL, cost 1 AP

Module 1
  Effect: DASH
  Range: 1–3 (dash length)
  Shape: SINGLE / dash-line rules, mode: TILE
  Gate: Always
  Layer: BULLDOZE (ATK 3, PUSH 2 per Bible) → passthrough + on-collision package
```

---

## 11. Validation rules (editor + runtime)

Fail loud; do not silently “fix up” intent.

1. Header cost/type present and legal.
2. At least one module.
3. Each module: effect + legal range + legal shape + legal tile/unit mode for that effect.
4. Unit mode: at least one of self/ally/enemy allowed when required.
5. Gated modules: condition id known to the shared condition table.
6. Keywords expand to known engine flags/effects.
7. Upgrade profile, if any, validates the same way.
8. Presentation fields optional but `presentation_anim` must be a known enum value.

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
| `ALL_REMAINING` MP | Missing | **Add** |
| Dual cost (AP + HP) | Simulated by effects | **Add** explicit secondary_cost on header |

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
| Aim binding NEW / SAME / RULE_PICK | Missing (always one aim) | **Add** |
| Target filters (HP%, debuff, …) | Mostly missing or hard-coded | **Add** filter checklist on module |
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
| `on_kill_heal_shield`, `frenzy_on_kill_ap` | Layer `ON_KILL` + HEAL/SHIELD/GRANT_AP |
| `next_attack_pierce` | Utility `GRANT_NEXT_ATTACK_MOD` |
| `buff_per_destroyed_object` | Layer after DESTROY_OBSTACLE |
| `intercept_grant_str` | Status/INTERCEPT layer params |
| `push_board_items`, `item_collision_damage` | Layer flags on PUSH AoE |
| `damage_adjacent_on_landing`, `belly_flop_push` | Layer `ON_LAND` |
| `exclude_caster` | Targeting checkbox |
| `buff_on_push` | Layer on PUSH (Push Through [+]) |

**Add** any Bible need not in this table as a **new named condition/flag**, not a new anonymous dict key.

### 12.10 Motion modes (mostly Add; some Restructure)

| Mode | Today | Verdict |
|------|-------|---------|
| Walk / dash / teleport to empty | `MOVE`, `DASH`, `TELEPORT_CASTER` + TILE | **Reuse** effects → modes `TO_EMPTY_TILE` |
| Into occupied + push | `MOVE_INTO_AND_PUSH` | **Restructure** → mode |
| Pass-through package | `TRAMPLE` / `BULLDOZE` effects | **Reuse** as keyword layers |
| `TO_TARGET_UNIT`, `ADJACENT_TO_TARGET`, `BEHIND_TARGET`, `VAULT_OVER`, `BACKWARDS`, `SLIDE_TARGET_OPPOSITE`, `ALLY_STEP` | Missing or one-off | **Add** |
| `MovementType` WALK/FLY/TELEPORT (unit locomotion) | Unit data, not ability | **Reuse** for unit; don’t confuse with skill motion mode |

### 12.11 Gates, layer conditions, OR choice

| Item | Today | Verdict |
|------|-------|---------|
| Ordered `effects[]` always all run | Flat list | **Restructure** → modules with gates; layers with conditions |
| On-kill / on-land / collision behavior | Scattered `modifiers` + special EffectTypes | **Restructure** into shared condition table |
| `resolution_choice` (OR) | Missing | **Add** |
| Condition vocabulary | Implicit in code | **Add** explicit shared ids (Always, IF_KILL, IF_COLLIDED, ON_LAND, …) |

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

1. [ ] Data schema per §12.14: header + `AbilityModule` + `AbilityLayer` (EffectData payload reused)
2. [ ] Shared tables: gates, layer conditions, target filters, motion modes, cost modifiers, rule-pick ids
3. [ ] Port §12.9 modifier keys → typed fields; stop adding new anonymous modifiers
4. [ ] Demote modifier-only `EffectType`s (§12.7) to layer conditions
5. [ ] Keyword expansion (TRAMPLE, BULLDOZE, GHOST, …) — reuse engine paths
6. [ ] Range: per-module min/max + origin + LOS; delete MOVE→`range_tiles` fallback
7. [ ] Aim binding + `resolution_choice`
8. [ ] Planning: multi-aim + choices + gated aims preview-correct (`PlanningCommitFlow` reused)
9. [ ] Sim: modules in order; layers; gates; events for presentation
10. [ ] Class library editor follows §2; factories emit modules (Knight/Bruiser first)
11. [ ] QA: planning gate + regression; Bible spot-checks
12. [ ] Remove `is_movement_skill` mirror; slim ability-level `scaling_stat` if fully per-module

---

## 15. Owner quick reference

**To invent a skill:** pick header (type + cost block) → add modules in order → for each module: effect (+ motion mode if needed), min/max range, shape, aim binding, tile/unit + filters, values → layers → gate → presentation.

**Remember**

- Structure stays the same; new Bible needs = new dropdown rows  
- Cost/type once on the header (with modifiers / HP / all-MOV as needed)  
- New player aim = new module (`NEW_AIM`); same targets = layer or `SAME_AS_MODULE_N`  
- After move, next RANGE is from the new tile (unless you override origin)  
- Move destination ≠ path; trample/bowling use path/collision layers  

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
| `execution_phase` on every module | Default **ACTION**. Set PRE/POST only on multi-step skills. Single-module skills shouldn’t ask. |
| Aim binding on every module | Default **NEW_AIM** for multi-module; **same-target extras = layers** (don’t make authors pick SAME_AS_MODULE_N for push-after-damage). Add RULE_PICK / SAME only when needed. |
| `AbilityLayer` as a new Resource type | Prefer **`EffectData` + `condition` id** (and optional keyword id) so migration isn’t a full type explosion. |
| Motion mode laundry list | Ship with what factories already imply: empty-tile walk/dash/teleport, into-occupied push, pass-through keywords. Add vault/behind/ally-step when those classes are implemented. |
| Range origin “last unit tile” | Defer until a spotter-style skill is built. Default actor-after-prior-modules is enough. |
| `turn_flags` DELAY / ENDS_TURN | Defer to mage/teleport work. Don’t block Knight/Bruiser modular cut. |
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
| **CANTO** (full refund) | Passive/status | A skill “keyword” that reinvents post-move — skill partial canto = POST_MOVE module |

**Optional extra layers** when the Bible adds something beyond the keyword (e.g. Bowling [+] chain). Trampling Advance (locked): MOVE + **TRAMPLE 2** + **PUSH** layer — not passthrough/damage micro-checkboxes.

**Also prefer compact forms**

| Pattern | Prefer |
|---------|--------|
| Frenzy 3 hits | `DAMAGE` + `hit_count: 3` — not three damage layers |
| Shield Slam adjacent +ATK | Keep simple condition or existing `bonus_if_adjacent_at_cast` until a generic condition table exists |
| Iron Grip AP refund | One layered “refund AP if target has CC” (today’s EffectType/modifier) — don’t force GRANT_AP + hand-built gate for v1 |

### 16.4 Still missing / underspecified

| Gap | Notes |
|-----|-------|
| **MOVE “up to N” default min** | **Locked:** min ≥ 1 (MOVE 0 disabled in editor). |
| **Undo / cancel** | Planning concern — **out of this doc.** |
| **Gated second aim (Violent Collision)** | Preview/planning UX when a gated second MOVE is required — specify at implementation time. |
| **Upgrade authorship** | **Locked:** separate `modules` and `upgraded_modules`. |
| **Facing** | `BACKWARDS` / behind landing exist as modes; **attack from behind** as a filter/condition still thin. |
| **Accuracy / ACC interactions** | Not in this doc; leave to combat math unless a skill modifies ACC. |
| **Class library / JSON schema** | No mapping yet from modular resources ↔ `class_library_data.json`. |
| **Tooltip generation** | “Derive Bible line from modules” stated but no precedence rules (order of keywords). |
| **OR choice commit payload** | Branch id must live on timeline/commit slots — not designed. |
| **Multi-module phase vs universal walk** | Reaffirm: skill modules never spend the universal walk pool unless the module is literally that walk (they shouldn’t be). |

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
