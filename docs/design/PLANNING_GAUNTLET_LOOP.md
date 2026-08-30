# Planning voluntary-walk gauntlet loop (two-pass contract)

**Status:** ACTIVE — mandatory for planning preview / voluntary-walk refactor work.  
**Backlog:** `docs/design/PLANNING_GAUNTLET_BACKLOG.md`  
**Parent spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 4d

---

## Problem this fixes

A **narrow static grep BAR** alone can score 85+ while **owner bible rules** still fail on a fresh read (round 25 → 26). That is not a regression in code — it is a **broken loop contract**.

**Every round** must be:

1. **Built on the previous loop** — prove prior gaps are fixed or regressed.  
2. **Completely fresh** — full line-by-line bible audit, not assumed from last PASS.

Both passes run **in the same critic invocation**, in order. Neither is optional.

---

## Pass A — Regression (verify prior loop)

**Input:** `PLANNING_GAUNTLET_BACKLOG.md` — all rows `Status: OPEN` or `VERIFY`.

**Critic must:**

1. Read each row’s evidence location in the repo at the stated **COMMIT** (or `HEAD` if lead says so).
2. Mark each row: `FIXED` | `STILL_OPEN` | `REGRESSED` with file:line proof.
3. Update the backlog table (lead commits backlog changes after critic returns).

**Regression PASS:** zero `OPEN`, `STILL_OPEN`, or `REGRESSED` in Pass A queue + verify queue all `FIXED` for this round.

**Forbidden:** inventing a new symbol grep list instead of verifying backlog rows; marking FIX-* PASS without reading code.

---

## Pass B — Fresh bible audit (line by line)

**Input (read in full, every round):**

- `docs/design/MOVE_PREVIEW_RULES.md` — especially § Timeline model, § The one rule, § Live vs frozen (§88 invalid hover), § Movement steps, § Stand/origin, architecture audit table.
- `docs/design/PLANNING_REFACTOR_MATRIX.md` — rows R1–R12.

**Critic must:**

1. Walk owner rules **as if the codebase were new** — do not assume Pass A clean implies bible clean.
2. Log every **HIGH** gap with bible line ref + file:line evidence.
3. Append new gaps to backlog (`GAP-NNN`, `Status: OPEN`).

**Bible PASS:** zero new **HIGH** gaps in Pass B.

**Forbidden:** “structural BAR only,” “grep checklist only,” skipping sections because last round passed.

---

## Verdict (report separately)

| Field | Meaning |
|-------|---------|
| `REGRESSION_PASS` | Pass A — all backlog rows verified fixed |
| `BIBLE_PASS` | Pass B — no new HIGH gaps |
| `RESULT` | `PASS` only if **both** regression and bible PASS |
| `SCORE` | Harsh rubric (`.cursor/agents/gauntlet-critic.md`) — **cannot** PASS on score alone if either pass FAIL |
| `100% abidance claim` | Allowed only when `RESULT: PASS` **and** backlog has zero OPEN HIGH rows. **Claimed:** gauntlet round 31 (`docs/design/PLANNING_GAUNTLET_ROUND31.md`). |

When owner policy is **NO QA**, missing runtime tests must **not** fail Bible PASS or cap score — static read/grep is adequate unless BAR explicitly requires QA.

---

## Lead handoff template (copy every round)

```
PIECE: Planning voluntary-walk refactor
ROUND: <n>
COMMIT: <40-char hash>
PASS_THRESHOLD: 85
NO_QA: yes (unless owner overrides)

PASS A — Regression:
  Backlog: docs/design/PLANNING_GAUNTLET_BACKLOG.md
  Verify every OPEN and VERIFY row.

PASS B — Fresh bible:
  Read MOVE_PREVIEW_RULES.md (full) + PLANNING_REFACTOR_MATRIX R1–R12
  Line-by-line; append new HIGH gaps to backlog.

OUTPUT (required):
  REGRESSION_PASS: PASS|FAIL
  BIBLE_PASS: PASS|FAIL
  RESULT: PASS only if both PASS
  Update backlog row statuses + round history table
```

---

## Builder turn (after FAIL)

1. Fix **Pass A STILL_OPEN / REGRESSED** rows first.  
2. Fix **Pass B new HIGH** gaps (or get owner bible clarification for GAP-004-style ambiguity).  
3. Re-run critic with **same two-pass contract** — round number increments; backlog persists.

---

## Relationship to gameplay QA

`run_planning_qa_gate.ps1` is **WP-9** / owner-run — **not** a substitute for Pass B. Pass B is **static bible vs code**. QA proves runtime behavior after static PASS + owner approval.
