# Unattended Gauntlet Run — AbilityData Modular Refactor (COMPLETE)

**Status:** **STOPPED — SUCCESS** (`STOP_CONDITION_MET: yes`)  
**Spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) §5.4 · **Progress:** [`workbench.md`](workbench.md)  
**Authority:** [`ability-data.md`](ability-data.md) (READY_FOR_REFACTOR)  
**Template:** [`UNATTENDED_RUN.template.md`](UNATTENDED_RUN.template.md)  
**AD-5 deferral:** [`FAILURE_REPORT.md`](FAILURE_REPORT.md) (MAX_ROUNDS @ 90; not required for STOP_ON)

The lead agent must **not** ask the owner questions during this run. It stops only when **STOP_ON** is satisfied or a **boundary** fires.

---

## Run identity

| Field | Value |
|-------|-------|
| **CHUNK_ID** | `ability-data-modular-2026-08-03` |
| **PIECE_ID** | `AD-0` … `AD-SMOOTH` (see workbench) |
| **GOAL** | Refactor live AbilityData to modular header+modules per `ability-data.md` §0–§14; **all current** Knight/Bruiser/positioning skills keep identical gameplay |
| **PASS_THRESHOLD** | **92** per code piece · **90** wave smooth |
| **BAR** | See **Machine bar** below |
| **Started (UTC)** | 2026-08-03 |
| **Godot** | `godot` on PATH (`4.7.stable`) |

### Machine bar (all must be true to claim STOP_ON success)

1. Schema matches bible §12.14: `AbilityData` header (`planner_group`, tags, cost) + `AbilityModule` + layers/gates/keywords
2. Factories/class library author **modules** (not dual flat+modular UIs); runtime may compile modules → `effects[]` during transition
3. `godot --headless --path . --script res://tests/regression_test.gd` — no new FAIL vs baseline attributable to this refactor
4. Planning QA: `godot --headless --path . --script res://tests/run_planning_qa_gate.gd` (or project equivalent) → **PASS**
5. Knight QA + Bruiser QA gates → **PASS** (behavior-identical skills)
6. Fresh **`gauntlet-critic`** on final piece (**AD-SMOOTH**) returns `RESULT: PASS`, `SCORE ≥ 90`, `Infrastructure: ADEQUATE`
7. No new per-skill `if ability.id == …` heuristics; no new anonymous `modifiers` keys
8. **AD-5 deferred** at critic 90 — not required for STOP_ON; remaining pieces AD-2…SMOOTH must still clear bar

### Behavior freeze (must not change)

Knight + Bruiser factory actives, Swap / Push Through, universals they use — same costs, ranges, shapes, effects, upgrades, planning commit flows.

---

## Boundaries (safety — not the primary stop condition)

| Boundary | Value |
|----------|-------|
| **MAX_ROUNDS_PER_PIECE** | `8` *(AD-5 exhausted; other pieces reset)* |
| **MAX_PIECES** | `8` |
| **MAX_WALL_CLOCK** | `24h` *(optional owner stop)* |

---

## Scope lock

### ALLOWED_PATHS

```
data/definitions/**
core/game_enums.gd
core/systems/ability_system.gd
core/factory/**
core/simulation/**
presentation/combat_*.gd
presentation/combat_ui_formatters.gd
ui/class_library_*.gd
tests/**
docs/design/UNATTENDED_RUN.md
docs/design/workbench.md
docs/design/ability-data.md
docs/design/FAILURE_REPORT.md
```

### FORBIDDEN

- Changing skill gameplay numbers / targeting fantasy
- New global rules without owner ⚠ exception
- Dual authoring UIs (flat effects editor + modules editor)
- New anonymous `modifiers` dict keys
- Per-skill `if ability.id == …` branches
- Skipping BAR while claiming PASS
- Marking PASS without gauntlet-critic `RESULT: PASS` + `SCORE ≥ PASS_THRESHOLD`
- Passives / reactions / undo UX (out of AbilityData)

---

## MANDATORY_COMMANDS

| Order | Command | When |
|-------|---------|------|
| 1 | `godot --headless --path . --script res://tests/regression_test.gd` | After AbilitySystem / sim / factory changes |
| 2 | Planning QA gate (headless Godot entry used by `run_planning_qa_gate`) | After planning / commit / AbilityData reader changes |
| 3 | Knight + Bruiser QA gates (headless) | After factory skill ports |
| 4 | Spawn `gauntlet-critic` | After every builder piece |

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | Checklist §14 items 1–12 done; machine bar green; critic PASS ≥ **92** on pieces / ≥ **90** on AD-SMOOTH → commit → workbench → stop |
| **Failure** | MAX_ROUNDS or FORBIDDEN → `FAILURE_REPORT.md` → stop |
| **Blocked** | Godot/auth missing → FAILURE_REPORT → stop |

---

## Copy-paste: attach to lead prompt

```text
UNATTENDED RUN — honor-and-iron-3
Read and obey docs/design/UNATTENDED_RUN.md (filled).
Read docs/design/00-gauntlet-loop-cursor.md §5.4.
Read docs/design/ability-data.md (§0 + §12–§14).
Update docs/design/workbench.md each wave.
Do not ask the owner questions. Stop per STOP_ON only.
```
