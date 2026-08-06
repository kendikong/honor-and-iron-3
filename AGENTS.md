# Honor & Iron — Universal Agent Rules

Godot 4.x deterministic cooperative tactical roguelike. Players solve spatial
puzzles by manipulating future board states. Positioning is more important than
damage. Combat has no RNG.

## Always preserve

- No combat RNG: identical inputs produce identical outputs.
- Enemy intent is public and locked during planning.
- Simulation is plain `RefCounted` state and never references Nodes.
- `Simulator.simulate(state, timeline)` is the shared preview/execution truth.
- Move preview is intent truth; commit ratifies the last valid preview and must
  not silently reinterpret it.
- Use existing global systems before adding local logic; no bandaids or second
  sources of truth.
- Abilities are data-driven Resources; use shared economy, targeting, timeline,
  and effect systems instead of ability-ID branches.
- Use static typing, explicit return types, enums, constants, composition, and
  fail-loud validation in GDScript.
- Keep Data → Simulation → Presentation → UI dependencies flowing downward.
- Managers own one responsibility and communicate through signals.
- Co-op synchronizes player inputs and seeds, never raw board state or frames.

## Required workflow

1. Read only the relevant files and search narrowly before editing.
2. Identify and extend the canonical owner of the behavior.
3. Make the smallest surgical change; remove an obsolete path when replacing it.
4. Run the matching QA suite after gameplay, simulation, planning, commit, or
   ability changes. UI-only changes still require a parse/error check.
5. Clean up generated QA/debug output before finishing: keep only the compact
  latest summary and raw logs needed for an active investigation; write raw
  output to the OS temp directory whenever possible. Do not leave duplicate,
  numbered, or multi-megabyte logs in the project root.
6. Report the result briefly, including failures and unverified risks.

## Canonical references

- Core constitution and Git safety: `.agents/AGENTS.md`
- Domain guidance: `.agents/skills/*/SKILL.md`
- Global engineering rules: `.cursor/rules/`
- QA commands and scope: `docs/QA_COMMANDS.md`
- Detailed Git workflow: `docs/GIT_WORKFLOW.md`
- Environment notes: `docs/DEVELOPMENT_ENVIRONMENT.md`
- Agent/model workflows: `docs/AGENT_WORKFLOWS.md`

## Output and usage discipline

- Lead with the answer; use concise plain-language responses.
- Do not paste large code blocks or full logs unless requested.
- Do not invoke subagents unless explicitly requested or necessary to unblock the task.
- For complex work, plan once, keep scope fixed, and obtain approval where the
  active agent integration requires it.
- Do not claim a test passed without running it.

## Task-specific skills

Load only the relevant skill: `identity`, `gameplay`, `architecture`,
`ai-standards`, or `roadmap`. Do not read every skill for a routine task.

## Generated-output hygiene

- Treat `qa_*.txt`, `test_output_*.txt`, `*_stdout.txt`, `*_stderr.txt`,
  `live_plan_*.log`, `drag_debug.log`, `godot_error*.txt`, and `execute*.txt`
  as temporary diagnostics unless explicitly designated as a fixture.
- Never attach or read an entire historical log when a targeted error search or
  short summary is sufficient.
- Before a QA, debugging, or commit task is complete, check for newly created
  root-level logs and remove or archive obsolete output outside the workspace.
- Preserve only the latest relevant result and the evidence needed to reproduce
  an unresolved failure. Do not delete logs needed for an active investigation.
