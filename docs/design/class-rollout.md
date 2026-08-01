# Class rollout (P6)

**Status:** `LOOP_READY` *(gauntlet C4: 88/88 PASS)*  
**Pillar ID:** P6  
**Authority chain:** `class_abilities.txt` · `docs/design/knight-template.md` (P3) · `docs/design/appendices/mass-sim-balance.md`

## Goal

Roll out Bible classes Phases 6–21 **one class per gauntlet campaign**, cloning P3 pipeline; optional mass-sim balance between classes.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Per class | `PLANNED — scripts/run_<class>_qa_gate.ps1` (clone P3 Knight gate) | Balance taste |
| Per-class skills | `tests/run_skill_scenarios_only.gd` pattern per class | `docs/PLANNING_SKILL_QA_CHECKLIST.md` |
| Optional balance | `tests/run_mass_sim_test.gd` | `tests/captures/mass_sim_interpretation.json` review |

## Non-goals

- Knight re-work (use P3 LOCK)
- Per-class global rule exceptions without owner approval
- Misusing global keywords for “close enough” Bible text (clone `docs/KNIGHT_QA_GATE.md` § Global systems fidelity)

## Global systems fidelity (P6 — clone from P3)

Every shipped class must follow **`docs/KNIGHT_QA_GATE.md` § Global systems fidelity**:

- **Rule A:** Factory data + shared `EffectType` / passive triggers — no per-skill heuristics.
- **Rule B:** Bible-exact keywords only (e.g. behind-placement ≠ SWAP).
- **QA:** Scenario headers name Bible clause + expected global effect; meta-critic FAIL on keyword mismatch.

Copy that section verbatim into each `docs/<CLASS>_QA_GATE.md` at P6 split.

## Human-only worksheet

N/A

## Decomposition

1. One class = copy P3 checklist (`docs/design/knight-template.md`)
2. Per skill: clone `tests/skills/shield_bash_scenario.gd` → `tests/skills/<skill>_scenario.gd`; register in `tests/planning_skill_scenarios_test.gd`
3. Batch 2–3 skills per wave; run **class QA gate** + skill scenarios per `knight-template.md` (not planning QA gate)
4. Mass sim epoch after class complete (`appendices/mass-sim-balance.md`)

## Builder playbook

1. Read class section in `class_abilities.txt`.
2. Map each skill/passive to **exact** global effect or passive trigger (`docs/KNIGHT_QA_GATE.md` § Global systems fidelity) before writing factory data or scenarios.
3. Clone `tests/skills/shield_bash_scenario.gd` per skill; register in class scenario registry.
4. Run class QA gate + `run_skill_scenarios_only.gd` (or per-class runner when split).

## Critic playbook

```powershell
# Class bar (when run_knight_qa_gate.ps1 / per-class gate exists)
# Planning QA gate: only after gameplay-core edits — see qa-after-gameplay-changes.mdc
godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd
```

Per skill/class: clone `docs/design/knight-template.md` critic playbook.

## Gauntlet stub

```text
GOAL: P6 doc clones P3 class QA gate — not gameplay planning QA
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
- [ ] No Bible/keyword mismatches (Rule B) in factory data or scenarios

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
