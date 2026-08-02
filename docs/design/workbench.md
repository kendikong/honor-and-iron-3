# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Sync:** `docs/design/LOCAL_CLOUD_SYNC.md`

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ B6-REOPEN │ 25/31 │ SELF-GRADED: no (prior batch critic)
SCORE: 25/31 rows PASS │ THRESHOLD: 88/row · 95 full-matrix
GATE: harness PASS · exit 2 INCOMPLETE
STOP_CONDITION_MET: no — handoff: Cloud Agent + gauntlet-critic (local Task quota dead)
══════════════════════════════════════
```

| Round | Piece | Score | Result |
|-------|-------|-------|--------|
| batch | 16 rows | ≥88 | PASS — promoted |
| deepen | 6 FAIL rows | pending critic | harness deepen done |
| — | local Task | blocked | usage exhausted — use Cloud |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** — Cloud handoff ready after push |
| **Matrix** | **25/31** PASS |
| **Cloud prompt** | `docs/design/prompts/B6-REOPEN-CLOUD.md` |

---

## STOP_ON

`STOP_CONDITION_MET: no`
