# Move preview rules (owner spec)

**Status:** ACTIVE — player-facing planning behavior (paths, tiles, lines).  
**Implementation log (agents — not rules):** [`MOVE_PREVIEW_IMPLEMENTATION_LOG.md`](MOVE_PREVIEW_IMPLEMENTATION_LOG.md)  
**Related:** `class_abilities.txt`, `.cursor/rules/move-preview-intent-truth.mdc`

Plain-language rules. One pipeline. No parallel preview logic.

---

## Design principle

**Fewer global rules → fewer branches → one canonical path → simpler code.**

- One voluntary-walk rule for premove, MOVE module, and postmove — same preview, same paint, same commit shape; only slot and execution order differ.
- **Shown path = walked path.**
- **Hover paints intent. Click freezes it.** Nothing recomputes at commit.
- Exceptions are rare and explicit (forced push/pull UI, teleport hop) — not per-skill branches.

---

## Preview = commit truth (non-negotiable)

**What you see on hover is exactly what gets committed and frozen.**

- Click a tile → commit **ratifies** that picture. Path, landing, approach, facing — unchanged.
- **Nothing recomputes at commit.** No corridor builder, no approach invent, no second path at click time.
- **After you click, the preview must not change.** If the path, tiles, or ghosts jump to a different interpretation, that is a bug — not a feature.

If commit would need geometry the hover did not show, the hover preview was incomplete — fix hover paint, do not patch at commit.

---

## Timeline

**Turn order:** premove → skill modules → postmove → wait → Execute.

Same pipeline for every movement phase. Only **commit metadata** differs (timeline slot, `move_timing`, animate-on-commit).

**Do not** fork preview, origin, or path logic per PRE / MOVE / POST label.

### Stand / origin

**Forecast stand at the start of the current planning phase** = walk origin, blue range origin, red range origin.

- **Latest predicted stand** = **stand when this phase started** = **forecast at phase entry**.
- **Next phase on hover:** forecast stand at the next phase’s entry if that hover outcome happened — still one forecast system.
- **Sealed painted leg:** lock the phase-entry anchor so hover cannot drift off forecast.

**Forbidden:** turn-start / live-board / `base_board` as origin after a committed step; separate origin stacks per phase label or skill.

---

## What move preview is

**Move preview** = the path this character **walks** tile-to-tile to their **chosen destination** (blue tiles, path arrow, painted route).

**Not move preview:** forced movement on another unit (push, pull, knockback) — separate UI.  
**Teleport / blink:** direct hop line start → landing — not a stepped walk.

---

## The one rule

**Movement step** (premove, skill MOVE module, or postmove):

- Live walk preview from **latest predicted stand** to the mouse (or along a **painted drag route** to the hovered tile).

**Any other step** (damage, target pick, wait, etc.):

- **No** live walk from the mouse.
- **No** blue walk tiles.
- **Do** keep showing **committed** walks not yet executed (frozen full path).

**Modular skills:** each module finishes and hands off **stand** to the next. A later module does not redraw or replace an already-committed walk.

---

## Live vs frozen

| Situation | What you see |
|-----------|----------------|
| Choosing a walk | Live path: stand → mouse (or painted route) |
| Committed a walk, now on a non-move step | **Frozen** full committed path — mouse does not draw a new one |
| Invalid hover for this movement step | **No** move preview (invalid cursor only) |
| Undo a committed walk | Frozen path clears; on a movement step again → live preview works |

**Frozen** = show the locked path. Not live from cursor.

### Invalid hover vs sealed restore

| Situation | Movement step? | Hover legality | What you see |
|-----------|----------------|----------------|--------------|
| **Invalid movement-step hover** | Yes | Illegal tile | **No** blue path — sealed restore **must not** run |
| **Sealed restore** | No (skill step) or legal hover | Enemy on cell, non-extend hover | **Frozen** sealed path re-shown — not a new live corridor |
| **Sealed freeze** | Corridor paint off | Non-move-tile hover while sealed | **Frozen** landing path |

---

## When previews clear

Committed move previews stay visible until **Ready to Execute** or that walk **starts executing**.

**Execution phase:** zero planning UI — no blue tiles, hover paths, or planning overlays.

---

## Movement steps

If the character **moves to another tile**, that is a **blue move preview** — same look, paint, and path truth. Only **when it commits** and **when it runs** differ.

| Step | Only difference |
|------|-----------------|
| **Premove** | PRE slot; runs before the action |
| **MOVE module** | Skill MOVE leg; stand handoff for next module |
| **Postmove** | POST slot; runs after the action |

**Painted routes:** drag through blue tiles; preview follows that route to the hover tile.

**Teleport / blink:** hop line, not a walked corridor.

---

## Tile colors

**Two range fields** during planning (except **Wait**).

### Current phase (locked)

From stand **when this phase started**:

| Phase | Color |
|-------|--------|
| Movement | **Blue** — legal walk |
| Non-movement | **Red** — aim range |

### Next phase (on hover)

If a next phase is possible from the hover tile, show its range from **predicted stand at hover** (blue or red). Otherwise no second range.

**Faint outline** on the hover tile when inside a field.

### Yellow — hover selection

What your **click would affect** — destination tile or skill footprint (AOE = full blast). Hover only; no yellow on invalid; does not freeze after commit.

### Wait

All tiles off.

---

## Lines and arrows

| What | UI |
|------|-----|
| Voluntary walk | Solid path — walked path |
| Teleport / blink | Dashed hop line |
| Push / pull / forced displacement | Separate UI — not blue walk |
| Targeting intent (strike arrow) | Separate from walk path |

---

## Co-op

Everyone sees all units' move previews.

---

## Common bugs

| Symptom | Wrong because |
|---------|----------------|
| New walk arrows on damage / target step | Not a movement step |
| Blue walk tiles during non-move module | Blue range only on movement steps |
| Path on screen ≠ path walked | Preview is not truth |
| Preview changes after click | Commit recomputed or re-rendered — forbidden |
| Commit path ≠ last hover preview | Preview ≠ commit |
| Push/pull shown as blue walk | Forced displacement is different UI |
| Planning UI during execution | Execution = zero planning UI |

---

## Acceptance examples

- **Any walk leg:** blue move preview; tile-to-tile path = truth.  
- **Postmove:** same as premove; slot and timing only differ.  
- **Trampling Advance:** commit landing → frozen walk on damage step; mouse does not paint alternate walks.  
- **Charge Strike:** after premove + charge, strike uses charge landing stand.  
- **Tiles:** locked current field; hover may add next field; yellow = hover footprint; Wait = all off.
