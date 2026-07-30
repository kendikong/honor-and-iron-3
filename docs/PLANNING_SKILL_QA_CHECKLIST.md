# Planning Skill QA Checklist

**Owner rule (absolute):** What you see in **move preview** is the truth. Commit must lock exactly that picture. Execute must match what was committed. If preview and commit disagree, that is a bug — not “close enough.”

Use this checklist for **every class skill** (manual F5 + automated tests). One skill = one full pass through all 7 phases below.

**Where to test manually:** Skill Arena / TestBattle (tactical combat, planning phase).

**Where automated tests live:** `.\scripts\run_planning_qa_gate.ps1` — see [PLANNING_QA_GATE.md](PLANNING_QA_GATE.md) for suite mapping.

---

## The 7 phases (minimum per skill)

Every skill test must record pass/fail at **each** phase. Do not skip a phase because “slots looked fine in code.”

| Phase | What you do | What must be correct |
|-------|-------------|----------------------|
| **1. Select** | Click your unit. Select the skill (or basic move). | Blue move tiles. Red skill-range tiles (or correctly hidden). Cursor state. AP/MP display if shown. |
| **2. Hover empty tiles** | Move mouse over open tiles (no commit). | Blue and red update with the cursor. Move-preview ghosts/paths match where you would stand. Nothing stale from start tile. |
| **3. Pathing** | Paint a path (walk and/or run). Change hover while pathing. | Path line, waypoints, run vs walk icon, blue/red at **intent stand** (end of path / hover), previews stay in sync. |
| **4. Hover enemy** (if skill targets enemy) | Hover enemy (and approach tiles if needed). | Approach path, walk/run cursor, attack cursor, push/pull arrows, blue/red anchored at **attack stand** not knight start. |
| **5. Commit** | Click or drop to lock the plan. | **Same** paths, tiles, arrows, timeline icons, projected AP/MP as last valid preview. No jump or redraw after click. |
| **6. Execute** | End planning / run turn. | Units end where preview/commit said. Pushes, pulls, damage, statuses match preview. |
| **7. Pre / post-move** | Add or change PRE_MOVE or POST_MOVE after the above. | Phases 2–6 checks still hold. Tiles and preview refresh; nothing left stale from before. |

### At every phase, check these layers together

| Layer | Question |
|-------|----------|
| **Blue tiles** | Can I move here? Correct set for MP, run, committed pre-move? |
| **Red tiles** | Can this skill hit from **where I would stand**? Hidden when skill is impossible (e.g. run ate last AP)? |
| **Move preview** | Ghost/path shows the route and end position I expect? |
| **Arrows** | Push, pull, approach, trample — direction and target match design? |
| **Cursor** | Walk, run, attack, composite icons match intent? |
| **Slots / timeline** | Pre / action / post columns match what preview showed? |
| **Economy** | AP/MP after commit matches what preview implied? |

**Automated tests must assert the same layers** at each scripted step (overlay tile sets + live preview + slots + sim). Slot-only checks alone are **not** enough.

---

## Recording a manual run

Copy this block per skill, per build:

```
Skill: _______________  Date: _______  Build/commit: _______

[ ] 1 Select       — blue / red / cursor / AP
[ ] 2 Hover empty  — tiles + preview follow cursor
[ ] 3 Pathing      — walk + run + path preview
[ ] 4 Hover enemy  — approach + arrows + tiles at stand
[ ] 5 Commit       — matches last preview (no jump)
[ ] 6 Execute      — sim matches commit
[ ] 7 Pre/post     — add move column; repeat 2–6

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
