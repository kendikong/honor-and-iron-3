# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b

---

## Score ticker (update every critic round — owner reads this first)

```text
══════════════════════════════════════
GAUNTLET SCORE │ knight-template K3-LOCK │ Round 7 (critic)
SCORE: 57/100 │ THRESHOLD: 95 │ FAIL │ STALLED
DELTA: +2 vs round 6 (was 55)
NEXT: deepen 14 PASS row asserts; promote remaining 16 rows; re-critic until ≥95
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Score | Delta | Result |
|-------|-------|-------|--------|
| r1 | 51 | — | FAIL |
| r2 | 44 | −7 | FAIL |
| r3 | 64 | +20 | FAIL |
| r4 | 44 | −20 | FAIL (SLIPPED) |
| r5 | 48 | +4 | FAIL |
| r6 | 55 | +7 | FAIL (CLIMBING) |
| r7 | 57 | +2 | FAIL (STALLED) |

---

## Run

| Field | Value |
|-------|-------|
| **Chunk / goal** | P3 Knight — K3-doc spec + meta-critic; template for P6 |
| **Started** | 2026-08-01 |
| **Status** | **K3-LOCK gauntlet loop** — critic r6 **55/95 FAIL** (14/30 manifest PASS) |
| **Lead session** | knight-template-gauntlet-rerun |

---

## Current piece

| Field | Value |
|-------|-------|
| **Piece ID** | K3-LOCK (full matrix — owner threshold 95) |
| **Critic pass** | r6 (gauntlet-critic subagent) |
| **Last result** | **FAIL 55/95** — 16 rows HARNESS_ONLY; deepen asserts on 14 PASS rows |
| **Largest gap** | 26 rows HARNESS_ONLY; manifest 4/30 |

---

## Score progression (final)

| Piece | Best | Threshold | Result | On-disk status |
|-------|------|-----------|--------|----------------|
| `00-remaining-work-suite-plan.md` | 91 (C6) | 90 | **PASS** | POLISHED |
| `01-doc-polish-protocol.md` | 91 (C3) | 90 | **PASS** | POLISHED |
| `REMAINING_WORK_MAP.md` | 89 (C4) | 88 | **PASS** | LOOP_READY |
| `knight-template.md` | 90 (K3-r1) | 88 | **PASS** | LOOP_READY *(K3-LOCK 0/30)* |
| `verification-matrix.md` | 89 (C6) | 88 | **PASS** | LOOP_READY |
| `combat-core-closeout.md` | 88 (C4) | 88 | **PASS** | LOOP_READY |
| `class-rollout.md` | 88 (C4) | 88 | **PASS** | LOOP_READY |
| `presentation-audio-ui.md` | 89 (C5) | 88 | **PASS** | LOOP_READY |
| `world-assets-and-map.md` | 91 (C5) | 88 | **PASS** | DRAFT (P7 worksheet) |
| `roguelike-run.md` | 89 (C4) | 88 | **PASS** | DRAFT (P4 worksheet) |
| `enemy-design.md` | 88 (C3) | 88 | **PASS** | DRAFT (P5 worksheet) |
| `appendices/encounter-fixture-format.md` | 89 (C6) | 88 | **PASS** | LOOP_READY |
| `appendices/pixelforge-v14-contract.md` | 88 (C5) | 88 | **PASS** | LOOP_READY |
| `appendices/mass-sim-balance.md` | 88 (C5) | 88 | **PASS** | LOOP_READY |
| `appendices/gauntlet-prompt-library.md` | 89 (C3) | 88 | **PASS** | LOOP_READY |

---

## Wave log (final)

| Time | Piece | Score | Result | Notes |
|------|-------|-------|--------|-------|
| 2026-08-01 | enemy-design | 88/88 | PASS | C3 — bridge/fixture split, human gate |
| 2026-08-01 | knight-template K3-doc | 90/88 | PASS | KNIGHT_QA_GATE.md + run_knight_qa_gate.ps1 |

**Lint (latest):** `[PASS] lint_design_doc`

---

## Blockers (owner only — not doc gauntlet)

- **P3 K3-LOCK:** 30 factory rows need meta-critic `PASS` (scenarios + Bible/`[+]` asserts)
- P4 worksheet (`roguelike-run.md`)
- P5 worksheet (`enemy-design.md`)
- P7 worksheet (`world-assets-and-map.md`)

Doc gauntlet **PASS** for all three; **LOOP_READY** promotion waits on worksheets per human-gate rules.
