# Move preview rules (owner spec)

**Status:** ACTIVE — canonical player-facing behavior for walk previews during planning.  
**Related:** `class_abilities.txt` (economy/timeline), `PLANNING_SKILL_QA_CHECKLIST.md` (preview = commit truth).

This doc states the game rules in plain language. Implementation must follow these rules; agents should not invent parallel preview logic.

---

## The one rule

**If the player is in a movement step** (premove, the skill’s MOVE module, or postmove):

- Show a **live** walk preview from **latest predicted stand** to the mouse (or along a **painted drag route** to the hovered tile).

**If the player is in any other step** (damage, pick target, wait, etc.):

- **Do not** draw a new live walk from the mouse.
- **Do** keep showing any walk that was already **committed** but not yet **executed** (frozen route).

**Move previews clear only when the walk actually runs** at turn execution — not when you advance to the next module, not when you change target, not when you arm another part of the same ability.

---

## Modular skills = chained mini-skills, one resource

Treat each **module** of a multi-part ability as **its own skill use**, one after another, all paid from the **same ability / AP / timeline slot**.

Example — **Trampling Advance**:

1. **MOVE module** — “Walk here.” Player commits a landing tile and path. That leg is **done**. Predicted stand updates.
2. **DAMAGE module** — “Hit from where you landed.” Starts from the **new** stand. It does **not** get to redraw or replace the walk; the walk module already finished.

Example — **Charge Strike**:

1. Premove (if used) → commit → new stand.  
2. Charge MOVE module → commit → new stand.  
3. Strike (damage / target) → only uses stand **after** prior committed legs.

**Handoff rule:** When module N finishes, module N+1 only sees the board **after** everything committed in modules 1…N. Earlier legs must not leak path or stand into later legs.

---

## Live vs frozen preview

| Situation | What the player sees |
|-----------|----------------------|
| **Choosing** a walk (movement step active, not yet committed) | Live preview: stand → mouse (or painted route to hover) |
| **Committed** a walk, now on a non-movement step | **Frozen** committed route — same path as at commit |
| **Committed** a walk, still planning before Execute | Frozen route **stays visible** until that walk runs |
| **Turn executes**, walk resolves | Move preview for that leg **clears** (after animation / resolution as appropriate) |

Frozen does **not** mean hidden. It means: **no new corridor from the cursor**; show what was locked in.

---

## Movement steps (when live preview applies)

All three use the **same** live preview behavior; only **which timeline slot** receives the commit differs:

| Step | When |
|------|------|
| **Premove** | Walk before the action |
| **MOVE module** | Walk leg inside a skill (e.g. Trampling Advance landing) |
| **Postmove** | Walk after the action |

**Painted routes:** Dragging through blue tiles builds a path. Live preview follows that painted route to the hovered cell, not only a single-step hop.

**Move + damage on the same hover** (e.g. Charge Strike on the MOVE module): Blue walk preview and red hit preview can both show. Blue still follows the movement-step rule; red follows targeting rules from the **landing** stand.

---

## Latest predicted stand

**Latest predicted stand** = where the unit would stand **after all committed planning so far** (premove, committed move modules, swaps, etc.), not necessarily turn-start position.

- Red action range, blue walk tiles, and walk preview origin all use this stand during planning.
- After each **committed** movement leg, stand advances for the next module.

---

## Preview = commit truth

What the player sees in the last valid preview for a click is what commit must lock:

- Same path / waypoints  
- Same landing tile  
- Same predicted stand for the next step  

Commit must not jump to a different route than preview showed. Execution must match commit.

---

## Performance (player-visible)

- **While moving the mouse:** Path arrows and tiles should update smoothly (lightweight path paint).
- **When the pointer settles:** Heavier “what-if” simulation may run to validate AP, damage preview, etc.

Sluggish hover is a bug; throttling must not change **what** preview means, only **when** expensive validation runs.

---

## Common failure modes (do not ship)

| Symptom | Violation |
|---------|-----------|
| On damage step, mouse draws **new** walk arrows | Non-movement step using live walk preview |
| Committed walk **disappears** when opening next module | Cleared preview before execution |
| Strike range/path uses **old** premove position | Module handoff / latest stand wrong |
| Commit path ≠ last hover preview | Preview ≠ commit |
| Premove path **duplicated** or walk animates twice | Same leg merged or applied twice |

---

## Acceptance (plain language)

- **Trampling Advance:** Paint and commit landing → frozen walk stays visible on damage targeting; mouse does not paint alternate walks; preview clears only after Execute runs the walk.  
- **Charge Strike:** After premove + charge commit, strike preview uses charge landing stand, not premove ghost.  
- **Any skill:** Movement step = live stand→mouse; other steps = frozen committed walks only until execution.
