# Design specs (`docs/design/`)

Agent-ready design layer between vision (`ROADMAP.md`, `class_abilities.txt`) and implementation.

## Start here

| Doc | Purpose | Status |
|-----|---------|--------|
| [`00-remaining-work-suite-plan.md`](00-remaining-work-suite-plan.md) | How to create this suite (W1–W4) | POLISHED (C6=91) |
| [`REMAINING_WORK_MAP.md`](REMAINING_WORK_MAP.md) | What to build — milestone index | LOOP_READY |
| [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) | Builder/critic loops | ACTIVE |
| [`01-doc-polish-protocol.md`](01-doc-polish-protocol.md) | Doc polish process (P1) | DRAFT |
| [`verification-matrix.md`](verification-matrix.md) | Machine bar per domain (P9) | LOOP_READY |
| [`workbench.md`](workbench.md) | Live gauntlet scores | — |

## Pillar specs

| ID | Doc | Status |
|----|-----|--------|
| P2 | [`combat-core-closeout.md`](combat-core-closeout.md) | DRAFT |
| P3 | [`knight-template.md`](knight-template.md) | LOOP_READY |
| P4 | [`roguelike-run.md`](roguelike-run.md) | DRAFT (owner worksheet) |
| P5 | [`enemy-design.md`](enemy-design.md) | DRAFT |
| P6 | [`class-rollout.md`](class-rollout.md) | DRAFT |
| P7 | [`world-assets-and-map.md`](world-assets-and-map.md) | DRAFT (owner worksheet) |
| P8 | [`presentation-audio-ui.md`](presentation-audio-ui.md) | DRAFT |

## Appendices

| Doc | Status |
|-----|--------|
| [`appendices/encounter-fixture-format.md`](appendices/encounter-fixture-format.md) | DRAFT |
| [`appendices/pixelforge-v14-contract.md`](appendices/pixelforge-v14-contract.md) | DRAFT |
| [`appendices/mass-sim-balance.md`](appendices/mass-sim-balance.md) | DRAFT |
| [`appendices/gauntlet-prompt-library.md`](appendices/gauntlet-prompt-library.md) | DRAFT |

## Reference

| Doc | Purpose |
|-----|---------|
| [`_TEMPLATE.md`](_TEMPLATE.md) | Copy for new pillar files |
| [`UNATTENDED_RUN.md`](UNATTENDED_RUN.md) | Overnight boundary template |

## Polish legend

`DRAFT` → `LOOP_READY` (critic ≥88) → `POLISHED` (≥90 meta) → `LOCKED` (owner)

Run: `.\scripts\lint_design_doc.ps1` then `/gauntlet-critic` per file.
