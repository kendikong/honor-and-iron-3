# Unattended Gauntlet Run — AbilityData Modular Refactor (CLOSED — STOP_ON met)

**Status:** **CLOSED** — AD-5b critic **PASS 93/92** ADEQUATE; AD-REGRESS **PASS 93/90** with Tier 3 live r8; `ability-data.md` §14 checklist complete.  
**Spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) §5.4 · **Progress:** [`workbench.md`](workbench.md)  
**Authority:** [`ability-data.md`](ability-data.md) (READY_FOR_REFACTOR)  
**Template:** [`UNATTENDED_RUN.template.md`](UNATTENDED_RUN.template.md)  
**AD-5 / AD-5b:** [`FAILURE_REPORT.md`](FAILURE_REPORT.md)

The lead agent must **not** ask the owner questions during this run. It stops only when **STOP_ON** is satisfied or a **boundary** fires.

---

## Run identity

| Field | Value |
|-------|-------|
| **CHUNK_ID** | `ability-data-modular-2026-08-03` |
| **PIECE_ID** | `AD-5b` **CLOSED** (critic 93/92 ADEQUATE) — AD-REGRESS remains PASS |
| **GOAL** | Modular AbilityData per `ability-data.md` §0–§14; editor planner path unified; behavior freeze via AD-REGRESS Tier 3 |
| **PASS_THRESHOLD** | **92** per code piece · **90** wave smooth |
| **BAR** | See **Machine bar** below |
| **Started (UTC)** | 2026-08-03 |
| **Godot** | `godot` on PATH (`4.7.stable`) |

### Machine bar (all must be true to claim STOP_ON success)

1. Schema matches bible §12.14: `AbilityData` header (`planner_group`, tags, cost) + `AbilityModule` + layers/gates/keywords
2. Factories/class library author **modules** (not dual flat+modular UIs); runtime may compile modules → `effects[]` during transition
3. Bridge + Knight QA + Bruiser QA headless → **PASS**
4. **Tier 3 live planning** (`LIVE_QA_PROFILE=fast`): GdUnit `res://tests/live_planning_scene_test.gd` via planning gate / CmdTool → **PASS** (zero `[FAIL]`; exit 0). Scenario-only is **not** enough.
5. Fresh **`gauntlet-critic`** on closeout with **Tier 3 live stdout on disk** → `RESULT: PASS`, `SCORE ≥ 90`, `Infrastructure: ADEQUATE`
6. No new per-skill `if ability.id == …` heuristics; no new anonymous `modifiers` keys
7. **AD-5 deferred** at critic 90; **AD-5b PASS 93** closes planner-callback gap
8. `is_movement_skill` = displacement **effects**; `is_movement_kind` = **PRE_MOVE column** — do not conflate

### Behavior freeze (must not change)

Knight + Bruiser factory actives, Swap / Push Through, universals they use — same costs, ranges, shapes, effects, upgrades, **live** planning commit flows (Tier 3 journeys).

---

## Boundaries (safety — not the primary stop condition)

| Boundary | Value |
|----------|-------|
| **MAX_ROUNDS_PER_PIECE** | `8` *(AD-5 exhausted; AD-5b / AD-REGRESS reset)* |
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
presentation/tactical_planning_overlay.gd
presentation/tactical_map_view.gd
presentation/combat_ui_formatters.gd
ui/class_library_*.gd
tests/**
.cursor/agents/gauntlet-critic.md
docs/design/UNATTENDED_RUN.md
docs/design/UNATTENDED_RUN.template.md
docs/design/00-gauntlet-loop-cursor.md
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
- Marking PASS / STOP without **Tier 3 live PASS** + gauntlet-critic ADEQUATE
- Passives / reactions / undo UX (out of AbilityData)

---

## MANDATORY_COMMANDS

| Order | Command | When |
|-------|---------|------|
| 1 | Bridge + Knight + Bruiser headless QA | After AbilitySystem / factory / module changes |
| 2 | **Tier 3 live** `live_planning_scene_test.gd` (`LIVE_QA_PROFILE=fast`) | After any planning reader / `is_movement_*` / AbilitySystem change |
| 3 | Spawn `gauntlet-critic` with live log paths in ARTIFACT | After every builder piece that claims behavior freeze |

Linux Cloud (Tier 3):

```bash
LIVE_QA_PROFILE=fast DISPLAY=:1 LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path . --rendering-driver opengl3 -s -d \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/live_planning_scene_test.gd
```

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | Machine bar green **including Tier 3 live**; critic PASS ≥ **90** on closeout with ADEQUATE → commit → workbench `STOP_CONDITION_MET: yes` → stop |
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
Tier 3 live planning is MANDATORY for STOP_ON.
Do not ask the owner questions. Stop per STOP_ON only.
```
