# QA Fix Discipline (Owner Mandate)

**Status:** ACTIVE — enforced by `.cursor/rules/qa-fix-no-heuristics.mdc` (always on).

## The problem

Agents repeatedly try to turn QA green by patching **presentation** or **tests** with shortcuts:

- Fallback stand when the sealed receipt is missing
- Extra `if` branches for one failing scenario
- Loosening validation so paint "looks right"
- A second code path that disagrees with commit slots / sim

Each shortcut creates **refactor tax**: the next agent fixes symptoms again, SSOT drifts, and failure counts bounce.

## The rule (plain language)

**Correct behavior** = `docs/design/planning/MOVE_PREVIEW_RULES.md`. This discipline is *how* to fix QA without shortcuts — not a second spec.

1. **Read the FAIL log** — group by *who owns the behavior*, not which file asserted.
2. **Fix the owner** — settle, slots, sim, or director — so the normal path produces correct truth.
3. **Paint and commit only read that truth** — never invent a fallback because the receipt was empty.
4. **Re-run QA once** — report PASS/FAIL and failure-count delta.

If the fix plan says "add fallback in overlay when receipt doesn't match" → **wrong plan**. Stop.

## What agents must show you

On any QA-fix turn, the changelog includes:

- Which failure buckets were addressed
- Which **owner** was fixed (not "updated overlay")
- Which tempting shortcuts were **refused**
- Suite result after one re-run

## For owners

You do not need to repeat "don't add heuristics to fix QA." Point agents at this doc or say **"QA fix discipline"** — the always-on rule requires the owner map and refusal list before code edits.
