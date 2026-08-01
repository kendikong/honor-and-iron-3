# Presentation, audio, and UI (P8)

**Status:** `DRAFT`  
**Pillar ID:** P8  
**Authority chain:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` (HUD phases) · `presentation/` · `ui/` · `SfxPlayer`

## Goal

Inventory screens, wire SFX events, align HUD with tactical path — extend parity plan presentation slices without legacy `board_view` HUD.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| SFX map | `PLANNED — §Event→SFX map below` | Loudness / feel |
| UI inventory | `scenes/TacticalCombat.tscn`, `scenes/MainMenu.tscn`, `scenes/Options.tscn` on disk | Layout / fonts |
| Menu apply | `ui/menu_interface_applier.gd` pattern | — |

## Screen inventory (partial — expand as HUD ships)

| Screen | Scene path |
|--------|------------|
| Tactical combat | `scenes/TacticalCombat.tscn` |
| Main menu | `scenes/MainMenu.tscn` |
| Options | `scenes/Options.tscn` |
| Battle setup | `scenes/BattleSetup.tscn` |

## Event→SFX map

`PLANNED —` table mapping `EventBus` combat events → `SfxPlayer` clip paths (fill during P8 implementation).

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
RULES: global-systems-first.mdc, qa-after-gameplay-changes.mdc
ARTIFACT: this file, lint stdout, grep SfxPlayer in presentation/
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
