# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md`  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ ACTIVE │ SELF-GRADED: no
THRESHOLD: 92
AD-1: PASS 93 │ AD-2: PASS 93 │ AD-5: DEFERRED 90
AD-3: r1=39 FAIL · r2=83 FAIL · r3 BAR green — awaiting critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r3 | AD-1 | **93** | **92** | **PASS** |
| r3 | AD-2 | **93** | **92** | **PASS** |
| r6–r13 | AD-5 | best **90** | **92** | **DEFERRED** |
| r1 | AD-3 | 39 | **92** | FAIL |
| r2 | AD-3 | 83 | **92** | FAIL |
| r3 | AD-3 | *(critic pending)* | **92** | BAR PASS — critic next |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** |
| **PASS_THRESHOLD** | **92** |
| **Next** | AD-3 critic ≥92 → AD-4/6 → SMOOTH |

### Piece queue

| Piece | Status |
|-------|--------|
| AD-5 | **DEFERRED** @ 90 |
| AD-1 | **PASS** @ 93 |
| AD-2 | **PASS** @ 93 |
| AD-3 Planning gated-aim | **r3 BAR PASS** — critic pending |
| AD-4 | PARTIAL |
| AD-6 | PENDING |
| AD-SMOOTH | PENDING |

---

## AD-3 r3 notes (for critic)

Extended `_test_violent_collision_gated_aim`: `preview_commit_valid` + `Simulator.simulate` end-tile parity; invalid/missing follow-up fail-loud (`gated_followup_missing_aim`).

BAR: planning_input / bruiser / knight / bridge → PASS (`*ad3_r3*`)

---

## STOP_ON

`STOP_CONDITION_MET: no`
