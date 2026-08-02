# Run card — B6-REOPEN (Bruiser gauntlet restart)

**Status:** ACTIVE  
**Prior:** B6-LOCK **REVOKED** — r20 critic did not prove Bible clause coverage per owner audit  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rules 4, 5c, 6b, §5.4  
**Unattended:** `docs/design/UNATTENDED_RUN.md`

## GOAL

Re-earn Bruiser LOCK: **31/31** matrix rows `PASS` only after **fresh per-row `gauntlet-critic`** (≥88) with Bible excerpt + assert evidence; full-matrix critic **≥95** at end.

## BAR (per tick)

1. Pick **one** `HARNESS_ONLY` row (matrix order); deepen scenario if critic gap says `qa_test`
2. `.\scripts\run_bruiser_qa_gate.ps1` → harness must stay green; matrix may be INCOMPLETE (exit 2)
3. Spawn **fresh** `gauntlet-critic` on **that row only** — `SELF-GRADED: no (subagent)`
4. On row critic PASS ≥88: append `approved_rows` in manifest + set matrix row `PASS`
5. Never promote row without manifest entry

## FORBIDDEN

- Self-grade manifest or full-matrix score
- Matrix `PASS` without critic approval
- Planning QA edits for Bruiser coverage
- Knight regression

## STOP_ON

- 31/31 manifest + matrix PASS
- Gate exit **0**
- Full-matrix gauntlet-critic **≥95**, `Infrastructure: ADEQUATE`
- `bruiser-template.md` → `LOCKED`
