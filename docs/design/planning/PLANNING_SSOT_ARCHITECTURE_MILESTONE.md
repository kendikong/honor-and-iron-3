# Milestone — Planning SSOT architecture (Attempt 9 close)

**Owner reference doc** — read this first if you suspect architecture compliance was faked, incomplete, or overstated again.  
**Declared:** 2026-08-30 (UTC-7)  
**Pin commit (milestone tree):** `ebb0f51a15a469c4824a603ac716aafbf518841a`  
**Prior false closes:** Attempts 7–8 and post–voluntary-walk milestone claims — withdrawn; see `MOVE_PREVIEW_IMPLEMENTATION_LOG.md` Attempts 7–9.

---

## What was claimed (plain language)

**Planning hover architecture** — settle once, carry sealed intent through display and click, ratify without rebuild:

| Rule | Meaning |
|------|---------|
| **One paint owner** | Selected player: blue routes, red/yellow tiles, and stand marker all come from the sealed `PlanningHoverPreview` receipt (or one atomic `resolve_paint` at settle). |
| **No partial settle** | Board, slots, route, and paint seal together. Paint-only hovers are documented display-only (`SETTLED_PAINT_SSOT_PLAN.md`) and use `preview_actions`, not projection clone. |
| **Four-way parity** | Hover settle, click ratify, timeline slots, and sim `preview_actions` share the same slot geometry. Click copies sealed slots only. |
| **One sim path (live)** | Live hover settle runs one `preview_actions` → `Simulator` for the receipt board. |

**Verification at close:** Three independent **static code** re-audits (settle/ratify, paint/overlay, parallel-path hunt) — **unanimous COMPLIANT**.

---

## What was NOT claimed (read before getting mad)

| Limitation | Meaning |
|------------|---------|
| **QA suspended** | `docs/qa/QA_SUSPENDED.flag` still on. No planning gate, T3 mimic, swap, or F5 proof at this milestone. |
| **Behavioral parity** | K1/K3/K4, drag/swap, premove range-after-commit, etc. are **not** proven green by this close. |
| **Class kits** | Architecture milestone only — not class QA or Bible LOCK. |
| **GDScript immutability** | Receipt fields are not compile-time locked; discipline is structural, not language-enforced. |
| **Voluntary-walk milestone** | Still a separate close (`PLANNING_VOLUNTARY_WALK_MILESTONE.md`). This milestone **supersedes** any “SSOT architecture done” implied by that gauntlet alone. |

If hover feels wrong in F5, that is **not** disproven by this milestone — runtime QA was explicitly out of scope at close.

---

## Attempt history (honest)

| Attempt | Outcome |
|---------|---------|
| Post voluntary-walk / early hardening | **Overstated** — structure not closed |
| 7 | **Withdrawn** — premature 100% claim |
| 8 | **Structural progress** — triple audit still NOT COMPLIANT |
| **9** | **Milestone close** — four production blockers fixed; triple re-audit unanimous |

---

## Evidence chain

| Artifact | Role |
|----------|------|
| [`HOVER_PREVIEW_CARRIED_SSOT_PLAN.md`](HOVER_PREVIEW_CARRIED_SSOT_PLAN.md) | Carried-bundle architecture spec |
| [`SETTLED_PAINT_SSOT_PLAN.md`](SETTLED_PAINT_SSOT_PLAN.md) | Move + range + blast paint at settle |
| [`MOVE_PREVIEW_IMPLEMENTATION_LOG.md`](../logs/MOVE_PREVIEW_IMPLEMENTATION_LOG.md) | Attempt 7–9 diary |
| [`run_hover_preview_ssot_gate.ps1`](../../../scripts/qa/run_hover_preview_ssot_gate.ps1) | Structural forbidden-pattern gate |

**Primary code owners (Attempt 9):**

- `presentation/combat_planning_input.gd` — settle, seal, ratify, `_authoritative_*`, paint-only
- `presentation/planning_hover_preview.gd` — sealed receipt bundle
- `presentation/planning_preview_tiles.gd` — atomic `resolve_paint`
- `presentation/tactical_planning_overlay.gd` — selected-player receipt display
- `presentation/combat_planning_preview.gd` — `apply_settled_preview_paths`, scratch path build
- `presentation/combat_director.gd` — `ratify_sealed_intent`, `preview_actions`

---

## Attempt 9 deliverables (closed blockers)

1. `display_move_route_cells` — selected unit reads sealed receipt only  
2. `_write_voluntary_walk_preview_path` **deleted**; restore re-settles  
3. Paint-only settle uses `preview_actions` + sim `temp_board`  
4. `_authoritative_*` receipt-only; settle snapshot slots-only (no mutable buffer)  
5. Facing before QA validate; stand from `settled_board` / receipt in overlay  

---

## Re-open criteria

Delete milestone trust (not the code pin) if any of:

- Selected-player display reads `preview_state.preview_paths` for routes/tiles/stand again  
- Commit rebuilds slots at click  
- Ghost path writer returns outside settle  
- Triple static audit fails on the four criteria above  

Re-enable QA (`QA_SUSPENDED.flag` removed + owner says re-enabled) for **behavioral** sign-off — separate from this architecture milestone.
