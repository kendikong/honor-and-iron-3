# Honor & Iron — Agent Instructions

Godot 4.x deterministic cooperative tactical roguelike. Players manipulate future
board states to solve spatial puzzles. **Positioning over damage. No RNG in combat.**

The core constitution is managed through Antigravity's Customizations. The core rules are loaded via `.agents/AGENTS.md` and detailed guidelines load dynamically via Workspace Skills in `.agents/skills/`.

## Active Skills (Loaded Dynamically)
- `identity` — Phase 1: design constitution & game pillars.
- `gameplay` — Phase 2: gameplay systems & combat.
- `architecture` — Phase 3: Godot technical architecture (resolution order, signals, layers).
- `ai-standards` — Phase 4: coding standards & rules.
- `roadmap` — Phase 5: milestones & build order.

## Quick Rules of Thumb
- **Global systems first (absolute):** Every edit uses shared global systems; minimal heuristics; **warn before any exception** — see `.cursor/rules/global-systems-first.mdc` (always on). Owner must not re-explain this.
- **Move preview = intent truth (absolute):** On-screen move preview is the intent system; commit ratifies it and must not change/re-render a different outcome — see `.cursor/rules/move-preview-intent-truth.mdc` (always on).
- One pure `Simulator.simulate(state, timeline)`; preview == execution.
- Simulation = plain RefCounted state, headless, never references Nodes.
- Static typing, enums over strings, composition over inheritance, data over hardcoding.
- Validate mechanics before adding content; prototype code is temporary.
- **Every commit is a full backup** — self-contained, exact copy of the working game at commit time. If revert would not restore the same playable game, do not commit yet. See `.agents/AGENTS.md` § Git Hygiene.

## Code Quality (All Agents — every model)

**See also (always on, highest priority):**
- `.cursor/rules/global-systems-first.mdc` — every edit respects global systems; **mandatory exception warning** before bypassing any global rule
- `.cursor/rules/no-bandaid-fixes.mdc` — no bandaids; one truth path; delete obsolete hacks

The project owner is not a coder. **All agents and models** must write code that would pass a normal professional review — clean, correct, and maintainable, not a rushed patch.

**Do:**
- Fix the **actual cause** of the bug or requirement, not just the visible symptom.
- **Match how this project already works** — same naming, patterns, file layout, and architecture as surrounding code.
- Keep changes **easy to read and easy to change later** — a future developer (or agent) should understand what changed and why without guesswork.
- Use **proper types, clear names, and existing systems** (managers, data files, enums) instead of inventing one-off shortcuts.
- Leave the codebase **no messier than you found it** — no stray debug prints, commented-out junk, or duplicate logic.

**Do not (bandaid / messy code):**
- **Bandaid fixes** — e.g. extra `if` flags to paper over a logic bug, disabling a check "for now", hardcoding a special case for one unit/scene, or returning early to hide an error instead of fixing it.
- **Copy-paste patches** — repeating the same logic in multiple places when the project already has (or should use) one shared path.
- **Mystery code** — vague names, unexplained numbers, or behavior that only works for one case but breaks the next.
- **Hacks to dodge scope** — if the correct fix is too large for the task or model, say so and recommend the right approach — do **not** ship a shortcut to stay within limits.

Full copy also lives in `.agents/AGENTS.md` § Code Quality.


**Only frontier models** (Gemini Pro, Claude Sonnet/Opus, or superior) may perform **medium or big code edits** in this repo.

Medium edits include: changes to a whole file, new features in an existing system,
multi-function refactors, or roughly 30–100 lines in one file.

Big edits include: multi-file changes, large rewrites, new subsystems, refactors
that touch architecture, restoring/reverting large file sets, or any change spanning
roughly 100+ lines or 3+ files.

If you are using a lighter model **other than Composer 2.5** (e.g. Gemini Flash, GPT-OSS medium):
- Do **not** implement medium or big edits yourself.
- Tell the user to **switch this chat** to a frontier model or use Antigravity with Gemini Pro. Do **not** spawn a subagent to do it (subagents burn API quota twice).
- Perform only small, local fixes: tiny diffs, one-liners, typo fixes, config tweaks, questions, and reviews.

If you are using **Composer 2.5**, follow **only** the Composer 2.5 section below — not the lighter-model defaults above.

## Composer 2.5 (Cursor Agent) — Specific Instructions

> **Scope:** These rules apply **only** when the active model is **Composer 2.5** in Cursor.
> They do **not** apply to frontier models, Antigravity, Gemini Flash, GPT-OSS, or any other agent.

Composer 2.5 draws from Cursor's **Auto + Composer pool**, not the frontier API pool. Treat it as a **quota-efficient surgical agent** — not a substitute for frontier models on architecture or Master Bible work.

### Non-negotiable workflow (Composer 2.5 code tasks only)
1. **Never Fast mode.** Use Composer 2.5 Standard only. Do not enable or recommend Fast mode.
2. **Understand → Propose → Ask permission (before any code edit).** For any task that would change files, respond in this order and **stop**:
   - **Every turn, every chat.** This cycle is required for **each user message** that would change files — not only the first message in a conversation. Follow-up fixes, refinements, bug reports, and new requests in the **same** chat still need a fresh proposal and explicit approval. A prior "yes", "go ahead", or "DO IT" on an earlier message does **not** approve later messages.
   - **What I understood** — separate **what you said** (short, faithful summary — do not regurgitate your message word-for-word) from **what I think you mean** (implied goal, symptom vs desired behavior). Call out ambiguity or assumptions explicitly.
   - **Proposed solution** — write out **what I plan to do**, step by step (files, functions, concrete changes), and **why each step** fixes the problem or meets your intent. This is not a repeat of your request — it is the agent's plan and reasoning. Follow the **Proposal format** below.
   - **Ask for permission** — end with an explicit question (e.g. "Should I apply these edits?"). **Do not** run `git commit`, `StrReplace`, `Write`, or any other edit tool until the user approves (e.g. "yes", "go ahead", "approved").
   - Read-only investigation (grep/read) to draft the proposal is allowed before approval; **implementing** is not.
3. **Commit before writing (local only).** After approval only: before the first edit, run `git status`. If the repo is dirty, stage only relevant source files and **local-commit the current state** so recovery is one revert away. Only then apply edits. Pre-edit commits do **not** require an immediate remote push unless the spread-push rules below already apply.
4. **Targeted edits only — never full rewrites.** Use surgical replacements (`StrReplace` / partial edits) on the minimum lines needed. Do not rewrite entire files, functions, or classes when a localized diff suffices. If a task would require replacing >50% of a file, stop and defer or ask the user to rescope.
5. **Edit size limits:**
   - **Small (default):** ≤5 lines changed, single file, no new functions or logic flows — proceed only after user approval.
   - **Small-medium (requires explicit approval):** one file, ~6–30 lines, or a small localized addition (one helper, one signal hook) — include scope in the proposal; user must approve small-medium explicitly in their reply.
   - **Medium+:** defer to a frontier model or Antigravity with Gemini Pro.
6. **Changelog summary always (Composer 2.5).** Every Composer 2.5 response that includes edits, a plan, or a review must end with a **detailed Changelog** section in the format below. Read-only Q&A with no proposed changes may omit it. **Proposal-only turns** (before approval) use Changelog **Notes** to list proposed changes instead of claiming edits were made.
7. **Remote sync after local commits (Composer 2.5).** Follow `.agents/AGENTS.md` § Git Hygiene — Remote push / account sync. Local commit frequency is unchanged; always ensure unpushed commits reach `origin` on the spread schedule (every 3rd local commit, end-of-turn if 3+ ahead, always at session end). Note push result in Changelog **Notes** when a push was attempted.

### Detail & paraphrasing (Composer 2.5 — all written output)

Applies to action plans, changelogs, reviews, and explanatory prose in Composer 2.5 responses.

- **Prefer substance over brevity.** Do not compress a change into a one-liner if that loses meaning.
- **Paraphrasing is allowed** for long code blocks, but the paraphrase must be **long and specific enough** that the user understands exactly what differed — name symbols, values, files, and behavioral effects.
- **Bad (too paraphrased):** "Updated model policy." / "Fixed the handler." / "Aligned with Master Bible."
- **Good (enough detail):** "In `AGENTS.md` Model Policy, split 'lighter models' into two bullets: non-Composer lighter models keep ≤5-line default; Composer 2.5 is redirected to its own section so Fast-mode and pre-edit-commit rules do not apply to Gemini Flash."
- For code: quote exact **Before / After** when feasible; when paraphrasing, include function names, property names, literal values, and what runtime behavior changes.
- Proposal **Changes** bullets must each describe the concrete delta, not the intent alone.
- **Proposal turns** use the **Proposal format** (What I understood → Proposed solution → Permission) on **every** file-changing user message; do not skip straight to editing because an earlier message in the chat was approved.
- **Bad proposal:** parrots the user's message with no plan ("You want Phase 2 undo fixed").
- **Good proposal:** states implied intent, then lists specific file/function changes and why each one fixes it.

### Changelog format (Composer 2.5 — required after plans, edits, and reviews)

Every entry must show **what changed to what**. Use **exact before → after** for code/config edits; use a **detailed summary** (old behavior → new behavior) for logic or doc changes. **Do not over-paraphrase** — if a short summary would hide the delta, write more.

```
## Changelog

### Global systems
- **Global system used:** (canonical owner — required every edit/plan/review turn with changes)
- **Heuristics added:** `none` OR each heuristic named (required; see `global-systems-first.mdc`)

### Added
- `path/to/file.gd` — (what was added and why)

### Changed
- `path/to/file.gd` (lines N–M or function `_foo`)
  - **Before:** `old code, value, or behavior`
  - **After:** `new code, value, or behavior`
  - **Why:** (one line, if not obvious)

### Removed
- `path/to/file.gd` — **Was:** `...` → **Now:** (gone / replaced by X)

### Notes
- (follow-ups, risks, things not done)
```

**Rules:**
- **### Global systems** is mandatory — never omit **Heuristics added:** (`none` or list).
- Use empty sections as `- (none)`.
- **Never** write vague or over-paraphrased entries ("updated file", "fixed bug", "tweaked rules") — always state the concrete delta with enough length to understand without opening the diff.
- **Minimum detail:** each **Changed** entry needs enough prose that the user knows the old state, the new state, and the affected location (file, function, line range, or key name).
- For multi-line edits in one file, group under one bullet with Before/After blocks.
- For `.tres` / enum / config: show old value → new value (exact literals when short).
- For plans/reviews (no edits yet): Changelog lists **proposed** Before → After per planned change, with the same detail level as post-edit changelogs.
- If exact text is too long, quote the **longest useful fragment** (full line or full clause), then paraphrase the remainder — do not replace the whole entry with a single vague sentence.

### When Composer 2.5 SHOULD handle the task
- Single-file small fixes (typos, null checks, signal wiring, enum renames) after user approval.
- Reading/grepping to answer questions about how existing code works (no plan needed for read-only Q&A).
- Reviews, audits, and diff explanations (read-only; no implementation).
- Implementing a **user-approved** proposal with named files and acceptance criteria.
- Small data tweaks (`.tres` value changes, one new constant, one new enum member) with no new logic flows.
- Updating skills/rules/docs when the user provides the exact text or a narrow, explicit diff.

### When Composer 2.5 MUST defer (tell user to switch model)
- Any task sourced from `class_abilities.txt` (Master Bible): passives, actives, keywords, class promotions, scaling rules.
- New subsystems, new managers, or changes to simulation resolution order.
- Multi-file refactors (2+ files) unless user explicitly approves a scoped small-medium plan covering all files.
- Co-op networking, timeline sync, or determinism-sensitive simulation logic.
- "Implement the whole class / phase / milestone" requests without a scoped, approved sub-phase.
- Any edit beyond small-medium scope even if the user has not yet approved expansion.

### Composer 2.5 execution discipline (quota + quality)
- **Targeted edits only.** Never use `Write` to replace a whole file when `StrReplace` can patch the change. Never reformat or refactor code outside the approved plan scope.
- **One scoped deliverable per prompt.** Do not expand scope mid-turn without a new plan and approval.
- **Grep/narrow read first.** Open only the file(s) named in the approved plan; never full-repo reads.
- **No subagents** unless the user explicitly asks.
- **No exploratory agent loops.** If blocked after one read pass, ask a focused question — do not brute-force with 10+ tool calls.
- **Do not re-paste** long rule/skill text into responses; the rules are already in context.
- **Master Bible check:** If the task touches gameplay mechanics, keywords, or class data, stop and recommend frontier-model execution before planning edits.
- **Code quality:** Follow global **Code Quality (All Agents)** rules — no bandaid fixes or messy shortcuts.

### Proposal format (Composer 2.5 — required before any code edit)

Use this structure every time file changes are requested — **once per user message**, including follow-ups in an ongoing conversation. **Stop after "Permission" — do not edit until the user says yes.**

```
## What I understood
- **What you said:** (short summary of the request — do not copy-paste or regurgitate your message)
- **What I think you mean:** (implied intent — the outcome you want, e.g. "Phase 2 should start fresh; undo must not touch Phase 1")
- **Assumptions / open questions:** (anything unclear, or "(none)")

## Proposed solution
- **Root cause:** (if known from investigation, or "will confirm with grep/read before edit")
- **What I plan to do:** (numbered steps — each names file(s), function(s), and the concrete change)
  1. ...
  2. ...
- **Why this fixes it:** (tie each step to the symptom or implied intent — explain cause → effect, not just "because you asked")
- **Size:** small | small-medium
- **Risks:** (determinism, simulation layers, compile, side effects)

## Permission
Should I apply these edits? (Waiting for your approval before changing any files.)
```

Approval means an explicit yes (e.g. "approved", "go ahead", "yes", "apply it") **for that specific message's plan**. Silence, a new unrelated question, or "looks good" without clear go-ahead is **not** approval — ask again if unclear.

**Does not carry forward:** Approval on message N does not authorize edits for message N+1, even in the same chat. Treat each file-changing request as a new permission gate unless the user explicitly says to implement an **already-approved** plan from the immediately prior turn (same numbered steps, no scope change).

**Exceptions (still no silent edits):**
- Read-only Q&A, reviews, and investigations — no permission needed.
- User provides exact replacement text for rules/docs and says to apply it — that message is the approval for that exact diff.
- User says to continue or execute a named step from the **just-approved** proposal in the previous message only.

### Composer 2.5 + Honor & Iron reminders
- Simulation never references Nodes; preview and execution share `Simulator.simulate(state, timeline)`.
- Abilities are data (`.tres` / Resources), not hardcoded engine branches.
- Static typing and explicit return types in all GDScript.
- Fail loudly (assert); do not silently swallow invalid state.

## Antigravity Best Practices (API Efficiency)

To keep workspace limits and API usage optimized:
- Read **only** files/sections needed for the task (grep/narrow search first; no full-repo reads).
- Prefer **targeted code replacements** over rewriting whole files.
- **Never spawn subagents** unless the user explicitly asks or the task is blocked without one.
- **Commit before pivots** — suggest `git commit` before architectural experiments so recovery is easy.
- Keep responses concise; avoid re-explaining architecture the rules already state.
- One scoped deliverable per request when possible; ask before expanding scope.

