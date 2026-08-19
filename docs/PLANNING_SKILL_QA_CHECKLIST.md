# Planning Skill QA Checklist

**Owner rule (absolute):** What you see in **move preview** is the truth. Commit must lock exactly that picture. Execute must match what was committed. If preview and commit disagree, that is a bug — not “close enough.”

Use this checklist for **every class skill** (manual F5 + automated tests). One skill = one full pass through all 7 phases below.

**Where to test manually:** Skill Arena / TestBattle (tactical combat, planning phase).

**Where automated tests live:** `.\scripts\run_planning_qa_gate.ps1` — see [PLANNING_QA_GATE.md](PLANNING_QA_GATE.md) for suite mapping.

---

## The 7 phases (minimum per skill)

Every skill test must record pass/fail at **each** phase. Do not skip a phase because “slots looked fine in code.”

### Phase 1 — Select unit and skill

**What you do:** Click your unit. Select the skill from the bar (or leave basic move selected).

**What must be correct:**

- **Selection:** The right unit is selected. Enemy units are not accidentally selected. Selection highlight matches the unit you clicked.
- **Blue move tiles:** Every blue tile is a tile you can legally reach this turn with current MP, movement type, and terrain. Tiles you cannot reach are not blue. If you already committed a PRE_MOVE, blue is calculated from your **projected** position and remaining MP — not from where you started the turn.
- **Blue when blocked:** Rooted, staggered, or out-of-MP units show no blue (or the correct reduced set). Bleed doubles move cost where rules say so.
- **Red skill-range tiles:** If a class skill is selected, red shows where that skill can target **from your current intent stand** (usually current projected position). Red is absent when no skill is selected, when Run/Wait is selected, or when the skill cannot be used (silence, stagger, pacify on attack skills, etc.).
- **Red anchor:** Red is drawn from where you would **stand** to use the skill, not from a stale start tile after you have already committed movement.
- **Red vs economy:** If using the skill after an implicit or committed move would cost too much AP/MP, red must hide — not show a range you cannot afford.
- **Move preview at rest:** With no hover yet, ghosts/paths should be idle or absent — not showing a path from a previous unit, previous skill, or previous hover.
- **Cursor:** Default planning cursor (or skill-appropriate idle cursor). No walk/run/attack composite until you hover a valid target.
- **AP/MP display:** Side panel or HUD shows correct AP and MP for the **projected** unit state (after committed pre-moves on the timeline).
- **Timeline:** Empty columns show empty. Any already-committed pre/action/post icons match what you committed earlier in the test.
- **No stale overlay:** Switching onto this unit from another unit clears the previous unit’s blue/red, paths, and arrows.

---

### Phase 2 — Hover empty tiles

**What you do:** Move the mouse over open tiles (no enemy on tile). Do not commit yet.

**What must be correct:**

- **Blue updates live:** As the cursor moves, the blue reachable set stays correct for the hovered intent. It does not flicker to a wrong set or freeze on the first tile you hovered.
- **Red follows stand:** Red skill range re-anchors to the tile you would stand on if you moved there (implicit premove / hover stand). Red tiles shift when the stand shifts — they do not stay drawn as if you were still on your start cell.
- **Red hide when illegal:** Hovering a tile that requires Run when you cannot afford Run + skill must hide red (or show that bash/trample/etc. is impossible after that premove). Same for any AP/MP rule that blocks the skill after that stand.
- **Move preview ghost:** Unit ghost (or path endpoint) appears on the hovered tile when that hover represents a valid move intent. Ghost position equals preview board position for your unit.
- **Path line:** If the game draws a path to the hover tile, every step is walkable, respects MP budget, and uses Run only when rules require Run. Path does not cut through blockers or show a route you cannot afford.
- **Path vs committed plan:** If you already have a committed PRE_MOVE, hovering other tiles shows preview **in addition to** or **instead of** committed state per rules — but never contradicts the timeline (e.g. ghost on a tile that committed plan says you will not visit).
- **Cursor on empty tile:** Walk glyph on adjacent/legal walk tiles; run glyph when destination requires run; no attack glyph on empty tiles unless a movement skill targets tiles.
- **Composite cursor:** If auto-use-skill-after-move is on and AP allows move+skill, cursor may show walk+attack (or run+attack) on tiles that set up a valid pair — only when both legs are actually affordable.
- **Arrows:** No push/pull/approach arrows on empty tiles unless a skill explicitly previews displacement through that hover (e.g. trample corridor). No orphan arrows from last hover.
- **Threat / danger overlay:** If enabled, danger tiles stay consistent with hover — no stale threat from previous cell.
- **Performance:** Hover does not leave trails of wrong tiles; moving mouse away clears or updates preview promptly.

---

### Phase 3 — Pathing (walk, run, drag)

**What you do:** Paint a path by dragging or stepping through tiles. Include at least one walk-only segment and one run-required segment if the skill test allows.

**What must be correct:**

- **Paint order:** Waypoints are stored in the order you painted them. Autocorrect on jump-drag does not silently reorder your corridor (e.g. east-then-north stays east-then-north).
- **Path preview:** The drawn route matches painted waypoints tile-for-tile. Preview path in data (`preview_paths`) matches what you see.
- **Run vs walk:** Tiles that require Run show run cursor/icon on commit preview; walk tiles show walk. Run is not shown when a walk suffices. Run is shown when distance/rules require it.
- **Run economy:** If Run would consume AP needed for the selected skill, red range and skill pairing behave correctly (hide red or drop skill leg — per design).
- **Blue during drag:** While dragging, blue reachable set reflects drag origin rules (fixed range origin if applicable). Illegal extensions are rejected or not painted.
- **Red during drag:** Red range anchors to the **end** of the current drag route (intent stand), not the drag start, unless rules say otherwise for awaiting-target skills.
- **Drop preview:** Releasing drag on a valid cell shows the same slots/preview as clicking that cell (click/drop parity).
- **Cancel drag:** Right-click or invalid cancel clears painted route and restores preview to committed + hover state — no leftover waypoints in slots.
- **Stale route rejected:** Changing hover or enemy target after a bad drag does not keep stale approach waypoints (e.g. diagonal shortcut that is not the canonical bash approach).
- **Occupancy:** Path cannot end on an occupied enemy tile for a plain move; skill approach rules handle enemy-adjacent stops correctly.
- **Timeline ghost:** Before commit, timeline ghost (if shown) matches painted intent — pre/action/post placement preview.

---

### Phase 4 — Hover enemy (and approach tiles)

**What you do:** Hover the enemy unit (and any approach tiles between you and the enemy). Do not commit until you have verified preview.

**What must be correct:**

- **Approach leg:** If you are not adjacent, preview builds a pre-move to the correct approach tile (e.g. bash approach `(6,5)` from knight `(4,5)` vs dummy `(7,5)`). Approach is walk or run per MP/rules — not an illegal diagonal or wrong flank if design specifies one approach.
- **Action leg:** Skill action targets the enemy (or correct cell), correct ability id, correct timing column (usually PRE_ACTION for bash/hook).
- **Walk + attack cursor:** Enemy hover shows composite cursor when move+skill is valid (walk+attack or run+attack). Cursor matches what slots will commit.
- **Red at attack stand:** Red tiles are centered on **approach / stand** cell, not knight’s pre-move start. Enemy must be inside red if in range from that stand.
- **Blue on enemy hover:** Blue still shows legal movement options from projected state where rules allow — not confused with attack range.
- **Push arrow (bash, etc.):** Orange push arrow points **away** from player. Segment is from enemy cell to landing cell. Arrow only appears when skill is valid.
- **Pull arrow (hook, etc.):** Orange pull arrow points **toward** player. Segment matches preview displacement.
- **Trample / tile skills:** For tile-target skills, hover shows valid target tiles in red; painted corridor matches trample path; awaiting-target state keeps red visible where rules say so.
- **Preview board:** Ghost positions match — knight on approach tile, enemy still on start until push/pull applied in preview; after push/pull, enemy on landing cell in preview board.
- **preview_pushes / displacement:** Data matches arrows — landing cell equals preview board enemy position.
- **Targeting cell:** Skills that need pre-push position target the enemy **before** displacement, not the cell they land on.
- **Out of range:** Hovering enemy when bash/hook cannot reach even with move shows invalid slots or no attack leg — not a lying attack cursor.
- **Switch hover:** Moving from enemy A to enemy B (if multiple) updates approach, arrows, and slots — no stale arrow toward first enemy.

---

### Phase 5 — Commit

**What you do:** Click or drop to lock the plan shown in preview.

**What must be correct:**

- **Preview = commit (absolute):** Timeline entries match last valid preview slots — same pre-move destination, same waypoints, same action target, same ability, same uses_run flag, same timing column.
- **No post-click jump:** Immediately after commit, ghosts, blue/red, paths, and arrows do not **change interpretation** relative to what preview showed on the frame before click. Commit ratifies; it does not recalculate a different move or attack.
- **Promote path:** Live preview is promoted to committed display; stale live preview board is cleared; overlay recomputes tiles from new projected state.
- **Timeline icons:** PRE_MOVE shows walk or run icon matching committed step. ACTION shows skill icon. POST_MOVE if used shows move icon.
- **Projected AP/MP:** After commit, projected unit AP/MP match what preview implied (e.g. committed run only → 0 AP if run costs 1 AP and you had 1).
- **Red after commit:** If skill is no longer affordable from new projected state, red hides (e.g. bash selected, run committed, 0 AP, hover destination → **no red**).
- **Blue after commit:** Move range reflects remaining MP and whether another move slot is open.
- **Cursor after commit:** Cursor glyph matches new state (often run icon on committed run dest, or idle on exhausted unit).
- **Undo available:** If rules allow undo, undo stack includes what you just committed.
- **Reject invalid:** Invalid click does not partial-commit — no half timeline, no corrupted preview.
- **Click vs drop:** Same cell → same commit for click path and drag-drop path.
- **Sound/UI:** Reject sound on invalid only; no false success feedback.

---

### Phase 6 — Execute

**What you do:** End planning and run the turn (or run sim in headless test).

**What must be correct:**

- **Unit positions:** Every unit ends on the cell preview and commit promised. Knight on approach/final cell; enemy on pushed/pulled cell or original if no displacement.
- **Push direction:** Bash pushes away from attacker along correct axis. Hook pulls toward attacker. No sideways or zero-length displacement unless design says so.
- **Order of resolution:** Pre-move resolves before action; post-move after action; matches timeline column order.
- **Run spend:** Run consumes AP and applies run boost when committed step uses run. Walk consumes MP only when walk step.
- **Damage / effects:** HP, armor, statuses match preview predictions where preview shows them.
- **Failed action:** If sim would fail, preview should have blocked commit earlier — no surprise fail after honest preview.
- **Determinism:** Same plan executed twice → same result (no combat RNG).
- **Animation layer (manual):** Sprites follow committed path smoothly; no teleport except where sim says teleport. See Layer B.

---

### Phase 7 — Pre-move / post-move after

**What you do:** After a commit (or partial plan), add or change PRE_MOVE or POST_MOVE — e.g. commit walk first, then skill; or skill then post-move reposition.

**What must be correct:**

- **Column rules:** PRE_MOVE fills before action when appropriate; POST_MOVE only when action slot allows; no illegal double-fill of same timing slot.
- **Re-run phases 2–6:** After each new commit, hover empty tiles, path, enemy hover, commit, and execute all behave as in phases 2–6 — using **new** projected stand as the baseline.
- **Red/blue refresh:** Tiles recompute from projection + timeline — not from turn-start position.
- **Approach from new stand:** Enemy hover builds approach from **committed** pre-move destination, not from original spawn cell.
- **Arrows refresh:** Push/pull preview uses new geometry after pre-move committed.
- **Undo boundaries:** Undo last action removes skill but may keep pre-move (per rules); tiles/preview match after undo.
- **Exhaustion:** When AP/MP/slots are exhausted, blue/red hide correctly; wait/run rules apply.
- **No ghost bleed:** Committed timeline ghost clears when live hover matches committed pre-move; live ghost does not stack on committed ghost incorrectly.

---

### At every phase — check these layers together

Do not pass a phase if only one layer looks right. All applicable rows must pass.

| Layer | What must be correct |
|-------|----------------------|
| **Blue tiles** | Set equals legal reachable tiles for projected MP, movement type, terrain, bleed, root/stagger, and open move slot. Updates when hover, drag, commit, or timeline changes. Never includes blocked or out-of-budget cells. |
| **Red tiles** | Set equals skill range from **intent stand** (hover stand, path end, or projected position). Hidden when no skill, Run/Wait selected, skill illegal, or economy forbids skill after premove. Overlay red matches `action_range_visible_for_hover()` gate. |
| **Move preview** | `preview_board` unit positions match ghosts. `preview_paths` match drawn path. Clearing hover clears or updates preview — no orphan preview board. Live preview active flag matches whether preview is shown. |
| **Arrows** | Push/pull/trample/approach arrows match `preview_pushes` and design direction. Arrows disappear when intent becomes invalid. No arrows from previous hover cell. |
| **Cursor** | `compute_hover_action_icon` / commit-slot cursor match intent (walk, run, attack, composite, wait). Hidden or default when invalid. |
| **Slots / timeline** | `_final_commit_slots_for_interaction` (or click/drop equivalent) matches preview. pre/action/post arrays match timeline after commit. Waypoints preserved. `uses_run` correct. |
| **Economy** | `planning_display_ap_left` / projected AP match preview. MP idem. Run cost applied in projection when run step committed or previewed. |
| **Parity** | Hover slots = click slots = drop slots for same cell. Preview = commit. Commit = sim (for execute phase). |

**Automated tests must assert the same layers** at each scripted step (overlay tile sets + live preview + slots + sim). Slot-only checks alone are **not** enough.

---

## Recording a manual run

Copy this block per skill, per build:

```
Skill: _______________  Date: _______  Build/commit: _______

Phase 1 — Select
[ ] Blue correct for MP / projection / terrain
[ ] Red correct or hidden (skill, economy, status)
[ ] Red anchored on stand not stale start
[ ] Cursor + AP/MP + timeline baseline

Phase 2 — Hover empty
[ ] Blue + red follow cursor / intent stand
[ ] Ghost + path match hover; no stale tiles
[ ] Cursor walk/run correct; arrows absent unless valid

Phase 3 — Pathing
[ ] Paint order preserved; preview path = painted
[ ] Run vs walk icon + economy; red at path end
[ ] Click/drop parity; cancel clears stale route

Phase 4 — Hover enemy (or tile target)
[ ] Approach + action legs; composite cursor
[ ] Red at attack stand; push/pull arrows + preview board

Phase 5 — Commit
[ ] Timeline = last preview; no post-click jump
[ ] AP/MP projected; red/blue refresh (e.g. run + 0 AP)

Phase 6 — Execute
[ ] Positions + push/pull + order match preview/sim

Phase 7 — Pre/post move
[ ] Re-check phases 2–6 from new projected stand

Notes / failures:
```

---

## Skill walkthroughs — what you should **see** (specific)

Below: exact boards, cells, cursors, timeline icons, and preview positions.  
**Training Arena / QA fixture** unless noted: open 12×12 plain grid, knight **1 AP / 3 MP** (knight default), auto-run **on**, auto-skill-after-move **on**.

**Economy (read from code, not ability names):** Knight has **1 AP / 3 MP** per turn (`knight_factory.gd`). **Every knight class skill costs 1 AP** — `DataLibrary._make_ability(..., ap_cost: 1)` in `knight_factory.gd`. **Run also costs 1 AP** when a step requires it. So with 1 AP you get **one** of: a class skill, **or** a run-required move — **not** run + skill in the same turn.

**Do not confuse range with AP:** Numbers in ability names or upgrade text (e.g. Chain Hook **range 3**, Trampling Advance **range 2**, Bowling Charge **range 3** dash) are `range_tiles` / effect amounts — **not** `action_point_cost`. Trampling Advance additionally costs **2 MP** (`movement_point_cost = 2`), not extra AP.

**Legend**

- **K** = knight · **E** = enemy dummy · **.** = empty  
- **Blue** = move range overlay · **Red** = selected skill range overlay  
- **Ghost** = translucent unit on preview board · **→** = path or push/pull arrow  

---

## Shield Bash (`knight_shield_bash`) — full 7 phases

**Skill:** 1 AP · melee range **1** · **PUSH 2** (east when knight is west of dummy)

**Board (start):**

```
      3   4   5   6   7   8   9
  5   .   .   K   .   .   E   .
```

- **K** = `(4,5)` · **E** = `(7,5)` · canonical **approach** = `(6,5)` (tile east of K, west of E)

---

### Phase 1 — Select knight + Shield Bash

**You do:** Click knight. Click Shield Bash on the bar.

**You must see:**

| What | Exactly |
|------|---------|
| **Selection** | Knight at `(4,5)` highlighted. Dummy stays at `(7,5)`. |
| **AP / MP** | **1 / 1** AP and **3 / 3** MP (full pools). |
| **Blue tiles** | Walk reach from `(4,5)` with 3 MP — includes `(3,5)(5,5)(4,4)(4,6)` and tiles up to 3 steps away on open ground. Does **not** include dummy cell `(7,5)`. |
| **Red tiles** | Small pattern around **knight stand `(4,5)`** only (range-1 bash footprint from current stand). **Dummy `(7,5)` is NOT covered in red** — too far to bash from start. |
| **Ghost / path** | **None** (no hover yet). |
| **Arrows** | **None**. |
| **Cursor** | Default planning cursor (not walk/run/attack composite). |
| **Timeline** | PRE / ACTION / POST empty. |

---

### Phase 2 — Hover empty tiles (no commit)

**You do:** Move mouse over empty tiles. Try at least: `(5,5)`, `(3,4)`, `(3,6)`.

**Hover `(5,5)` — one step east:**

| What | Exactly |
|------|---------|
| **Ghost** | Knight ghost on **`(5,5)`**. |
| **Path** | Line **`(4,5) → (5,5)`** (one walk step). |
| **Blue** | Reachable set from **projected** start `(4,5)` still (no commit). |
| **Red** | Red range **re-anchored to `(5,5)`** (intent stand). Still **does not** reach dummy at `(7,5)`. |
| **Cursor** | **Walk** icon. |
| **Arrows** | None. |

**Hover `(3,6)` — run-required tile (typical with 0 MP test setup):**

| What | Exactly |
|------|---------|
| **Ghost** | Knight ghost on **`(3,6)`** (if valid). |
| **Path** | Uses **run** segment when distance/rules require run. |
| **Cursor** | **Run** icon on commit preview for that tile. |
| **Red** | **Off** — run would consume your only AP, so Shield Bash (1 AP) cannot follow. **No red anywhere.** |

**Hover `(5,5)` with only 1 AP:** You may see walk cursor and path; red re-anchors to `(5,5)` but still does not reach dummy. Pairing bash on enemy still costs 1 AP on commit — you have exactly enough for **one** bash after walk, not bash after run.

**Moving mouse away:** Ghost, path, and stale red at old stand **clear or update** — no red still drawn as if knight were on start `(4,5)` while ghost is elsewhere.

---

### Phase 3 — Pathing (walk toward approach)

**You do:** Drag or step a path toward `(6,5)` — e.g. paint **`(4,5) → (5,5) → (6,5)`**.

**You must see:**

| What | Exactly |
|------|---------|
| **Painted route** | Waypoints in order: `(4,5)`, `(5,5)`, `(6,5)` — not reordered to a shortcut. |
| **Path overlay** | Same cells as painted route. |
| **Ghost at end of drag** | Knight ghost on last painted cell (e.g. `(6,5)` when path complete). |
| **Red** | Anchored on **path end / hover stand** `(6,5)`, not on `(4,5)`. From `(6,5)`, red **includes dummy `(7,5)`** (adjacent, in bash range). |
| **Cursor (on path end)** | **Walk** icon for pure walk path; **Run** only if a step requires run. |
| **Timeline** | Still empty until commit — only **preview**, not committed yet. |

---

### Phase 4 — Hover enemy (dummy at `(7,5)`)

**You do:** With Shield Bash selected, hover the **dummy** (not just approach tile).

**You must see:**

| What | Exactly |
|------|---------|
| **Ghost knight** | On **`(6,5)`** (approach tile), **not** on `(4,5)`. |
| **Path** | Walk path **`(4,5) → (5,5) → (6,5)`** (or equivalent minimum walk approach on open board). |
| **Cursor** | **Walk + attack** composite (walk glyph + attack glyph). |
| **Red tiles** | Centered on stand **`(6,5)`**; **dummy cell `(7,5)` inside red**. |
| **Orange push arrow** | Starts on dummy **`(7,5)`**, points **east**, ends on landing cell (open board: **`(9,5)`** with PUSH 2 — arrow tip = preview landing). |
| **Preview board** | Knight at **`(6,5)`**; dummy **starts `(7,5)`**, then appears at **arrow tip** (e.g. **`(9,5)`**) after push resolution in preview. |
| **Slots (if inspected)** | PRE: move to **`(6,5)`** · ACTION: Shield Bash targeting enemy id **2** at **`(7,5)`**. |

**Wrong (fail):** Ghost on `(4,5)` while showing bash on enemy. Red drawn from `(4,5)`. Push arrow north/south/west. Approach to `(5,5)` when hovering enemy (stale drag). Cursor attack-only with no walk leg when approach required.

---

### Phase 5 — Commit (click dummy or approach per your hover)

**You do:** Click to commit exactly what phase 4 preview showed.

**You must see (immediately after click, no mouse move):**

| What | Exactly |
|------|---------|
| **Timeline PRE** | Walk (or run) icon · destination **`(6,5)`** · `uses_run` = false for walk approach. |
| **Timeline ACTION** | Shield Bash icon · target enemy. |
| **AP / MP after** | **0 / 1** AP (bash spent your only action point) · MP reduced by walk steps (e.g. **1 / 3** after two east steps from `(4,5)` to `(6,5)`). |
| **Ghost / live preview** | Promoted to **committed** picture — same knight/enemy positions as last preview. |
| **Blue / red** | **Red OFF** — 0 AP left, cannot bash again. Blue shows remaining move range from `(6,5)` if MP left. |
| **No jump** | Arrow tip, ghost, and timeline **do not change** to a different approach or target than preview showed. |

**Special case — commit RUN only (your regression):**

- Setup: **1 / 1** AP, **0 / 3** MP, auto-run on, Shield Bash selected.  
- Hover run destination e.g. **`(3,6)`** → run cursor → commit **run only**.  
- **Timeline PRE:** **Run** icon · dest **`(3,6)`** · `uses_run` = true.  
- **AP after:** **0 / 1** (run spent your only AP).  
- **Red:** **OFF** everywhere — bash cannot fire with 0 AP.  
- **Mouse still on `(3,6)`:** Still **no red**.  

---

### Phase 6 — Execute

**You do:** End planning; run turn.

**You must see:**

| What | Exactly |
|------|---------|
| **Knight** | Ends **`(6,5)`** (after pre-move resolves). |
| **Dummy** | Ends on **push landing cell** = orange arrow tip from phase 4 (e.g. **`(9,5)`** on open board). |
| **Order** | Pre-move walk **then** bash **then** push — not bash before knight reaches `(6,5)`. |
| **Match preview** | Final positions **equal** preview board from phase 4 / commit. |

---

### Phase 7 — Pre-move then bash (two-step plan)

**You do:** Commit **walk only** to `(5,5)` first. Then hover dummy and commit bash.

**After first commit (walk to `(5,5)` only):**

| What | Exactly |
|------|---------|
| **Timeline** | PRE: walk to **`(5,5)`** only. ACTION empty. |
| **Projected knight** | **`(5,5)`**. |
| **Blue / red** | From **`(5,5)`** — red still does not reach dummy until you hover enemy for approach to `(6,5)`. |

**After hover enemy + second commit:**

| What | Exactly |
|------|---------|
| **Timeline** | PRE: **`(6,5)`** (or combined plan per rules) + ACTION: bash. |
| **Preview** | Same as single-step bash: ghost **`(6,5)`**, push east from **`(7,5)`**. |

**Automated coverage:** partial — see table at end of doc. **Gap:** no single test asserts every row above in order.

---

## Chain Hook (`knight_chain_hook`) — full 7 phases

**Skill:** **1 AP** · **range 3** · **PULL 2** (`knight_factory.gd` — third `_make_ability` arg is range, fifth is AP)

**Board (start):**

```
      0   1   2   3   4   5
  3   .   K   .   .   E   .
```

- **K** = `(1,3)` · **E** = `(4,3)` (Manhattan **3** — at hook **range** edge from start)

---

### Phase 1 — Select Chain Hook

| What | Exactly |
|------|---------|
| **AP / MP** | **1 / 1** AP · **3 / 3** MP |
| **Blue** | Full 3 MP walk reach from `(1,3)` |
| **Red** | Around stand `(1,3)` — **dummy `(4,3)` IS in red** (range 3 reaches Manhattan 3). |
| **Ghost / arrows** | None |

### Phase 2 — Hover empty `(2,3)`

| What | Exactly |
|------|---------|
| **Ghost** | `(2,3)` |
| **Path** | `(1,3) → (2,3)` |
| **Red** | Re-anchored to `(2,3)` — dummy still in red (distance 2 ≤ 3) |

### Phase 3 — Pathing / direct-range boundary

Do **not** paint an approach route for this fixture. Chain Hook is already in
range from the canonical start `(1,3)` to enemy `(4,3)`; the direct-hook branch
must prove that no `(3,3)` heuristic route is invented.

| What | Exactly |
|------|---------|
| **Stand** | Remains `(1,3)` |
| **Action range** | Enemy `(4,3)` remains legal at distance 3 |
| **Slots** | ACTION Chain Hook only; no synthetic PRE approach |

### Phase 4 — Hover enemy `(4,3)`

| What | Exactly |
|------|---------|
| **Ghost knight** | **`(1,3)`** (canonical direct-hook stand) |
| **Cursor** | **Chain Hook action** |
| **Orange pull arrow** | **`(4,3) → (2,3)`** (west, toward knight) — PULL 2 |
| **Preview dummy** | Lands **`(2,3)`** on preview board |
| **Dashed line (manual)** | Player `(1,3)` to enemy `(4,3)` targeting segment (Layer B pixels) |

### Phase 5 — Commit

| What | Exactly |
|------|---------|
| **Timeline** | ACTION Chain Hook on enemy; no invented PRE walk |
| **AP after** | **0 / 1** (hook spent your only AP) |
| **No jump** | Pull arrow and landing cell unchanged vs preview |

### Phase 6 — Execute

| What | Exactly |
|------|---------|
| **Knight** | **`(1,3)`** |
| **Dummy** | **`(2,3)`** (matches preview landing) |

### Phase 7 — Committed pre-move then hook

Commit walk to `(2,3)` first · projected stand `(2,3)` · hover enemy from new
stand · range/arrow refreshes from `(2,3)` · **no** `(3,3)` route or POST
approach is invented.

---

## Trampling Advance (`knight_trampling_advance`) — full 7 phases

**Skill:** **1 AP** · **2 MP** (`movement_point_cost`) · **range 2** tiles · tile-target movement skill

**Board (E2E reference):**

```
      4   5   6
  3   .   .   T
  4   .   K   .
```

- **K** = `(5,4)` · painted route **`(5,4) → (6,4) → (6,3)`** · end **`(6,3)`**

---

### Phase 1 — Select Trampling Advance

| What | Exactly |
|------|---------|
| **Red** | Trample target pattern from current stand (tile-target range 2) |
| **Blue** | Normal move range |

### Phase 2–3 — Arm + paint corridor

**You do:** Select skill → arm awaiting targeting → drag **east then north**.

| What | Exactly |
|------|---------|
| **Paint order** | `(5,4)` → `(6,4)` → `(6,3)` — **not** north-first shortcut |
| **Path preview** | Same three cells in same order |
| **Red** | Stays visible while awaiting (skill still armed) |

### Phase 4 — Hover end tile `(6,3)`

| What | Exactly |
|------|---------|
| **Ghost / path** | Full painted corridor to `(6,3)` |
| **No enemy** | Tile skill — no bash-style push arrow on units |

### Phase 5 — Commit

| What | Exactly |
|------|---------|
| **Timeline ACTION** | Trample with waypoints **`(6,4)`, `(6,3)`** preserved |
| **AP / MP** | **1 AP** and **2 MP** spent per skill rules |

### Phase 6 — Execute

| What | Exactly |
|------|---------|
| **Sim path** | Knight visits **`(6,4)` then `(6,3)`** in that order |

### Phase 7 — Pre-move walk then trample

**You do:** Commit basic walk to `(6,4)` · then arm trample · paint `(6,4)→(6,3)` · commit.

| What | Exactly |
|------|---------|
| **Timeline** | PRE walk + ACTION trample |
| **Tiles** | Recomputed from **`(6,4)`** stand, not `(5,4)` |

---

## Bowling Charge — red tile / run economy (1 AP skill)

**Skill:** **1 AP** · **range 3** (dash) · DASH 3 + BULLDOZE (`knight_factory.gd`)

**Board:** Knight `(4,5)`, dummy `(7,5)`, auto-run on, knight **1 / 1** AP

**Also applies with Shield Bash selected** (your main F5 case) — same economy: run OR skill, not both.

### Hover run tile (e.g. `(3,6)`) with **1 AP** — phases 2–3

| What | Exactly |
|------|---------|
| **Red** | **Completely off** — no red on dummy `(7,5)`, no red at knight start |
| **Cursor** | **Run** on that hover |
| **Reason** | Only **1 AP** · implicit premove = run → **0 AP** → any **1 AP** class skill (Bowling, Bash, etc.) impossible → **red off** |

### After commit run only — phase 5

| What | Exactly |
|------|---------|
| **Timeline PRE** | **Run** icon · **`(3,6)`** |
| **AP** | **0 / 1** |
| **Shield Bash selected** | **No red** with mouse still on `(3,6)` |

---

## Run / Wait (universal)

### Run — commit to `(5,5)` from `(4,5)` (adjacent walk)

| Phase | Exactly |
|-------|---------|
| **4 hover** | Walk cursor · path `(4,5)→(5,5)` |
| **5 commit** | PRE walk icon · dest `(5,5)` · MP **2/3** · AP stays **1/1** (walk does not spend AP) |
| **6 execute** | Knight **`(5,5)`** |

### Run — run-required tile with run icon

| Phase | Exactly |
|-------|---------|
| **Cursor** | **Run** glyph only (no attack) |
| **Timeline after commit** | PRE **run** icon · `uses_run` true · AP **0/1** |

### Wait

| Phase | Exactly |
|-------|---------|
| **5 commit** | Wait marker on timeline · planning exhausted per rules |
| **Blue / red** | Cleared or per exhausted rules |

---

## Automation vs this checklist

| Skill | Current automated scope | Still manual / gap |
|-------|-----------------------------------------------|-------------------|
| Shield Bash | `tests/skills/shield_bash_scenario.gd` — scenario-specific contracts | Full seven-phase × 40-dimension atomic expansion; F5 pixels |
| Chain Hook | `tests/skills/chain_hook_scenario.gd` — scenario-specific contracts | Full seven-phase × 40-dimension atomic expansion; F5 pixels |
| Trample | `tests/skills/trampling_advance_scenario.gd` — scenario-specific contracts | Full seven-phase × 40-dimension atomic expansion; F5 pixels |
| Run + 0 AP | `tests/skills/run_economy_scenario.gd` + `hide_after_commit_run_icon_bash` | Run economy + F5 commit path |

**Target:** The atomic contract in `docs/design/intent_architecture_evidence.md`
§8.1 and `canvases/planning-preview-truth-matrix.canvas.tsx` expands every
scenario to **17 checkpoints × 40 dimensions**. The current skill scenarios do
not yet claim that full expansion.

---

## What automated QA runs today

| Suite | File | Role |
|-------|------|------|
| Planning QA gate | `scripts/run_planning_qa_gate.ps1` | Default headless orchestrator |
| Headless contracts | `scripts/run_planning_headless_contracts.ps1` + `scripts/run_t3_mimic_headless.ps1` | Current headless contracts and seven-journey mimic |
| Legacy fixture runner | `tests/run_planning_qa_gate.gd` | Legacy Tier 1/2 only with explicit `-IncludeLegacyTier12`; not the default gate |
| Drag E2E | `planning_drag_e2e_test.gd` | Real drag → release → commit → undo |
| Planning input | `planning_input_test.gd` | Cursor, AP gates, synthetic abilities |
| Trample E2E | `trampling_advance_e2e_test.gd` | Trample paint → commit → sim |
| Action-range regression | `action_range_regression_test.gd` | Red tile contract (visibility + overlay) |
| Checklist mirror | `planning_qa_gate_test.gd` | Slots, sim, click/drop parity per skill |
| Source-of-truth gate | `tests/intent_source_of_truth_gate_test.gd` | Seven recorded journey signatures, stale/await rejection, swap/trample parity |

**Run:**

```powershell
.\scripts\run_planning_qa_gate.ps1
```

**Pass bar:** All `[FAIL]` lines must be zero. PASS in headless does **not** replace your F5 pixel/animation check (see Layer B in [PLANNING_QA_GATE.md](PLANNING_QA_GATE.md)).

---

## Automation roadmap (target: match this checklist)

Each skill needs a **scenario test** that steps through phases 1–7 and snapshots at each step:

- Blue tile set  
- Red tile set (+ visibility gate)  
- Live preview (path, stand, pushes)  
- Cursor glyph  
- Commit slots (phase 5)  
- Sim result (phase 6)  

**Movement-ability minimum bar:** Trampling Advance must cover painted
waypoint order, pathfinder-repath protection, live preview overlays, faded
timeline ghost, real click ratification, post-move continuation, and
Simulator parity. Sidestep remains a separate tile-target regression and is
not the movement-family bar.

**Template skill:** Shield Bash (`tests/skills/shield_bash_scenario.gd`). Add new skills by copying that file + registering in `planning_skill_scenarios_test.gd`.

Until that exists, use this document for manual sign-off and treat “partial” rows above as regression risk.

### Journey and phase traceability

The atomic matrix uses these journey IDs as its single naming source:
`WALK-01`, `MOVE-SKILL-01`, `PUSH-PULL-01`, `SWAP-01`, `AWAIT-01`,
`TRAMPLE-01`, `TRAMPLE-REPATH-01`, `BASH-POST-01`, `TRAMPLE-POST-01`, `RUN-WAIT-01`, `DRAG-DROP-01`, `TELEPORT-01`,
`I-T01-01`…`I-T10-01`, and `N-OOB-01`…`N-SNAPSHOT-01`. Their canonical
core fixtures are recorded in `docs/design/intent_architecture_evidence.md`
§5; extended Archer, transition, rejection, and post-move fixtures are defined in the
canvas `scenarioFacts` bank and must not be confused with currently executed
SoT signatures.
`N-RANGE-01` is a rejection-path alias of `PS-R-INVALID` and inherits its
route facts; it is not a second independent fixture.
`STALE-01` is the recorded SoT OOB rejection at `(-1,0)`; `N-OOB-01` is a
separate atomic invalid-path fixture at `(99,99)`. They share the same
rejection contract but are different boundary fixtures, not an alias.

`PUSH-PULL-01/bash` is the same fixture/signature as `MOVE-SKILL-01`;
`PUSH-PULL-01/hook` is the direct Chain Hook fixture represented by atomic
`PUSH-PULL-01`. The two displacement behaviors must not be collapsed.

The canonical 40-dimension catalog is the `atomicDimensions` list in
`canvases/planning-preview-truth-matrix.canvas.tsx`: `hover-cell`,
`selected-unit`, `route-cells`, `waypoints`, `route-leg`, `approach-origin`,
`latest-stand`, `projected-board`, `facing`, `target-coord`, `target-unit`,
`ability-id`, `authored-ability`, `module-coords`, `module-units`,
`affected-tiles`, `forecast-damage`, `forecast-status`, `terrain-forecast`,
`ap-before`, `mp-before`, `ap-after`, `mp-after`, `legality`, `blue-tiles`,
`red-tiles`, `arrows`, `cursor`, `unit-ghost-position`,
`unit-ghost-facing`, `timeline-ghost-visible`, `timeline-ghost-metadata`,
`snapshot-identity`, `slot-signature`, `sim-result`, `movement-events`,
`displacement-events`, `execution-economy`, `execution-effects`, and
`execution-parity`.

The current matrix target is **41 scenarios × 17 checkpoints × 40 dimensions =
27,880 required rows**. This is a regression specification count, not a claim
that the current headless runner already executes every row.

The 17 atomic checkpoints map to the seven phases as follows:

| Phase | Checkpoints |
|---|---|
| P1 select/rest | `setup`, `select-unit`, `select-ability` |
| P2 empty hover | `initial-hover`, `route-begin`, `route-progress` |
| P3 drag/waypoints | `route-final` |
| P4 enemy/target hover | `enemy-transition`, `target-settled`, `snapshot-captured`, `pre-click` |
| P5 commit | `click-ratified`, `timeline-written`, `post-commit` |
| P6 execute | `sim-resolution`, `final-parity` |
| P7 replan | `replan-from-stand` and re-enter P2–P6 |

This is the checklist mapping and target contract; current automated scenarios
remain partial until each atomic row has a concrete `file::function` owner.

---

## Layer B — manual only (~3 min after headless PASS)

1. **FPS / hover stutter** — planning overlay while moving mouse.  
2. **Pixels** — arrow color, dashed vs solid, tile outlines, ghost alignment.  
3. **Walk animation** — sprite follows path smoothly (data path is tested separately).

---

## Sign-off

- [ ] Automated: `run_planning_qa_gate.ps1` → headless planning gate PASS  
- [ ] Separate live Tier 3 / F5 acceptance (not claimed by the headless gate)  
- [ ] This checklist: skill(s) touched → phases 1–7 manual PASS  
- [ ] Commit hash: `________________`
