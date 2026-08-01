# Gauntlet prompt library (appendix)

**Status:** `DRAFT`  
**Authority chain:** `docs/design/00-gauntlet-loop-cursor.md` · `.cursor/agents/gauntlet-critic.md`

## Goal

Copy-paste lead, builder handoff, and critic payloads per pillar — no editing required at invoke time.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Each prompt block | Matches `00-gauntlet-loop-cursor.md` §8–9 | Runnable after placeholder fill |

## Non-goals

- Replacing gauntlet spec
- Per-run custom prose

## Lead (minimal)

```text
Gauntlet Loop — Honor & Iron — Composer 2.5
Read docs/design/UNATTENDED_RUN.md (filled) + 00-gauntlet-loop-cursor.md
GOAL: [from pillar doc]
You are LEAD. Builder → gauntlet-critic each piece. Loud score banners. workbench.md every pass.
```

## Critic handoff

```text
PIECE: [id]
GOAL: [one sentence]
BAR: [commands]
PASS_THRESHOLD: 88
RULES: global-systems-first.mdc, move-preview-intent-truth.mdc, qa-after-gameplay-changes.mdc
ARTIFACT: diff, stdout, screenshots
Evaluate Infrastructure: ADEQUATE | INADEQUATE
```

## Pillar quick thresholds

| Doc | PASS_THRESHOLD |
|-----|----------------|
| P2–P8 implementation | 85 |
| Pillar specs (this suite) | 88 |
| Meta (suite plan, doc-polish) | 90 |

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

## Gauntlet stub

```text
GOAL: Prompt blocks match gauntlet spec §8–9 with Infrastructure line
BAR: lint PASS; compare to 00-gauntlet-loop-cursor.md
PASS_THRESHOLD: 88
RULES: gauntlet-critic agent spec
ARTIFACT: this file, .cursor/agents/gauntlet-critic.md
```

## Decomposition

1. Lead prompt
2. Critic handoff
3. Per-pillar BAR one-liners in each pillar doc

## Builder playbook

1. Copy blocks from this file into lead/critic handoffs.
2. Fill `GOAL` / `BAR` from target pillar doc gauntlet stub.
3. Never omit `Infrastructure: ADEQUATE | INADEQUATE` line in critic handoff.

## Exit criteria

- [ ] Prompts match gauntlet spec §8–9
- [ ] Infrastructure adequacy line included

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
