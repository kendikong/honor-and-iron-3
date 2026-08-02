# AbilityData — Modular Skill Design Bible

**Status:** `DRAFT` — owner design authority for the future AbilityData refactor  
**Audience:** Project owner (readable) + implementers (refactor checklist)  
**Authority chain:** `class_abilities.txt` (Master Bible keywords & economy) → **this doc** (AbilityData shape) → `AbilitySystem` / planning / sim (interpretation)  
**Non-authority:** Current flat `AbilityData` fields are **legacy** until refactor; when they conflict with this doc, **this doc wins** for the target design.

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
| **skill_type** | Planner bucket + classification only: `PRE_MOVE` (class movement skill), `CLASS_SKILL` (Action column), `BASIC_ATTACK` (0 AP Action). Universal Run/Wait stay system actions, not normal class-library skills. |
| **cost_resource** | `AP` or `MP` |
| **cost_value** | Integer (0 allowed, e.g. basic attack) |
| **uses_per_combat** | Max uses this fight (`-1` = unlimited) |
| **upgrade** | Optional upgraded variant (see §8) |
| **presentation_key** | Opaque key for VFX/SFX bank (sim only stores/forwards the string) |
| **presentation_anim** | Pose/anim hint: `AUTO`, `ATTACK`, `SPELL`, `WALK`, `RUN`, `NONE`, … |
| **tooltip / keyword line** | Derived for UI from modules when possible; may store Bible-style summary text |
| **notes (editor only)** | Designer comments; ignored by sim |

### Skill type → planner

| skill_type | Timeline | Consumes Action slot? |
|------------|----------|------------------------|
| `PRE_MOVE` | Pre-Move | No |
| `CLASS_SKILL` | Action | Yes |
| `BASIC_ATTACK` | Action | Yes (0 AP typical) |

**Module execution phase** (below) can still place steps in Pre-Move / Action / Post-Move **inside** one skill (e.g. class skill that moves, hits, then conditional post-move). The **header** type is what the skill list and cancel rules use for the card as a whole.

### Cost rules

- Cost is charged **once** when the skill is committed/used (header), not per module.
- A class skill may include move modules; that does **not** add a second AP cost unless the header says so.
- Movement-skill cards (`PRE_MOVE` + MP cost) never consume the Action slot.

---

## 2. Module (one step)

Modules run in **order**. Each module is a full targeting pass (new criteria), unless a future option explicitly links targets (not required for v1).

### 2.1 Execution phase

When this step runs relative to the turn columns:

| Phase | Typical use |
|-------|-------------|
| `PRE_MOVE` | Skill-owned walk/dash before the “main” hit |
| `ACTION` | Main strike / buff / primary effect |
| `POST_MOVE` | Canto-like move after the action (including “if kill, move again”) |

Default: if omitted, infer from effect (MOVE/DASH → often Pre or Post by gate; damage/heal → Action). Prefer **explicit** phase in the editor.

### 2.2 Primary effect

What this module *is*. Examples (non-exhaustive; grow as shared vocabulary):

| Effect family | Examples |
|---------------|----------|
| Damage | ATK-based, MAG-based, fixed |
| Heal | Mag-based heal, fixed heal, HP%-based heal |
| Motion | MOVE, DASH, JUMP/teleport-to-tile, SWAP |
| Control | PUSH, PULL, THROW_BEHIND, … |
| Status | Apply / remove status |
| Utility | SHIELD, CHANGE_TERRAIN, DESTROY_OBSTACLE, SPAWN, … |
| Keywords (bundles) | TRAMPLE, BULLDOZE (see §6) |

Editor greys out illegal combos (e.g. MOVE + ARC shape).

### 2.3 Min / max range

- Inclusive Manhattan range from the **range origin** (see §3).
- Examples: `0–0` (self), `1–1` (melee), `1–3`, `2–2`, `0–unlimited` (GLOBAL-style).
- Some mins/maxes greyed out by effect (e.g. MOVE: must allow a legal destination rule; often `1–N` or `0–N` “up to N”).

**Important:** RANGE is **per module**. Move 2 and attack range 4 are different modules — never one overloaded field.

### 2.4 Targeting shape + size

| Shape | Notes |
|-------|--------|
| SINGLE | One tile / one unit |
| AOE square (e.g. 3×3) | Size = side length |
| AOE cross / diamond | Size = radius |
| ARC | Sweep; size rules per Bible |
| CONE / LINE (skewer) | Directional; size = length |

Editor shows only shapes valid for the primary effect (MOVE → typically SINGLE destination).

### 2.5 Targeting mode: tile vs unit

**Tile mode**

- Player aims a **tile** (empty or occupied per rules).
- Invokes **two-phase awaiting** when the skill needs destination confirm (same spirit as today’s awaiting-target for movement endpoints).
- Checkboxes: **affect allies on tiles?** / **affect enemies on tiles?** (disabled if the effect does not care about occupants).

**Unit mode**

- Player aims a **unit** only; empty tile = invalid.
- Checkboxes: **ally valid?** / **enemy valid?** / **self valid?** as applicable.

### 2.6 Effect values + duration

- Magnitude(s) for the primary effect (ATK power, heal X, dash length already in range, push distance if primary is push, etc.).
- **Duration** when the effect is a status or timed buff/debuff.
- Scaling (STR / MAG / NONE / special) attaches here or on damage/heal subtypes.

### 2.7 Module gate (does this module run?)

Checked at **this module’s resolution time**, using the board **after earlier modules** of this skill.

| Gate examples | Meaning |
|---------------|---------|
| Always | Always runs (if skill itself was legal) |
| If killed enemy | At least one enemy reached 0 HP from earlier steps of this skill |
| If damage dealt | Earlier step dealt damage |
| If adjacent to enemy / ally | Actor adjacency at check time |
| If isolated | No allies adjacent (Bible-style flanking isolation) |
| If no move this turn yet | Actor has not spent movement before this skill |
| … | Shared vocabulary grows; no per-skill code |

**Planning:** Preview uses the same sim rules. If a gated module would not run, its aim/path is inactive or cleared in UI so commit does not show a lie.

---

## 3. Range origin

**Default:** RANGE is measured from the **actor’s current position after all earlier modules** of this skill have applied (so after a move module, the next module’s range is from the **new** tile).

**Optional override (per module):**

| Origin | Use |
|--------|-----|
| Actor (default) | Normal skills |
| Last targeted tile | Effects measured from the tile aimed by a previous module |
| *(future)* Last targeted unit’s tile | Spotter-style / ally-origin skills |

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

**Layer condition examples**

| Condition | Typical use |
|-----------|-------------|
| At resolution | Always with the module’s hit |
| When damage dealt | Push only if the hit connected |
| When moved through enemy | Path hit (trample push, etc.) |
| On collision | Bowling / bulldoze end or ram |
| On kill | Bonus on that target |
| On land | After jump/teleport arrival |

**Multi-hit:** Prefer a damage layer (or hit-count on the primary damage) on the **same** module — not a second module — when targets are the same.

---

## 6. Keywords as bundled layers

Some Bible terms are **packages** so authors do not assemble five checkboxes every time.

| Keyword | Intent (author-facing) | Expands to (engine) |
|---------|------------------------|---------------------|
| **TRAMPLE** | Passthrough + attack-on-move-through | Pass-through movement flag + ON_PASS damage (amount on keyword) |
| **BULLDOZE** | Passthrough + collision package | Pass-through + ON_COLLISION damage/push (amounts on keyword) |
| **GHOST** (during move) | Pass terrain/units per Bible | Movement flag for that module |
| **CANTO** (full refund) | Unit/passive style full MOV refund after action | Status / passive — prefer header or post-move module with fixed tiles for **skill-granted** partial canto |

Authors may **split** a keyword into separate layers when a skill needs only part of the bundle. Default: keep the keyword for simplicity.

---

## 7. Presentation (animation / VFX / SFX)

Simulation stays headless. Presentation reads events + ability presentation fields.

| Level | What to author |
|-------|----------------|
| **Skill header** | `presentation_key`, `presentation_anim` (default pose family) |
| **Module (optional)** | Override anim for this step (e.g. walk for move module, attack for strike) |
| **Layer (optional)** | Rare; usually inherit module/skill |

Rules:

- `AUTO` = derive from skill_type + primary effect + targeting (same idea as today).
- Multi-module skills may play **sequenced** presentation from module order (move anim → attack anim → optional post-move).
- No gameplay legality may depend on animation length or art existing.

---

## 8. Upgrades

Upgrades are a **second authored profile** of the same skill id, not a pile of disconnected `-1` overrides forever.

Preferred target model:

- **Base** header + modules  
- **Upgraded** header deltas and/or module list (replace or patch)

Until refactor lands, factories may keep today’s `upgraded_*` fields; the **design intent** is: upgrade changes are still expressed as modular data (range bumps, extra layers, new gate, etc.), described in `upgrade_description` for the player.

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
Header: CLASS_SKILL (or as Bible class line requires), cost 1 AP
presentation_anim: WALK or ATTACK per art direction

Module 1 — PRE_MOVE or ACTION (pick one phase policy; prefer ACTION if the whole package is the skill)
  Effect: MOVE
  Range: 1–2
  Shape: SINGLE, mode: TILE
  Gate: Always
  Layer: TRAMPLE 2          → passthrough + ATK 2 on move-through
  Layer: PUSH 1             → when enemy moved through
```

Destination = end tile. Trample/push layers use **path** enemies.

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

## 12. What this replaces (legacy flat AbilityData)

Today’s flat resource roughly has: one `range_tiles`, one `kind`, one effect list, targeting flags, shape, presentation, upgrade overrides.

**Pain this design removes**

- `range_tiles` used for both attack range and move distance  
- No clean “move N then range M” or “range M then canto N”  
- Effect `modifiers` dictionaries and one-off EffectTypes growing without structure  
- Unclear multi-hit vs multi-target  

**Migration note (later refactor):** factories and `.tres` should emit **header + modules**; runtime adapters may temporarily flatten into old structures only if needed for a transitional bridge — prefer one cut to modular runtime.

---

## 13. Known holes (not solved by v1 modules alone)

Still out of scope unless we add a **new shared construct** (owner approval):

| Hole | Why |
|------|-----|
| Player **OR** branch (pull me **or** pull them) | Needs choice / XOR branches, not only if-gates |
| Range from **another unit** without standing there | Needs range origin = selected ally (listed as future origin) |
| Reactions / interrupts | Outside Pre-Move → Action → Post-Move planning |
| Mimic / cast another unit’s skill | Ability-as-value, not static modules |
| Passives | Separate system; not AbilityData modules |

---

## 14. Refactor checklist (when we implement)

Use this doc as the acceptance bar:

1. [ ] Data schema: `AbilityData` header + `AbilityModule` + `AbilityLayer` (+ condition ids)
2. [ ] Shared condition table (module gates + layer conditions)
3. [ ] Keyword expansion (TRAMPLE, BULLDOZE, …)
4. [ ] Range origin default + optional overrides
5. [ ] Path vs destination targeting for movement modules
6. [ ] Planning: multi-aim in module order; gated aims preview-correct
7. [ ] Sim: execute modules in order; layers; gates; events for presentation
8. [ ] Presentation: header/module anim sequencing
9. [ ] Class library editor UX matches §2 field order (effect → range → shape → mode → values → layers → gate)
10. [ ] Migrate Knight/Bruiser factories off flat range/effects
11. [ ] QA: planning gate + regression; Bible spot-checks for trampling / bowling / charge lines
12. [ ] Delete obsolete fallbacks (e.g. MOVE distance falling back to attack range)

---

## 15. Owner quick reference

**To invent a skill:** pick header (type + cost) → add modules in order → for each module set effect, min/max range, shape, tile/unit, values → add layers for same-target extras → set module gate if not Always → set presentation.

**Remember**

- Cost/type once on the header  
- New aim = new module  
- Same targets extra juice = layer  
- After move, next RANGE is from the new tile (unless you override origin)  
- Move destination ≠ path; trample/bowling use path/collision layers  

---

## Changelog (doc)

| Date | Change |
|------|--------|
| 2026-08-02 | Initial DRAFT from owner modular design + planning/presentation/upgrade gaps filled for refactor readiness |
