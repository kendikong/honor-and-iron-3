# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b

---

## Score ticker (update every critic round — owner reads this first)

```text
══════════════════════════════════════
GAUNTLET SCORE │ knight_phalanx_stance (row) │ Round 8 (critic)
SCORE: 79/100 │ THRESHOLD: 88 │ FAIL │ CLIMBING
DELTA: +22 vs full-matrix r7 (row-level); full-matrix still 57/95
NEXT: STURDY turn-expiry deepen OR re-critic row; then manifest promote
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
| r8 | 79 | +22 | FAIL (row: phalanx — below 88) |

---

## Run

| Field | Value |
|-------|-------|
| **Chunk / goal** | P3 Knight — K3-doc spec + meta-critic; template for P6 |
| **Started** | 2026-08-01 |
| **Status** | **K3-LOCK loop ACTIVE** (`/loop 20m`) — phalanx tick r8 row critic 79/88 |
| **Lead session** | knight-k3-lock-2026-08-01 |

---

## Current piece

| Field | Value |
|-------|-------|
| **Piece ID** | K3-LOCK (full matrix — owner threshold 95) |
| **Critic pass** | r7 (gauntlet-critic subagent) |
| **Last result** | Row r8: phalanx **79/88 FAIL** — harness green; STURDY expiry deepen for manifest |
| **Largest gap** | phalanx row < 88; 15 HARNESS_ONLY rows remain |

---

## Score progression (final)

| Piece | Best | Threshold | Result | On-disk status |
|-------|------|-----------|--------|----------------|
| `00-remaining-work-suite-plan.md` | 91 (C6) | 90 | **PASS** | POLISHED |
| `01-doc-polish-protocol.md` | 91 (C3) | 90 | **PASS** | POLISHED |
| `REMAINING_WORK_MAP.md` | 89 (C4) | 88 | **PASS** | LOOP_READY |
| `knight-template.md` | 90 (K3-r1) | 88 | **PASS** | LOOP_READY *(K3-LOCK 14/30 — LOCK pending)* |
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

## Blockers (owner only)

- **P3 K3-LOCK:** 16 HARNESS_ONLY rows — unattended loop in [`UNATTENDED_RUN.md`](UNATTENDED_RUN.md) + [`runs/K3-LOCK.md`](runs/K3-LOCK.md)
- P4 worksheet (`roguelike-run.md`)
- P5 worksheet (`enemy-design.md`)
- P7 worksheet (`world-assets-and-map.md`)

Doc gauntlet **PASS** for all three; **LOOP_READY** promotion waits on worksheets per human-gate rules.
