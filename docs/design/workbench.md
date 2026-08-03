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
AD-1 PASS 93 │ AD-2 PASS 93 │ AD-5 DEFERRED 90
AD-3: r1=39 · r2=83 · r3=90 · r4 BAR — awaiting critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Result |
|-------|-------|-------|--------|
| AD-1 r3 | 93 | PASS |
| AD-2 r3 | 93 | PASS |
| AD-5 | 90 | DEFERRED |
| AD-3 r1–r3 | 39→83→90 | FAIL |
| AD-3 r4 | pending | BAR PASS |

### AD-3 r4
Unconditional: out-of-range follow-up slots invalid + commit rejected; `gated_followup_invalid_dest` sim assert; missing aim still covered.

BAR: `*ad3_r4*` planning/bruiser/knight/bridge PASS

## STOP_ON
`STOP_CONDITION_MET: no`
