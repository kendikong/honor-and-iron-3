# Post-process / safety-net audit (owner flag list)

**Purpose:** Hotspots that look like "fix bad output downstream" instead of fixing the producer.

**Removed 2026-08-31 (batch 1):** seal/discard ceremony, overlay live tile fallback, click-time hover redo, revision-key bundle invalidation.

**Removed 2026-08-31 (batch 2):** `_settle_paint_only_preview_at_cell`, `_restore_sealed_voluntary_walk_preview` (route restore = geometry write only).

**Removed 2026-08-31 (batch 3):** `_sanitize_drag_route_context` — drag stages `_drag_route` only; preview/settle via `_sync_drag_route_stand` → voluntary-walk hover refresh (same as hover).

---

## Still flagged — review when editing owner

| Severity | What | Where | Why it's suspect |
|----------|------|-------|------------------|
| **MED** | **Post-commit full refresh chain** | `CombatPlanningInput._apply_post_commit_hover_truth` | Runs after every commit — verify each step is necessary |
| **MED** | **Sealed-leg hover restore** on blocked cell | `CombatPlanningInput._sealed_leg_hover_restore_if_blocked` | Restores path display; must not re-sim |
| **MED** | **Enemy hover buffer discard** | `CombatPlanningInput._discard_enemy_hover_painted_buffers_if_needed` | Discards + expects re-paint upstream |
| **LOW** | **Hover sim schedule generation** bump | `CombatPlanningInput._hover_sim_schedule_generation` | OK if stale-only; watch for redo storms |
| **LOW** | **Duplicate receipt on commit** | `PlanningHoverPreview.duplicate_slots` at ratify | Needed for immutability at click; not display |

---

## Not flagged (correct owner work)

- Single `_preview_from_commit_slots_at_cell` settle path
- `PlanningPreviewTiles.resolve_paint` **at settle** (not in overlay fallback)
- `commit_from_slots` validation fail-loud
- `CombatPlanningPreview.set_unit_preview_path` for route geometry restore (no re-sim)
- `_finish_drag_route_extension` → `_sync_drag_route_stand` → `_refresh_voluntary_walk_hover_preview` (drag = hover settle)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-31 | Created after owner removal of seal/discard + overlay safety recalc |
| 2026-08-31 | Removed HIGH flags: paint-only settle + re-settle restore |
