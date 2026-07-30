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

## Shield Bash (`knight_shield_bash`)

**Setup:** Knight `(4,5)`, training dummy `(7,5)`, approach tile `(6,5)`.

| Phase | Expected behavior | Automated coverage |
|-------|-------------------|-------------------|
| **1 Select** | Bash selected: red range from current stand; blue from MP/run rules. | Partial — `action_range_enemy_hover`, `action_range_live_stand` (red only; not full select step) |
| **2 Hover empty** | Red follows cursor stand; blue shows reachable tiles; preview ghost at hover dest when valid. | Partial — `action_range_move_hover_follows_cursor`, `show_move_hover_no_action_slot` |
| **3 Pathing** | Walk to approach or run tile: path preview, run icon when needed, red at path end. | Gap — no full pathing snapshot test |
| **4 Hover enemy** | Pre-move to `(6,5)` + bash on dummy; walk+attack cursor; orange push **east**; red at approach. | Partial — `bash_slots`, `bash_push`, `bash_cursor`, `bash_full_approach_push` (slots/preview, not all tiles every step) |
| **5 Commit** | Timeline: pre walk + bash; projected state matches preview; tiles refresh (e.g. committed run + 0 AP → **no red**). | Partial — `commit_matches_hover`, `bash_commit_sim`, `action_range_commit_run_icon_hide` (run+AP case only) |
| **6 Execute** | Dummy pushed east to preview destination. | `bash_commit_sim_push`, `bash_sim_determinism` |
| **7 Pre/post** | Pre-move committed first; hover enemy again — approach from new stand; post-move after bash if applicable. | Partial — `show_enemy_bash_committed_premove`; gap on post-move |

**Known gap:** No single automated test runs phases 1–7 in order with blue+red+preview+commit parity at each step.

---

## Chain Hook (`knight_chain_hook`)

**Setup:** Knight west of dummy (e.g. `(1,3)` vs `(4,3)`).

| Phase | Expected behavior | Automated coverage |
|-------|-------------------|-------------------|
| **1 Select** | Red range for hook; blue move tiles. | Gap |
| **2 Hover empty** | Tiles + preview follow cursor. | Gap |
| **3 Pathing** | Path to hook range if needed. | Gap |
| **4 Hover enemy** | Hook action on enemy; pull arrow **west** (toward player). | `hook_segment`, `hook_pull` |
| **5 Commit** | Timeline matches preview; pull direction preserved. | `hook_commit_sim` |
| **6 Execute** | Enemy ends at pulled cell from preview. | `hook_commit_sim_pull` |
| **7 Pre/post** | Committed pre-move then hook from new stand. | `hook_committed_premove` |

**Known gap:** No tile/preview checks at phases 1–3; line rendering is manual only.

---

## Trampling Advance (`knight_trampling_advance`)

| Phase | Expected behavior | Automated coverage |
|-------|-------------------|-------------------|
| **1 Select** | Red trample pattern; blue move tiles. | Partial — `action_range_awaiting_trample` (after arm only) |
| **2 Hover empty** | Tiles while picking trample route. | Gap |
| **3 Pathing** | Painted corridor (e.g. east then north); preview path = paint order. | `trample_paint_preview`, `trample_commit_wps`, `trample_sim_order` |
| **4 Hover enemy** | N/A (tile-target skill) — use tile hover / arm flow. | `trample_flow` |
| **5 Commit** | Pre-move on timeline if used; trample segment committed; preview promoted. | `trample_full_chain`, `trample_flow` |
| **6 Execute** | Sim visits painted cells in order. | `trample_sim_order`, trample E2E suite |
| **7 Pre/post** | Pre-move walk then arm trample from new stand; post-move trample leg if used. | `trample_flow`, `post_move_sim_preview` (E2E) |

**Known gap:** Phases 1–2 red/blue at select + empty hover not fully automated.

---

## Bowling Charge / auto-run AP (action-range reference)

Used to verify **red hides when run would consume skill AP**.

| Phase | Expected behavior | Automated coverage |
|-------|-------------------|-------------------|
| **2–3** | Hover run-required tile with 1 AP: red **off** (run eats AP). | `action_range_auto_run_ap_gate`, `hide_auto_run_ap_gate` |
| **5** | Commit run only; 0 AP; bash still selected; hover dest: **no red**. | `hide_after_commit_run_icon_bash` |

---

## Universal skills (Run / Wait)

| Skill | Phase 5 commit check | Automated |
|-------|----------------------|-----------|
| **Run** | Run icon on timeline; MP+AP spent per rules; tiles refresh. | Partial — drag/walk suites, `action_range_commit_run_icon_hide` |
| **Wait** | Wait marker; planning exhausted rules. | Partial — planning input wait cursor tests |

---

## What automated QA runs today

| Suite | File | Role |
|-------|------|------|
| Planning QA gate | `tests/run_planning_qa_gate.gd` | All suites below |
| Drag E2E | `planning_drag_e2e_test.gd` | Real drag → release → commit → undo |
| Planning input | `planning_input_test.gd` | Cursor, AP gates, synthetic abilities |
| Trample E2E | `trampling_advance_e2e_test.gd` | Trample paint → commit → sim |
| Action-range regression | `action_range_regression_test.gd` | Red tile contract (visibility + overlay) |
| Checklist mirror | `planning_qa_gate_test.gd` | Slots, sim, click/drop parity per skill |

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

**Template skill:** Shield Bash first (`tests/skills/shield_bash_scenario.gd` — not yet implemented).

Until that exists, use this document for manual sign-off and treat “partial” rows above as regression risk.

---

## Layer B — manual only (~3 min after headless PASS)

1. **FPS / hover stutter** — planning overlay while moving mouse.  
2. **Pixels** — arrow color, dashed vs solid, tile outlines, ghost alignment.  
3. **Walk animation** — sprite follows path smoothly (data path is tested separately).

---

## Sign-off

- [ ] Headless: `run_planning_qa_gate.ps1` → PASS  
- [ ] This checklist: skill(s) touched → phases 1–7 manual PASS  
- [ ] Commit hash: `________________`
