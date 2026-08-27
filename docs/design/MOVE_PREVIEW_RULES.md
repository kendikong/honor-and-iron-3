# Planning preview UI (owner spec)

**Status:** ACTIVE — canonical player-facing behavior for planning overlays (paths, tiles, lines).  
**Related:** `class_abilities.txt`, `PLANNING_SKILL_QA_CHECKLIST.md`, `ACTION_RANGE_LATEST_STAND.md`.

Plain-language rules. No parallel preview logic.

---

## Design principle (why this stays simple)

**Fewer global rules → fewer branches → one canonical path → fewer bugs → easier debug.**

- One rule for every **voluntary walk** (premove, MOVE module, postmove): same blue preview, same paint, same commit shape — only slot and execution order differ.
- One rule for **what preview means**: shown path = walked path.
- **Exceptions are rare and explicit** (forced push/pull UI, teleport hop) — not per-skill `if` trees.
- Do not invent a second hover, route, or preview pipeline when the global path can carry the case.

---

## What move preview is

**Move preview** = the path this character **walks** (tile to tile) to reach their **chosen destination**.

- Blue tiles, path arrow, painted route — all of that is move preview.
- **Source of truth:** what is shown is what they walk on Execute.

**Not move preview** (different UI):

- **Forced movement** on another unit — push, pull, knockback, slide, etc.
- Those use their own arrows / markers; do not mix them into the walker’s blue move path.

**Teleport / blink:** Not a walked path — direct line from start tile to landing (hop). Still the character’s own relocation, not push/pull UI.

---

## The one rule

**Movement step** (premove, skill MOVE module, or postmove):

- Live walk preview from **latest predicted stand** to the mouse (or along a **painted drag route** to the hovered tile).

**Any other step** (damage, target pick, wait, etc.):

- **No** live walk from the mouse.
- **No blue walk tiles** — if blue tiles appear here, that is a bug.
- **Do** keep showing **committed** walks that are not cleared yet (frozen full path).

**Modular skills** = chained mini-skills on one ability/AP. Each module finishes and hands off **stand** to the next. A damage module does not redraw or replace a walk that was already committed.

---

## Live vs frozen (planning only)

| Situation | What you see |
|-----------|----------------|
| Choosing a walk | Live path: stand → mouse (or painted route) |
| Committed a walk, now on a non-move step | **Frozen** full committed path — mouse does not draw a new one |
| Invalid hover for this movement step | **No** move preview for that step (invalid cursor only) |
| Undo a committed walk | Frozen path goes away; on a movement step again → live preview works |

**Frozen** = show the locked path, not hidden. Not live from cursor.

---

## When previews clear

All committed move previews stay visible through planning until:

1. **Ready to Execute** is pressed, or  
2. That walk **starts animating / executing**.

**Execution phase:** **Zero planning UI** — no blue tiles, no hover paths, no planning overlays. Only the actual turn playing out.

Do not add extra clear rules beyond this.

---

## Movement steps (same behavior, different slot)

**Simple rule:** If the character **moves to another tile**, that is a **blue move preview** — same look, same paint, same path truth. Only **when it commits** and **when it runs** on Execute differ.

| Step | Same as premove? | Only difference |
|------|------------------|-----------------|
| **Premove** | — | Commits to PRE slot; runs before the action |
| **MOVE module** | Same preview | Commits to the skill’s MOVE leg; stand/handoff for next module |
| **Postmove** | **Exactly like premove** | Commits to POST slot; runs after the action |

**Painted routes:** Drag through blue tiles to build a path; preview follows that route to the hover tile.

**Run:** No change to current behavior — run icon already signals when Run is used.

**Teleport / blink:** Not a real walk. Preview is a **direct line** from start tile to landing tile (hop), not a stepped corridor.

---

## Latest predicted stand

Where the unit stands **after everything already committed** this turn — not necessarily turn-start. Walk preview, **blue tiles**, and **red tiles** all measure from this stand unless a rule below says otherwise.

---

## Tile colors (global)

Three tile layers. Same rules everywhere — no per-skill tile forks.

### Blue tiles — where can I walk?

**Meaning:** Legal **movement** range — tiles this unit can reach in the current **movement step**.

**When shown:**

- Premove  
- Active **movement module** (skill MOVE leg)  
- Postmove  

**When not shown:** Any non-movement module (damage, target pick, wait, etc.). Blue during those steps is a bug (frozen **path line** from an earlier commit is still OK — that is not the blue *range* field).

**Hover:** During a movement step, the tile under the mouse is part of the walk preview (see move path rules above).

---

### Red tiles — where can the *next* module reach?

**Meaning:** Range of the **next module** in the skill chain, **only when that next module is not a movement module**.

Examples: after premove, red shows where the upcoming **damage** module can aim from latest stand; not “where I can walk.”

**Origin:** Latest predicted stand (after committed legs).

**When not shown:** When there is no upcoming non-movement module, or when a special case below replaces hover red with blue.

---

### Yellow tiles — what does this module hit?

**Meaning:** Tiles **affected by the current module** (one tile for non-AOE; full footprint for AOE).

**When shown:**

- **Hover** — while aiming the current module (before commit).  
- **Committed** — after target/tiles for this module are locked in.

**Not** a substitute for red (range) or blue (walk).

---

### Hover highlight outline

When the tile under the mouse is **also** part of the premove/module tile field (blue or red), draw a **faint outline** on that hover tile so it does not blend into the field.

Apply to **both** blue-hover and red-hover cases.

---

## Case: skill **starts** with a move module (premove + armed skill)

While planning **premove** before the skill’s first module runs:

1. **Blue field** — normal premove walk range (from latest stand).  
2. **Under the mouse** — show **blue** reach around the cursor (walk context), **not** red next-module range on the hover tile.  
3. **Red field** may still show elsewhere for the upcoming non-move module, but the **hovered** tile uses the blue-hover treatment + faint outline.

Same global colors; this case only swaps **what the cursor tile uses** during premove when the skill’s first module is MOVE.

---

## Lines and arrows (global)

| What | UI |
|------|-----|
| **Voluntary walk** (premove / MOVE module / postmove) | Solid path — move preview; path = walked path |
| **Teleport / blink** | Direct **dashed** line start → landing (hop, not a walked corridor) |
| **Push / pull / forced displacement** on another unit | **Separate** UI — not blue walk path, not yellow blast |
| **Targeting intent** (e.g. strike arrow to enemy) | Separate from walk path; does not replace move preview |

---

## Co-op

Everyone sees all units’ move previews. Option to hide others’ previews may come later.

---

## Common bugs (do not ship)

| Symptom | Wrong because |
|---------|----------------|
| New walk arrows on damage / target step | Not a movement step |
| Blue walk tiles during non-move module | Only movement steps get blue **range** |
| Red tiles showing walk range | Red is next **non-move** module only |
| Yellow on wrong module or wrong footprint | Yellow = **current** module effect |
| Hover tile blends into blue/red field | Missing faint outline |
| Path on screen ≠ path walked | Preview is not truth |
| Push/pull/knockback shown as blue walk path | Forced displacement is different UI |
| Old premove ghost affects later module | Module handoff / stand wrong |
| Planning UI visible during execution | Execution = zero planning UI |

---

## Acceptance examples

- **Any walk leg:** Blue move preview — character moves tile to tile → same preview rules.  
- **Postmove:** Same as premove; only commit slot and execution order differ.  
- **Teleport:** Straight hop line, not a walked path.  
- **Tiles:** Blue = walk range in movement steps; red = next non-move module range; yellow = current module impact (hover or committed).

---

## Open questions (owner)

See chat / update this section when answered — gaps the global rules do not settle by themselves.
