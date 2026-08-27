# Move preview rules (owner spec)

**Status:** ACTIVE — canonical player-facing behavior for walk previews during planning.  
**Related:** `class_abilities.txt`, `PLANNING_SKILL_QA_CHECKLIST.md`.

Plain-language rules. No parallel preview logic.

---

## Core truth

**The move preview is the source of truth.** Whatever path is shown is the path the character actually walks on Execute. Preview, commit, and execution must match.

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

| Step | When |
|------|------|
| **Premove** | Before the action |
| **MOVE module** | Walk leg inside a skill |
| **Postmove** | After the action |

**Painted routes:** Drag through blue tiles to build a path; preview follows that route to the hover tile.

**Run:** No change to current behavior — run icon already signals when Run is used.

**Teleport / blink:** Not a real walk. Preview is a **direct line** from start tile to landing tile (hop), not a stepped corridor.

---

## Latest predicted stand

Where the unit stands **after everything already committed** this turn — not necessarily turn-start. Walk preview, blue tiles, and action range all use this during planning.

---

## Co-op

Everyone sees all units’ move previews. Option to hide others’ previews may come later.

---

## Common bugs (do not ship)

| Symptom | Wrong because |
|---------|----------------|
| New walk arrows on damage / target step | Not a movement step |
| Blue walk tiles during non-move module | Only movement steps get blue tiles |
| Committed path vanishes when opening next module | Cleared too early |
| Path on screen ≠ path walked | Preview is not truth |
| Old premove ghost affects later module | Module handoff / stand wrong |
| Planning UI visible during execution | Execution = zero planning UI |

---

## Acceptance examples

- **Trampling Advance:** Commit landing → full frozen path on damage step; mouse does not paint new walks; Execute → planning UI gone; character walks the shown path.  
- **Charge Strike:** Strike uses stand after committed legs, not premove ghost.  
- **Teleport:** Straight hop line, not a walked path.

---

## Open (owner to confirm)

1. **Postmove:** After the action, is postmove painted the same way as premove (drag a route through blue tiles), or only one tile at a time?  
2. **Approach then swap:** Is the “step next to ally” walk previewed exactly like a normal premove/MOVE walk (blue tiles + path arrow)?
