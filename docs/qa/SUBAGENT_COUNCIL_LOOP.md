# Subagent Council Loop

**Established:** 2026-08-31 (owner mandate)  
**NOT:** Gauntlet loop · gauntlet-critic scores · meta-critic BAR · “40 structural passes”

Full rule (always on): `.cursor/rules/subagent-council-loop.mdc`

**Audit log (violations + remediation):** [`COUNCIL_AUDIT_LOG.md`](COUNCIL_AUDIT_LOG.md)

**Permanent report mandate (owner 2026-09-01):** [`COUNCIL_REPORT_MANDATE.md`](COUNCIL_REPORT_MANDATE.md) · always-on `.cursor/rules/council-report-mandatory.mdc` — every fix turn shows **what fixed** + **per-critic PASS proof before apply**. Unauthorized ships may be **reverted** (see audit log V4).

---

## Why this exists

Agents kept applying code before review, using gauntlet scoring as “rules check,” and calling grep PASS “follows rules” while basic bible behavior (e.g. locked blue tiles) was wrong.

**Subagent Council Loop** = mandatory gate **before implementation**.

---

## Process

1. **Propose** — what changes, which rules satisfied, what you will not do, **which behavioral tests** will prove it, and any **⚠ exception** blocks already owner-approved. **No code.**
2. **Council** — launch critics in parallel (see **Council size**). Rules-only PASS/FAIL.
3. **Verdict** — **all** critics PASS → apply. Any FAIL → new proposal → new council.
4. **Apply** — approved proposal only.
5. **Verify** — automated QA per `qa-after-gameplay-changes.mdc` (see **Verify routing**). Council ≠ tests.

6. **Report** — owner-facing reply and changelog use [`COUNCIL_REPORT_MANDATE.md`](COUNCIL_REPORT_MANDATE.md): council proof table **before** apply; **what fixed** after apply. QA headline without proof = invalid.

---

## Proposal minimum (lead agent — critics enforce)

Every proposal **must** include or critics **FAIL**:

| Required in proposal | Why |
|---------------------|-----|
| Owner layer + files + bible section | Scope |
| **Behavioral tests** named (add/update/run) for each bible rule touched | Structural grep alone is not done (`MOVE_PREVIEW_RULES.md` § Authority) |
| **Will not do** list (overlay fallback, per-test branches, sync settle every cell, etc.) | Anti-heuristic |
| If using an **owner-approved exception** below → cite it by ID; do not relabel as “cleanup” | Exceptions are few and explicit |
| If needing a **new** exception → full `⚠ Global system exception` block; council FAIL until owner **yes** | `global-systems-first.mdc` |
| QA failure owner map (when fixing FAILs) | `qa-fix-no-heuristics.mdc` |

**Instant FAIL (any critic):** proposal claims structural SSOT gates alone prove bible compliance.

---

## Council size (efficient split)

| Situation | Critics | Why |
|-----------|---------|-----|
| **Default planning / paint / commit / hover** | **5** | Full rule coverage in one parallel batch |
| **Proposal also fixes QA FAILs or edits tests** | **5 + Critic 6** | QA-fix owner-map discipline |
| **Proposal touches class factories / skills / passives** | **5 + Critic 7** | Skill-global + class QA bar |
| **Tiny doc-only / pointer edit** | **0** | Owner pasted verbatim or read-only — skip council |

Launch all selected critics **in one message** (parallel).

**Verdict:** all PASS (5/5, 6/6, or 7/7). Not majority.

**Cross-critic conflicts:** When charters appear to disagree, **owner-approved exception IDs win** over older milestone prose — e.g. **EX-LOCKED-FIELD** overrides “display reads bundle only” in `SETTLED_PAINT_SSOT_PLAN.md` / `planning-hover-perf-mandatory.mdc` for **locked** current-phase tiles only; bundle-owned layers (next-field, yellow, path) stay on settle path.

**Stale proposal:** If repo or proposal text changes between Propose and Council, **re-run council** on the updated proposal before apply.

**Post-apply amendments (mandatory):** If **any** production or test code changes **after** council PASS and **before** commit (or after commit on the same layer), **stop** — do **not** mark the layer DONE. Run an **amendment council** on the **full shipped delta** (same critic count as the layer) and record in [`COUNCIL_AUDIT_LOG.md`](COUNCIL_AUDIT_LOG.md). Silent post-council patches are a **process violation**.

**Remediation (when violation discovered):** If code shipped without council, or council was skipped on a delta:

1. **Owner may order REVERT** (see `COUNCIL_AUDIT_LOG.md` V4) — not only remediation council.
2. If not reverted: run **remediation council** on **current shipped scope** (commit hash + file list).
3. Record violation type, commits, remediation verdict with **full per-critic table**, and gate result in `COUNCIL_AUDIT_LOG.md`.
4. Layer may stay **DONE** only after remediation **all PASS** + verify gate PASS + valid report per `COUNCIL_REPORT_MANDATE.md`.

**Lead agent records:** After council, changelog must include **`### Council proof (pre-apply)`** with each critic row (1–7) PASS + rule IDs — not a single “council approved” line. After apply: **`### What fixed`** with owner, before→after, commit hash. See `COUNCIL_REPORT_MANDATE.md`. Remediation turns add `Remediation council: N/N PASS` + audit log entry with **full critic table**.

---

## Owner-approved exceptions registry

**Few exceptions exist. Critics must know them — do not FAIL correct use; do FAIL misuse, silent bypass, or deletion.**

| ID | What is allowed | What is **not** allowed | Primary critics |
|----|-----------------|-------------------------|-----------------|
| **EX-PERF-SCHED** | Bounded defer/throttle/coalesce for expensive hover sim + presentation redraw on live F5; cheap empty-walk / occupy-push board clone when slots already built; interaction/revision key + discard stale callbacks; commit flush sync settle before ratify | Deferred intent creation; alternate tile paint truth; commit-slot reconstruction in callback; ratify without matching sealed bundle; removing throttle “for SSOT purity” | **5**, **2**, **4** |
| **EX-BIBLE-UI** | Teleport/blink = dashed hop line (not blue walk corridor); push/pull/forced displacement = **separate UI** (not voluntary-walk settle / blue flood) | Per-skill branches when shared pipeline + data could apply | **1**, **2** |
| **EX-LOCKED-FIELD** | **Locked** current-phase blue/red painted from phase-entry stand + plan revision — **outside** per-hover bundle; not a `_noop` or paint-only settle | Using hover bundle as sole paint source for locked fields; clearing locked paint when bundle mismatches | **1**, **2**, **3** |
| **EX-FROZEN-REPLAY** | Sealed voluntary-walk path **re-shown** on skill step / blocked hover — **display geometry only** (`FROZEN_REPLAY`); no re-sim, no repath | `_restore_sealed_voluntary_walk_preview` full sim; sealed restore on **illegal movement-step hover** | **1**, **2** |
| **EX-POSTMOVE-SLOT** | `_voluntary_walk_postmove_slot_open` and documented POSTMOVE/modular timeline cursor sites only (`PLANNING_REFACTOR_MATRIX` R5) | New PRE/MOVE/POST preview or origin forks | **3**, **4** |
| **EX-SIM-REJECT** | `Simulator` / `preview_commit_valid` **fail-loud reject** at commit — must not mutate displayed intent into a different outcome on accept | Commit-time “fixup” that changes path/landing/facing from last preview | **2**, **4** |
| **EX-INTENT-DIVERGE** | Intentional preview ≠ post-commit presentation | Only with owner **yes** to `⚠ Global system exception` block in chat | **2**, **4** |
| **EX-CLASS-QA-SCOPE** | Full drag/undo/selection sweep **not** required on every skill row; Tier A flagship may include drag in pathing | Using this to skip class gates or leave matrix `HARNESS_ONLY` while claiming done | **7** |
| **EX-QA-DEFER** | Ship with documented QA FAIL + owner deferral | Claiming done without reporting FAIL lines | **6** (process) |

**Not exceptions (common mistakes):** overlay live tile recompute when bundle missing; seal/discard/redo loops; paint-only fake bundles; `if test_name` / `if ability.id` branches; turn-start `base_board` as range origin.

Sources: `global-systems-first.mdc` § Approved performance scheduling; `planning-hover-perf-mandatory.mdc`; `minimal-performance-impact.mdc`; `no-heavy-postprocess-safety.mdc` § Allowed; `MOVE_PREVIEW_RULES.md`; `HOVER_PREVIEW_CARRIED_SSOT_PLAN.md`; `SETTLED_PAINT_SSOT_PLAN.md`; `PLANNING_REFACTOR_MATRIX.md` R3/R5; `move-preview-intent-truth.mdc` § Exception; `CLASS_QA_BIBLE.md` § Owner exceptions.

---

## Verify routing (after apply — not council)

| Change type | Run |
|-------------|-----|
| Planning / paint / commit / hover (default) | `.\scripts\run_planning_qa_gate.ps1` once per completed layer |
| Swap-only fix iteration | `.\scripts\run_swap_planning_acceptance.ps1` until PASS, then full gate if other files touched |
| Class factory / skills | `run_<class>_qa_gate.ps1` + `run_<class>_live_qa.ps1` |
| `docs/qa/QA_SUSPENDED.flag` present | QA blocked — report suspension; do not claim Verify PASS |

Structural gates (`run_hover_preview_ssot_gate.ps1`, `run_planning_ssot_gates.ps1`, etc.) run as guardrails — **never** substitute for behavioral tests in **Proposal minimum**.

---

## The five critics (default council)

Each critic checks **only** its charter + **exceptions registry** rows in its column. Answer: **PASS** or **FAIL** + rule/exception ID cites. No scores. No gauntlet. No “also fix X.”

Subagent type: **generalPurpose** with charter pasted below. **Not** `gauntlet-critic`.

---

### Critic 1 — Bible paint & tiles

**Charter:** Player-visible planning paint behavior.

**Must read if in scope:**
- `docs/design/planning/MOVE_PREVIEW_RULES.md` (authority — wins conflicts)
- `docs/design/planning/SETTLED_PAINT_SSOT_PLAN.md` (locked vs bundle; EX-LOCKED-FIELD)
- `docs/design/planning/PLANNING_ACTION_FIX_PLAN_2026-08-31.md` (paint layer split)

**Check — locked vs bundle (Layer 0):**
- Locked **blue** / **red** (current phase) from **phase-entry** stand; stable across hover until plan revision
- Locked fields **not** owned solely by per-hover bundle; keyed by plan revision + `resolve_layer_origins`
- Bundle mismatch → **hold** locked layer; **do not** clear locked blue/red to empty
- **EX-LOCKED-FIELD** is bible compliance, not a bypass of preview=commit for hover-shaped intent

**Check — hover-shaped paint (in bundle):**
- **Next-phase** field optional on hover; **yellow** hover-only; invalid hover = no yellow
- Walk **path** (live on movement step) vs legal-walk **flood** (locked blue) not conflated
- Frozen path on non-move step; invalid movement-step hover = no path (**EX-FROZEN-REPLAY** must not run there)
- Wait / execution = no planning UI

**Check — bible UI exceptions:**
- **EX-BIBLE-UI:** teleport hop line; push/pull not blue walk

**Check — pipeline:**
- One voluntary-walk pipeline for premove / MOVE module / postmove — no PRE/POST fork in proposal
- Modular skills: later module does not redraw committed walk

**Check — AOE / yellow:**
- Blast footprint from correct stand; shared geometry via `GridSystem.get_affected_tiles` — no per-skill overlay branches

**Check — proposal quality:**
- Names behavioral tests per `PLANNING_ACTION_FIX_PLAN` matrix for rules touched
- FAIL if structural grep alone claimed as behavioral done

---

### Critic 2 — Settle, bundle, commit

**Charter:** Preview = commit; one ratify path; canonical sim/director owners.

**Must read if in scope:**
- `.cursor/rules/move-preview-intent-truth.mdc`
- `docs/design/planning/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md`
- `.cursor/rules/no-heavy-postprocess-safety.mdc`
- `docs/design/planning/POST_PROCESS_AUDIT.md` (if touching flagged hotspots)

**Canonical owners (name in proposal when in scope):**
- Slots: `_build_commit_slots_at_cell` → `_finalize_commit_slots`
- Commit authority: `CombatDirector.validate_commit_slots` / `commit_from_slots` — **same** validator hover and click
- Sim truth: `Simulator.simulate` — preview and execution share one path
- Seal: `PlanningHoverPreview` via `CombatPlanningInput` settle

**Check — settle → seal → display → ratify:**
- Hover settles → seal → display reads correct layer (locked vs bundle per EX-LOCKED-FIELD); click ratifies **same slots**
- No click-time hover redo; no overlay fallback tile math when hover bundle missing for **bundle-owned** layers
- No seal/discard/redo storms; no paint-only fake bundles for commit-shaped hover
- Drag drop = same commit path as hover (`_commit_at_interaction_cell`); `_drag_route` / waypoint caches **staging only** — never direct overlay paint

**Check — exceptions:**
- **EX-PERF-SCHED:** cheap walk allowed only when same slots at commit flush; throttle does not skip flush before ratify
- **EX-FROZEN-REPLAY:** sealed path restore = geometry write only — no re-sim (`no-heavy-postprocess-safety.mdc`)
- **EX-SIM-REJECT:** reject invalid; never rewrite displayed intent on accept
- **EX-INTENT-DIVERGE:** only with owner-approved ⚠ block

**Check — reject paths:**
- Commit rejects without matching / stale bundle (fail loud)
- Stale interaction key discards scheduled callbacks — does not ratify wrong revision

**Check — proposal:**
- FAIL if proposal re-adds display-layer recompute, `_noop` commit-shaped bundles, or click-time full hover redo

---

### Critic 3 — Stand & range origins

**Charter:** Where floods anchor; locked vs next-phase; timeline phase cursor.

**Must read if in scope:**
- `.cursor/rules/action-range-latest-stand.mdc`
- `docs/design/planning/ACTION_RANGE_LATEST_STAND.md`
- `MOVE_PREVIEW_RULES.md` § Stand / origin, § Tile colors (two-range model)
- `docs/design/planning/PLANNING_REFACTOR_MATRIX.md` R3, R5

**Check — locked field origins:**
- Locked blue/red use **phase-entry** stand — not turn-start `base_board`, not raw `hover_coord`
- After committed premove within same planning session: locked blue from **projected** stand + remaining MP (phase entry for *current* phase, not turn-start)

**Check — next-phase origins:**
- Next red/blue from predicted stand at hover / sim landing (approach bash, premove+skill)
- `_action_range_paint_stand` / `next_aim_origin` only for next-phase — not locked field

**Check — no duplicate truth:**
- No duplicate origin getters for same concern (`_intent_stand_origin` vs `_proj_origin` both live)
- `phase_entry_stand` semantics consistent across `PlanningPreviewTiles` and overlay

**Check — timeline exceptions:**
- **EX-POSTMOVE-SLOT:** only documented POSTMOVE/modular sites — no new phase-label forks

---

### Critic 4 — Global systems & anti-heuristic

**Charter:** One owner, one path; 6-row audit; exceptions used correctly.

**Must read if in scope:**
- `.cursor/rules/global-systems-first.mdc` (exceptions registry + 6-row audit)
- `.cursor/rules/non-heuristic-mandate.mdc`
- `.cursor/rules/no-bandaid-fixes.mdc`
- `.agents/AGENTS.md` — 4 layers, sim headless, data over branches

**6-row audit — walk every row; any fail → FAIL unless covered by owner-approved exception ID:**
1. Single owner — no parallel owner
2. One apply path — no second preview/commit/hover path
3. No identity branches — no `if ability.id` / test-name / scene/tab unless ⚠ approved
4. No UI-only flags/meta sim or commit ignores
5. Reusable — same path for other skills/screens without new `if`
6. Obsolete path removed in same change (or proposal says why not)

**Check — architecture:**
- Presentation does not embed sim logic; `Simulator` never references Nodes
- No presentation-only workaround when global owner should be extended

**Check — exceptions:**
- **EX-PERF-SCHED** used inside canonical owner — not labeled “heuristic” to delete
- Misuse of exception (second paint path, deferred intent) → FAIL even if perf cited
- New exception without ⚠ block + owner yes → FAIL

**If proposal touches abilities:** also `.cursor/rules/skill-global-rules.mdc` + `class_abilities.txt` § Global Rules First.

---

### Critic 5 — Perf & scheduling

**Charter:** Live F5 perf rules without breaking SSOT; **EX-PERF-SCHED** guardian.

**Must read if in scope:**
- `.cursor/rules/planning-hover-perf-mandatory.mdc`
- `.cursor/rules/minimal-performance-impact.mdc`
- `.cursor/rules/no-heavy-postprocess-safety.mdc`

**Check — required live F5 mechanisms (do not FAIL proposals that preserve these):**
- `_schedule_hover_sim_refresh` + pointer-still + min interval
- `_should_run_hover_sim_sync` false for live basic move hover
- `_hover_can_preview_move_without_simulate` / occupy-push cheap path when allowed
- `_flush_hover_heavy_sync` → `_run_hover_sim_refresh` before commit ratify
- QA `qa_static_overlay` always full sim on hover

**Check — SSOT parity under perf:**
- Cheap walk produces **same commit slots** as full sim when flush runs before ratify
- Throttle pending must not break **EX-LOCKED-FIELD** (locked blue/red stable while bundle catches up)
- Perf changes must not reintroduce overlay fallback recompute

**Check — doc alignment:**
- If Layer 0 splits locked vs bundle paint, proposal updates `planning-hover-perf-mandatory.mdc` / `SETTLED_PAINT_SSOT_PLAN.md` where they still say “bundle only” for **all** tiles — locked layer is plan-revision keyed

**Check — forbidden:**
- Sync full voluntary-walk settle on every `on_hover_moved` cell on live F5
- Removing PERF GUARD blocks without owner approval
- “Make gate green” heuristics disguised as perf

---

### Critic 6 — QA-fix discipline (optional)

**Add when:** proposal responds to QA FAIL or edits tests/harness.

**Must read:**
- `.cursor/rules/qa-fix-no-heuristics.mdc`
- `docs/qa/QA_FIX_DISCIPLINE.md`

**Check:**
- Fix names canonical owner + **one broken step** (settle / slots / sim / director — not “overlay”)
- Owner map table present; “will not do” heuristics listed
- No overlay fallback, no per-test production branches, no weakened asserts to chase green
- Proposal names behavioral test that would have caught the bug if missing
- **EX-QA-DEFER** only with explicit owner deferral — not silent

---

### Critic 7 — Class / skill scope (optional)

**Add when:** proposal touches `*_factory.gd`, skill scenarios, class gates.

**Must read:**
- `.cursor/rules/class-qa-knight-bar.mdc`
- `.cursor/rules/class-qa-all-classes-mandatory.mdc`
- `.cursor/rules/skill-global-rules.mdc`
- `.cursor/rules/skill-lists-are-drafts.mdc`
- `docs/qa/CLASS_QA_BIBLE.md` § Owner exceptions

**Check:**
- Data/effects path; no new global rule without ⚠ block
- AOE/shaped skills: sim footprint in/out + live overlay parity per Knight bar
- Class changes name required gate runners in proposal
- **EX-CLASS-QA-SCOPE:** drag/undo sweep not required on every row — does not waive factory matrix depth
- No sign-off / LOCK recitals in proposal

---

## Council prompt template (per critic)

```
Subagent Council — [Critic N name] — rules only (NOT gauntlet).

Charter + check list + exception IDs: [paste from SUBAGENT_COUNCIL_LOOP.md § Critic N + registry rows for that critic]

Proposal:
[paste full proposal — must include behavioral tests named]

Answer ONLY:
- PASS or FAIL
- If FAIL: rule file or exception ID + one sentence per violation. No scores. No extra fixes.
```

---

## Master rules index (unowned = gap)

| Domain | Primary sources | Default critic |
|--------|-----------------|----------------|
| Player paint behavior | `MOVE_PREVIEW_RULES.md`, action fix plan | 1 |
| Locked vs bundle split | `SETTLED_PAINT_SSOT_PLAN.md`, action fix plan Layer 0 | 1, 2 |
| Settle / bundle / commit | `move-preview-intent-truth.mdc`, `HOVER_PREVIEW_CARRIED_SSOT_PLAN.md` | 2 |
| Director + sim authority | `CombatDirector.validate_commit_slots`, `Simulator.simulate`, `AGENTS.md` | 2 |
| Stand / range | `action-range-latest-stand.mdc`, `ACTION_RANGE_LATEST_STAND.md` | 3 |
| Anti-heuristic / SSOT architecture | `global-systems-first.mdc`, `non-heuristic-mandate.mdc`, `no-bandaid-fixes.mdc` | 4 |
| Post-process ban | `no-heavy-postprocess-safety.mdc`, `POST_PROCESS_AUDIT.md` | 2, 5 |
| Hover perf + EX-PERF-SCHED | `planning-hover-perf-mandatory.mdc`, `minimal-performance-impact.mdc` | 5 |
| QA fix turns | `qa-fix-no-heuristics.mdc`, `qa-after-gameplay-changes.mdc` | 6 |
| Skills / economy | `skill-global-rules.mdc`, `class_abilities.txt` | 4, 7 |
| Class QA | `class-qa-knight-bar.mdc`, `class-qa-all-classes-mandatory.mdc` | 7 |
| Owner exceptions | This doc § Owner-approved exceptions registry | per ID column |
| Process (lead agent) | `interpret-plan-permission.mdc`, `subagent-council-loop.mdc` | lead |
| Behavioral done | `PLANNING_QA_GATE.md`, action fix plan § Minimum bible behavioral matrix | Verify |

---

## Planning recovery

Use with `docs/design/planning/PLANNING_ACTION_FIX_PLAN_2026-08-31.md` — **one council per layer** before apply. Layer 0 council must explicitly PASS **EX-LOCKED-FIELD** split + behavioral stability tests.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-31 | Owner mandate; distinguished from Gauntlet Loop |
| 2026-08-31 | Expanded to 5-critic efficient split + optional 6/7; master rules index |
| 2026-08-31 | Rigorous checklists; owner-approved exceptions registry; proposal minimum; verify routing |
| 2026-09-01 | Permanent `COUNCIL_REPORT_MANDATE.md` + `council-report-mandatory.mdc`; proof before apply; V4 revert policy |
