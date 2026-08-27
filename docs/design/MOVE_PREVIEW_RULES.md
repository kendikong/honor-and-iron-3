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
- Those use their own arrows / markers; do not mix them into the walker's blue move path.

**Teleport / blink:** Not a walked path — direct line from start tile to landing (hop). Still the character's own relocation, not push/pull UI.

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
| **MOVE module** | Same preview | Commits to the skill's MOVE leg; stand/handoff for next module |
| **Postmove** | **Exactly like premove** | Commits to POST slot; runs after the action |

**Painted routes:** Drag through blue tiles to build a path; preview follows that route to the hover tile.

**Run:** No change to current behavior — run icon already signals when Run is used.

**Teleport / blink:** Not a real walk. Preview is a **direct line** from start tile to landing tile (hop), not a stepped corridor.

---

## Latest predicted stand

Where the unit stands **after everything already committed** this turn — not necessarily turn-start. Walk preview, **blue tiles**, and **red tiles** all measure from this stand unless a rule below says otherwise.

---

## Tile colors (global)

**Two range fields** during planning (except **Wait**). Same rules everywhere.

### 1 — Current phase (locked)

The **current** module/phase range, from the stand **when this phase started**:

| Current phase | Color |
|---------------|--------|
| **Movement** (premove, MOVE module, postmove) | **Blue** — legal walk this phase |
| **Non-movement** (damage, target pick, etc.) | **Red** — where this phase can aim from that start stand |

Locked until the phase ends. Does not follow the mouse.

### 2 — Next phase (on hover)

If there **is** a next phase **and** it is **possible** from the hover tile, show that phase's range from **predicted stand at hover**:

| Next phase | Color |
|------------|--------|
| **Movement** | **Blue** |
| **Non-movement** | **Red** |

No next phase, or not possible from that tile → **no second range**.

**Faint outline** on the hover tile when it sits inside a blue or red field.

### Yellow — hover selection (Triangle Strategy style)

**Yellow** = what your **click would affect** at the current hover — movement destination tile **or** skill target footprint.

- **AOE:** show the **full affected tile set** at hover (not just the cursor cell).  
- **Non-AOE:** the single target tile.  
- **Hover only** — does **not** freeze or persist after commit; move the mouse → yellow updates.  
- **Invalid tile** — **no** yellow (invalid cursor only).

### Wait

Last planning phase before Execute. **All tiles off** — no blue, red, or yellow.

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

Everyone sees all units' move previews. Option to hide others' previews may come later.

---

## Common bugs (do not ship)

| Symptom | Wrong because |
|---------|----------------|
| New walk arrows on damage / target step | Not a movement step |
| Blue walk tiles during non-move module | Only movement steps get blue **range** |
| Red tiles showing walk range | Red is next **non-move** module only |
| Yellow on wrong tile | Yellow = **hover-only** click footprint (AOE = full blast) |
| Yellow on invalid hover | No yellow — invalid cursor only |
| Yellow frozen after commit | Yellow does **not** freeze |
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
- **Tiles:** Locked field = current phase (blue move / red aim). Hover may add **next** phase field from predicted stand. Yellow = hover selection. Wait = all off.

---

## Resolved (owner 2026-08-26)

- Two ranges: **current** (locked at phase-start stand) + **next** (from hover predicted stand, if any).  
- Yellow = hover-only click footprint (AOE = full blast; Triangle Strategy style). No yellow on invalid. Does not freeze.  
- Wait = last phase; all tiles off.

---

## Implementation SSOT (code owners)

| Concern | Owner |
|---------|--------|
| Planning phase (movement / non-move / wait) | `PlanningPreviewTiles.planning_phase` |
| Two-range tile origins + yellow blast | `PlanningPreviewTiles.resolve_layer_origins` (`show_action_range` gates red/yellow once) |
| Voluntary walk path write (hover) | `CombatPlanningInput._set_preview_path` via `_write_movement_hover_preview_paths` when `live_move_hover_rewrite_applies` |
| Painted drag → `preview_paths` | `CombatPlanningInput._sync_painted_drag_route_to_preview_paths` → `_set_preview_path` |
| Sim / commit path merge | `CombatPlanningPreview.apply_result` — `authoritative_paths` restore + `skip_path_merge` in `ensure_movement_intent_from_actions`; anchor skipped for authoritative actor |
| Movement-step authority gate | `CombatPlanningInput._movement_hover_path_authoritative` |
| Painted route lock predicate | `CombatPlanningInput._painted_drag_route_matches_leg` |
| Path display (read) | `CombatPlanningPreview.display_route_cells_from_preview` via `CombatPlanningInput.display_move_route_cells` |
| Path data store | `CombatPlanningPreview.preview_paths` |
| Tile layers (one entry + one apply) | `_recompute_hover_ranges_from_inputs` → `TacticalPlanningOverlay._apply_planning_tile_layers` |
| Action-range stand (aim origin) | `CombatPlanningInput.action_range_intent_stand_cell` (overlay `_intent_stand_origin` delegates) |
| Targeting intent arrow (live hover) | `TacticalPlanningOverlay.targeting_intent_arrow_cells` |

### Architecture audit (2026-08-26 pass 5)

**Write paths (honest):**
- Live hover/drag/stand-stub (input): `_set_preview_path` → `set_unit_preview_path` + mandatory overlay sync.
- Sim timeline merge (preview): `apply_result` → `build_preview_paths` + `ensure_movement_intent_from_actions` with `skip_path_merge` for authoritative actors; `anchor_preview_paths_to_latest_stand` only when not authoritative.
- Post-commit promote trim: `trim_committed_paths_after_slot_promote` → `anchor_preview_paths_to_latest_stand` on committed snapshot only.
- Committed promote copy: `preview_state.preview_paths = committed.preview_paths.duplicate` after promote (display sync, not route calculation).
- Overlay display copy: `apply_preview_paths_only` mirrors input `preview_state` into `_live_preview` (not a route calculator).

**Read paths:**
- On-screen walk routes (live + frozen committed preview): `display_move_route_cells` → `display_route_cells_from_preview`.
- Committed timeline chevrons: same read API first; `movement_intent_cells` fallback only when preview has no route.

**Removed parallel paths (pass 5):**
- Overlay hover tile cache keyed on `_intent_stand_origin` (stale two-range risk).
- `set_hover_coord` → `_refresh_cursor_action_tiles` fork (second tile entry).
- Overlay `_intent_stand_origin` live-board duplicate (delegates to input stand SSOT).

**Pass 6 (gauntlet loop):**
- `_apply_preview_result_preserving_hover_paths` — snapshot/restore authoritative movement hover paths across `build_preview_paths` `paths.clear()`.
- `CombatPlanningPreview.set_unit_preview_path` — shared path assign for input + committed promote.
- `on_hover_moved` — single movement hover pipeline via `_refresh_movement_slot_hover_preview`.
- `tactical_side_panels` — tile refresh via `_recompute_hover_ranges_from_inputs` only.

**Pass 9 (gauntlet loop — cold-audit response):**
- Removed duplicate merge/anchor/swap from `_ensure_live_movement_intent_from_preview_actions` (merge owner is `apply_result` only).
- `_set_preview_path` always syncs overlay (`_live_preview` mirror).
- Committed ability route draw uses `display_route_cells_from_preview` first.
- Side panel tile refresh: `on_hover_moved` only (no double recompute).

**Pass 10 (gauntlet loop — critic HIGH fixes):**
- Removed `_can_show_action_range_tiles` (blast gated only by `resolve_layer_origins` `show_blast`).
- Post-commit path trim: `trim_committed_paths_after_slot_promote` only (no preview_state anchor before copy).
- Hover tile recompute: `set_hover_coord` only; `_run_hover_overlay_refresh` no longer duplicates.
