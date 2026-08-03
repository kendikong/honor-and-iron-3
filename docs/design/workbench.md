# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-5 r8 │ SELF-GRADED: no (awaiting critic)
THRESHOLD: 92 │ wave smooth: 90
AD-5: r6=87 → r7=90 → r8 builder (planner↔cost enforce)
AD-1: RE-OPEN (86 < 92)
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r2 | AD-1 | 86 | **92** | RE-OPEN |
| r6 | AD-5 | 87 | **92** | FAIL |
| r7 | AD-5 | 90 | **92** | FAIL (planner↔cost grey/force) |
| r8 | AD-5 | — | **92** | Builder: enforce_planner_cost_coupling + full tag reject; critic pending |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** |
| **PASS_THRESHOLD** | **92** |
| **Next** | Critic AD-5 r8 |

### AD-5 r8 deltas
- `AbilityModuleBridge.enforce_planner_cost_coupling` — PRE_MOVE→MP, ACTION→AP|HP
- `primary_resource` row greyed (driven by planner_group)
- `apply_ability_dict` full-rejects mixed unknown tags (no partial apply)
- Roundtrip asserts coupling + full reject

### BAR r8
- editor_roundtrip / bridge / knight / bruiser → PASS

---

## STOP_ON

`STOP_CONDITION_MET: no`
