# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

```text
══════════════════════════════════════
GAUNTLET SCORE │ ACTIVE │ SELF-GRADED: no
AD-1..AD-4 PASS (≥92) │ AD-5 DEFERRED 90
AD-6: r1=90 FAIL · r2 BAR — awaiting critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

### Piece queue
| Piece | Status |
|-------|--------|
| AD-1..AD-4 | **PASS** |
| AD-5 | **DEFERRED** @ 90 |
| AD-6 | **r2 BAR** — awaiting critic |
| AD-SMOOTH | PENDING |

### AD-6 r2
- `is_movement_kind()` / `consumes_action_slot()` / `is_class_kind()` read `planner_group` (universals stay kind)
- Test stubs set `planner_group = PRE_MOVE` with MOVEMENT_SKILL kind

BAR: bridge/bruiser/knight/planning PASS (`*ad6_r2*`)

## STOP_ON
`STOP_CONDITION_MET: no`
