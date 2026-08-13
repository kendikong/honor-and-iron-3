# In-game bug reports

The ESC menu exposes **Report Bug** in every scene:

- Tactical scenes use the existing tactical pause menu.
- Other scenes use the global lightweight ESC menu.
- The Main Menu also has a direct **Report Bug** button.

## What is captured

The player supplies the category, severity, title, description, expected result,
and actual result. The tool automatically adds:

- Current scene, mode, engine/project version, git commit (when available), FPS, window size, and pause state.
- A bounded buffer of the last 64 meaningful events.
- Event history resets when changing scenes, so reports do not mix unrelated modes.
- Current board, projected board, turn-start board, units, statuses, abilities,
  passives, terrain, selected unit/skill, timelines, hover tiles, route, battle
  log tail, and planning preview-failure state.
- The latest preview summary and rejected-action reason.
- An optional screenshot captured only when the player saves the report.

## Where reports go

Reports are written to both locations when the project directory is writable:

- `user://bug_reports/` — always the primary runtime location.
- `reports/bug_reports/` — convenient for the agent to inspect in the repo.

If the project copy cannot be written, use the user-data copy. The report JSON
is self-contained; the screenshot is optional.

## Owner workflow

1. Press Escape.
2. Choose **Report Bug**.
3. Describe what happened and save.
4. Tell the agent: **“Fix all open bug reports.”**

The agent should read the JSON files (each has `"status": "open"` until fixed),
triage design/balance concerns separately from implementation bugs, fix actionable
reports, run the matching QA, and leave the report files available as the audit trail.

## Performance contract

The report system does not record video, serialize the board every frame, scan
the scene tree every frame, or take continuous screenshots. Normal play only
keeps a fixed-size lightweight event ring. Full capture, screenshot readback,
serialization, and disk writes happen after the player presses **Save Bug
Report**, while the game is paused.
