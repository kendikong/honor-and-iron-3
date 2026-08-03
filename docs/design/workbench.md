# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Sync:** `docs/design/LOCAL_CLOUD_SYNC.md`  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-1 │ Round 1 │ SELF-GRADED: pending critic
SCORE: —/100 │ THRESHOLD: 85 │ PENDING CRITIC
DELTA: first round
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Result |
|-------|-------|-------|--------|
| r1 | AD-0+AD-1 | pending | Builder done — awaiting gauntlet-critic |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** — AbilityData modular refactor |
| **Current piece** | AD-1 (schema + bridge + factory finalize) |
| **Next** | Critic → AD-5 editor / AD-2 native runtime |
| **Bible** | `docs/design/ability-data.md` READY_FOR_REFACTOR |

### Piece queue

| Piece | Goal | BAR | Status |
|-------|------|-----|--------|
| AD-0 | UNATTENDED_RUN + workbench + freeze | Docs present | DONE |
| AD-1 | AbilityModule + header + bridge + finalize | Bridge test + Knight/Bruiser QA | BUILDER DONE — critic next |
| AD-2 | AbilitySystem native module execution | regression / skill QA | PENDING (bridge compiles to effects today) |
| AD-3 | Planning gated-aim via modules | planning QA | PENDING (legacy modifiers still drive VC) |
| AD-4 | Port factories to author modules first | Knight+Bruiser QA | PARTIAL (infer+finalize from flat) |
| AD-5 | Class library editor modular authoring | editor schema | PENDING |
| AD-6 | Remove legacy kind/is_movement authoring | full QA | PENDING |
| AD-SMOOTH | Combined-diff critic | SCORE ≥ 80 | PENDING |

### Machine bar this wave

| Check | Result |
|-------|--------|
| `AbilityModuleBridgeTest.tscn` | **PASS** |
| `BruiserQaGate.tscn` | **PASS** |
| `KnightQaGate.tscn` | **PASS** |
| Tier 3 GdUnit live planning | **FAIL** (23) — cloud software-GL/Vulkan; not treated as skill regression (Knight/Bruiser planning scenarios green) |

### Behavior freeze (skill ids)

**Knight:** `knight_swap`, `knight_shield_bash`, `knight_phalanx_stance`, `knight_taunting_strike`, `knight_seismic_stomp`, `knight_fortify`, `knight_bowling_charge`, `knight_iron_grip`, `knight_redirect_strike`, `knight_indomitable_will`, `knight_retaliation_protocol`, `knight_shield_slam`, `knight_defensive_formation`, `knight_chain_hook`, `knight_trampling_advance`

**Bruiser:** `bruiser_push_through`, `bruiser_charge_strike`, `bruiser_concussion_blow`, `bruiser_cleave`, `bruiser_suplex`, `bruiser_adrenaline_surge`, `bruiser_earthshatter`, `bruiser_meat_shield`, `bruiser_frenzy`, `bruiser_guttural_roar`, `bruiser_headbutt`, `bruiser_blood_boil`, `bruiser_violent_collision`, `bruiser_crimson_whirlwind`, `bruiser_belly_flop`, `bruiser_breaching_dash`

---

## STOP_ON

`STOP_CONDITION_MET: no`
