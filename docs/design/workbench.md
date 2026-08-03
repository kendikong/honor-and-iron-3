# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

```text
══════════════════════════════════════
GAUNTLET SCORE │ IN PROGRESS │ SELF-GRADED: no
AD-5b builder complete — awaiting critic ≥92
Editor BAR + bridge/Knight/Bruiser PASS on disk
STOP_CONDITION_MET: pending AD-5b critic
══════════════════════════════════════
```

| Piece | Score | Result |
|-------|-------|--------|
| AD-1 | **93** | PASS |
| AD-2 | **93** | PASS |
| AD-3 | **92** | PASS |
| AD-4 | **93** | PASS |
| AD-5 | **90** | **DEFERRED** — MAX_ROUNDS @ bar 92 |
| AD-5b | *pending critic* | Builder: `apply_planner_group_change` + BAR + §14.12 displacement sync |
| AD-6 | **92** | PASS |
| AD-SMOOTH | **91** | **REVOKED** — inadequate BAR (no Tier 3 live) |
| AD-REGRESS | **93** | **PASS** — Tier 3 live ADEQUATE; re-closes wave |

## Lesson
Scenario/bridge green ≠ behavior freeze. Critic must demand Tier 3 live evidence for behavior-freeze goals. Editor pieces: BAR must exercise the **same callback** the UI wires (not bare enforce).

## STOP_ON
`STOP_CONDITION_MET: pending` — reopen until AD-5b critic ≥92 (owner: finish unfinished plan pieces).

## AD-5b evidence (builder)
- Editor roundtrip: `reports/ability_data_gauntlet/editor_ad5b_r1.txt` PASS
- Bridge / Knight / Bruiser: `*_ad5b_r1.txt` PASS
- Shared path: `ClassLibrarySchema.apply_planner_group_change` ← editor OptionButton + BAR
- §14.12: `is_movement_skill` synced from displacement effects (not `planner_group`)
