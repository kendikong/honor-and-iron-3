# Council Report Mandate (Permanent)

**Owner mandate:** 2026-09-01  
**Always-on rule:** `.cursor/rules/council-report-mandatory.mdc`  
**Process:** `docs/qa/SUBAGENT_COUNCIL_LOOP.md`

Unauthorized R30–R32 were **reverted** (`09287ca14` + audit log V4). This document exists so that never happens again without visible proof.

---

## Rule in one sentence

**No gameplay fix is reported, applied, or committed until the turn shows a per-critic PASS table and a plain-language “what fixed” block — council proof first, QA second.**

---

## Valid vs invalid owner-facing report

### Invalid (forbidden)

```
Planning QA down to 263 failures. Council 6/6 PASS. Commit f2e44912a.
```

```
Fixed orbit settle. Logged council post-verify.
```

```
R32 applied — see COUNCIL_AUDIT_LOG.md
```

### Valid (required shape)

**Council proof (before any code edit this turn)**

| Critic | Verdict | IDs cited |
|--------|---------|-----------|
| 1 Bible paint | PASS | EX-LOCKED-FIELD, MOVE_PREVIEW § Tile colors |
| 2 Settle/commit | PASS | EX-PERF-SCHED, EX-FROZEN-REPLAY |
| 3 Stand/range | PASS | action-range-latest-stand |
| 4 Anti-heuristic | PASS | 6-row audit — single owner CombatPlanningInput |
| 5 Perf | PASS | EX-PERF-SCHED — throttle preserved |
| 6 QA-fix | PASS | owner map filled, no overlay fallback |

**Verdict: 6/6 PASS — apply authorized**

**What we are fixing**

- **Bucket:** `trample/matrix/armed_move_hover` stale corridors on unreachable orbit cells  
- **Owner:** `CombatPlanningInput._refresh_voluntary_walk_hover_preview`  
- **Broken step:** stand-only orbit probe still passed stale slot waypoints into settle  
- **Planned delta:** clear `settle_waypoints` when `probe_path.size() < 2` on orbit; write stand anchor before settle  

**What we will not do:** overlay fallback; skip settle entirely; per-test `if` branches  

*(Then apply, verify, commit.)*

**After apply**

- **What fixed:** unreachable orbit hovers settle with empty waypoints so receipt matches `[stand]` only  
- **QA:** `PlanningQaGate.tscn` — FAIL (N lines) — honest bucket list  
- **Commit:** `<hash>`  
- **Audit log:** R33 entry with same critic table  

---

## Where the block must appear

| Location | Required sections |
|----------|-------------------|
| Chat (owner reply) | §2 proof **before** apply; §4 after apply |
| `## Changelog` | `### Council proof (pre-apply)` + `### What fixed` |
| `COUNCIL_AUDIT_LOG.md` | Per-round table + what fixed + commit hash **after** proof, not “6/6 (applied)” alone |

---

## Council round entry template (`COUNCIL_AUDIT_LOG.md`)

```markdown
## YYYY-MM-DD — Layer N R__ (<short title>)

### What we are fixing
- **Bucket:**
- **Owner:**
- **Broken step:**
- **Planned delta:**

### Council proof (pre-apply — before first edit)
| Critic | Verdict | Rule / exception IDs |
|--------|---------|----------------------|
| 1 | PASS | |
| 2 | PASS | |
| 3 | PASS | |
| 4 | PASS | |
| 5 | PASS | |
| 6 | PASS / N/A | |
| 7 | PASS / N/A | |
**Verdict:** __/6 PASS

### What we will not do
- …

### Applied
- **Commit:** `<40-char hash>`
- **What fixed:** (before → after, owner path)
- **Heuristics refused:** …

### Verify
- **Suite:** …
- **Result:** PASS / FAIL
```

---

## Enforcement

- **Lead agent:** Do not use `StrReplace`/`Write` on gameplay files until §2 table is in chat for this turn.
- **Owner:** If the opening lines are QA delta or “fixed” without a critic table, treat the turn as **unauthorized** — demand revert or force council before accepting the commit.
- **Violations:** Log under `COUNCIL_AUDIT_LOG.md` with type **V-REPORT**, **V-FORGE**, or **V-POST** (see always-on rule).
