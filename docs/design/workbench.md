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
GAUNTLET SCORE │ BIBLE-TO-CODE │ Round 5 │ SELF-GRADED: no (subagent)
SCORE: 86/100 │ THRESHOLD: 85 │ PASS │ CLIMBING
DELTA: +30 vs round 4 (was 56)
STOP_CONDITION_MET: yes (this piece)
══════════════════════════════════════
```

`STOP_CONDITION_MET: no` (owner reopened: Correct QA + remaining DATA-ONLY/MISSING)

### Score progression

| Round | Piece | Score | Result | SELF-GRADED |
|-------|-------|-------|--------|-------------|
| 1 | BIBLE-CONSISTENCY | 86 | FAIL | no (subagent) |
| 1 | BIBLE-TO-CODE | 50 | FAIL | no (subagent) |
| 2 | BIBLE-CONSISTENCY | 90 | PASS | no (subagent) |
| 2 | BIBLE-TO-CODE | 62 | FAIL | no (subagent) |
| 3 | BIBLE-TO-CODE | 58 | FAIL | no (subagent) |
| 4 | BIBLE-TO-CODE | 56 | FAIL | no (subagent) |
| 5 | BIBLE-TO-CODE | 86 | PASS | no (subagent) |

### Wave 8 (2026-08-14)

Beast Rider 11 canvas FAILs closed:

- Gallop [+] +1 STR (not flat ATK) + +1 DEF post-move
- Griffin/Wyvern promotions grant AIRBORNE from `promotion_stat_bonuses` even without an aerial passive
- Reposition: caster stays; target flips to opposite empty
- Isolation: +2 STR; per-tile ATK is upgrade-only
- Pack Hunter: follow-up on hit, ignore 50% DEF
- Vantage: STR in hazards or elevated tiles
- Furious Charge: straight tiles only
- Pounce: land adjacent via `move_to_target_adjacent` (preview=commit); [+] PUSH on that hit
- Bestial Roar: PUSH always; FEAR only if already debuffed
- Rest & Recover: remaining MOV consumed on CLASS_SKILL
- Tail Swipe [+] wall STAGGER

QA: Beast Rider gate+live PASS. Planning QA PASS.

### Wave 9 (2026-08-14)

Monk 10 canvas FAILs closed: Leap over 1-tile blocker; Harmony ATK not STR; Weaver phys/mag hybrid; Vaulting Strike via leap vault; Flying Crane stop-adjacent-first-enemy; Spirit Palm base collision splash; Mantra TILE targeting; Inner Fire 2-turn decay; Cyclone TILE pick; Geyser PUSH 2 only on WATER.

QA: Monk gate+live PASS.

Canvas FAIL remaining: Mage 9, Engineer 10, Shaman 9, Cleric 1 (dual-pick). Next cluster: **Mage 9**.

Bowling Charge / Trampling Advance untouched. No class LOCK claim.

### Wave 10 (2026-08-14)

Mage 9 canvas FAILs closed: Overchannel refund/SHIELD upgrade-only; Elementalist lightning-all on water/ice; Overload +3 instead of +2 and cannot SHIELD; Fireball steam splash sim; Arcane Trail MAG ATK; Meteor delay+crater; Black Hole pull-to-center; Mana Shield SHIELD X; Gravity Well enemies-only.

QA: Mage gate+live PASS. Planning QA PASS.

Canvas FAIL remaining: Shaman 9, Cleric 1 (dual-pick). Next cluster: **Shaman 9**.

### Wave 11 (2026-08-14)

Engineer 10 canvas FAILs closed: Turret Syndrome +50% turret HP; Expanded Blast cross +1 / destroy traps; Scrap Mechanic HP; Maintenance MOV-spend HEAL 1/2 SHIELD 1; Field Technician RANGE 2 + next STR; Wrench +1 STR; EMP HEAL 2; Rocket delay+sacrifice; Manual Det adjacent cross; Overdrive damages construct.

QA: Engineer gate+live PASS.

Canvas FAIL remaining: Shaman 9, Cleric 1 (dual-pick). Next cluster: **Shaman 9**.

Lancer 12 canvas FAILs closed (Glorious Charge live dual-pick; Piercing Charge dash-then-RANGE 2; Polearm ignore-DEF upgrade-only; etc.). Archer 11 canvas FAILs closed (Steady Aim spends remaining MOV; Sidestep keep facing; Overwatch cone; Vantage on Steady Aim only; Camouflage Range>3; Caltrop 1 AP / Expert waiver; Target Painter PIERCE upgrade-only; Hunter's Mark ally RANGE/PIERCE; Repelling ally pick; Suppressing RANGE 4).

QA: Lancer gate+live PASS. Archer gate+live PASS. Planning QA PASS.

Canvas FAIL remaining ~50 (Beast Rider, Monk, Mage, Engineer, Shaman, Cleric dual-pick). Next cluster: **Beast Rider 11**.

Bowling Charge / Trampling Advance untouched. No class LOCK claim.

### Wave 12 (2026-08-14)

Shaman + Cleric dual-pick canvas FAILs closed. Alignment gate **FAIL 0**.

- Usher: ally then empty tile; caster stays
- Curse: STR−2 DEF−2, no WEAKEN/MAG; [+] Push Mit 0
- Healing Totem: Bible HEAL 1
- Flame Totem: FIRE upgrade-only
- Voodoo Link / Sympathetic Bond / Martyr's Chains: second NEW_AIM pick required
- Terrify: boss SHIELD strip upgrade-only
- Bone Spear: MAG ATK 2 + furthest empty barricade
- Ancestral Spirit: ally corpse gate + echo_upgraded

QA: Shaman live PASS. Shaman harness PASS. Planning QA PASS. Alignment gate PASS (MATCH 373, DATA-ONLY 20, MISSING 4, FAIL 0).

Bowling Charge / Trampling Advance untouched. No class LOCK claim.

**Round 5 critic:** BIBLE-TO-CODE **86 PASS** ([Bible-to-code R5](3ff91942-c408-4214-8a80-f7fe7e10bd6a)). Residual (not FAIL): DATA-ONLY 20 including Totem Guard `[+]` `melee_def`; MISSING 4 Beast Rider. `STOP_CONDITION_MET: yes`.

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
