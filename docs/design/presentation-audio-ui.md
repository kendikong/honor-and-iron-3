# Presentation, audio, and UI (P8)

**Status:** `LOOP_READY` *(gauntlet C5: 89/88 PASS)*  
**Pillar ID:** P8  
**Authority chain:** `docs/TACTICAL_COMBAT_PARITY_PLAN.md` (HUD phases) · `presentation/` · `ui/` · `SfxPlayer`

## Goal

Inventory screens, wire SFX events, align HUD with tactical path — extend parity plan presentation slices without legacy `board_view` HUD.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| SFX map | `presentation/sfx_player.gd` DEFS keys (see §Event→SFX map) | Loudness / feel |
| UI inventory | `scenes/TacticalCombat.tscn`, `scenes/MainMenu.tscn`, `scenes/Options.tscn` on disk | Layout / fonts |
| Menu apply | `ui/menu_interface_applier.gd` pattern | — |

## Screen inventory (partial — expand as HUD ships)

| Screen | Scene path |
|--------|------------|
| Tactical combat | `scenes/TacticalCombat.tscn` |
| Main menu | `scenes/MainMenu.tscn` |
| Options | `scenes/Options.tscn` |
| Battle setup | `scenes/BattleSetup.tscn` |

## Event→SFX map (skeleton — wire during P8)

| SfxPlayer key | SimEvent / trigger | Status |
|---------------|-------------------|--------|
| `select` | Unit select | wired |
| `move` | Move commit | wired |
| `ability` | Skill use | wired |
| `spellcast` | Spell cast | wired |
| `invalid` | Illegal action | wired |
| `cancel` | Cancel | wired |
| `execute` | Execute turn | wired |
| `step` | Step sound | wired |
| `hit` | Damage dealt | wired |
| `push` | Push/knockback | wired |
| `thud` | Block/thud | wired |
| `die` | Unit death | wired |
| `turn` | Turn change | wired |
| `win` | Combat win | wired |
| `lose` | Combat lose | wired |

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
GOAL: P8 presentation spec with scene paths + full SfxPlayer DEFS inventory
BAR: lint PASS; Test-Path scene paths + presentation/sfx_player.gd
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
