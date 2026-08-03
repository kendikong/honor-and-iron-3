# Honor & Iron — Workspace Rules

Godot 4.x deterministic cooperative tactical roguelike. Players manipulate future
board states to solve spatial puzzles. **Positioning over damage. No RNG in combat.**

## Core Non-Negotiables
- **No RNG in combat**: Same inputs -> identical outputs, always.
- **Perfect Information**: Enemy intent is public and locked during planning.
- **Board State > HP**: Positioning/movement/displacement is more valuable than raw damage.

## Co-op Multiplayer Rules
- **Input-Synced Determinism**: Co-op networking must synchronize only user input actions (timeline events, targets, pings) and initial PRNG seeds. Full game state or visual frames must never be synced.
- **Shared, Concurrent Planning**: Players collaborate on a single timeline. Planning must support concurrent client edits, spatial pings, and visual cursor sharing without locking player interfaces.

## Godot Architecture Rules
- **4 Layers (depend downward only)**: Data -> Simulation -> Presentation -> UI.
- **Headless Simulation**: Simulation runs on plain RefCounted state (BoardState/UnitState/TileState) and never references Nodes, allowing cheap cloning/previews.
- **Unified Path**: `Simulator.simulate(state, timeline) -> {final_state, events}` is the single source of truth for both preview (discarded state) and execution (committed state).
- **Decoupled Systems**: Managers own single responsibilities (e.g. CombatManager handles damage/status, GridManager handles occupancy, etc.) and communicate upward via signals.

## General Coding Standards
- **Static Typing**: Always use static typing and explicit return types in GDScript.
- **Enums & Consts**: Prefer enums over strings, and constants over magic numbers.
- **Composition over Inheritance**: Assemble units/entities from independent components.
- **Data-Driven**: Abilities are data (Ability Resources / tres files), not engine code modifications.
- **Fail Loudly**: Assert on resource/state validation; do not silently ignore errors.
- **Global systems first (absolute)**: `.cursor/rules/global-systems-first.mdc` — every edit; minimal heuristics; **mandatory exception warning** before bypassing any global rule. Owner must not re-explain.
- **Move preview = intent truth (absolute)**: `.cursor/rules/move-preview-intent-truth.mdc` — move preview is the intent system; commit must not rewrite or re-render a different outcome than the last valid preview.
- **No bandaid fixes (absolute)**: `.cursor/rules/no-bandaid-fixes.mdc` — one commit/preview path; delete obsolete hacks in the same change.

## Model Policy & API Efficiency
- **Frontier Models (Gemini 1.5 Pro / Claude 3.5 Sonnet)** must be used for medium/big edits (30+ lines, architectural changes, multi-file edits), unless the user explicitly instructs otherwise.
- **Lighter Models (Gemini 1.5 Flash / GPT-OSS medium)** may perform Q&A, reviews, rule edits, and **very small line edits** (≤ 5 lines changed, single file, no new functions or logic flows). They must ask the user to switch model for anything larger.
  - **Pre-edit commit required for lighter models**: Before making any code change, a lighter model must ensure the repo is clean (`git status`) and commit any staged/unstaged work. Only then may it apply the tiny edit and commit it.
- **Surgical Edits**: Use targeted replacements (`replace_file_content` / `multi_replace_file_content`) instead of full file rewrites.
- **Planning Mode**: For complex changes, write `implementation_plan.md` first and wait for approval.
- **No Subagents**: Do not invoke `browser_subagent` or other task-delegating subagents unless explicitly asked.

## Git Hygiene (Mandatory)
- **1 Mandatory Commit Per Prompt:** Any and all code edits require exactly 1 mandatory commit per prompt from the user. Do not split changes across multiple commits, and do not fail to commit if changes were made. Use `git add -A; git commit -m "..."` (semicolon, not &&, for PowerShell).
- **Never use `git add -A` without checking what's untracked first** via `git status`. Stage only source files (`.gd`, `.tscn`, `.tres`, `.godot`-related). Do not stage `.docx`, `.zip`, `.txt` reference files, or temp scripts.
- **Delete temp/debug files immediately** after they are no longer needed (e.g. `old_*.gd`, `diff.txt`, scratch outputs).
- **Commit message format**: `"<Verb> <what>: <short reason>"` — e.g. `"Fix map centering: call _layout_hud after board loads"`.
- **After every commit:** report the full commit hash (`git rev-parse HEAD`) in the agent Changelog as `**Commit:** \`<hash>\`` so the user can cite it for reverts.
- **Never leave the repo dirty at end of turn.** If a task is complete, commit before responding to the user to satisfy the 1 mandatory commit rule.
- **Push to remote every 3 commits:** After every 3rd local commit (count since the last push), run `git push origin master` (or current branch) to sync the remote. Also **always push at the end of a session** and **immediately before any Cloud Agent / Automation handoff**. Prefer `.\scripts\sync_local_remote.ps1 -Mode Push`. After Cloud merges: `.\scripts\sync_local_remote.ps1 -Mode Pull`. Full protocol: `docs/design/LOCAL_CLOUD_SYNC.md`. If a push fails due to auth or no-remote errors, report it clearly rather than silently skipping.
- **Commits are full backups (non-negotiable):** Every commit is a **frozen, self-contained, exact copy of the entire working game at the moment of commit**. Reverting or checking out that commit must give **the same playable game** — no parse errors, no “it only worked because of extra local files.” **If it is not 100% the game at commit time, do not commit** — there is no point. Before committing, verify the tree is complete (all files the game needs are in the commit; nothing required is left uncommitted). Before any `git reset --hard` or revert, warn the user that **only committed files** are restored and **uncommitted work is lost**.

## Implementation Plan Mandate (Master Bible Strict Adherence)
Whenever tasked with writing or executing an Implementation Plan based on a "Master Bible" or source design document (e.g., `class_abilities.txt`), you are strictly forbidden from summarizing, skipping, or paraphrasing mechanics. You must read the relevant section in full and reflect its contents with 100% exhaustive accuracy and detail. Every single passive, active skill, keyword, and upgrade must be explicitly listed and accounted for in your plan before you begin execution.

**Global rules first:** Skills must follow shared economy, timeline, targeting, and effect systems unless the Bible explicitly requires otherwise. If a new global rule or per-skill exception is needed, warn the project owner and get acceptance before implementing (see `class_abilities.txt` § Global Rules First).
- **Never Overwrite the Plan**: When updating the implementation plan, always append new phases or fixes to the existing structure. Never overwrite, truncate, or delete future phases from the document unless that entire phase has been 100% completed.
