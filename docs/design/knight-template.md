# Knight template (P3)

**Status:** `DRAFT`  
**Pillar ID:** P3  
**Authority chain:** `class_abilities.txt` (Knight) · `docs/PLANNING_SKILL_QA_CHECKLIST.md` · `data/` factories

## Goal

Knight is the **reference class**: every skill Bible-complete with headless scenario + 7-phase planning QA; other classes clone this pipeline (P6).

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Per Knight skill | Row in `tests/planning_skill_scenarios_test.gd` PASS | Checklist phases 1–7 |
| Gate | `.\scripts\run_planning_qa_gate.ps1` PASS | 60s Boredom / play feel |
| Template | `tests/skills/shield_bash_scenario.gd` pattern copied | — |

## Non-goals

- Non-Knight classes (P6)
- New global timeline rules without owner exception
- Per-skill `if ability.id` branches

## Human-only worksheet

N/A

## Decomposition

1. One skill = one gauntlet piece (data + factory + scenario test)
2. Register scenario in `planning_skill_scenarios_test.gd`
3. Run planning QA gate

## Builder playbook

1. Read Knight section in `class_abilities.txt`.
2. Copy `tests/skills/shield_bash_scenario.gd` → `tests/skills/<skill>_scenario.gd`.
3. Add `.tres` / factory hooks per global systems.
4. Register in `planning_skill_scenarios_test.gd`.
5. Run `run_planning_qa_gate.ps1`.

## Critic playbook

```powershell
.\scripts\run_planning_qa_gate.ps1
```

Grep skill id in `planning_skill_scenarios_test.gd`.

## Gauntlet stub

```text
GOAL: knight_<skill> Bible-complete
BAR: planning QA PASS + scenario file exists
PASS_THRESHOLD: 85
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

| Dimension | /10 |
|-----------|-----|
| Covers scope | 9 |
| Machine bars | 10 |
| No duplication | 9 |
| Agent-executable | 9 |
| Human boundaries | 8 |
| Sequencing | 8 |
| Tooling I/O | 9 |
| Loop-polishable | 9 |
