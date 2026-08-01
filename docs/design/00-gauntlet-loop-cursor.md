# Gauntlet Loop — Cursor / Composer 2.5

**Status:** ACTIVE  
**Authority:** [Matt Shumer — Gauntlet Loop](https://somethingbig.ai/gauntlet-loop) · [Claude of Duty prompt](https://github.com/mshumer/Claude-of-Duty/blob/main/prompt.md)  
**Scope:** How to run builder/critic gauntlet loops in **Cursor** with **Composer 2.5**, including unattended (sleep/work) runs for Honor & Iron.

This document adapts Shumer’s rules to Cursor’s actual architecture. It does **not** replace repo gameplay rules (`.cursor/rules/global-systems-first.mdc`, `qa-after-gameplay-changes.mdc`, etc.) — critics must enforce those bars too.

---

## 1. What a Gauntlet Loop is

A **lead agent** receives a short goal and a **concrete quality bar**. It:

1. Decomposes the goal into the **smallest independently judgeable pieces**
2. For each piece: **builder subagent** creates → **critic subagent** (fresh context) judges against the bar
3. While our output **fails** the bar: critic returns the **largest meaningful gap** → builder fixes → repeat
4. **Stops** when the bar is **met**, improvements plateau, a **documented boundary** fires, or the **owner stops the run**

**Unattended is in-scope:** Shumer’s CoD run used one prompt, then *“left it alone”* for many hours. Mediation is done by the **lead agent**, not the human between every round.

---

## 2. Cursor architecture (what is and is not possible)

### Supported

| Capability | Cursor behavior |
|------------|-----------------|
| **Lead orchestrator** | The Agent chat you start (Composer 2.5) |
| **Builder subagent** | Task/subagent with write access |
| **Critic subagent** | Separate invocation; use `readonly: true` in `.cursor/agents/*.md` |
| **Fresh critic context** | Subagent does not receive builder chat history — only artifact + bar + rules |
| **Long runs** | Local Agent re-invoking builder → critic each round (machine on) · **Cloud Agents + Automations** (machine off). `/loop` is Claude Code/Fable — not a Cursor guarantee; see Rule 5. |
| **Progress without interrupting** | Lead updates `workbench.md` (or HTML) each wave |

### Not supported

| Myth | Reality |
|------|---------|
| Two Composer agents message each other peer-to-peer | **No** — only parent → subagent → parent |
| Same agent “plays critic” in one turn | **Violates gauntlet** — self-grading |
| Fully autonomous loop with zero orchestrator | **No** — lead parent or Cloud Agent must re-invoke critic after each fix |
| Cheap unlimited overnight on Composer pool | **Budget tradeoff** — subagents add context cost; Cloud Agents use different billing |

### Role diagram

```
Owner (one prompt at start; optional stop at end)
    │
    ▼
LEAD AGENT (Composer 2.5 — this chat or Cloud Agent)
    │  decompose · assign · re-invoke loops · update workbench.md
    ├── Builder subagent (piece A) ──► artifact on disk
    ├── Critic subagent (piece A, readonly, fresh) ──► PASS or largest gap
    ├── Builder subagent (fix A) …
    └── (repeat per piece; optional smoothing pass per wave)
```

**The owner does not paste between builder and critic.** The **lead** does.

---

## 3. The rules (non-negotiable)

### Rule 0 — Agentic harness only

Do not run a gauntlet in a single-shot chat with no tools. The lead must: read/write files, run commands, run tests, capture screenshots when needed, and **spawn subagents**.

### Rule 1 — Goal, not implementation

Give **destination**, not architecture. Short prompt beats 10-page spec. The lead chooses decomposition and parallelization.

**Bad:** “Add these 14 files and refactor `CombatDirector` like …”  
**Good:** “Knight skill `knight_fortify` Bible-complete with headless scenario; bar = planning QA PASS + checklist.”

### Rule 2 — Real bar

The bar must be **inspectable**. Vague goals are invalid.

| Work type | Honor & Iron bar examples |
|-----------|---------------------------|
| Planning / commit | `.\scripts\run_planning_qa_gate.ps1` → **PASS** |
| Sim / bridge | `.\scripts\run_regression_tests.ps1` → **PASS** (wraps headless `regression_test.gd`) |
| Skill | `tests/planning_skill_scenarios_test.gd` row for that skill |
| Docs | Section checklist + `scripts/lint_design_doc.ps1` (W1 bar; pillar files must include `## Goal` + `## Quality bar`) |
| Visual / map | F5 compositor gates in `phase-audit.mdc` + screenshot vs reference |
| Backend (Shumer) | Test suite, determinism hash, fail-loud asserts |

Bar may be **aspirational** (unreachable reference) — it prevents stopping at “good enough for AI.”

If the owner gives a goal but **no bar**, the lead must **propose a concrete bar** (commands + artifacts) and write it to `workbench.md` **before** the first builder pass. No building until the bar is inspectable.

### Rule 3 — Lead decomposes

Do not pre-split every task in the owner prompt. Tell the lead:

> Break the goal into the smallest pieces that can be improved and judged independently.

Coupled systems (e.g. preview + commit for one skill) stay **one piece** — do not parallelize tightly coupled work.

### Rule 4 — Never let the builder grade itself

| Builder gets | Critic gets |
|--------------|-------------|
| Full task context for one piece | Goal snippet, bar, repo rules, **artifact only** |
| Permission to edit | **Readonly** (no file writes) |
| Prior attempt reasoning | **No** builder chat history |

Critic inspects **the real artifact**: test stdout, `git diff`, running scene output, PNG screenshots — **never** a builder-written summary alone.

When possible: **blind A/B** (reference vs output, labels swapped).

**Visual / map pieces:** BAR must name a **reference asset path** (PNG, scene screenshot, or `reports/` capture). Critic compares output to reference — not builder prose. If labels are not blind, critic still must cite **specific pixel/compositor deltas** (draw order, blend mode, z_index, shader errors).

On failure: return **one largest meaningful gap**, not a laundry list.

**Lead cannot mark a piece PASS** without a `gauntlet-critic` subagent returning **`RESULT: PASS`** and **`SCORE: ≥ PASS_THRESHOLD`** on that piece in the same run. “Looks good to me” without critic invocation = **Rule 4 violation**.

### Rule 4b — Harsh score gate (mandatory)

The critic is **harsh** and returns **`SCORE: x/100`**. A piece passes only when **both** are true:

1. All **BAR** commands/checks pass (machine truth).
2. **`SCORE ≥ PASS_THRESHOLD`** (human+rules quality).

| Work type | Default PASS_THRESHOLD |
|-----------|----------------------|
| Code / gameplay piece | **85** |
| Design doc (`docs/design/` pillar) | **88** |
| Meta / plan / suite docs | **90** |
| Wave smoothing pass | **80** |

Override via **PASS_THRESHOLD** in the §9 handoff. Full rubric: [`.cursor/agents/gauntlet-critic.md`](../../.cursor/agents/gauntlet-critic.md).

**Calibration:** 65–78 = mediocre; 79–84 = not ship-ready; **85+** = pass candidate. Critic must not inflate.

**Automatic FAIL scores:** BAR failure → capped at **59**; unverified artifact (summary only) → capped at **40**; infrastructure **INADEQUATE** → capped at **65**.

### Rule 4c — Infrastructure adequacy (mandatory)

Before scoring work quality, the critic must judge whether **inspection infrastructure** is adequate to evaluate **GOAL**:

- **ADEQUATE** — BAR + artifacts (+ reference images when visual) can judge the piece; proceed to rubric.
- **INADEQUATE** — critic cannot properly verify GOAL (missing test, no capture path, no vision reference, doc lint gap, PixelForge/manifest chain missing, BAR misaligned with GOAL).

When **INADEQUATE**:

1. **RESULT: FAIL** (even if partial BAR passed).
2. Critic returns **`Proposed infrastructure:`** — one concrete tool, test, script, or pipeline step (e.g. new skill scenario, `run_planning_qa_gate` coverage, screenshot capture + reference PNG, `lint_design_doc.ps1` rule, PixelForge CANON promote path).
3. Lead schedules a **separate bar-infrastructure piece** — builder implements proposal → critic re-checks infrastructure → then original piece is re-criticed.

Critics **do not** implement infrastructure; they **name** what’s missing. See [`.cursor/agents/gauntlet-critic.md`](../../.cursor/agents/gauntlet-critic.md) § Infrastructure adequacy.

**PASS gate adds a third condition:** `Infrastructure: ADEQUATE` in critic output.

Lead logs **Infrastructure** verdict in `workbench.md` wave notes when `INADEQUATE`.

### Rule 5 — Keep looping

Do not cap at “3 rounds” as the primary stop condition. Use:

- Bar met (tests PASS **and** critic `SCORE ≥ PASS_THRESHOLD`)
- Improvements below noise (document criterion)
- **Boundary** (max rounds per piece, token budget, time box) — safety only; **not** “good enough”
- Owner stops the run

When **MAX_ROUNDS_PER_PIECE** exhausts: write `FAILURE_REPORT.md` and stop — do **not** accept the piece or expand scope.

For long runs: use **Cursor Cloud Automations** or a **recurring local Agent task** (if your build supports it). The `/loop` skill is **Claude Code / Fable** terminology — Cursor may not expose the same slash command; if not, the **lead must explicitly re-invoke** builder → critic each round. For overnight: Cloud Automation or explicit “continue until boundary in `UNATTENDED_RUN.md`.”

### Rule 6 — Watch without mediating

Lead maintains **`docs/design/workbench.md`** (or run-specific path) with:

- Current piece / wave
- Last bar result (PASS/FAIL + **SCORE/threshold** + command output excerpt)
- Largest open gap
- Commit hash when green

Owner checks from phone or morning review — **without** stopping the agent each round.

### Rule 6b — Loud score announcements (mandatory while owner watches)

Every critic round must be **impossible to miss**. The owner should see score movement at a glance.

**Critic:** first output line = score banner (see `gauntlet-critic` format).

**Lead:** immediately after critic returns, post the **same banner** as the **first line** of the lead message (before changelog, before builder plan). Include:

- Piece ID + round number
- `SCORE: x/100` and `THRESHOLD: y`
- `DELTA: +N` or `−N` vs previous round on this piece (or `first round`)
- `RESULT: PASS | FAIL`
- One-word progress hint: `CLIMBING` (delta ≥ +3), `STALLED` (|delta| ≤ 2), `SLIPPED` (delta ≤ −3)

**Workbench:** append every round to **Score progression** (below); update **Score ticker** at top.

**Example (lead + critic must match):**

```text
══════════════════════════════════════
GAUNTLET SCORE │ knight-fortify │ Round 3
SCORE: 82/100 │ THRESHOLD: 85 │ FAIL │ CLIMBING
DELTA: +7 vs round 2 (was 75)
══════════════════════════════════════
```

Do **not** bury scores only in `workbench.md` or Changelog — the banner is the headline.

### Rule 7 — Optional smoothing pass

After a wave (e.g. 5 skills), one **fresh readonly** subagent reviews the **combined** diff for consistency, duplicate paths, and global-rule violations. It does not redesign scope.

---

## 4. Composer 2.5 + budget

| Choice | Guidance |
|--------|----------|
| **Default model** | Composer 2.5 for lead, builder, and critic (`model: inherit` or `composer-2.5`) |
| **Escalate** | GPT 5.6 Terra / frontier only when Composer fails twice on same scoped piece |
| **Subagents** | Required for rule 4; each critic spawn ≈ extra context — keep critic prompts **small** |
| **Parallel builders** | Only for **independent** pieces; never builder+critic in parallel on same piece |
| **Cheapest critic** | Machine bar only (scripts) — valid for backend per Shumer, but not a full visual gauntlet |
| **Overnight, PC off** | Cloud Agent + Automation — not the same as Composer pool pricing |

**Honor & Iron bias:** Prefer **script bars** (QA gate, bridge tests) as critic ground truth; add LLM critic only for gaps scripts cannot see (doc clarity, visual compositor).

---

## 5. Cursor setup

### 5.1 Critic subagent (installed)

**Canonical definition:** [`.cursor/agents/gauntlet-critic.md`](../../.cursor/agents/gauntlet-critic.md) — do not duplicate its body in this doc (avoids drift).

Invoke: `/gauntlet-critic` or “use gauntlet-critic subagent on this piece.”

**Readonly + shell fallback:** `readonly: true` blocks file edits, not necessarily read-only commands. If your Cursor build prevents the critic subagent from running PowerShell/Godot, the **lead** runs the BAR commands, then passes **stdout/stderr only** to the critic (no builder rationale).

### 5.2 Lead agent instructions

Add to the overnight prompt (or `.cursor/rules` pointer):

- Spawn **separate** `gauntlet-critic` subagent after **every** builder pass on a piece — log invocation in `workbench.md` (`Critic: yes`)
- **Loud score banner** as first line of every post-critic message (Rule 6b) — include DELTA vs prior round
- Never self-grade — piece PASS requires critic `RESULT: PASS`, `SCORE ≥ PASS_THRESHOLD`, and **`Infrastructure: ADEQUATE`**
- Update `docs/design/workbench.md` every wave
- On gameplay edits: run mandatory QA per `qa-after-gameplay-changes.mdc` before claiming PASS
- Commit per `auto-commit-absolute.mdc` when bar passes for a piece

### 5.3 Unattended boundary file

For sleep/work runs, also pass [`docs/design/UNATTENDED_RUN.md`](UNATTENDED_RUN.md):

- `CHUNK_ID` — one scoped deliverable
- `ALLOWED_PATHS` — glob allowlist
- `MAX_ROUNDS_PER_PIECE` — e.g. 8
- `MANDATORY_COMMANDS` — exact QA commands
- `STOP_ON` — PASS + commit, or `FAILURE_REPORT.md` + stop

---

## 6. Honor & Iron bar matrix (quick reference)

| Domain | Primary bar | Critic type |
|--------|-------------|-------------|
| Planning / input | `.\scripts\run_planning_qa_gate.ps1` | Script + readonly LLM for parity notes |
| Core sim | `.\scripts\run_regression_tests.ps1` | Script |
| Single skill | Skill scenario + planning QA | Script + checklist grep |
| Design doc | Template sections + lint script | Script + readonly LLM |
| Map / VFX slice | Compositor gates + 10s runtime + reference PNG path in BAR | Script + blind A/B or vision critic (not builder summary) |
| Roguelike / pacing | **Human gate** — not overnight LLM |

---

## 7. Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| Builder and critic in same message without subagent | Self-grading |
| Lead marks piece PASS without `gauntlet-critic` `RESULT: PASS` **and** score ≥ threshold | Fake gauntlet — same as self-grading |
| Accepting piece with tests green but critic score 79/100 | Below threshold — keep looping |
| PASS while critic reports `Infrastructure: INADEQUATE` | Bar cannot judge GOAL — schedule bar-infrastructure piece first |
| Critic reads builder’s “implementation notes” | Contaminated judgment |
| “LGTM” without running bar commands | False PASS (Phase 9 lesson) |
| Owner pastes between two chats each round | Not unattended; lead should orchestrate |
| Open-ended “improve the game” overnight | Scope explosion |
| Fixing `board_view.gd` when tactical path is canonical | Wrong owner — see parity plan |
| `Heuristics added: none` without audit | Rule violation — critic should catch |

---

## 8. Copy-paste: lead prompt (minimal)

Use once at run start. Adjust `GOAL`, `BAR`, and `CHUNK`.

```text
Gauntlet Loop — Honor & Iron — Cursor Composer 2.5

GOAL: [one scoped outcome, e.g. "Implement knight_fortify per class_abilities.txt"]

BAR: [concrete, e.g. "run_planning_qa_gate.ps1 PASS + skill scenario PASS"]

RULES: global-systems-first.mdc, move-preview-intent-truth.mdc, qa-after-gameplay-changes.mdc, no-bandaid-fixes.mdc

You are the LEAD. Do not ask the owner questions during this run.

1. Decompose into smallest independently judgeable pieces.
2. Per piece: builder subagent implements → separate readonly gauntlet-critic subagent judges ARTIFACT against BAR.
3. Critic never sees builder reasoning. Critic returns SCORE/100 + largest gap only.
4. Loop until BAR passes **and** SCORE ≥ PASS_THRESHOLD for that piece, or MAX_ROUNDS_PER_PIECE in UNATTENDED_RUN.md.
5. Update docs/design/workbench.md every wave (piece, bar result, **score ticker**, score progression row, gap, commit).
6. On piece PASS: commit full backup per auto-commit-absolute.mdc.
7. Optional: after each wave, readonly smoothing pass on combined diff.
8. Stop at chunk complete or documented FAILURE_REPORT.md — do not expand scope.

Use Composer 2.5 for subagents unless blocked. Do not prescribe file-level architecture in advance.
```

---

## 9. Copy-paste: critic handoff payload

Lead sends **only this** to `gauntlet-critic` (no builder chat log):

```text
PIECE: [id + one sentence]
GOAL: [acceptance for this piece only]
BAR: [exact commands to run]
PASS_THRESHOLD: [85 | 88 | 90 | 80 — default 85 if omitted]
RULES: [bullet list of enforced .mdc paths]
ARTIFACT:
- git diff --stat
- relevant test stdout (lead runs BAR if critic cannot shell; paste raw output only)
- screenshot paths if visual
- reference asset path if visual (for A/B)
Do not implement. SCORE/100 + PASS or FAIL + Infrastructure + Proposed infrastructure + largest gap + evidence.
```

---

## 10. Relationship to other docs

| Document | Role |
|----------|------|
| `ROADMAP.md` | What to build (canonical phases) |
| `docs/TACTICAL_COMBAT_PARITY_PLAN.md` | Combat path truth |
| `docs/PLANNING_QA_GATE.md` | Planning bar detail |
| `docs/design/UNATTENDED_RUN.md` | Per-run scope lock and stop conditions (overnight) |
| `docs/design/*` pillar specs | Per-domain goals and bars |
| **This file** | How agents loop to hit those bars in Cursor |
| `docs/design/00-remaining-work-suite-plan.md` | How to create the pillar doc suite (waves W1–W4) |

---

## 11. Sources

- [How to Run a Gauntlet Loop](https://somethingbig.ai/gauntlet-loop) — Matt Shumer  
- [Claude of Duty prompt.md](https://github.com/mshumer/Claude-of-Duty/blob/main/prompt.md)  
- [Cursor Subagents](https://cursor.com/docs/subagents) — parent/child model, `readonly`, `model`  
- [How I Prompt Fable](https://shumer.dev/how-i-prompt-fable) — separate critic, `/loop`, workbench

---

## Changelog (this document)

| Date | Change |
|------|--------|
| 2026-08-01 | Initial Cursor/Composer 2.5 adaptation for Honor & Iron |
| 2026-08-01 | Review pass: clarify bar pass/fail loop, dedupe critic agent, `/loop` caveat, regression script path, `UNATTENDED_RUN.md` |
| 2026-08-01 | Hardening: propose-bar-if-missing, critic-required PASS, visual A/B bar, MAX_ROUNDS → FAILURE_REPORT, workbench critic column |
| 2026-08-01 | Harsh score gate: SCORE/100 + PASS_THRESHOLD by work type; rubric in gauntlet-critic agent |
| 2026-08-01 | Rule 6b: loud score banners + DELTA + workbench score progression for owner visibility |
| 2026-08-01 | Rule 4c: critic must judge infrastructure adequacy; Proposed infrastructure on INADEQUATE |
