# Knight template (P3)

**Status:** `LOOP_READY` *(gauntlet C4: 89/88 PASS — owner scope clarified 2026-08-01)*  
**Pillar ID:** P3  
**Authority chain:** `class_abilities.txt` (Knight) · `docs/PLANNING_SKILL_QA_CHECKLIST.md` · `data/` factories

## Goal

Knight is the **reference class** for **class/skill validation**: every MVP skill Bible-complete with its own scenario row, run through a **dedicated Knight QA gate** (PLANNED — separate from gameplay-core planning QA). P6 clones this gate per class.

**Do not conflate with gameplay-core QA:** `.\scripts\run_planning_qa_gate.ps1` / `tests/live_planning_scene_test.gd` validate intent system, planning UI, battle shell, and commit path — they use Knights as **fixtures only**. That suite is **not** Knight LOCK and must **not** be changed to serve class validation.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Knight QA gate** (blocks Knight LOCK) | `PLANNED — scripts/run_knight_qa_gate.ps1` — class/skill acceptance (design mirrors planning gate structure; **new** runner) | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per skill |
| **Per-skill scenarios** (interim + gate input) | `godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd` PASS | Checklist phases 1–7 |
| Reference scenario | `tests/skills/shield_bash_scenario.gd` exists | — |
| Gameplay-core regression (when touching planning) | `.\scripts\run_planning_qa_gate.ps1` — **P2 / core only**; not a Knight bar | — |

## Non-goals

- Non-Knight classes (P6) — clone Knight gate, do not extend planning QA
- Changing `live_planning_scene_test.gd` or `run_planning_qa_gate.ps1` for Knight coverage
- New global timeline rules without owner exception
- Per-skill `if ability.id` branches

## Human-only worksheet

N/A

## Decomposition

1. **PLANNED:** Design `run_knight_qa_gate.ps1` + acceptance spec (`docs/KNIGHT_QA_GATE.md` — to write) modeled on `docs/PLANNING_QA_GATE.md` tier structure
2. One skill = one scenario file + registry row in `planning_skill_scenarios_test.gd`
3. Knight gate runs skill scenarios (+ future live class acceptance when designed)
4. Gameplay-core changes still use planning QA gate separately — never merge the two gates

## Builder playbook

1. Read Knight section in `class_abilities.txt`.
2. Copy `tests/skills/shield_bash_scenario.gd` → `tests/skills/<skill>_scenario.gd`.
3. Add `.tres` / factory hooks per global systems.
4. Register in `planning_skill_scenarios_test.gd`.
5. Run **Knight** bar: `run_skill_scenarios_only.gd` today; `run_knight_qa_gate.ps1` when implemented.
6. If you touched planning/intent/UI core: run `run_planning_qa_gate.ps1` per `qa-after-gameplay-changes.mdc` — that is **not** Knight sign-off.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
Test-Path tests/run_skill_scenarios_only.gd
Test-Path tests/skills/shield_bash_scenario.gd
grep planning_skill_scenarios_test.gd
```

Do **not** use `run_planning_qa_gate.ps1` as the P3 doc-critic BAR.

## Gauntlet stub

```text
GOAL: P3 doc — Knight QA gate separate from gameplay-core planning QA; planning gate is fixture-only
BAR: lint PASS; run_skill_scenarios_only.gd + shield_bash_scenario.gd exist; no claim that planning gate = Knight LOCK
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, qa-after-gameplay-changes.mdc, move-preview-intent-truth.mdc
ARTIFACT: this file, lint stdout, grep planning_skill_scenarios_test.gd
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `class_abilities.txt` | Ability `.tres` | `AbilitySystem` |
| Scenario `.gd` | Knight gate PASS | P6 clone (`run_<class>_qa_gate.ps1` pattern) |
| Planning QA gate | Core planning PASS | P2 / gameplay edits only |

## Exit criteria

- [ ] `docs/KNIGHT_QA_GATE.md` + `scripts/run_knight_qa_gate.ps1` designed (PLANNED)
- [ ] All Knight MVP skills registered in `planning_skill_scenarios_test.gd`
- [ ] Knight QA gate PASS (when implemented)
- [ ] Skill scenario runner PASS (`run_skill_scenarios_only.gd`)
- [ ] No bandaid preview/commit paths on Knight skills

## Doc polish scorecard

*(Critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| Covers scope | |
| Machine bars | |
| No duplication | |
| Agent-executable | |
| Human boundaries | |
| Sequencing | |
| Tooling I/O | |
| Loop-polishable | |
