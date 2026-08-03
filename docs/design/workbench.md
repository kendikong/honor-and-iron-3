# Gauntlet workbench (live progress)

**Updated by:** lead agent  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md`  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/6

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-4 │ Round 1 │ SELF-GRADED: no (awaiting critic)
SCORE: —/100 │ THRESHOLD: 92 │ PENDING CRITIC
DELTA: —
AD-1 PASS 93 │ AD-2 PASS 93 │ AD-3 PASS 92 │ AD-5 DEFERRED 90
NEXT: AD-6 → SMOOTH
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Threshold | Result |
|-------|-------|-------|-----------|--------|
| r3 | AD-1 | **93** | **92** | **PASS** |
| r3 | AD-2 | **93** | **92** | **PASS** |
| r5 | AD-3 | **92** | **92** | **PASS** |
| r6–r13 | AD-5 | best **90** | **92** | **DEFERRED** |
| r1 | AD-4 | — | **92** | **AWAITING CRITIC** |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** |
| **PASS_THRESHOLD** | **92** |
| **Next** | AD-6 remove legacy kind → SMOOTH (90) |

### Piece queue

| Piece | Status |
|-------|--------|
| AD-5 Class library editor | **DEFERRED** @ 90/92 |
| AD-1 Schema + bridge | **PASS** @ 93 |
| AD-2 Native module/gate runtime | **PASS** @ 93 |
| AD-3 Planning gated-aim | **PASS** @ 92 (`f6ccfded7`) |
| AD-4 Factories modules-first | **AWAITING CRITIC** (r1) |
| AD-6 Remove legacy kind authoring | PENDING |

### AD-4 r1 notes (awaiting critic)

**Audit:** Knight + Bruiser factories already modules-first via `DataLibrary.finalize_unit_abilities` → `AbilityModuleBridge.finalize_ability` (infer modules from flat `effects[]`, compile ALWAYS modules back to legacy readers). Explicit gate authoring: `AbilityModuleBridge.ensure_if_collided_followup_move` on `bruiser_violent_collision` before append.

**BAR strengthened:** `run_ability_module_bridge_test.gd` now asserts **all** Knight abilities have non-empty `modules` (parity with existing Bruiser check) plus `upgraded_modules` when `upgraded_effects` present.

**Residual gaps (not AD-4):** factories still author flat `effects[]` as migration input — full module-native authoring deferred to post-AD-6; `kind` field retained per scope lock.
| AD-SMOOTH | PENDING (threshold **90**) |

---

## STOP_ON

`STOP_CONDITION_MET: no`
