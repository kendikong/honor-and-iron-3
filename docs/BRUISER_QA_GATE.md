# Bruiser QA Gate

**Scope:** **Class validation** — every Bruiser **active skill**, **movement skill**, and **passive** in `core/factory/classes/bruiser_factory.gd` behaves per `class_abilities.txt` § Bruiser. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Bruiser LOCK):** 100% coverage matrix rows **PASS** (meta-critic approved) + `run_bruiser_qa_gate.ps1` PASS + meta-critic **≥ 95** on full matrix.

**Runner:** `scripts/run_bruiser_qa_gate.ps1` — cloned from Knight gate; **does not** invoke or modify `run_planning_qa_gate.ps1`. Each run writes **`qa_bruiser_gate_canonical.txt`** (authoritative stdout snapshot for gauntlet-critic BAR).

**P3 clone authority:** [`docs/design/knight-template.md`](design/knight-template.md) · [`docs/KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity

---

## Three tiers

| Tier | Runner | Gate status |
|------|--------|-------------|
| **1 — Headless scenarios** | `.\scripts\run_bruiser_qa_gate.ps1` (wraps `BruiserQaGate.tscn`) | **Required** — per-ability/passive scenarios via harness + sim |
| **2 — Live Bruiser acceptance** | `PLANNED — tests/live_bruiser_class_test.gd` | Optional until Tier 1 complete |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per ability | Required for feel/pixels Tier 1 cannot see |

**Only Tier 1 blocks Bruiser LOCK.**

---

## Meta-critic (owner proxy)

Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic — judge Bible adherence, global systems fidelity (Rules A/B), test adequacy, coverage, and fix target (`implementation` \| `qa_test` \| `fixture` \| `coverage_matrix`).

**Forbidden:** Using planning QA PASS as Bruiser sign-off. **Forbidden:** Changing `live_planning_scene_test.gd` for Bruiser coverage.

---

## Global systems fidelity (mandatory — clone from P3)

Copy **verbatim** from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity (Rules A/B, QA enforcement, keyword table).

**Bruiser-specific reminders:**

| Bible intent | Wrong global | Right approach |
|--------------|--------------|----------------|
| **Suplex:** behind caster placement | `SWAP` | `THROW_BEHIND` (`bruiser_suplex`) |
| **Meat Shield:** swap with ally | `TELEPORT` | `SWAP` + `INTERCEPT` |
| **Violent Collision:** dash + recast on hit | single `MOVE` | `DASH` + `violent_collision_recast` modifier |
| **Push Through:** move into occupied tile | `SWAP` | `MOVE_INTO_AND_PUSH` |

---

## Coverage matrix (authoritative — `bruiser_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file yet |
| `HARNESS_ONLY` | Scenario runs green but **fails meta-critic contract** |
| `PASS` | Meta-critic approved — Bible clause + base + `[+]` when data has `upgraded_effects` |
| `N/A` | Owner deferral with target phase |

**Summary (honest):** **27 / 31** factory rows meta-critic `PASS` · **4** `HARNESS_ONLY` · **0** `PLANNED` · **Manifest:** `docs/bruiser_meta_critic_manifest.json` — B6-REOPEN active.

### Movement + actives

| Bible / factory id | Type | Scenario file | Tier 1 | Notes |
|--------------------|------|---------------|--------|-------|
| `bruiser_push_through` | Movement | `tests/skills/bruiser_push_through_scenario.gd` | PASS | MOVE_INTO_AND_PUSH; `[+]` cost 1 MOV + STR on push |
| `bruiser_charge_strike` | Active | `tests/skills/bruiser_charge_strike_scenario.gd` | PASS | MOVE 2 + DAMAGE 3 + PUSH 1; `[+]` GHOST + terrain bonus |
| `bruiser_concussion_blow` | Active | `tests/skills/bruiser_concussion_blow_scenario.gd` | PASS | RANGE 1 ATK 2 PUSH 1; object STAGGER; `[+]` mutual STAGGER on enemy collision |
| `bruiser_cleave` | Active | `tests/skills/bruiser_cleave_scenario.gd` | PASS | RANGE 1 ARC ATK 2; `[+]` BLEED (WPN-scaled) on all arc targets |
| `bruiser_suplex` | Active | `tests/skills/bruiser_suplex_scenario.gd` | PASS | RANGE 1 ATK 4 THROW_BEHIND (not SWAP); `[+]` bonus_dmg_per_10_hp |
| `bruiser_adrenaline_surge` | Active | `tests/skills/bruiser_adrenaline_surge_scenario.gd` | PASS | SELF spend 5 HP +MOV/+STR; 0 AP if 2+ adjacent; `[+]` on-kill heal/shield |
| `bruiser_earthshatter` | Active | `tests/skills/bruiser_earthshatter_scenario.gd` | PASS | RANGE 1 ARC ATK 2 + destroy; `[+]` ATK per destroy |
| `bruiser_meat_shield` | Active | `tests/skills/bruiser_meat_shield_scenario.gd` | PASS | RANGE 1 ally SWAP + INTERCEPT 50%; `[+]` RANGE 3 + STR per intercept |
| `bruiser_frenzy` | Active | `tests/skills/bruiser_frenzy_scenario.gd` | PASS | RANGE 1 ATK 1 x3; `[+]` on-kill +1 AP |
| `bruiser_guttural_roar` | Active | `tests/skills/bruiser_guttural_roar_scenario.gd` | PASS | AOE PUSH + DEF debuff; `[+]` item push/collision |
| `bruiser_headbutt` | Active | `tests/skills/bruiser_headbutt_scenario.gd` | PASS | Mutual DAMAGE + STAGGER; `[+]` % Max HP bonus |
| `bruiser_blood_boil` | Active | `tests/skills/bruiser_blood_boil_scenario.gd` | PASS | SELF HP → STR; `[+]` 10 HP → STR +5 |
| `bruiser_violent_collision` | Active | `tests/skills/bruiser_violent_collision_scenario.gd` | PASS | DASH bulldoze + recast; `[+]` STAGGER on collision |
| `bruiser_crimson_whirlwind` | Active | `tests/skills/bruiser_crimson_whirlwind_scenario.gd` | PASS | AOE DAMAGE; `[+]` heal per hit |
| `bruiser_belly_flop` | Active | `tests/skills/bruiser_belly_flop_scenario.gd` | PASS | TELEPORT_CASTER + DAMAGE; `[+]` landing PUSH |
| `bruiser_breaching_dash` | Active | `tests/skills/bruiser_breaching_dash_scenario.gd` | PASS | DASH + destroy cover; `[+]` next attack PIERCE |

### Passives (trigger-based)

| Factory id | Passive | Scenario file | Tier 1 | Trigger setup |
|------------|---------|---------------|--------|----------------|
| `cellular_regeneration` | Cellular Regeneration | `tests/passives/cellular_regeneration_scenario.gd` | PASS | Turn start + adjacent enemy count |
| `blood_for_blood` | Blood for Blood | `tests/passives/blood_for_blood_scenario.gd` | HARNESS_ONLY | Damaged last turn → BLEED on attack |
| `adrenaline_junkie` | Adrenaline Junkie | `tests/passives/adrenaline_junkie_scenario.gd` | PASS | Missing HP → MOV/STR; `[+]` DEF |
| `enraged` | Enraged | `tests/passives/enraged_scenario.gd` | PASS | Debuff/hazard count → STR; `[+]` MOV |
| `last_stand` | Last Stand | `tests/passives/last_stand_scenario.gd` | PASS | HP &lt; 25% → STR/DEF |
| `colossal_mass` | Colossal Mass | `tests/passives/colossal_mass_scenario.gd` | PASS | Max HP → STR scaling |
| `overwhelming_bulk` | Overwhelming Bulk | `tests/passives/overwhelming_bulk_scenario.gd` | PASS | HP vs target Max HP → PIERCE; `[+]` PUSH |
| `thrill_of_pain` | Thrill of Pain | `tests/passives/thrill_of_pain_scenario.gd` | PASS | On damage → next attack buff |
| `momentum_of_titan` | Momentum of the Titan | `tests/passives/momentum_of_titan_scenario.gd` | PASS | PUSH collision % Max HP damage |
| `scar_tissue` | Scar Tissue | `tests/passives/scar_tissue_scenario.gd` | PASS | Physical damage reduction scaling |
| `momentum_transfer` | Momentum Transfer | `tests/passives/momentum_transfer_scenario.gd` | HARNESS_ONLY | PUSH collision → HEAL; `[+]` STR |
| `crowd_breaker` | Crowd Breaker | `tests/passives/crowd_breaker_scenario.gd` | PASS | Adjacent enemy STR + splash |
| `juggernaut` | Juggernaut | `tests/passives/juggernaut_scenario.gd` | PASS | Trap destroy; `[+]` SHIELD |
| `battering_ram` | Battering Ram | `tests/passives/battering_ram_scenario.gd` | HARNESS_ONLY | PUSH +1 tile; `[+]` wall STAGGER |
| `unstoppable_force` | Unstoppable Force | `tests/passives/unstoppable_force_scenario.gd` | HARNESS_ONLY | STAGGER/ROOT immune + SHIELD on resist |

**LOCK rule:** All factory rows `PASS` (or owner-documented `N/A`). Gate script **fails** until then.

Registry: `tests/bruiser_scenario_registry.gd` + `tests/bruiser_qa_runner.gd` (31 factory rows).

---

## Scenario contract (per row)

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Scenario contract — cite Bible + global effect in header; assert base + `[+]` via `Simulator` / planning harness where applicable.

**Promotion:** `PLANNED` → `HARNESS_ONLY` → `PASS` only after meta-critic approves adequacy for that row.

---

## Gauntlet handoff stub (B6-doc — spec critic)

```text
GOAL: P6 Bruiser pillar — gate doc + meta-critic contract + honest 31-row matrix
BAR: lint PASS; Test-Path docs/BRUISER_QA_GATE.md, core/factory/classes/bruiser_factory.gd, scripts/run_bruiser_qa_gate.ps1; matrix lists all factory ids PLANNED
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc, knight-template.md (P3 clone), KNIGHT_QA_GATE.md § Global systems fidelity
ARTIFACT: this file, docs/design/bruiser-template.md, bruiser_factory.gd, lint stdout
```
