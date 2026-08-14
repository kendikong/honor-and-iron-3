# Run card — Bible consistency + Bible-to-code

**Started:** 2026-08-14  
**Closed:** 2026-08-14 Round 6 — both pieces critic PASS with Correct QA  
**Lead:** this Agent chat  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md`

## GOAL

1. **BIBLE-CONSISTENCY** — `class_abilities.txt` has no internal contradictions (glossary vs class lines, examples vs definitions).
2. **BIBLE-TO-CODE** — factories + shared runtime match the class skill lines in `class_abilities.txt`.

Owner rulings that stay MATCH even if an old audit disagreed: Bowling Charge, Trampling Advance, Flank & Run GHOST, AP grants kept, ROOT applies after that hit's damage, global examples are not base skill defs.

## BAR

| Piece | Threshold | Machine checks |
|-------|-----------|----------------|
| BIBLE-CONSISTENCY | **88** | Glossary vs class lines: Fortify ADD, SHARED TILE, CALTROPS; no global-example-as-definition |
| BIBLE-TO-CODE | **85** | **Correct QA:** `.\scripts\run_<class>_qa_gate.ps1` (not raw `.tscn` bypass) + live for every factory touched; planning QA if planning files change; `.\scripts\run_bible_alignment_gate.ps1` FAIL while any canvas `verdict: "FAIL"` remains. Manifest `last_score` uses that class `pass_threshold`. |

## STOP_ON

Fresh `gauntlet-critic` returns `RESULT: PASS`, `SCORE ≥ threshold`, `Infrastructure: ADEQUATE` on **both** pieces.

## FORBIDDEN

- Regress `knight_bowling_charge` / `knight_trampling_advance`
- Treat global Shield Slam examples as base defs
- Per-skill `if ability.id` when data can express it
- Claiming class LOCK / owner QA PASS (only Knight has sign-off)
