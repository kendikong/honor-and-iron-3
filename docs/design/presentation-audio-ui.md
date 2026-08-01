# Presentation, audio, and UI (P8)

**Status:** `DRAFT`  
**Pillar ID:** P8  
**Authority chain:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` (HUD phases) · `presentation/` · `ui/` · `SfxPlayer`

## Goal

Inventory screens, wire SFX events, align HUD with tactical path — extend parity plan presentation slices without legacy `board_view` HUD.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| SFX map | Every listed combat event calls `SfxPlayer` | Loudness / feel |
| UI inventory | Scene paths exist for each listed screen | Layout / fonts |
| Menu apply | `MenuInterfaceApplier` pattern for settings | — |

## Non-goals

- Full AAA UI redesign without mockups
- Music composition (human gate)
- Sandbox editor (Phase 15)

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| HUD layout reference PNG | |
| Font tier / scale | |

## Decomposition

1. Screen inventory table
2. Event→SFX map
3. HUD parity per parity Phase 12–13

## Builder playbook

1. Grep `SfxPlayer` / `EventBus` for combat events.
2. List scenes under `scenes/` and `ui/`.
3. Match parity plan HUD deliverables.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Grep event names vs Sfx map in this doc (when table filled).

## Gauntlet stub

```text
GOAL: SFX map complete for combat events in spec table
BAR: grep SfxPlayer hooks
PASS_THRESHOLD: 88
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| Combat events list | SFX `.tres` or baked paths | Tactical combat |
| Mockups | HUD layout | `TacticalCombatHud` |

## Exit criteria

- [ ] Screen inventory matches disk
- [ ] No silent combat events in map

## Doc polish scorecard

| Dimension | /10 |
|-----------|-----|
| Covers scope | 8 |
| Machine bars | 7 |
| No duplication | 9 |
| Agent-executable | 8 |
| Human boundaries | 8 |
| Sequencing | 8 |
| Tooling I/O | 8 |
| Loop-polishable | 8 |
