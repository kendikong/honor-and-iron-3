# Doc polish protocol (P1)

**Status:** `POLISHED`  
**Pillar ID:** P1 (pairs with `00-gauntlet-loop-cursor.md` runtime OS)  
**Authority chain:** `docs/design/00-gauntlet-loop-cursor.md` · `docs/design/_TEMPLATE.md` · `.cursor/agents/gauntlet-critic.md`

## Goal

Any `docs/design/` pillar or meta doc reaches **POLISHED** only through builder → harsh critic loops with **SCORE/100**, **infrastructure adequacy**, and machine lint — never self-grade.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Pillar doc | `.\scripts\lint_design_doc.ps1` PASS | — |
| Promotion | `gauntlet-critic` PASS + SCORE ≥ threshold | Owner LOCK for `LOCKED` |
| Infrastructure | Critic `Infrastructure: ADEQUATE` | — |

## Status promotion

| Status | Machine | Critic | Owner |
|--------|---------|--------|-------|
| `DRAFT` | — | — | — |
| `LOOP_READY` | `lint_design_doc.ps1` PASS | PASS + SCORE ≥ **88** + Infrastructure ADEQUATE | — |
| `POLISHED` | W1 paths accurate | PASS + SCORE ≥ **90** (meta) / **88** (pillar) | — |
| `LOCKED` | — | — | Reply + commit hash in header |

## Rule summary (canonical — do not misdefine)

- **4b:** PASS only if BAR passes **and** `SCORE ≥ PASS_THRESHOLD` (85 code · 88 pillar doc · 90 meta · 80 smoothing).
- **4c:** `Infrastructure: ADEQUATE | INADEQUATE` — can BAR+artifacts judge **GOAL**? If INADEQUATE → FAIL + **Proposed infrastructure** (new test, capture, lint rule, PixelForge step).
- **6b:** Critic + lead post loud score banner first line; update `workbench.md` score progression every pass.

### Rule 6b — Loud score banner (verbatim)

Critic **first output line** and lead **first line** after every pass must match:

```text
══════════════════════════════════════
GAUNTLET SCORE │ [piece-id] │ Critic pass Cn
SCORE: x/100 │ THRESHOLD: y │ PASS|FAIL │ CLIMBING|STALLED|SLIPPED
DELTA: +N vs C(n-1) (was z)
══════════════════════════════════════
```

**Hint legend:** `CLIMBING` (Δ ≥ +3) · `STALLED` (|Δ| ≤ 2) · `SLIPPED` (Δ ≤ −3) · `FIRST` (no prior pass).

Update `workbench.md` **Score ticker** and **Score progression** every pass. Do not bury scores only in Changelog.

## Non-goals

- Replacing `ROADMAP.md` or parity plan bodies
- Implementing game features while polishing docs
- Skipping critic because lint passed

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| LOCK sequencing on master map | *(owner gate)* |
| Approve POLISHED at score 88 vs require 90 | *(default: 88 pillars, 90 meta)* |

## Decomposition

1. Draft from authority + grep (`DRAFT`)
2. Critic pass C1+ (`LOOP_READY` at ≥88)
3. Fix largest gap per pass until `POLISHED` (≥90 meta, ≥88 pillar)
4. Owner `LOCKED` + commit hash in header

## Builder playbook

1. Copy `_TEMPLATE.md` sections into new pillar file.
2. Fill Goal, Quality bar, authority chain only — link canonical docs.
3. Run `lint_design_doc.ps1`.
4. Hand off to `gauntlet-critic` per `00-gauntlet-loop-cursor.md` §9.
5. Update `workbench.md` score ticker every pass (Rule 6b).

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Invoke `/gauntlet-critic` with `PASS_THRESHOLD: 88` (pillar) or `90` (meta).

## Gauntlet stub

```text
Gauntlet — doc-polish — [filename]
GOAL: Document meets _TEMPLATE + lint + critic SCORE threshold
BAR: lint_design_doc.ps1 PASS; gauntlet-critic on this file
PASS_THRESHOLD: 90
Infrastructure: evaluate ADEQUATE per Rule 4c (not merely "lint ran")
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `_TEMPLATE.md` | New pillar `.md` | W2–W4 waves |
| `lint_design_doc.ps1` | PASS/FAIL | Critic BAR |
| `gauntlet-critic` | SCORE/100 + Infrastructure | `workbench.md` |

## Exit criteria

- [ ] Protocol matches Rule 4b, 4c, 6b in gauntlet spec
- [ ] Status promotion table documented
- [ ] Critic PASS ≥88 (this file ≥90)

## Doc polish scorecard

*(Leave blank until critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| | |
