# Pillar spec template

**Status:** `REFERENCE` — copy for new `docs/design/*.md` pillar files (P2–P9)  
**Pillar ID:** `P?`  
**Authority chain:** *(list canonical docs — do not paste their bodies)*

## Goal

*(One paragraph: what “done” means for this slice.)*

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| *(named chunk)* | *(script / test path)* | *(F5 / taste / owner)* |

## Non-goals

- *(≤5 bullets)*

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| | |

*(Or `N/A`.)*

## Decomposition

1. *(Independently verifiable chunk)*

## Builder playbook

1. Read authority chain; grep repo for owners.
2. *(Ordered steps — files/systems.)*

## Critic playbook

```powershell
# Commands only — no builder chat
.\scripts\run_planning_qa_gate.ps1
```

**PASS_THRESHOLD:** 88 (pillar doc)

## Gauntlet stub

```text
Gauntlet — Honor & Iron — [PIECE_ID]
GOAL: [from this doc Goal]
BAR: [from Quality bar machine column]
PASS_THRESHOLD: 88
RULES: global-systems-first.mdc, move-preview-intent-truth.mdc, qa-after-gameplay-changes.mdc
ARTIFACT: git diff, test stdout, screenshots if visual
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| | | |

## Exit criteria

- [ ] *(checkbox)*

## Doc polish scorecard (target ≥8 avg before POLISHED)

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
