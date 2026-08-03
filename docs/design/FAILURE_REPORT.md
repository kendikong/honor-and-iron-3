# Failure Report — AbilityData Gauntlet

**CHUNK_ID:** `ability-data-modular-2026-08-03`  
**Branch:** `cursor/ability-data-modular-refactor-5448`  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6  

---

## Historical: AD-5 MAX_ROUNDS

**MAX_ROUNDS_PER_PIECE (8)** on AD-5 under bar **92** — best critic **90**. Spawned **AD-5b**.

| Round | Score | Largest gap |
|-------|-------|-------------|
| r13 | **90** | Planner-switch BAR not on editor callback wiring |

---

## AD-5b — CLOSED

**Critic:** PASS **93**/92 · Infrastructure **ADEQUATE**  
**Scope closed:** `ClassLibrarySchema.apply_planner_group_change` is the shared planner path for:
- Class library editor OptionButton
- BAR (`run_class_library_editor_roundtrip_test.gd`)
- `apply_ability_dict` planner/kind import (r2 residual)

**Also:** §14.12 — `is_movement_skill` syncs from displacement effects, not `planner_group`.

**Evidence:** `editor_ad5b_r1.txt` / `editor_ad5b_r2.txt` · bridge/Knight/Bruiser `*_ad5b_r1.txt`

---

## Piece status (final)

| Piece | Status |
|-------|--------|
| AD-1…AD-4, AD-6 | **PASS** |
| AD-5 | **DEFERRED** → superseded by AD-5b |
| AD-5b | **PASS 93** |
| AD-SMOOTH | **REVOKED** → AD-REGRESS |
| AD-REGRESS | **PASS 93** (Tier 3 live) |

`STOP_CONDITION_MET: yes`
