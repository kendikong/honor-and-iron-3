# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

```text
══════════════════════════════════════
GAUNTLET SCORE │ CLOSED │ SELF-GRADED: no
AD-5b critic PASS 93/92 · Infrastructure ADEQUATE
§14 checklist complete · AD-REGRESS Tier 3 live green
STOP_CONDITION_MET: yes
══════════════════════════════════════
```

| Piece | Score | Result |
|-------|-------|--------|
| AD-1 | **93** | PASS |
| AD-2 | **93** | PASS |
| AD-3 | **92** | PASS |
| AD-4 | **93** | PASS |
| AD-5 | **90** | **DEFERRED** — MAX_ROUNDS @ bar 92; closed via AD-5b |
| AD-5b | **93** | **PASS** — planner callback + dict import share `apply_planner_group_change` |
| AD-6 | **92** | PASS |
| AD-SMOOTH | **91** | **REVOKED** — inadequate BAR (no Tier 3 live) |
| AD-REGRESS | **93** | **PASS** — Tier 3 live ADEQUATE; re-closes wave |

## Lesson
Scenario/bridge green ≠ behavior freeze. Critic must demand Tier 3 live evidence for behavior-freeze goals. Editor pieces: BAR must exercise the **same callback** the UI wires (not bare enforce).

## STOP_ON
`STOP_CONDITION_MET: yes` — AD-5b critic PASS 93 (≥92) + AD-REGRESS Tier 3 live r8 + §14 checklist complete.

## AD-5b evidence
- Critic: PASS **93**/92 ADEQUATE (round 1)
- Editor: `editor_ad5b_r1.txt` / `editor_ad5b_r2.txt` PASS (r2: dict import uses `apply_planner_group_change`)
- Bridge / Knight / Bruiser: `*_ad5b_r1.txt` PASS
- §14.12: `is_movement_skill` = displacement effects
