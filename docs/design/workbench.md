# Gauntlet workbench (live progress)

**Updated by:** lead agent during gauntlet runs  
**Spec:** `docs/design/00-gauntlet-loop-cursor.md` Rule 6 + Rule 6b  
**Run:** Bible consistency + Bible-to-code (`docs/design/runs/BIBLE-ALIGN.md`)

---

## Score ticker

```text
══════════════════════════════════════
GAUNTLET SCORE │ BIBLE-CONSISTENCY │ Round 2 │ SELF-GRADED: no (subagent)
SCORE: 90/100 │ THRESHOLD: 88 │ PASS │ CLIMBING
DELTA: +4 vs round 1 (was 86)
STOP_CONDITION_MET: yes (this piece)
══════════════════════════════════════
```

```text
══════════════════════════════════════
GAUNTLET SCORE │ BIBLE-TO-CODE │ Round 4 │ SELF-GRADED: no (subagent)
SCORE: 56/100 │ THRESHOLD: 85 │ FAIL │ SLIPPED
DELTA: −2 vs round 3 (was 58)
STOP_CONDITION_MET: no
══════════════════════════════════════
```

`STOP_CONDITION_MET: no` (both pieces required; bible-consistency already PASS)

### Score progression

| Round | Piece | Score | Result | SELF-GRADED |
|-------|-------|-------|--------|-------------|
| 1 | BIBLE-CONSISTENCY | 86 | FAIL | no (subagent) |
| 1 | BIBLE-TO-CODE | 50 | FAIL | no (subagent) |
| 2 | BIBLE-CONSISTENCY | 90 | PASS | no (subagent) |
| 2 | BIBLE-TO-CODE | 62 | FAIL | no (subagent) |
| 3 | BIBLE-TO-CODE | 58 | FAIL | no (subagent) |
| 4 | BIBLE-TO-CODE | 56 | FAIL | no (subagent) |

### Wave 7 (2026-08-14)

Lancer 12 canvas FAILs closed (Glorious Charge live dual-pick; Piercing Charge dash-then-RANGE 2; Polearm ignore-DEF upgrade-only; etc.). Archer 11 canvas FAILs closed (Steady Aim spends remaining MOV; Sidestep keep facing; Overwatch cone; Vantage on Steady Aim only; Camouflage Range>3; Caltrop 1 AP / Expert waiver; Target Painter PIERCE upgrade-only; Hunter's Mark ally RANGE/PIERCE; Repelling ally pick; Suppressing RANGE 4).

QA: Lancer gate+live PASS. Archer gate+live PASS. Planning QA PASS.

Canvas FAIL remaining ~50 (Beast Rider, Monk, Mage, Engineer, Shaman, Cleric dual-pick). Next cluster: **Beast Rider 11**.

Bowling Charge / Trampling Advance untouched. No class LOCK claim.

### Wave 6 (2026-08-14)

Audits collapsed to 1 finding (Rogue 13 canvas FAILs). Implemented in `RogueSystems` + factory data + harness:

- Pass [+] pierce gated; Slip Past lands opposite empty; Lethal Position STR/RANGE/DEF; Shadow Clone TAUNT on enemies + explode; Phase Shift until-attack; Blink Strike teleport; Shadow Slip MOV refund on attack; Panic Cascade WPN on debuff apply; Smoke stealth-vs-outside + heal/turn; Grapple pull-until-adjacent / self-pull RANGE 4 + trap×2; Amnesia unacted + CONFUSION next turn; Kidnap push away from caster; Poison Flask AOE 1 + BLIND on entry.

QA: Rogue gate PASS 32/32. Rogue live PASS 3/3. Planning QA PASS. Alignment gate FAIL **73** (was 86). Rogue FAIL **0**.

Next largest cluster: **Lancer 12**.

Bowling Charge / Trampling Advance untouched. No class LOCK claim.

**Commit:** `44a61de6d68c441cd1f92f39e12cbcc37a59677c`

### Wave 5 (2026-08-14)

Infrastructure ADEQUATE: `scripts/run_bible_alignment_gate.ps1` parses canvas FAIL rows, writes `docs/bible_alignment_audit.json`, exits 1 while FAIL>0.

Cleric: MAG ATK / HEAL X / SHIELD X via CombatSystem helpers; Holy Light dual-faction; Blinding Ray keeps BLIND; Divine Hammer adjacent MAG+PUSH + HOLY AURA; Life Link no INTERCEPT; Resurrection corpse-only; Divine Guidance upgrade does not zero MOV; Shield of Faith SHIELD 3 formula. Martyr's Chains still auto-picks the second enemy (1 Cleric FAIL).

Canvas: 101 → 86 FAIL. Next largest cluster: Rogue 13.

QA: Cleric gate+live PASS. Planning QA PASS. Alignment gate FAIL (86) — expected until canvas-zero.

Bowling Charge / Trampling Advance untouched.

**Commit:** `b4ec248ca2ae7210e0a1aab7ee3d4eb59af7b403`

### Wave 4 (2026-08-14)

Bible consistency:
- Action Economy now defines the global 1 AP refund cap (Mana Siphon cites it).
- Keyword Parity example is `AOE 3` (cross), matching the glossary.

Bible-to-code (Mercenary cluster + Knight Shield Bash):
- Predatory: Bible is free MOVE 1, not 0 AP. Dead unused target-id 0-AP path removed.
- Calculated Strike: TAG_MOVEMENT skills only; STR/DEF are turn buffs.
- Dual Wield: 0-AP basic vs same unit after any AP active (not damage-gated).
- Precision Edge BLEED uses pre-hit full HP.
- Duelist/Precision Strike: `turn_action_used`.
- Swift Feet ZOC + difficult terrain flags read.
- Evasive immunities apply the same turn.
- Flanking/Feint STR go through the ATK formula.
- Ruthless and Flank & Run bonuses consume on the next attack.
- Second Wind 0-AP consumes on spend.
- Defense Strike `shield_blocked` blocks SHIELD.
- Caltrop Toss skips Archer ROOT+BLEED; entry ATK 1.
- Swift Strike lands adjacent to the aimed unit.
- Hamstring caps MOV at 1 only.
- Acrobatic Vault TELEPORT to opposite empty tile.
- Executioner's Blade 50%/75%.
- Boss hard-CC fallback in `CombatSystem.try_resist_crowd_control` (STAGGER → +WPN).

Bowling Charge / Trampling Advance untouched.

QA this wave: pending mercenary gate+live, knight gate, planning QA.

---

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
