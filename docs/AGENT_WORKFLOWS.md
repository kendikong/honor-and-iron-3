# Agent Workflows

## Model selection

- Use the cheapest capable model for the task.
- Small scoped edits and read-only audits should stay on the lightweight model.
- Use a stronger model for new subsystems, resolution-order changes, broad
  determinism/networking work, full classes, or full phases.
- Do not use Fast mode for Composer 2.5.

## Edit workflow

- Read narrowly, plan once, make surgical edits, validate, and report.
- Do not expand scope mid-turn or spawn subagents without explicit request.
- Cursor/Composer workflows require the proposal and permission format defined by
  the active `.cursor/rules/` integration.
- Roo/DeepSeek workflow is defined in `.roo/rules/roo-deepseek-agent.mdc`.

## Response workflow

- Explain the result first and avoid large code or log dumps.
- Every edit summary should identify the canonical system used, whether a
  heuristic was added, validation performed, and remaining risks.

## Historical material moved here

Old model names, quota policy, detailed proposal/changelog templates, and agent
history are intentionally kept out of the universal project instructions. The
active integration rules remain authoritative when a specific agent requires
those formats.
