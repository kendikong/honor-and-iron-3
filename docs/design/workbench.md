# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md`  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ REOPENED │ SELF-GRADED: no
THRESHOLD: 92 │ wave smooth: 90
AD-5: DEFERRED @ 90 (MAX_ROUNDS)
AD-2: r3 BAR green — awaiting gauntlet-critic
AD-1: RE-OPEN after AD-2
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r2 | AD-1 | 86 | **92** | RE-OPEN (await AD-2) |
| r6–r13 | AD-5 | best **90** | **92** | **DEFERRED** (MAX_ROUNDS; owner continue other pieces) |
| r1 | AD-2 | 69 | **92** | FAIL |
| r2 | AD-2 | 88 | **92** | FAIL |
| r3 | AD-2 | *(critic pending)* | **92** | BAR PASS — critic next |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** — owner continue after AD-5 plateau |
| **PASS_THRESHOLD** | **92** |
| **Next** | AD-2 critic ≥92 → re-critic AD-1 → AD-3/4/6 → SMOOTH |

### Piece queue

| Piece | Status |
|-------|--------|
| AD-5 Class library editor | **DEFERRED** @ 90/92 |
| AD-2 Native module/gate runtime | **r3 BAR PASS** — critic pending |
| AD-1 Schema + bridge | RE-OPEN (86) — re-critic after AD-2 |
| AD-3 Planning gated-aim | PENDING |
| AD-4 Factories modules-first | PARTIAL |
| AD-6 Remove legacy kind authoring | PENDING |
| AD-SMOOTH | PENDING (threshold **90**) |

---

## AD-2 r3 builder notes (for critic)

**GOAL:** `ModuleGate.IF_COLLIDED` is runtime truth for Violent Collision; no `violent_collision_recast` stamp; class-library JSON wipe cannot drop the gated MOVE module.

**BAR (lead ran — paste for critic):**

```
godot --headless --path . --script res://tests/run_ability_module_bridge_test.gd
→ ABILITY_MODULE_BRIDGE_TEST: PASS
  (reports/ability_data_gauntlet/bridge_ad2_r3g.txt)

godot --headless --path . --script res://tests/run_bruiser_scenarios_only.gd
→ [PASS] Bruiser QA Tier 1 scenarios
  (reports/ability_data_gauntlet/bruiser_ad2_r3h.txt)

godot --headless --path . --script res://tests/run_skill_scenarios_only.gd
→ [PASS] Knight QA Tier 1 scenarios
  (reports/ability_data_gauntlet/knight_ad2_r3g.txt)
```

**Artifact deltas (r3):**

- `AbilityModuleBridge.finalize_ability` restores IF_COLLIDED via package detect (DASH+bulldoze+push) after JSON clears modules
- Physics: `ability_has_module_gate` + `evaluate_module_gate(IF_COLLIDED, true)`
- Stamp stripped from class library JSON + module compile
- `ClassLibrarySchema.in_game_ability_bbcode` uses `load()` to avoid EventBus compile cycle under headless `--script`
- BAR runners: SceneTree + deferred `load()` (Node+preload broke EventBus before autoloads)

**Critic:** pending (this wave)

---

## STOP_ON

`STOP_CONDITION_MET: no`  
Owner directed: finish AbilityData refactor (AD-5 deferred; continue AD-2+).
