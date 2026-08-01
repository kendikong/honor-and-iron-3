# Roguelike run (P4)

**Status:** `DRAFT` — **blocked on owner worksheet**  
**Pillar ID:** P4  
**Authority chain:** `ROADMAP.md` (post-combat) · `docs/design/00-remaining-work-suite-plan.md` · gameplay skill

## Goal

Define v1 **run loop** spec (worksheet-gated implementation). **Doc gauntlet PASS** = agent-executable spec with clear worksheet gate; **LOOP_READY** requires worksheet filled.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Run spec | — | Worksheet filled + owner approves v1 scope |
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

**Human gate rule:** Doc gauntlet BAR = `lint_design_doc.ps1` only. Empty worksheet is expected in `DRAFT` and must **not** FAIL critic rounds. Worksheet completeness is owner-only and gates **`LOOP_READY`** promotion only — not doc-critic PASS.

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
GOAL: P4 run-loop spec (worksheet gates LOOP_READY only)
BAR: lint PASS; empty worksheet must not FAIL doc critic
PASS_THRESHOLD: 88
RULES: global-systems-first.mdc, roadmap.mdc
ARTIFACT: this file, lint stdout
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
