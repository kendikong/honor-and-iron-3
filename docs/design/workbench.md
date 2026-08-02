# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b

---

## Score ticker (update every critic round — owner reads this first)

```text
══════════════════════════════════════
GAUNTLET SCORE │ K3-LOCK matrix │ Round 32
FULL MATRIX: 59/95 FAIL │ MANIFEST: 30/30
GATE: exit 0 (30/30 PASS + Tier 1 PASS)
STOP_CONDITION_MET: no — full-matrix critic < 95 (EventBus headless gap)
NEXT: headless EventBus/planning host OR owner threshold deferral
══════════════════════════════════════
```

| Round | Score | Delta | Result |
|-------|-------|-------|--------|
| r31 | 89 | — | **PASS** (row: knight_bowling_charge → manifest) |
| r29 | 90 | — | **PASS** (row: knight_trampling_advance → manifest) |
| r32 | 59 | — | **FAIL** (full matrix LOCK review) |

---

## Run

| Field | Value |
|-------|-------|
| **Chunk / goal** | P3 Knight — K3-LOCK until `knight-template.md` LOCKED |
| **Started** | 2026-08-01 |
| **Status** | **30/30 manifest + gate exit 0** — full-matrix critic **FAIL 59/95** |
| **Last result** | bowling r31 + trample r29 promoted; gate LOCK green |
| **Lead session** | knight-k3-lock-2026-08-01 |

---

## STOP_ON checklist

| Check | Target | Actual |
|-------|--------|--------|
| Matrix 30/30 PASS | yes | **yes** |
| Manifest 30 rows | yes | **yes** |
| `run_knight_qa_gate.ps1` exit 0 | yes | **yes** (`qa_knight_gate_lock.txt`) |
| Full-matrix critic ≥ 95 | yes | **no** (59/95 r32) |
| `knight-template.md` LOCKED | yes | **no** (still LOOP_READY) |
| `STOP_CONDITION_MET: yes` | yes | **no** |

---

## Blockers (owner)

1. **Full-matrix critic 59/95:** Headless `--script` Tier 1 swallows `EventBus` SCRIPT ERRORs; planning E2E phases never assert. Proposed: `EventBus` stub + gate stderr policy.
2. **Manifest `pass_threshold: 95` vs row scores 80–90:** Per-row promotions use threshold 88; full-matrix LOCK uses 95 — clarify or re-score after infrastructure fix.

---

## Wave log (latest)

| Time | Piece | Score | Result | Notes |
|------|-------|-------|--------|-------|
| 2026-08-01 | knight_bowling_charge | 89/88 | PASS | r31 — sim + planning intent contracts |
| 2026-08-01 | knight_trampling_advance | 90/88 | PASS | r29 — MOVE/TRAMPLE/PUSH sim |
| 2026-08-01 | K3-LOCK full matrix | 59/95 | FAIL | r32 — infrastructure INADEQUATE |
