# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** (new after #5 merged — pending create)

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-5 r7 gap-close │ SELF-GRADED: no (awaiting critic)
THRESHOLD: 92 │ wave smooth: 90
AD-5 r6 critic: 87 FAIL → builder r7 (fail-loud tags + cost block)
AD-1: still RE-OPEN (86 < 92)
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r2 | AD-1 | 86 | **92** | RE-OPEN |
| r2/r6 | AD-5 | 88 → critic **87** | **92** | FAIL (largest: silent tags + no cost block UI) |
| r7 | AD-5 | — | **92** | Builder: fail-loud tags, cost block, label fix; critic pending |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** — PASS_THRESHOLD **92** |
| **Next** | Critic AD-5 r7; if ≥92 → AD-2 native gates → lift AD-1 |

### AD-5 r7 builder deltas

- `validate_tag_list` fail-loud — unknown tags not applied; editor warning; `push_error` on dict apply
- Cost block fields: `primary_resource`, `primary_value`, `cost_modifier`, `cost_modifier_n` (+ dump `cost:`)
- Effects subsection label corrected (modules rebuild from effects)
- Roundtrip BAR covers tag reject, shape dirty dump, dict modular header roundtrip

### BAR logs (r7)

- `reports/ability_data_gauntlet/editor_roundtrip_r7.txt`
- `reports/ability_data_gauntlet/bridge_r7.txt`
- `reports/ability_data_gauntlet/knight_r7.txt`
- `reports/ability_data_gauntlet/bruiser_r7.txt`

---

## STOP_ON

`STOP_CONDITION_MET: no`
