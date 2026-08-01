# Unattended Gauntlet Run — Boundary Contract

**Status:** TEMPLATE — copy this file per run and fill the fields below.  
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
| **MAX_ROUNDS_PER_PIECE** | `8` *(safety cap — on exhaust write FAILURE_REPORT; do not accept partial work)* |
| **MAX_PIECES** | *(e.g. `3` skills max this run)* |
| **MAX_WALL_CLOCK** | *(e.g. `6h` — optional)* |

---

## Scope lock

### ALLOWED_PATHS (globs — lead must not edit outside these)

```
data/**
core/factory/**
core/systems/**
tests/**
docs/design/**
presentation/combat_planning_input.gd
```

*(Adjust per chunk; tighten for doc-only or skill-only runs.)*

### FORBIDDEN (hard stop — write FAILURE_REPORT and exit)

- New global rules or per-skill `if ability.id == …` branches without owner ⚠ exception
- Editing `presentation/board_view.gd` for SP tactical path fixes (use `CombatPlanningInput` / tactical stack)
- Scope beyond **GOAL** / **CHUNK_ID**
- Skipping BAR commands while claiming PASS
- Marking a piece PASS without `gauntlet-critic` returning `RESULT: PASS` **and** `SCORE ≥ PASS_THRESHOLD`

---

## MANDATORY_COMMANDS (run after every piece that touches gameplay)

| Order | Command | When |
|-------|---------|------|
| 1 | `.\scripts\run_planning_qa_gate.ps1` | Planning / commit / preview / overlay / `presentation/combat_*` |
| 2 | `.\scripts\run_regression_tests.ps1` | `core/simulation/`, `core/systems/`, bridge, broad sim |

*(Delete rows that do not apply to this chunk.)*

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | All pieces meet **BAR** + **MANDATORY_COMMANDS** PASS **and** critic `SCORE ≥ PASS_THRESHOLD` → full backup commit → update `workbench.md` → stop |
| **Failure** | `MAX_ROUNDS_PER_PIECE` exhausted on a piece, or FORBIDDEN triggered → write `docs/design/FAILURE_REPORT.md` → update `workbench.md` → stop |
| **Blocked** | Godot not on PATH / command cannot run → FAILURE_REPORT with evidence → stop (do not fake PASS) |

---

## Gauntlet orchestration (lead checklist)

0. If **BAR** is empty or vague, propose concrete BAR + write to `workbench.md` — then stop until next owner-approved run (unattended: BAR must be filled before start).
1. Decompose **GOAL** into smallest judgeable pieces (see main spec Rule 3).
2. Per piece: builder subagent → **readonly** [`gauntlet-critic`](../../.cursor/agents/gauntlet-critic.md) with §9 handoff payload only.
3. **Piece PASS gate:** critic must return `RESULT: PASS` **and** `SCORE ≥ PASS_THRESHOLD` — log score in `workbench.md`. No PASS without critic.
4. Update [`workbench.md`](workbench.md) every wave — **score ticker**, **score progression** row, wave log.
5. **Loud banner:** first line of lead message after critic = score banner (Rule 6b) with DELTA.
6. On piece PASS: `git add` + commit per `auto-commit-absolute.mdc`.
7. Do not expand scope when a piece fails — report and stop or skip per **STOP_ON**.

---

## Copy-paste: attach to lead prompt

```text
UNATTENDED RUN — honor-and-iron-3
Read and obey docs/design/UNATTENDED_RUN.md (this file, filled).
Read docs/design/00-gauntlet-loop-cursor.md.
Update docs/design/workbench.md each wave.
Do not ask the owner questions. Stop per STOP_ON only.
```
