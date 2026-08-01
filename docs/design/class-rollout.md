# Class rollout (P6)

**Status:** `LOOP_READY` *(gauntlet C4: 88/88 PASS)*  
**Pillar ID:** P6  
**Authority chain:** `class_abilities.txt` · `docs/design/knight-template.md` (P3) · `docs/design/appendices/mass-sim-balance.md`

## Goal

Roll out Bible classes Phases 6–21 **one class per gauntlet campaign**, cloning P3 pipeline; optional mass-sim balance between classes.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Per class | `.\scripts\run_planning_qa_gate.ps1` (Tier 3 gate) | Balance taste |
| Per-class skills | `tests/run_skill_scenarios_only.gd` (P3 clone) | `docs/PLANNING_SKILL_QA_CHECKLIST.md` |
| Optional balance | `tests/run_mass_sim_test.gd` | `tests/captures/mass_sim_interpretation.json` review |

## Non-goals

- Knight re-work (use P3 LOCK)
- Per-class global rule exceptions without owner approval

## Human-only worksheet

N/A

## Decomposition

1. One class = copy P3 checklist
2. Batch 2–3 skills per wave
3. Mass sim epoch after class complete

## Builder playbook

1. Read class section in `class_abilities.txt`.
2. Clone shield_bash scenario pattern per skill.
3. Run `.\scripts\run_planning_qa_gate.ps1` + `tests/run_skill_scenarios_only.gd` per `knight-template.md`.

## Critic playbook

```powershell
.\scripts\run_planning_qa_gate.ps1
godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd
godot --headless --path <repo> --script res://tests/run_mass_sim_test.gd
```

Per skill/class: clone `docs/design/knight-template.md` critic playbook.

## Gauntlet stub

```text
GOAL: P6 doc clones P3 Tier 3 vs per-skill split
BAR: lint PASS; Test-Path paths in quality bar; knight-template.md alignment
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, knight-template.md, qa-after-gameplay-changes.mdc
ARTIFACT: this file, knight-template.md, lint stdout
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| P3 template | Class scenarios | QA gate |
| mass_sim | interpretation export | Balance review |

## Exit criteria

- [ ] Each shipped class has full scenario coverage
- [ ] No per-skill global bypasses

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
