# Post-process / safety-net audit (owner flag list)

**Purpose:** Hotspots that look like "fix bad output downstream" instead of fixing the producer.  
**Removed 2026-08-31:** `is_sealed` discard ceremony, overlay live tile fallback for selected player, click-time `on_hover_moved` redo, revision-key bundle invalidation.

---

## Still flagged — review when editing owner

| Severity | What | Where | Why it's suspect |
|----------|------|-------|------------------|
| **HIGH** | Full hover **re-settle** to restore painted route | `CombatPlanningInput._restore_sealed_voluntary_walk_preview` | Re-runs sim + settle instead of fixing why restore is needed |
| **HIGH** | **Paint-only settle** (`_noop` slots + settle) | `CombatPlanningInput._settle_paint_only_preview_at_cell` | Partial bundle for display; risks preview ≠ commit |
| **MED** | **Post-commit full refresh chain** | `CombatPlanningInput._apply_post_commit_hover_truth` | Five-step redo after every commit — verify each step is necessary |
| **MED** | **Sealed-leg hover restore** on blocked cell | `CombatPlanningInput._sealed_leg_hover_restore_if_blocked` | May trigger extra settle passes |
| **MED** | **Drag route sanitize / repath** | `CombatPlanningInput._sanitize_drag_route_context` | Post-hoc geometry fix on drag buffer |
| **MED** | **Enemy hover buffer discard** | `CombatPlanningInput._discard_enemy_hover_painted_buffers_if_needed` | Discards + expects re-paint upstream |
| **LOW** | **Hover sim schedule generation** bump | `CombatPlanningInput._hover_sim_schedule_generation` | OK if stale-only; watch for redo storms |
| **LOW** | **Duplicate receipt on commit** | `PlanningHoverPreview.duplicate_slots` at ratify | Needed for immutability at click; not display |

---

## Not flagged (correct owner work)

- Single `_preview_from_commit_slots_at_cell` settle path
- `PlanningPreviewTiles.resolve_paint` **at settle** (not in overlay fallback)
- `commit_from_slots` validation fail-loud
- Non-selected units using live tile helpers in overlay (not the selected-player SSOT path)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-31 | Created after owner removal of seal/discard + overlay safety recalc |
