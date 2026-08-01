# Roguelike run (P4)

**Status:** `DRAFT` — **blocked on owner worksheet**  
**Pillar ID:** P4  
**Authority chain:** `ROADMAP.md` (post-combat) · `docs/design/00-remaining-work-suite-plan.md` · gameplay skill

## Goal

Define and implement v1 **run loop** (nodes, death, rewards, save) after Knight MVP — agent implements only after human worksheet is filled.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Run spec | Worksheet filled in this doc | Owner approves v1 scope |
| Implementation | `PLANNED — tests/run_state_test.gd` (create with run impl) | Fun / pacing |
| Combat integration | Skirmish launch from run node uses tactical path | — |

## Non-goals

- Full meta-progression design without owner yes/no
- Co-op run sync (deferred)
- Replacing tactical combat systems

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| Run length (rooms / floors / time) | |
| Map structure (linear / branching / grid) | |
| Death rules (permadeath / checkpoint) | |
| Meta-progression (yes/no; what persists) | |
| Co-op in v1 run loop (yes/no) | |
| Save model (`user://` schema owner) | |

## Decomposition

1. Owner fills worksheet → spec `LOOP_READY`
2. `RunState` headless RefCounted + tests
3. Map/node UI shell
4. Hook to `SkirmishLaunch` / tactical combat

## Builder playbook

1. **Stop** if worksheet empty — status stays `DRAFT`.
2. Draft `RunState` API from worksheet answers.
3. Add headless tests before Nodes.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

If no `RunState` test: `Infrastructure: INADEQUATE` → propose `tests/run_state_test.gd`.

## Gauntlet stub

```text
GOAL: Run loop per filled worksheet
BAR: run_state_test.gd PASS when implemented
PASS_THRESHOLD: 85
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Owner worksheet | Run design section | Implementation waves |
| `RunState` | Save file schema | Main menu / continue |

## Exit criteria

- [ ] Worksheet complete
- [ ] Headless run test exists and PASS
- [ ] One full run playable F5

## Doc polish scorecard

| Dimension | /10 |
|-----------|-----|
| Covers scope | 8 |
| Machine bars | 7 |
| No duplication | 9 |
| Agent-executable | 8 |
| Human boundaries | 10 |
| Sequencing | 9 |
| Tooling I/O | 7 |
| Loop-polishable | 8 |
