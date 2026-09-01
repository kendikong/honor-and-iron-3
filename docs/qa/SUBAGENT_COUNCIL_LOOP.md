# Subagent Council Loop

**Established:** 2026-08-31 (owner mandate)  
**NOT:** Gauntlet loop · gauntlet-critic scores · meta-critic BAR · “40 structural passes”

---

## Why this exists

Agents kept:

- Applying code before review
- Using **gauntlet-critic** (scores, regressions, completeness) when the owner asked for **rules-only** review
- Calling structural grep PASS “follows rules” while basic bible behavior (e.g. locked blue tiles) was wrong

The **Subagent Council Loop** is the owner’s mandatory gate **before implementation**.

---

## Name

| Use this | Not this |
|----------|----------|
| **Subagent Council Loop** | Gauntlet loop |
| **Council** / **3 critics** | Gauntlet critic score |
| **Rules-only PASS/FAIL** | 78/100, BAR, threshold 85 |

---

## Process

### 1. Propose (no code)

Agent posts:

- What will change (files, functions)
- Which bible/rule lines it satisfies
- What it will **not** do (no parallel paths, no overlay fallback, etc.)

**No edits until council passes.**

### 2. Council (3 subagents)

Launch **3** subagents in parallel with the rules-only prompt (see `.cursor/rules/subagent-council-loop.mdc`).

- Subagent type: **generalPurpose** (or equivalent) with rules-only instructions  
- **Do not** use `gauntlet-critic` for council unless the owner explicitly asks for gauntlet

Each returns: **PASS** or **FAIL** + rule citations only.

### 3. Verdict

| Result | Action |
|--------|--------|
| 3/3 PASS | Go to Apply |
| Any FAIL | Revise **proposal** → new council. Do not apply. |

### 4. Apply

Implement **only** what the approved proposal says.

### 5. Verify

Run matching automated QA (`qa-after-gameplay-changes.mdc`). Council is **not** a substitute for tests.

---

## What council checks

**In scope:** Does the proposal violate any written rule?

**Out of scope:** Regressions, performance feel, “is it enough,” gauntlet scores, new feature ideas.

---

## Planning work

Use with `docs/design/planning/PLANNING_ACTION_FIX_PLAN_2026-08-31.md` — one council per layer (or per approved sub-slice), before apply.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-31 | Owner mandate recorded; distinguished from Gauntlet Loop |
