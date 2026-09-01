# Planning action fix plan

**Date:** 2026-08-31  
**Status:** ACTIVE — owner-approved recovery plan after SSOT refactor / tile paint failures  
**Authority:** `docs/design/planning/MOVE_PREVIEW_RULES.md` wins over SSOT milestone prose, checklists, and agent audits.

**Done means:** `.\scripts\run_planning_qa_gate.ps1` exit **0** + F5 spot-check on movement step (blue stable, path follows mouse).

**Workflow on every code change:**

1. Agent **proposes** fix (owner layer, files, bible section).
2. **Subagent Council Loop** — **5 parallel rules critics** (6–7 if QA-fix or class scope); see [`docs/qa/SUBAGENT_COUNCIL_LOOP.md`](../../qa/SUBAGENT_COUNCIL_LOOP.md) (proposal must name **behavioral tests**; critics use **owner-approved exceptions registry**). **All PASS** → apply.
3. Run matching gate slice → report PASS/FAIL.

This is **not** the Gauntlet Loop.

---

## Layer 0 — Split paint model (blocks everything)

**Problem:** Locked tiles (blue/red *current phase*) were stuffed into **per-hover bundle**. That violates the bible and causes flicker, blanks, and hover-chasing floods.

| Paint layer | Follows hover? | Owner | In hover bundle? |
|-------------|----------------|-------|------------------|
| **Locked blue** (legal walk, movement step) | **No** — phase-entry stand | `PlanningPreviewTiles` + overlay | **No** — keyed by plan revision |
| **Locked red** (aim, non-move step) | **No** — phase-entry stand | same | **No** |
| **Next-phase field** (blue or red at landing) | Yes — predicted stand at hover | settle → bundle | Yes |
| **Yellow** (click footprint / AOE) | Yes — hover only | settle → bundle | Yes |
| **Walk path** (solid route) | Yes — hover/drag | settle → bundle | Yes |

**Actions:**

1. Overlay selected-player branch: always paint **locked** fields from `resolve_layer_origins` + plan revision; bundle only for path / next-field / yellow.
2. Remove early `return` that leaves tiles **empty** when bundle mismatches — hold locked layer; bundle supplies hover-specific layers only.
3. Update `SETTLED_PAINT_SSOT_PLAN.md` one paragraph: locked current-phase fields ≠ bundle-only paint.

**New tests (mandatory before Layer 0 is “done”):**

- `locked_blue_stable_across_hovers` — hover A, hover B → **same blue set**; origin = phase entry.
- `locked_blue_visible_without_bundle` — movement step, no matched receipt → blue still shows.
- `bundle_mismatch_does_not_clear_locked_blue`.

---

## Layer 1 — Blue tiles (legal walk)

**Rule (`MOVE_PREVIEW_RULES.md` § Tile colors):** Movement step → **blue** = tiles you can legally walk to **this phase**, from **phase-entry stand**. **Locked.** Walk **path** is separate (§ What move preview is).

| Check | Pass criteria |
|-------|----------------|
| Origin | Flood from `phase_entry_stand`; never `hover_coord` or cheap-board unit position |
| Stability | Same set across hovers until plan revision / commit changes phase |
| When shown | Movement step only; **off** on damage / target / wait |
| When hidden | Rooted / stagger / 0 MP → correct empty or reduced set |
| After premove committed | Blue from **projected** stand + remaining MP (not turn-start) |
| Drag | Blue origin stays phase-entry; corridor union OK; flood does not recenter |

**Code owners:** `planning_preview_tiles.gd` (`_locked_current_phase_stand`, `resolve_move_tiles`, `reachable_move_tiles`), `tactical_planning_overlay.gd` (`_apply_planning_tile_layers`).

**Fix checklist:**

- [ ] Stop recomputing locked blue inside every hover settle.
- [ ] `reachable_move_tiles`: flood board = projection at phase entry, not settled board with unit on hover cell.
- [ ] Fix `PLANNING_SKILL_QA_CHECKLIST.md` “Blue updates live” → **path** updates live; **locked flood does not**.

**Gate tests:** `_test_blue_move_tiles_on_walk_select` + new stability tests above + `_test_move_preview_origin_premove_and_postmove`.

---

## Layer 2 — Red tiles (aim range)

**Rule:** Non-movement step → **locked red** from phase-entry stand. **Next-phase red** (optional) from predicted stand at hover (e.g. approach bash).

| Check | Pass criteria |
|-------|----------------|
| Locked red | Stable on skill step; from phase entry |
| Next red | Updates with hover when approach / premove+skill sim landing changes |
| 0 AP / exhausted | Red off when rules say so |
| `action_range_live_stand` | Red centered on **approach landing** after enemy hover (next field) |
| Walk-only hover | No spurious red blast |

**Code owners:** `_action_range_paint_stand` (next-phase only), `action_range_tiles`, `action_range_visible_for_hover`, overlay red paint.

**Gate tests:** `_test_action_range_centered_on_live_stand`, `_test_action_range_shows_on_enemy_hover`, `_test_action_range_hides_when_auto_run_blocks_skill_ap`, intent contract red cases.

---

## Layer 3 — Yellow tiles (hover footprint)

**Rule:** What click would hit — destination or AOE blast. Hover only; invalid = no yellow; **does not freeze** after commit.

| Check | Pass criteria |
|-------|----------------|
| AOE | Blast footprint at cursor from correct stand (aim stand, not turn-start) |
| TILE skills | Yellow on aim cell; no premove corridor stealing yellow |
| Invalid hover | No yellow |
| After commit | Yellow clears (frozen path may remain) |

**Code owners:** `PlanningPreviewTiles.blast_tiles`, `resolve_paint` blast branch, overlay `_hover_blast_tiles`.

**Gate tests:** tile AOE / Volley / waypoint hover cases (`tile_aoe_waypoint_hover/*` in gate log).

---

## Layer 4 — Move preview (path / route)

**Rule:** Shown path = walked path. Movement step → live path to mouse or painted drag. Non-move → **frozen** committed path only; no live corridor from mouse.

| Check | Pass criteria |
|-------|----------------|
| Path = slot waypoints | `preview_paths` matches commit slots |
| Hover → click | Same path; `commit_plan_matches_hover_slots` |
| Trample / damage step | Frozen path; mouse does not paint new walk |
| Drag | Same settle path as hover; drop = click |
| Teleport | Dashed hop, not blue corridor |
| Push/pull | Not blue walk UI |

**Code owners:** `CombatPlanningInput` voluntary walk assembler, `CombatPlanningPreview` paths, overlay route draw, `_sealed_leg_hover_restore_if_blocked` (display only, no re-sim).

**Gate tests:** trample chain, `waypoint_enemy_hover`, drag/drop parity suite, `MOVE-SKILL-01`, `PUSH-PULL-01`.

---

## Layer 5 — Preview = commit (settle / ratify)

**Rule:** Hover paints; click ratifies sealed bundle. No re-path at click. No overlay fallback recompute.

| Check | Pass criteria |
|-------|----------------|
| Settle once | Slots + sim (or cheap walk per perf rule) → seal |
| Commit | `ratify_sealed_intent` only; reject if no bundle |
| No click redo | No `on_hover_moved` before commit |
| Repeat hover | Same slot signature (`intent_source_of_truth_gate`) |

**Code owners:** `_preview_from_commit_slots_at_cell`, `_commit_at_cell`, `PlanningHoverPreview`.

**Do not re-add:** seal/discard loops, overlay live tile math, paint-only bundles.

**Gate tests:** `intent_source_of_truth_gate`, hover/click parity tests, structural SSOT gates (guardrails only — not “done”).

---

## Layer 6 — Perf (must not break layers 0–5)

**Rule:** `.cursor/rules/planning-hover-perf-mandatory.mdc` — throttle + cheap empty-walk on live F5; QA full sim; commit flush sync.

| Check | Pass criteria |
|-------|----------------|
| Throttle | Live F5 does not sync-settle every cell |
| Locked blue | **Still stable** while throttle pending (requires Layer 0) |
| Commit flush | `_flush_hover_heavy_sync` runs sync settle before ratify |

---

## Layer 7 — Doc / QA hygiene

| Action | File |
|--------|------|
| Align checklist with bible | `docs/qa/planning/PLANNING_SKILL_QA_CHECKLIST.md` |
| Add behavioral-done matrix | `docs/qa/planning/PLANNING_QA_GATE.md` — one row per bible section |
| Rules-only critic contract | `docs/qa/SUBAGENT_COUNCIL_LOOP.md` (`.cursor/rules/subagent-council-loop.mdc`) |
| Clarify locked vs bundle | `SETTLED_PAINT_SSOT_PLAN.md` |

---

## Execution order (do not skip)

```
0. Split paint model (locked vs bundle)     ← unblocks blue/red F5
1. Blue locked + tests
2. Red locked / next + tests
3. Yellow / AOE
4. Path / frozen vs live
5. Settle/commit parity (remaining gate FAIL buckets)
6. Perf regression check (F5 circling)
7. Doc cleanup
```

Run **full planning gate once per completed layer**, not per micro-fix. Report FAIL buckets by layer.

---

## Minimum bible behavioral matrix (what “follow rules” requires)

| Bible rule | Required behavioral test |
|------------|-------------------------|
| Locked blue stable | hover A ≠ hover B → same blue set |
| Locked red stable on skill step | same |
| Next red at approach | bash enemy hover → red at landing |
| Yellow at blast | AOE fixture |
| Path = walk | trample / drag / waypoint |
| No path on damage step | trample post-commit hover |
| Preview = commit | hover slots == click slots |
| Wait = all off | wait select |

Structural grep gates alone are **not** behavioral done (`MOVE_PREVIEW_RULES.md` § Authority).

---

## Changelog

| Date | Note |
|------|------|
| 2026-08-31 | Initial plan — owner mandate after locked blue / QA gap post-SSOT refactor |
