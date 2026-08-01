# Design specs (`docs/design/`)

Agent-ready design layer between vision (`ROADMAP.md`, `class_abilities.txt`) and implementation.

## Start here

| Doc | Purpose | Status |
|-----|---------|--------|
| [`00-remaining-work-suite-plan.md`](00-remaining-work-suite-plan.md) | How to create this suite (W1–W4) | POLISHED (C6=91) |
| [`REMAINING_WORK_MAP.md`](REMAINING_WORK_MAP.md) | What to build — milestone index | LOOP_READY |
| [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) | Builder/critic loops | ACTIVE |
| [`01-doc-polish-protocol.md`](01-doc-polish-protocol.md) | Doc polish process (P1) | POLISHED |
| [`verification-matrix.md`](verification-matrix.md) | Machine bar per domain (P9) | LOOP_READY |
| [`workbench.md`](workbench.md) | Live gauntlet scores | — |
| [`GAUNTLET_REVIEW_RESULTS.md`](GAUNTLET_REVIEW_RESULTS.md) | Final scoreboard | **15/15 PASS** |

## Pillar specs

| ID | Doc | Status |
|----|-----|--------|
| P2 | [`combat-core-closeout.md`](combat-core-closeout.md) | CLOSED *(owner 2026-08-01)* |
| P3 | [`knight-template.md`](knight-template.md) | LOOP_READY *(K3-LOCK ACTIVE — 14/30; [`runs/K3-LOCK.md`](runs/K3-LOCK.md))* |
| P4 | [`roguelike-run.md`](roguelike-run.md) | DRAFT *(doc gauntlet PASS; worksheet gates LOOP_READY)* |
| P5 | [`enemy-design.md`](enemy-design.md) | DRAFT *(doc gauntlet PASS; worksheet gates LOOP_READY)* |
| P6 | [`class-rollout.md`](class-rollout.md) | LOOP_READY |
| P7 | [`world-assets-and-map.md`](world-assets-and-map.md) | DRAFT *(doc gauntlet PASS; P7 worksheet gates LOOP_READY)* |
| P8 | [`presentation-audio-ui.md`](presentation-audio-ui.md) | LOOP_READY |

## Appendices

| Doc | Status |
|-----|--------|
| [`appendices/encounter-fixture-format.md`](appendices/encounter-fixture-format.md) | LOOP_READY |
| [`appendices/pixelforge-v14-contract.md`](appendices/pixelforge-v14-contract.md) | LOOP_READY |
| [`appendices/mass-sim-balance.md`](appendices/mass-sim-balance.md) | LOOP_READY |
| [`appendices/gauntlet-prompt-library.md`](appendices/gauntlet-prompt-library.md) | LOOP_READY |

## Reference

| Doc | Purpose |
|-----|---------|
| [`_TEMPLATE.md`](_TEMPLATE.md) | Copy for new pillar files |
| [`UNATTENDED_RUN.md`](UNATTENDED_RUN.md) | **ACTIVE** K3-LOCK boundary contract · template: [`UNATTENDED_RUN.template.md`](UNATTENDED_RUN.template.md) |
| [`runs/K3-LOCK.md`](runs/K3-LOCK.md) | Knight LOCK gauntlet run card + `/loop` prompt |

## Polish legend

`DRAFT` → `LOOP_READY` (critic ≥88) → `POLISHED` (≥90 meta) → `LOCKED` (owner)

Run: `.\scripts\lint_design_doc.ps1` then `/gauntlet-critic` per file.
