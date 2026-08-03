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
THRESHOLD: 92 │ wave smooth: 90
AD-1: PASS 93 │ AD-2: PASS 93 │ AD-5: DEFERRED 90
AD-3: r2 BAR green — awaiting gauntlet-critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r3 | AD-1 | **93** | **92** | **PASS** |
| r3 | AD-2 | **93** | **92** | **PASS** |
| r6–r13 | AD-5 | best **90** | **92** | **DEFERRED** |
| r2 | AD-3 | *(critic pending)* | **92** | BAR PASS — critic next |
| r1 | AD-3 | *(critic pending)* | **92** | BAR PASS — critic next |

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
| AD-5 Class library editor | **DEFERRED** @ 90/92 |
| AD-2 Native module/gate runtime | **PASS** @ 93 |
| AD-1 Schema + bridge | **PASS** @ 93 |
| AD-3 Planning gated-aim | **r2 BAR PASS** — critic pending |
| AD-4 Factories modules-first | PARTIAL |
| AD-6 Remove legacy kind authoring | PENDING |
| AD-SMOOTH | PENDING (threshold **90**) |

---

## AD-3 r2 builder notes (for critic)

**GOAL:** §2.7 gated-aim — planning runner fail-loud; Violent Collision gated-aim test; preview stays awaiting until follow-up aimed or gate inactive.

**BAR (lead verified):**
- planning_input → PASS (`reports/ability_data_gauntlet/planning_input_ad3_r2.txt`) — no EventBus false PASS; `_test_violent_collision_gated_aim` included
- bruiser → PASS (`bruiser_ad3_r2.txt`)
- knight → PASS (`knight_ad3_r2.txt`)
- bridge → PASS (`bridge_ad3_r2.txt`)

**Preview truth fix:** `_append_awaiting_ability_slot` uses `planning_next_awaiting_module_index`; incomplete gated aims keep `awaiting_target=true`; finalize skips sim for awaiting slots; multi-module finalize sets `target_coord`/waypoints from module 0 dash endpoint.

**Commit:** *(pending push)*

---

## AD-3 r1 builder notes (for critic)

**GOAL:** §2.7 gated-aim — `module_coords` intent; inline IF_COLLIDED MOVE; no AP-refund stand-in; fail-loud if gate passes without aim.

**BAR (lead verified):**
- bridge → PASS (`reports/ability_data_gauntlet/bridge_ad3_r1b.txt`)
- Bruiser → PASS (`bruiser_ad3_r1b.txt`)
- Knight → PASS (`knight_ad3_r1b.txt`)
- PlanningInputTest → PASS (`planning_input_ad3_r1b.txt`)
- `run_planning_qa_gate.gd` — EventBus headless compile gap (pre-existing); planning_input_only used as secondary

**Commit:** `7b3eb9f329f9ad03db93f64c12be3753b25f1d89`

---

## STOP_ON

`STOP_CONDITION_MET: no`
