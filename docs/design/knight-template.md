# Knight template (P3)

**Status:** `DRAFT`  
**Pillar ID:** P3  
**Authority chain:** `class_abilities.txt` (Knight) · `docs/PLANNING_SKILL_QA_CHECKLIST.md` · `data/` factories

## Goal

Knight is the **reference class**: every skill Bible-complete with a headless scenario row (`run_skill_scenarios_only.gd`) **and** Tier 3 planning gate PASS; other classes clone this pipeline (P6).

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Tier 3 planning gate** (blocks release) | `.\scripts\run_planning_qa_gate.ps1` PASS — Tier 3 live scene only; Tier 1/2 legacy in script is **informational** | F5 drag/commit parity |
| **Per Knight skill** (separate code pieces) | Row in `tests/planning_skill_scenarios_test.gd` PASS | `docs/PLANNING_SKILL_QA_CHECKLIST.md` phases 1–7 |
| Reference scenario | `tests/skills/shield_bash_scenario.gd` exists | — |

## Non-goals

- Non-Knight classes (P6)
- New global timeline rules without owner exception
- Per-skill `if ability.id` branches

## Human-only worksheet

N/A

## Decomposition

1. One skill = one gauntlet piece (data + factory + scenario test)
2. Register scenario in `planning_skill_scenarios_test.gd`
3. Run **Tier 3 gate** (`run_planning_qa_gate.ps1`) and **skill scenarios** (`run_skill_scenarios_only.gd`) separately

## Builder playbook

1. Read Knight section in `class_abilities.txt`.
2. Copy `tests/skills/shield_bash_scenario.gd` → `tests/skills/<skill>_scenario.gd`.
3. Add `.tres` / factory hooks per global systems.
4. Register in `planning_skill_scenarios_test.gd`.
5. Run `.\scripts\run_planning_qa_gate.ps1` (Tier 3) **and** `godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd`.

## Critic playbook

```powershell
.\scripts\run_planning_qa_gate.ps1
godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd
```

Grep skill id in `planning_skill_scenarios_test.gd`.

## Gauntlet stub

```text
GOAL: P3 pillar doc — Tier 3 gate vs per-skill scenarios clearly split
BAR: lint_design_doc.ps1 PASS; quality bar paths exist on disk
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, qa-after-gameplay-changes.mdc, move-preview-intent-truth.mdc
ARTIFACT: this file, lint stdout, grep planning_skill_scenarios_test.gd
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `class_abilities.txt` | Ability `.tres` | `AbilitySystem` |
| Scenario `.gd` | Gate PASS | P6 clone |

## Exit criteria

- [ ] All Knight MVP skills have scenarios
- [ ] Planning QA PASS
- [ ] No bandaid preview/commit paths

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
