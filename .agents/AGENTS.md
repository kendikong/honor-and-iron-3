# Honor & Iron — Core Workspace Rules

## Design pillars

- No combat RNG; identical inputs must resolve identically.
- Enemy intent is visible and locked during planning.
- Positioning, movement, and displacement are more valuable than raw HP damage.

## Architecture

- Layers depend downward: Data → Simulation → Presentation → UI.
- Simulation uses plain `BoardState` / `UnitState` / `TileState` objects and never
  references Nodes.
- Preview and execution share `Simulator.simulate(state, timeline)`.
- Managers own one responsibility and communicate upward through signals.
- Co-op synchronizes input actions and initial seeds, never raw state or frames.

## Engineering standards

- Use shared global systems and one truth path; never add a bandaid or local
  heuristic when the owning system can be fixed.
- Move preview is intent truth; commit ratifies it without reinterpretation.
- Abilities belong in data Resources and shared effect/economy/targeting systems.
- Use static typing, explicit return types, enums, constants, composition, and
  assertions for invalid state or resources.

## Git safety

- **Auto-commit every edit turn** — `.cursor/rules/auto-commit-absolute.mdc` (absolute;
  overrides "only commit when asked"). Full playable backup each commit.
- Check status before staging; stage all game-needed files for full-backup commits.
- Do not reset or revert without warning that uncommitted work will be lost.
- Push per `.cursor/rules/local-cloud-sync.mdc` and `docs/GIT_WORKFLOW.md`.

## Detailed rules

Global-system, preview-intent, no-bandaid, QA, phase, and model-specific rules
remain in `.cursor/rules/` and `.roo/rules/` where their integrations discover
them. This file is the compact project constitution; those files are canonical
for their specific workflows and must not be duplicated here.
