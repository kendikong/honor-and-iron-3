# Gauntlet prompt library (appendix)

**Status:** `LOOP_READY` *(gauntlet C3: 89/88 PASS)*  
**Authority chain:** `docs/design/00-gauntlet-loop-cursor.md` §8–9 · `.cursor/agents/gauntlet-critic.md`

## Goal

Copy-paste lead, builder handoff, and critic payloads per pillar — faithful mirrors of §8–9 (no abbreviation).

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Lead prompt | Matches `00-gauntlet-loop-cursor.md` §8 verbatim structure | Runnable after placeholder fill |
| Critic handoff | Matches §9 + Infrastructure line | — |

## Non-goals

- Replacing gauntlet spec
- Per-run custom prose

## Lead (minimal) — §8 mirror

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

## Critic handoff — §9 mirror

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

## Pillar quick thresholds

| Doc | PASS_THRESHOLD |
|-----|----------------|
| P2–P8 implementation | 85 |
| Pillar specs (this suite) | 88 |
| Meta (suite plan, doc-polish) | 90 |

## Decomposition

1. Lead prompt (§8)
2. Critic handoff (§9)
3. Per-pillar BAR one-liners in each pillar doc gauntlet stub

## Builder playbook

1. Copy §8/§9 blocks from this file — do not shorten.
2. Fill `GOAL` / `BAR` from target pillar doc gauntlet stub.
3. Never omit `Infrastructure:` line in critic handoff.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Compare lead + critic blocks to `00-gauntlet-loop-cursor.md` §8–9.

## Gauntlet stub

```text
GOAL: Prompt blocks match gauntlet spec §8–9 with Infrastructure line
BAR: lint PASS; byte-compare structure to 00-gauntlet-loop-cursor.md §8–9
PASS_THRESHOLD: 88
RULES: gauntlet-critic agent spec
ARTIFACT: this file, .cursor/agents/gauntlet-critic.md
```

## Exit criteria

- [ ] Lead prompt includes 8 numbered orchestration steps
- [ ] Critic handoff includes ARTIFACT bullet list + Infrastructure line

## Doc polish scorecard

*(Critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| Covers scope | |
| Machine bars | |
| No duplication | |
| Agent-executable | |
| Human boundaries | |
| Sequencing | |
| Tooling I/O | |
| Loop-polishable | |
