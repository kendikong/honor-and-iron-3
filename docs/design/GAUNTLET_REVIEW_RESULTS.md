# Gauntlet review — design suite (2026-08-01)

**Lint:** `.\scripts\lint_design_doc.ps1` → **PASS**

| Document | Best | Pass round | Threshold | Result | Status |
|----------|------|------------|-----------|--------|--------|
| `00-remaining-work-suite-plan.md` | 91 | C6 | 90 | **PASS** | POLISHED |
| `01-doc-polish-protocol.md` | 91 | C3 | 90 | **PASS** | POLISHED |
| `REMAINING_WORK_MAP.md` | 89 | C4 | 88 | **PASS** | LOOP_READY |
| `knight-template.md` | 90 | K3-r1 | 88 | **PASS** | LOOP_READY *(K3-doc rerun; K3-LOCK 0/30)* |
| `verification-matrix.md` | 89 | C6 | 88 | **PASS** | LOOP_READY |
| `combat-core-closeout.md` | 88 | C4 | 88 | **PASS** | LOOP_READY |
| `class-rollout.md` | 88 | C4 | 88 | **PASS** | LOOP_READY |
| `presentation-audio-ui.md` | 89 | C5 | 88 | **PASS** | LOOP_READY |
| `world-assets-and-map.md` | 91 | C5 | 88 | **PASS** | DRAFT *(P7 worksheet gates LOOP_READY)* |
| `roguelike-run.md` | 89 | C4 | 88 | **PASS** | DRAFT *(P4 worksheet gates LOOP_READY)* |
| `enemy-design.md` | 88 | C3 | 88 | **PASS** | DRAFT *(P5 worksheet gates LOOP_READY)* |
| `appendices/encounter-fixture-format.md` | 89 | C6 | 88 | **PASS** | LOOP_READY |
| `appendices/pixelforge-v14-contract.md` | 88 | C5 | 88 | **PASS** | LOOP_READY |
| `appendices/mass-sim-balance.md` | 88 | C5 | 88 | **PASS** | LOOP_READY |
| `appendices/gauntlet-prompt-library.md` | 89 | C3 | 88 | **PASS** | LOOP_READY |

**Suite summary:** **15/15 PASS** (doc gauntlet). **12 LOOP_READY** on disk; **3 DRAFT** remain worksheet-gated (P4, P5, P7).

## Knight template rerun (K3-doc — 2026-08-01)

- **Scope:** Full moveset + meta-critic spec; planning QA unchanged; P6 clone path at LOCK
- **New:** `docs/KNIGHT_QA_GATE.md`, `scripts/run_knight_qa_gate.ps1`
- **Score:** `knight-template.md` **90/88** (K3-r1); companion `KNIGHT_QA_GATE.md` **91/88**
- **Honest matrix:** 0/30 `PASS`, 3 `HARNESS_ONLY`, 27 `PLANNED` — gates **K3-LOCK**, not K3-doc

## Exempt (not scored)

`workbench.md`, `README.md`, `_TEMPLATE.md`, `UNATTENDED_RUN.md`, `00-gauntlet-loop-cursor.md`, this file.

## Final C6 fixes (encounter + enemy)

- `encounter-fixture-format.md`: encoding table (`id`, `blocked_cells` grass→wall), `puzzle_001.json` on disk, EncounterData I/O
- `enemy-design.md`: bridge vs fixture split, human gate rule, intent grammar + data owners
