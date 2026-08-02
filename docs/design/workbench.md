# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b

---

## Score ticker (update every critic round — owner reads this first)

```text
══════════════════════════════════════
GAUNTLET SCORE │ K3-LOCK matrix │ Round 37
FULL MATRIX: 92/95 FAIL │ MANIFEST: 30/30
GATE: exit 0 (30/30 PASS + Tier 1 PASS) — qa_knight_gate_r37c.txt
STOP_CONDITION_MET: no — full-matrix critic < 95
NEXT: ally-target planning commit (fortify/swap) OR owner tiered-LOCK approval
══════════════════════════════════════
```

| Round | Score | Delta | Result |
|-------|-------|-------|--------|
| r37 | 92 | +2 | **FAIL** (full matrix LOCK review — commit smoke + docs) |
| r36 | 92 | +2 | **FAIL** (9 actives commit smoke) |
| r35 | 90 | +1 | **FAIL** (11 actives select smoke) |
| r34 | 89 | +30 | **FAIL** (infra fixed; prior r32 59) |
| r32 | 59 | — | **FAIL** (EventBus headless gap) |
| r31 | 89 | — | **PASS** (row: knight_bowling_charge → manifest) |
| r29 | 90 | — | **PASS** (row: knight_trampling_advance → manifest) |

---

## Run

| Field | Value |
|-------|-------|
| **Chunk / goal** | P3 Knight — K3-LOCK until `knight-template.md` LOCKED |
| **Started** | 2026-08-01 |
| **Status** | **30/30 manifest + gate exit 0** — full-matrix critic **FAIL 92/95** (r37) |
| **Last result** | r37: commit smoke on 9 actives; bowling select smoke; gate green |
| **Lead session** | knight-k3-lock-2026-08-01 |

---

## STOP_ON checklist

| Check | Target | Actual |
|-------|--------|--------|
| Matrix 30/30 PASS | yes | **yes** |
| Manifest 30 rows | yes | **yes** |
| `run_knight_qa_gate.ps1` exit 0 | yes | **yes** (`qa_knight_gate_r37c.txt`) |
| Full-matrix critic ≥ 95 | yes | **no** (92/95 r37) |
| `knight-template.md` LOCKED | yes | **no** (still LOOP_READY) |
| `STOP_CONDITION_MET: yes` | yes | **no** |

---

## Planning coverage (honest tier — r37)

| Tier | Skills | Count |
|------|--------|------:|
| **A** — full 7-phase | shield_bash, chain_hook, trampling_advance | 3 |
| **B** — commit smoke (select + hover/click parity + no_jump) | phalanx, taunting, seismic, iron_grip, redirect, indomitable, retaliation, shield_slam, defensive_formation | 9 |
| **C** — select / intent only | fortify, knight_swap (ally-target; bash fixture invalidates commit slots), bowling_charge (intent contracts + select) | 3 |
| **Passives** — sim triggers | 14 passives | 14 |

**Known gap:** `knight_fortify` / `knight_swap` ally-unit commit on planning fixture returns invalid slots (`combat_planning_input.gd` ally branch) — **outside K3-LOCK ALLOWED_PATHS**. Sim paths green; planning commit deferred to P6 or presentation fix.

---

## Blockers (owner)

1. **Full-matrix critic 92/95:** Need +3 — deepen tier C to commit smoke or owner approves tiered LOCK bar.
2. **Ally-target planning commit:** Presentation path not in gauntlet scope; sim + select smoke only for fortify/swap.

---

## Wave log (latest)

| Time | Piece | Score | Result | Notes |
|------|-------|-------|--------|-------|
| 2026-08-01 | K3-LOCK full matrix | 92/95 | FAIL | r37 — commit smoke ×9; bowling select |
| 2026-08-01 | K3-LOCK full matrix | 92/95 | FAIL | r36 — same tier assessment |
| 2026-08-01 | K3-LOCK full matrix | 90/95 | FAIL | r35 — select smoke ×11 |
| 2026-08-01 | knight_bowling_charge | 89/88 | PASS | r31 — sim + planning intent contracts |
| 2026-08-01 | knight_trampling_advance | 90/88 | PASS | r29 — MOVE/TRAMPLE/PUSH sim |
