# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b

---

## Score ticker (update every critic round — owner reads this first)

```text
══════════════════════════════════════
GAUNTLET SCORE │ <piece-id> │ Round <n>
SCORE: —/100 │ THRESHOLD: — │ — │ —
DELTA: — vs round <n-1>
BEST THIS PIECE: — │ ROUNDS: —
══════════════════════════════════════
```

*(Lead replaces `—` after each critic. Copy the same banner to chat as the first line of the lead message.)*

---

## Run

| Field | Value |
|-------|-------|
| **Chunk / goal** | *(not started)* |
| **Started** | — |
| **Status** | IDLE |
| **Lead session** | — |

---

## Current piece

| Field | Value |
|-------|-------|
| **Piece ID** | — |
| **Round** | — |
| **Critic invoked** | — *(yes/no — required before PASS)* |
| **Last bar** | — |
| **Last result** | — *(PASS/FAIL)* |
| **Last score** | — *(e.g. 82/100, threshold 85 — required)* |
| **Best score this piece** | — |
| **Largest gap** | — |

---

## Score progression (append one row per critic round — shows loop momentum)

| Round | Score | Threshold | Δ vs prior | Hint | Result | Largest gap |
|-------|-------|-----------|------------|------|--------|-------------|
| — | — | — | — | — | — | — |

**Hint legend:** `CLIMBING` (Δ ≥ +3) · `STALLED` (|Δ| ≤ 2) · `SLIPPED` (Δ ≤ −3) · `FIRST`

---

## Wave log

| Time | Piece | Bar | Critic | Score | Result | Commit | Notes |
|------|-------|-----|--------|-------|--------|--------|-------|
| — | — | — | — | — | — | — | — |

---

## Blockers

*(Lead writes FAILURE_REPORT details here if run stops on FAIL.)*
