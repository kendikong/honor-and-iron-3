# Tactical Combat Parity Plan — Honor & Iron 3

**Status:** ACTIVE — supersedes the failed Phase 9 slice (2026-07-16)  
**Scope:** Make `TacticalCombat.tscn` the **single** SP skirmish combat path with **H&I planning fidelity** preserved unless explicitly deferred below.  
**Authority:** `ROADMAP.md` (unchanged) · `sandbox_map_system.md` · `.agents/AGENTS.md` · `.cursor/rules/phase-audit.mdc`  
**Reference implementation:** the tactical presentation modules and
`CombatDirector` (the removed BoardView path is not a valid implementation source)

---

## Why this plan exists

Phase 9 added UI **shells** without H&I **behavior**, duplicated state across files, and recorded **false PASS** audits in `IMPLEMENTATION_STATUS.md`. This plan replaces that approach with:

1. **Extract once, wire many** — shared modules before more ports  
2. **One owner per concern** — especially intent/hover/preview state  
3. **Full audit after every phase** — not checkbox audits  
4. **Knight MVP gate** — each phase lists explicit playtest scenarios  

**Phase 9 in `IMPLEMENTATION_STATUS.md` is re-opened as FAIL** until Phase 10 closes.

---

## Non-negotiables (carry forward)

| Rule | Detail |
|------|--------|
| Sim is truth | `CombatDirector` + `Simulator.simulate()` — preview == execution |
| No sim → Node | Presentation never decides outcomes |
| Extend, don't duplicate | Port from `board_view` into shared modules; delete copy-paste |
| H&I planning UX | Force basic move, approach/trample, skill-at-coord, dash-at-coord are **MVP**, not post-MVP |
| One combat path | All map and skirmish launches use `TacticalCombat.tscn` |
| Pixel integrity | Nearest filter, quantized overlay motion, compositor gates on visual phases |
| Feature toggles | Living effects remain behind `EffectsSettings` + Options (already wired) |

---

## Target architecture (end state)

```
TacticalCombat.tscn
├── TacticalMapView          # Map pipeline, effects, camera ONLY
├── CombatDirector
├── TacticalCombatShell      # NEW — orchestrator, setup order, no gameplay logic
│   ├── CombatIntentState    # NEW — single intent/hover/selection owner
│   ├── CombatUiFormatters   # NEW — log lines, unit info, ability BBCode (extracted once)
│   ├── TacticalInputController
│   ├── TacticalPlanningOverlay
│   ├── TacticalUnitLayer
│   ├── TacticalUnitOverlay
│   ├── TacticalSimPresenter
│   ├── TacticalCombatHud
│   ├── TacticalSidePanels
│   └── TacticalPauseMenu
├── OptionsMenu
└── SfxPlayer
```

**Completed:** the legacy BoardView scene, script, and sandbox path were removed.

---

## Explicit deferrals (user-approved "not yet")

These are **out of scope** until Phase 15+. Do not half-implement them in earlier phases.

| Item | Target |
|------|--------|
| Online co-op UI (chat, players panel, per-peer clear) | Phase 15 |
| Autobattler / AI score / telemetry HUD | Phase 15 |
| Sandbox HP/status/map-editor in pause | Phase 15 |
| Danger area overlay | Phase 15 |
| Additional classes beyond Knight MVP | Phase 16+ |
| Multiplayer map launch through `TacticalCombat.tscn` | Completed |

---

# Phase overview

| Phase | Name | Purpose |
|-------|------|---------|
| **10** | Foundation & bug fix | Shared modules, orchestrator, confirmed Phase 9 defects fixed |
| **11** | Planning input parity | H&I click/drag/aim semantics via `CombatDirector` RPCs |
| **12** | Inspector & overlays | Rich panels + map overlays + single intent pipeline |
| **13** | Combat flow & feedback | Pause, ready, log completeness, SFX, HP prediction polish |
| **14** | Knight MVP re-gate | Full SP skirmish loop shippable on tactical path only |
| **15** | MP & dev tools | Players panel, chat, sandbox, danger, autobattler |
| **16** | Options unification | Main-menu options + EffectsPanel depth + settings merge |

Each phase below ends with a **mandatory full audit** block. **No phase closes with HIGH issues open.**

---

# Phase 10 — Foundation & confirmed defect repair

## Deliverables

| # | Deliverable | Files |
|---|-------------|-------|
| 10.1 | `CombatIntentState` — owns `_intent_units`, hover coord, selection; signal `intents_changed` | `presentation/combat_intent_state.gd` |
| 10.2 | `CombatUiFormatters` — static formatters extracted from `board_view` (no behavior yet) | `presentation/combat_ui_formatters.gd` |
| 10.3 | `TacticalCombatShell` — wires setup order; director emits only after all listeners ready | `presentation/tactical_combat_shell.gd` |
| 10.4 | Remove `sync_from_board` bandaid once shell guarantees order | `tactical_unit_layer.gd`, `tactical_map_view.gd` |
| 10.5 | Fix BUG-1: timeline unhover must recompute intents, not `set_intent_units({})` | `tactical_combat_hud.gd` |
| 10.6 | Fix BUG-2: overlay + panels subscribe to `CombatIntentState` only | side panels, overlay, hud |
| 10.7 | Fix BUG-3: side panel layout uses anchor presets + `size_changed` handler | `tactical_side_panels.gd` |
| 10.8 | Fix BUG-4: suppress hover when `gui_get_hovered_control() != null` | `tactical_map_view.gd` |
| 10.9 | Fix BUG-7: single warning owner (`TacticalCombatHud` or shell) | hud, side panels |
| 10.10 | Remove dead `_map_view` fields; stop mutating `_sfx._director` — inject via setup | pause menu, map view, sfx |
| 10.11 | Replace `MovementSystem._is_walkable_for` with public API | `movement_system.gd`, input controller |
| 10.12 | Move runtime-spawned UI into `TacticalCombat.tscn` OR document in scene tree | scene + shell |
| 10.13 | Re-open Phase 9 as **FAIL** in `IMPLEMENTATION_STATUS.md` | docs |

## Exit criteria

- [ ] Exactly **one** `_recompute_intent_units` implementation (in `CombatIntentState`)
- [ ] Timeline row hover/unhover does not clear intents incorrectly
- [ ] Intent text and arrow visibility always match (same state object)
- [ ] Side panels survive window resize without manual F5 reposition hack
- [ ] Hover does not update tile info when cursor is over HUD buttons
- [ ] No presentation code calls `MovementSystem._*` private methods
- [ ] `board_changed` listeners work without `sync_from_board` workaround

## Full audit gate (Phase 10)

**Run all four pillars** (`.cursor/rules/phase-audit.mdc`):

### A. Completeness audit
- Every deliverable 10.1–10.13 checked against disk
- `IMPLEMENTATION_STATUS.md` Phase 9 marked FAIL with issue list
- Phase 10 section added with deliverable checklist

### B. Correct coding audit
- Static typing on all new public APIs
- No new `board_view` copy-paste blocks > 20 lines (must live in formatters/intent state)
- Grep: `presentation/` must not reference `MovementSystem._`
- Grep: `_recompute_intent_units` appears in **one** file only

### C. Consistency audit
- Setup order documented in `TacticalCombatShell` header comment
- EventBus vs direct signals: intent state uses signals; document who listens
- Layer numbers: SidePanels=21, Hud=20, Pause=35, Options=30 — unchanged and documented

### D. Issues audit
- Number every issue HIGH / MED / LOW
- **Pass rule:** 0 HIGH open; ≤2 MED/LOW deferred with target phase
- Re-audit entire phase if ≥3 issues found

### Automated tests (Phase 10)
- [ ] `tests/bridge_test_runner.gd` — green
- [ ] `tests/sim_test_runner.gd` — green
- [ ] **NEW** `tests/combat_intent_state_test.gd` — intent recompute on selection/hover/unhover

### Manual F5 checklist (Phase 10)
- [ ] Start skirmish: units visible turn 0
- [ ] Hover timeline row: intents show; unhover: intents restore from selection/hover
- [ ] Resize window: panels remain aligned
- [ ] Hover Execute button: tile info does not flicker under cursor

**Phase commit:** `Complete Phase 10: Combat foundation — intent state, shell, defect fixes` + tag `phase-10`

---

# Phase 11 — Planning input parity (H&I core)

## Deliverables

| # | Deliverable | `board_view` reference |
|---|-------------|------------------------|
| 11.1 | Force Basic Movement toggle (left panel) | `_force_basic_movement`, checkbox in `_build_hud` |
| 11.2 | `_basic_move_allowed`, `_movement_blocked_by_dash`, `_skill_takes_priority_over_basic_move` | same |
| 11.3 | `_try_plan_basic_move` on empty tile click | `_on_left_press` |
| 11.4 | `_try_plan_skill_at_coord` on empty tile + aim paths | `_on_left_press`, `_try_aim_click` extended |
| 11.5 | `_plan_approach_or_trample_on_enemy` on enemy click/drop | enemy branches |
| 11.6 | `rpc_plan_attack_with_approach` wired where needed | director API |
| 11.7 | Drag preview: intents + `_drag_saved_preview` stash/restore | `_refresh_live_interaction_preview` |
| 11.8 | RMB: undo if `director.unit_has_undoable_action` else deselect | `_on_right_click` |
| 11.9 | Per-unit selected ability memory | `_unit_selected_abilities` |
| 11.10 | Wheel during drag refreshes preview | wheel handler in board_view |

**Primary file:** `tactical_input_controller.gd` + `CombatIntentState` + shell wiring.

## Exit criteria (Knight playtest scripts)

| # | Scenario | Pass |
|---|----------|------|
| K1 | Select knight → Force Basic Move ON → click reachable tile → move planned | |
| K2 | Force Basic Move OFF → skill selected → click tile in range → ability planned (not move) | |
| K3 | Bowling Charge: dash to empty tile in line → dash planned | |
| K4 | Trample: drag through enemy → approach/trample plan matches tactical execution | |
| K5 | Drop on enemy with move route → move + attack queued | |
| K6 | RMB with queued actions → undoes; RMB with none → deselects | |
| K7 | Drag cancel restores previous preview (no stale ghosts) | |
| K8 | Scroll wheel changes ability; selected ability remembered per unit | |

## Full audit gate (Phase 11)

### A. Completeness
- All 11.1–11.10 implemented; K1–K8 executed and recorded in audit log

### B. Correct coding
- Input controller calls **only** `CombatDirector` RPCs / public methods — no local damage/move resolution
- Preview uses `preview_drag` / `preview_updated` — not ad-hoc board mutation
- Compare plan output: same seed + same clicks on the tactical path → identical `plan_phase_1` entries

### C. Consistency
- Force basic move state lives in one place (input controller or shell); overlay/panels read it for display only
- SFX keys match `board_view` (`select`, `move`, `ability`, `invalid`, `cancel`)

### D. Issues
- 0 HIGH; ≤2 MED/LOW deferred

### Automated tests (Phase 11)
- [ ] **NEW** `tests/planning_input_test.gd` — headless director: basic move, skill-at-coord, approach RPC smoke (no Nodes)

### Manual F5 (Phase 11)
- [ ] Full K1–K8 on 24×12 skirmish
- [ ] Repeat K4 on 40×20 (path length stress)

**Phase commit:** `Complete Phase 11: H&I planning input parity` + tag `phase-11`

---

# Phase 12 — Inspector, timeline, map overlays

## Deliverables

| # | Deliverable | Source |
|---|-------------|--------|
| 12.1 | Full `_unit_info` port → `CombatUiFormatters` | board_view |
| 12.2 | Full `_log_line` + `_format_damage_telemetry` | board_view |
| 12.3 | `_rebuild_ability_buttons` parity (3-line BBCode skills) | board_view |
| 12.4 | `_recompute_hover_ranges` + `_draw_hover_ranges` (blue move / red threat) | board_view |
| 12.5 | `_draw_preview_arrows`, `_draw_push_arrow`, `_preview_paths` | board_view |
| 12.6 | `_draw_interaction_overlays` / attack lines on hover | board_view |
| 12.7 | Timeline row hover → map unit highlight ring | `_timeline_hover_id` |
| 12.8 | Enemy intent rings on units when in intent set | `_draw_single_unit` |
| 12.9 | Undo button disabled when `!director.unit_has_undoable_action(id)` | board_view |
| 12.10 | `GameSettings.panel_width` / text size applied to side panels | board_view layout |
| 12.11 | Skills + Force Basic Move on **left** column (H&I layout) | board_view `_build_hud` |

## Exit criteria

- [ ] Hover enemy: equipment, passives, stat tooltips, status hints visible
- [ ] Battle log shows: move, push, collision, ability, damage w/ formula, death, face, enemy phase
- [ ] Skill buttons show effect BBCode matching tactical tooltips
- [ ] Blue reachable tiles + red threat tiles on hover during planning
- [ ] Preview arrows for queued moves/attacks visible
- [ ] Intent text, intent arrows, intent rings **always agree** (Phase 10 state owner)

## Full audit gate (Phase 12)

### Visual compositor gates (MANDATORY — code review insufficient)

| Gate | Check |
|------|-------|
| Draw order | Read `TacticalCombat.tscn` z_index: Ground→Shadow→Overlay→Planning→Trees→Units |
| Blend mode | No soft alpha blobs on overlays; dashed routes only |
| Sprite authorship | Pause F5: overlays look intentional, not duplicated stamp noise |
| Runtime 10s | Godot Output: zero shader/material errors on map generate |
| Shader compile | First `_ready` → `_generate_map` path clean |

### A. Completeness
- 12.1–12.11 on disk; visual gates table filled PASS/FAIL in `IMPLEMENTATION_STATUS.md`

### B. Correct coding
- `TacticalCombatInfo.gd` **deleted or reduced to thin wrapper** around `CombatUiFormatters` (no third formatter copy)
- Side panels do not rebuild skill list on every `board_changed` if selection unchanged (debounce or dirty flag)

### C. Consistency
- Log colors use same HEX constants as `board_view`
- Panel width respects `GameSettings`

### D. Issues + playtest
- K1–K8 still pass (no regressions)
- **NEW** K9: hover knight skill → threat tiles match enemy positions
- **NEW** K10: plan move → preview arrow matches execution path

**Phase commit:** `Complete Phase 12: Inspector and planning overlays` + tag `phase-12`

---

# Phase 13 — Combat flow, pause, execution feedback

## Deliverables

| # | Deliverable |
|---|-------------|
| 13.1 | Pause menu hides side panels; resume restores |
| 13.2 | `player_ready_changed` → Execute button "Cancel Ready" + modulate |
| 13.3 | Execute SFX; invalid/reject SFX on `action_rejected` |
| 13.4 | Floating text: heal, magical, burn colors (`_spawn_floating_text` parity) |
| 13.5 | Predicted HP/armor on unit bars during preview |
| 13.6 | Victory/defeat log lines + banner (both) |
| 13.7 | `ENEMY_PHASE_BEGAN` → phase label update |
| 13.8 | Push queue after attack anims (`_pending_push_queue` parity) |
| 13.9 | Compendium: overlay from HUD top bar (match pause behavior) |

## Exit criteria

- [ ] Esc pause → panels hidden → Resume → panels back
- [ ] Execute → Ready → Cancel Ready cycle works SP
- [ ] Damage/heal numbers correct color
- [ ] HP bar shows pending damage tint before commit
- [ ] Full turn execute: log readable start-to-finish

## Full audit gate (Phase 13)

### A–D pillars (standard)
### Execution path audit (MANDATORY)
- [ ] `EventBus.sim_event` order matches the tactical simulation for the same plan (spot-check 3 scenarios)
- [ ] `push_animations_complete` fires before director proceeds (no snap pops)

### Manual F5
- [ ] Play one full skirmish to victory on 28×14
- [ ] Play one skirmish to defeat
- [ ] Restart Turn / Restart Battle from pause + options

**Phase commit:** `Complete Phase 13: Combat flow and feedback` + tag `phase-13`

---

# Phase 14 — Knight MVP re-gate (tactical path only)

## Purpose

Re-close what Phase 8 claimed on **`TacticalCombat.tscn` only**. The legacy path has been removed.

## Deliverables

| # | Deliverable |
|---|-------------|
| 14.1 | BattleSetup → Skirmish → TacticalCombat: **only** path for SP random skirmish |
| 14.2 | All 7 size presets playtested (16×8 … 40×20) |
| 14.3 | Boredom Test optional: 60s idle, effects toggles off = near-still |
| 14.4 | `IMPLEMENTATION_STATUS.md`: Phase 9 FAIL → superseded; Phase 10–14 PASS |
| 14.5 | System audit doc block: tactical data flow diagram verified |

## Knight MVP acceptance (ALL required)

| # | Criterion |
|---|-----------|
| M1 | 1 knight vs hatchling×2 + charger spawns correctly all presets |
| M2 | Full planning loop: select, move, skill, aim, execute P1/P2, enemy turn |
| M3 | Victory and defeat screens + sfx |
| M4 | Options: display, char scale, ambient toggles, restart turn/battle |
| M5 | Compendium accessible |
| M6 | Camera pan/zoom on large maps |
| M7 | No invisible units; no shader spam 10s |
| M8 | Identical plan semantics vs `board_view` for K1–K8 script |

## Full audit gate (Phase 14) — SYSTEM AUDIT

This is the **strictest** audit in the plan. Treat as release gate.

### 1. Four pillars (all PASS required)
### 2. Visual compositor gates (all PASS — HIGH if fail)
### 3. Automated suite (all green)
- `bridge_test_runner.gd`
- `sim_test_runner.gd`
- `combat_intent_state_test.gd`
- `planning_input_test.gd`

### 4. Cross-repo consistency
- [ ] `TacticalConstants.TILE_PX` == 16 everywhere
- [ ] `core/` zero Node references (grep)
- [ ] Preview == execution (`sim_test` + manual K8)

### 5. Issue cap
- **0 HIGH**
- **≤2 LOW** deferred only (must cite target phase 15+)

### 6. Record
- Audit iteration count (expect ≥2 before pass)
- Commit hash + tag `phase-14` + `knight-mvp-tactical`

**Phase commit:** `Complete Phase 14: Knight MVP tactical re-gate` + tag `phase-14`

---

# Phase 15 — Multiplayer and tactical developer tools (optional)

Only start after Phase 14 tag exists.

## Deliverables

| # | Deliverable |
|---|-------------|
| 15.1 | Players panel + ready states (MP) |
| 15.2 | Chat panel + fade |
| 15.3 | Per-player Clear |
| 15.4 | Multiplayer ownership gate on input |
| 15.5 | Tactical developer overrides in pause |
| 15.6 | Danger area toggle + draw |
| 15.7 | Autobattler hooks + AI telemetry HUD |
| 15.8 | Reserved for future tactical launch extensions |

## Full audit gate (Phase 15)
- MP local 2-client test script documented
- SP regression: K1–K8 + M1–M8 still pass
- 0 HIGH; ≤2 deferred

**Tag:** `phase-15`

---

# Phase 16 — Options & settings unification (optional)

## Deliverables

| # | Deliverable |
|---|-------------|
| 16.1 | `ui/options_screen.gd` — wire Interface toggles to tactical flags |
| 16.2 | Combat Options: shadow tuning subset OR embed `EffectsPanel` section |
| 16.3 | Merge `SettingsManager` + `GameSettings` single persistence |
| 16.4 | Character generator/catalog access from combat options (if desired) |

## Full audit gate (Phase 16)
- Settings survive restart; combat + main menu agree on resolution
- Toggle off = zero CPU (ecology, wind) verified

**Tag:** `phase-16`

---

# Full audit protocol (every phase — no shortcuts)

Copy this checklist into `IMPLEMENTATION_STATUS.md` for **each** phase close.

## 1. Pre-audit freeze
- [ ] Working tree committed as full backup
- [ ] All deliverables for this phase listed with file paths

## 2. Four pillars (record PASS/PARTIAL/FAIL each)

| Pillar | Questions |
|--------|-----------|
| **Completeness** | Every deliverable exists? Every exit criterion checked? |
| **Correct coding** | Static types? No sim in presentation? No private API abuse? Tests green? |
| **Consistency** | Constants, layers, signals, naming match project patterns? |
| **Issues** | Numbered list HIGH/MED/LOW |

## 3. H&I fidelity check (Phases 11–14)
- [ ] Compared behavior to the canonical tactical modules for phase scope — not "looks similar"
- [ ] Knight scenarios K* executed and logged

## 4. Visual compositor gates (Phases 12–14)
- Draw order · blend mode · sprite authorship · runtime 10s · shader compile  
- **Any HIGH gate FAIL → phase FAIL**

## 5. Issue resolution loop
```
issues_found = audit()
while issues_found.high_count > 0 OR issues_found.total > 2:
    fix HIGH first
    re-audit ENTIRE phase from scratch
    iteration += 1
```
- Record iteration count in `IMPLEMENTATION_STATUS.md`

## 6. Phase close artifacts
- [ ] `IMPLEMENTATION_STATUS.md` phase section complete
- [ ] Commit: `Complete Phase N: <description>`
- [ ] Tag: `phase-N`
- [ ] Commit hash recorded

## 7. Anti-patterns that auto-fail audit
- New copy-paste block from `board_view` > 20 lines outside `CombatUiFormatters`
- Second `_recompute_intent_units` implementation
- HIGH issue deferred without user sign-off
- Phase marked PASS with F5 not run (user or agent documents "F5 pending" → max 1 LOW, not PASS for visual phases)
- `sync_from_board` reintroduced after Phase 10

---

# Implementation order summary

```
Phase 10  Foundation (BLOCK everything else until PASS)
   ↓
Phase 11  Planning input (Knight gameplay — BLOCKER)
   ↓
Phase 12  Inspector + overlays
   ↓
Phase 13  Flow + feedback
   ↓
Phase 14  Knight MVP re-gate ← shippable SP tactical
   ↓
Phase 15  MP + dev tools (optional)
   ↓
Phase 16  Options unification (optional)
```

**Do not start Phase 11 until Phase 10 audit passes with 0 HIGH.**

---

# Document history

| Date | Change |
|------|--------|
| 2026-07-16 | Initial plan — supersedes failed Phase 9 audit; Phases 10–16 defined |
