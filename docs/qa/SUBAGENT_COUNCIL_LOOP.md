# Subagent Council Loop

**Established:** 2026-08-31 (owner mandate)  
**NOT:** Gauntlet loop · gauntlet-critic scores · meta-critic BAR · “40 structural passes”

Full rule (always on): `.cursor/rules/subagent-council-loop.mdc`

---

## Why this exists

Agents kept applying code before review, using gauntlet scoring as “rules check,” and calling grep PASS “follows rules” while basic bible behavior (e.g. locked blue tiles) was wrong.

**Subagent Council Loop** = mandatory gate **before implementation**.

---

## Process

1. **Propose** — what changes, which rules satisfied, what you will not do. **No code.**
2. **Council** — launch critics in parallel (see **Council size** below). Rules-only PASS/FAIL.
3. **Verdict** — **all** critics PASS → apply. Any FAIL → new proposal → new council.
4. **Apply** — approved proposal only.
5. **Verify** — automated QA (`qa-after-gameplay-changes.mdc`). Council ≠ tests.

---

## Council size (efficient split)

| Situation | Critics | Why |
|-----------|---------|-----|
| **Default planning / paint / commit / hover** | **5** | Full rule coverage in one parallel batch; each owns one domain — no duplicate reads, no gaps |
| **Proposal also fixes QA FAILs or edits tests** | **5 + Critic 6** | Adds `qa-fix-no-heuristics` owner-map discipline |
| **Proposal touches class factories / skills / passives** | **5 + Critic 7** | Adds `skill-global-rules` + class QA bar |
| **Tiny doc-only / pointer edit** | **0** | Owner pasted verbatim or read-only — skip council |

**Do not use 3 generic critics** — too thin; misses stand, anti-heuristic, and perf domains.  
**Do not use 8+** — overlap and quota waste; merge into the 5 charters below.

Launch all selected critics **in one message** (parallel).

**Verdict:** 5/5 PASS (or 6/6, 7/7 if extras used). Not “majority.”

---

## The five critics (default council)

Each critic checks **only** its charter. Answer: **PASS** or **FAIL** + rule file cites. No scores. No gauntlet. No “also fix X.”

Subagent type: **generalPurpose** with charter pasted below. **Not** `gauntlet-critic`.

---

### Critic 1 — Bible paint & tiles

**Charter:** Player-visible planning paint behavior.

**Must read if in scope:**
- `docs/design/planning/MOVE_PREVIEW_RULES.md` (authority — wins conflicts)
- `docs/design/planning/SETTLED_PAINT_SSOT_PLAN.md` (locked vs bundle)
- `docs/design/planning/PLANNING_ACTION_FIX_PLAN_2026-08-31.md` (paint layer split)

**Check:**
- Locked **blue** / **red** (current phase) from phase-entry stand; stable across hover
- **Next-phase** field optional on hover; **yellow** hover-only
- Walk **path** vs legal-walk **flood** not conflated
- Live path on movement step only; frozen path on non-move; invalid hover rules
- Wait / execution = no planning UI
- Drag route, teleport hop, push/pull not blue walk

---

### Critic 2 — Settle, bundle, commit

**Charter:** Preview = commit; one ratify path.

**Must read if in scope:**
- `.cursor/rules/move-preview-intent-truth.mdc`
- `docs/design/planning/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md`
- `.cursor/rules/no-heavy-postprocess-safety.mdc`

**Check:**
- Hover settles → seal → display reads bundle; click ratifies same slots
- No click-time hover redo, no overlay fallback tile math when bundle missing
- No seal/discard/redo storms; no paint-only fake bundles
- Drag drop = same commit path as hover (`_commit_at_interaction_cell`)
- Commit rejects without matching bundle (fail loud)

---

### Critic 3 — Stand & range origins

**Charter:** Where red/blue floods anchor; locked vs latest.

**Must read if in scope:**
- `.cursor/rules/action-range-latest-stand.mdc`
- `docs/design/planning/ACTION_RANGE_LATEST_STAND.md`
- `MOVE_PREVIEW_RULES.md` § Stand / origin, § Tile colors (two-range model)

**Check:**
- Locked fields use **phase-entry** stand — not turn-start `base_board`, not raw `hover_coord`
- **Next-phase** red/blue may use predicted stand at hover / sim landing
- Projected stand after committed premove for remaining MP
- No duplicate origin getters for same concern
- `phase_entry_stand` semantics consistent in proposal

---

### Critic 4 — Global systems & anti-heuristic

**Charter:** One owner, one path; no bandaids.

**Must read if in scope:**
- `.cursor/rules/global-systems-first.mdc`
- `.cursor/rules/non-heuristic-mandate.mdc` (6-row audit on proposal)
- `.cursor/rules/no-bandaid-fixes.mdc`
- `.agents/AGENTS.md` — sim truth, 4 layers, data over branches (if sim/director touched)

**Check:**
- Single canonical owner; no parallel preview/commit/hover path
- No `if ability.id` / test-name / scene branches when data/shared API could apply
- No UI-only flags/meta sim ignores
- Obsolete path removed in same change (or proposal says why not)
- ⚠ exception block present if proposal bypasses a global rule

**If proposal touches abilities:** also `.cursor/rules/skill-global-rules.mdc` + `class_abilities.txt` § Global Rules First.

---

### Critic 5 — Perf & scheduling

**Charter:** Live F5 perf rules without breaking SSOT.

**Must read if in scope:**
- `.cursor/rules/planning-hover-perf-mandatory.mdc`
- `.cursor/rules/minimal-performance-impact.mdc` (owner scheduling exception only)
- `.cursor/rules/no-heavy-postprocess-safety.mdc` (no perf via redo loops)

**Check:**
- Live F5: throttle + cheap empty-walk allowed; QA `qa_static_overlay` full sim
- No sync full settle on every hover cell in `on_hover_moved`
- Commit flush runs sync settle before ratify
- Perf work does not remove locked blue/red or reintroduce overlay fallback
- No “make gate green” heuristics disguised as perf

---

### Critic 6 — QA-fix discipline (optional)

**Add when:** proposal responds to QA FAIL or edits tests/harness.

**Must read:**
- `.cursor/rules/qa-fix-no-heuristics.mdc`
- `docs/qa/QA_FIX_DISCIPLINE.md`

**Check:**
- Fix names canonical owner + broken step (settle/slots/sim/director)
- No overlay fallback, no per-test production branches, no weakened asserts
- Proposal includes owner map + “will not do” heuristics list

---

### Critic 7 — Class / skill scope (optional)

**Add when:** proposal touches `*_factory.gd`, skill scenarios, class gates.

**Must read:**
- `.cursor/rules/class-qa-knight-bar.mdc`
- `.cursor/rules/skill-global-rules.mdc`
- `.cursor/rules/skill-lists-are-drafts.mdc` (no sign-off recitals in proposal)

**Check:**
- Data/effects path; no new global rule without ⚠ block
- Class changes don't skip required gate runners in proposal

---

## Council prompt template (per critic)

```
Subagent Council — [Critic N name] — rules only (NOT gauntlet).

Charter: [paste critic charter + check list from SUBAGENT_COUNCIL_LOOP.md]

Proposal:
[paste full proposal]

Answer ONLY:
- PASS or FAIL
- If FAIL: rule file + one sentence per violation. No scores. No extra fixes.
```

---

## Master rules index (what “thorough” means)

Council critics use **scoped charters** above — not this whole table every time. This index is so nothing important is **unowned**.

| Domain | Primary sources |
|--------|-----------------|
| Player paint behavior | `MOVE_PREVIEW_RULES.md`, action fix plan |
| Settle / bundle / commit | `move-preview-intent-truth.mdc`, `HOVER_PREVIEW_CARRIED_SSOT_PLAN.md`, `SETTLED_PAINT_SSOT_PLAN.md` |
| Stand / range | `action-range-latest-stand.mdc`, `ACTION_RANGE_LATEST_STAND.md` |
| Anti-heuristic / SSOT architecture | `global-systems-first.mdc`, `non-heuristic-mandate.mdc`, `no-bandaid-fixes.mdc` |
| Post-process ban | `no-heavy-postprocess-safety.mdc` |
| Hover perf | `planning-hover-perf-mandatory.mdc`, `minimal-performance-impact.mdc` |
| QA fix turns | `qa-fix-no-heuristics.mdc`, `qa-after-gameplay-changes.mdc` |
| Skills / economy | `skill-global-rules.mdc`, `class_abilities.txt` |
| Class QA | `class-qa-knight-bar.mdc`, `class-qa-all-classes-mandatory.mdc` |
| Process (lead agent) | `interpret-plan-permission.mdc`, `subagent-council-loop.mdc` |
| Behavioral done | `PLANNING_QA_GATE.md`, `PLANNING_SKILL_QA_CHECKLIST.md` — **Verify step**, not council |

Structural grep gates (`run_hover_preview_ssot_gate.ps1`, etc.) are **guardrails after apply**, not council substitutes.

---

## Planning recovery

Use with `docs/design/planning/PLANNING_ACTION_FIX_PLAN_2026-08-31.md` — **one council per layer** before apply.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-31 | Owner mandate; distinguished from Gauntlet Loop |
| 2026-08-31 | Expanded to 5-critic efficient split + optional 6/7; master rules index |
