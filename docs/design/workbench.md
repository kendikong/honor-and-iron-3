# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** Bible consistency + Bible-to-code (`docs/design/runs/BIBLE-ALIGN.md`)

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ BIBLE-CONSISTENCY │ Round 0 │ SELF-GRADED: yes (invalid) until critic
SCORE: —/100 │ THRESHOLD: 88 │ pending critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

`STOP_CONDITION_MET: no`

### Wave 1 (2026-08-14) — largest gaps closed before first critic

- Bible: Fortify adds caster DEF (does not set/replace). SHARED TILE occupants are each selectable; melee/AOE hits both. CALTROPS glossary matches Caltrop Trap (no ATK) vs Caltrop Toss (ATK).
- Code: Knight/Bruiser/Archer/Lancer promotion stats; Lancer Push 1 MOV; Seismic Stomp AOE 1 cross; Fortify amount 0 + DEF scaling; Kinetic Armor Floor(DEF/2); Adrenaline Junkie per 25% cap 3; Scar Tissue step 15 on upgrade; Engineer 3x3 size 1; EMP AOE 2 cross; Mage Fireball/Meteor/Black Hole/Gravity Well crosses; Explosive Arrow cross; Tail Swipe 3x3 size 1; Safe Landing shockwave size 1; Apex +2 CON.

Bowling Charge / Trampling Advance untouched.

---

## Prior run (AbilityData modular — paused)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** AbilityData modular refactor (`docs/design/UNATTENDED_RUN.md`)  
**PR:** https://github.com/kendikong/honor-and-iron-3/pull/5

---

## Score ticker (AbilityData — paused)

```text
══════════════════════════════════════
GAUNTLET SCORE │ SHAMAN-LOCK │ Round 5 │ SELF-GRADED: no (subagent)
SCORE: 86/100 │ THRESHOLD: 85 │ PASS
DELTA: +31 vs Round 1 (was 55)
R1: 55 FAIL │ R2: 63 FAIL │ R3: 71 FAIL │ R4: 78 FAIL │ R5: 86 PASS
STOP_CONDITION_MET: yes (automated gauntlet bar)
══════════════════════════════════════
```

| Round | Piece | Score | Result |
|-------|-------|-------|--------|
| r5 | SHAMAN-LOCK | 86 | PASS — WITHER, usher totems, lightning rod, Knight-bar harness |
| r4 | SHAMAN-LOCK | 78 | FAIL |
| r3 | SHAMAN-LOCK | 71 | FAIL |
| r2 | SHAMAN-LOCK | 63 | FAIL |
| r1 | SHAMAN-LOCK | 55 | FAIL |

```text
══════════════════════════════════════
GAUNTLET SCORE │ AD-5 │ Round 2 │ SELF-GRADED: no (subagent)
SCORE: 88/100 │ THRESHOLD: 85 │ PASS │ CLIMBING
DELTA: +15 vs round 1 (was 73)
AD-1: 86 PASS │ AD-5: 88 PASS
STOP_CONDITION_MET: no
══════════════════════════════════════
```

| Round | Piece | Score | Result |
|-------|-------|-------|--------|
| r2 | AD-1 | 86 | PASS |
| r1 | AD-5 | 73 | FAIL — dual authoring |
| r2 | AD-5 | 88 | PASS — effects rebuild modules |

---

## Run

| Field | Value |
|-------|-------|
| **Status** | **ACTIVE** — resume next for AD-2 |
| **Commits** | AD-1 `1c782669…` · AD-5 `470ac0c8…` |
| **BAR** | bridge / Knight / Bruiser **PASS** (`*_r5.txt`) |

### Remaining to STOP_ON

| Piece | Status |
|-------|--------|
| AD-2 AbilitySystem native module/gate runtime | **NEXT** |
| AD-3 Planning gated-aim via modules | PENDING |
| AD-4 Factories author modules-first | PARTIAL |
| AD-6 Remove legacy kind authoring | PENDING |
| AD-SMOOTH Combined critic ≥ 80 | PENDING |

---

### AD-2 implementation note

- `PhysicsSystem._emit_collision` now detects Violent Collision's active `IF_COLLIDED` MOVE module; the compiled `violent_collision_recast` modifier remains only as compatibility output for unmigrated readers.
- AD-3 remains required for the planning/preview path to expose and ratify the gated follow-up aim from module slots. AD-2 does not claim that planning behavior is complete.

## STOP_ON

`STOP_CONDITION_MET: no`  
`BLOCKER: context/token — resume with "continue gauntlet"`
