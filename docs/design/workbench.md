# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** Bible consistency + Bible-to-code (`docs/design/runs/BIBLE-ALIGN.md`)

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ BIBLE-TO-CODE │ Round 1 pending critic
SCORE: —/100 │ THRESHOLD: 85 │ pending critic
STOP_CONDITION_MET: no
══════════════════════════════════════
```

`STOP_CONDITION_MET: no`

### Wave 2–3 (2026-08-14)

- Charge Strike: MOVE 2, GHOST through occupied, land adjacent empty, +2 from occupied tiles. `can_use` walk budget includes chained melee range.
- Concussion Blow upgrade keeps object STAGGER and adds enemy-collision STAGGER both.
- Bruiser: Sanguine overflow SHIELD; Reactive Adrenaline always converts turn-start heal to SHIELD; Earthshatter TILE; Headbutt extra true 1; Guttural item Floor(STR/2)+VULNERABLE; Violent Collision recast MOVE 2.
- Knight: Bastion 0 collision when shoved; Kinetic Dissipation when you collide (wall or unit); Concussive DEF=WPN plus upgrade VULNERABLE; Redirect RANGE 2 pick ally; Defensive Formation self-aim; Taunting TILE; deleted Redirect `ability.id` range loop.
- ADD_STATUS_SELF may designate an ALLY (range kept) so Redirect can aim without a per-skill branch.
- Canvas FAIL count after this wave: 119 (was 135).

Bowling Charge / Trampling Advance untouched.

QA this wave: Bruiser gate PASS (Tier 1 + live). Knight gate PASS (Tier 1). Planning QA PASS.

---

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
