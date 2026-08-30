# Unattended Gauntlet Run — Boundary Contract (TEMPLATE)

**Status:** TEMPLATE — copy to `UNATTENDED_RUN.md` per run and fill fields.  
**Spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) · **Progress:** [`workbench.md`](workbench.md)

The lead agent must **not** ask the owner questions during the run. It stops only when **STOP_ON** is satisfied or a **boundary** below fires.

---

## Run identity

| Field | Value |
|-------|-------|
| **CHUNK_ID** | *(e.g. `knight-fortify-2026-08-02`)* |
| **GOAL** | *(one scoped outcome)* |
| **BAR** | *(exact PASS criteria — commands, not vibes)* |
| **Started (UTC)** | — |

---

## Boundaries (safety — not the primary stop condition)

| Boundary | Value |
|----------|-------|
| **MAX_ROUNDS_PER_PIECE** | `8` |
| **MAX_PIECES** | *(e.g. `3`)* |
| **MAX_WALL_CLOCK** | *(e.g. `6h`)* |

---

## Scope lock

### ALLOWED_PATHS

```
*(globs)*
```

### FORBIDDEN

- New global rules without owner ⚠ exception
- Skipping BAR while claiming PASS
- Marking PASS without gauntlet-critic `RESULT: PASS` + `SCORE ≥ PASS_THRESHOLD`

---

## MANDATORY_COMMANDS

| Order | Command | When |
|-------|---------|------|
| 1 | *(command)* | *(when)* |

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | BAR + critic PASS → commit → workbench → stop |
| **Failure** | MAX_ROUNDS or FORBIDDEN → `FAILURE_REPORT.md` → stop |
| **Blocked** | Godot/auth missing → FAILURE_REPORT → stop |

---

## Copy-paste: attach to lead prompt

```text
UNATTENDED RUN — honor-and-iron-3
Read and obey docs/design/UNATTENDED_RUN.md (filled).
Read docs/design/00-gauntlet-loop-cursor.md §5.4.
Update docs/design/workbench.md each wave.
Do not ask the owner questions. Stop per STOP_ON only.
```
