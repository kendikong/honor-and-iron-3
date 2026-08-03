# Gauntlet workbench (live progress)

**Updated by:** subagent (AD-SMOOTH r1)  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md`  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-SMOOTH │ Round 1 │ SELF-GRADED: no (subagent)
SCORE: pending critic │ THRESHOLD: 90 │ AWAITING CRITIC
AD-1..AD-4 PASS │ AD-5 DEFERRED 90 │ AD-6 PASS 92
NEXT: critic review AD-SMOOTH r1
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Piece | Score | Result |
|-------|-------|--------|
| AD-1 | **93** | PASS |
| AD-2 | **93** | PASS |
| AD-3 | **92** | PASS |
| AD-4 | **93** | PASS |
| AD-5 | **90** | **DEFERRED** |
| AD-6 | **92** | PASS |
| AD-SMOOTH | pending critic | **r1 shipped** — BAR all PASS |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **AWAITING CRITIC** — AD-SMOOTH r1 |
| **PASS_THRESHOLD** | pieces **92** · SMOOTH **90** |
| **Next** | Critic score AD-SMOOTH r1 → STOP_ON if ≥90 |

### Piece queue

| Piece | Status |
|-------|--------|
| AD-5 | **DEFERRED** @ 90 |
| AD-1..AD-4, AD-6 | **PASS** |
| AD-SMOOTH | **r1 complete** — awaiting critic |

### AD-SMOOTH r1 delta

- `_spend_ability_cost`: `is_movement_kind()` / `is_universal_run()` / `consumes_action_slot()` instead of raw `kind` match
- Bridge test: `planner_group == ACTION` for AP primary_resource check
- `sync_header_from_legacy`: marked dead (finalize uses `sync_legacy_from_header`)

### AD-SMOOTH r1 BAR

| Suite | Result | Report |
|-------|--------|--------|
| `run_ability_module_bridge_test.gd` | **PASS** | `reports/ability_data_gauntlet/bridge_smooth_r1.txt` |
| `run_bruiser_scenarios_only.gd` | **PASS** | `reports/ability_data_gauntlet/bruiser_smooth_r1.txt` |
| `run_skill_scenarios_only.gd` | **PASS** | `reports/ability_data_gauntlet/knight_smooth_r1.txt` |
| `run_planning_input_only.gd` | **PASS** | `reports/ability_data_gauntlet/planning_smooth_r1.txt` |

---

## STOP_ON

`STOP_CONDITION_MET: no` — pending AD-SMOOTH critic ≥90
