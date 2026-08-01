# Knight QA Gate

**Scope:** **Class validation** — every Knight **active skill**, **movement skill**, and **passive** in `core/factory/classes/knight_factory.gd` behaves per `class_abilities.txt` § Knight. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Knight LOCK):** 100% coverage matrix rows **PASS** (meta-critic approved) + `run_knight_qa_gate.ps1` PASS + meta-critic **≥ 88** on full matrix — then P6 clones this gate per class.

**Runner:** `scripts/run_knight_qa_gate.ps1` — mirrors planning gate structure; **does not** invoke or modify `run_planning_qa_gate.ps1`.

---

## Three tiers

| Tier | Runner | Gate status |
|------|--------|-------------|
| **1 — Headless scenarios** | `.\scripts\run_knight_qa_gate.ps1` (wraps `run_skill_scenarios_only.gd`) | **Required** — per-ability/passive scenarios via harness + sim |
| **2 — Live Knight acceptance** | `PLANNED — tests/live_knight_class_test.gd` (GdUnit4, TestBattle, multi-knight board) | Optional until Tier 1 complete; F5-class journeys |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per ability | Required for feel/pixels Tier 1 cannot see |

**Only Tier 1 blocks Knight LOCK.** Tier 2 packs multiple promotion loadouts on one large board (owner optimization — see §Fixture strategy).

---

## Meta-critic (owner proxy)

The **gauntlet-critic** on Knight work is **not** only “tests green.” It judges:

1. **Bible adherence** — does behavior match `class_abilities.txt` + data in `knight_factory.gd`?
2. **Test adequacy** — does each scenario **prove** the Bible clauses it claims (base + `[+]` upgrade when implemented)?
3. **Coverage** — every matrix row has a scenario (or documented owner deferral)?
4. **Wrong owner** — failure in game vs failure in test design?

### Critic outputs (required)

| Field | Content |
|-------|---------|
| `SCORE` | /100 vs `PASS_THRESHOLD: 88` |
| `Largest gap` | Missing passive test, weak assert, untested upgrade, etc. |
| `Fix target` | `implementation` \| `qa_test` \| `fixture` \| `coverage_matrix` |
| `Evidence` | Bible excerpt + assert line + stdout |
| `Proposed infrastructure` | e.g. larger board, second knight on fixture, new `*_scenario.gd` |
| `Infrastructure` | `ADEQUATE` \| `INADEQUATE` |

### Decision tree (fix game vs fix QA)

```
BAR failed?
  yes → assert names Bible clause?
    yes → Fix implementation (data / AbilitySystem / effects)
    no  → Fix QA test (add asserts, triggers, upgrade tier)
  no  → critic: matrix row missing or scenario too shallow?
    yes → Fix QA (new scenario or deepen phases)
    no  → PASS candidate for that ability row
```

**Forbidden:** Using planning QA PASS as Knight sign-off. **Forbidden:** Changing `live_planning_scene_test.gd` for Knight coverage.

---

## Coverage matrix (authoritative — `knight_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file yet |
| `HARNESS_ONLY` | Scenario runs green but **fails meta-critic contract** (no Bible header, no base/`[+]` sim asserts) |
| `PASS` | Meta-critic approved — Bible clause + base + `[+]` when data has `upgraded_effects` |
| `N/A` | Owner deferral with target phase (not used in MVP) |

**Summary (honest):** **0 / 30** factory rows `PASS` · **3** `HARNESS_ONLY` · **27** `PLANNED` · run-economy slice separate (harness only).

### Movement + actives

| Bible / factory id | Type | Scenario file | Tier 1 | Notes |
|--------------------|------|---------------|--------|-------|
| `knight_swap` | Movement | `PLANNED — tests/skills/knight_swap_scenario.gd` | PLANNED | Swap + optional `[+]` DEF/SHIELD |
| `knight_shield_bash` | Active | `tests/skills/shield_bash_scenario.gd` | HARNESS_ONLY | 7-phase harness; missing Bible header + STAGGER `[+]` asserts |
| `knight_phalanx_stance` | Active | PLANNED | PLANNED | SELF, STURDY, DEF buff |
| `knight_taunting_strike` | Active | PLANNED | PLANNED | PULL, TAUNT, upgraded AOE |
| `knight_seismic_stomp` | Active | PLANNED | PLANNED | AOE, PURGE, terrain |
| `knight_fortify` | Active | PLANNED | PLANNED | Ally DEF scale, THORNS upgrade |
| `knight_bowling_charge` | Active | PLANNED | PLANNED | DASH, collision chain |
| `knight_iron_grip` | Active | PLANNED | PLANNED | ROOT, AP refund upgrade |
| `knight_redirect_strike` | Active | PLANNED | PLANNED | INTERCEPT |
| `knight_indomitable_will` | Active | PLANNED | PLANNED | missing HP → SHIELD |
| `knight_retaliation_protocol` | Active | PLANNED | PLANNED | counter-attack |
| `knight_shield_slam` | Active | PLANNED | PLANNED | adjacent bonus, DEF debuff upgrade |
| `knight_defensive_formation` | Active | PLANNED | PLANNED | AOE ally buffs |
| `knight_chain_hook` | Active | `tests/skills/chain_hook_scenario.gd` | HARNESS_ONLY | Harness green; deepen Bible + `[+]` asserts |
| `knight_trampling_advance` | Active | `tests/skills/trampling_advance_scenario.gd` | HARNESS_ONLY | Harness green; deepen Bible + `[+]` asserts |
| *(economy)* | Run / MP | `tests/skills/run_economy_scenario.gd` | HARNESS_ONLY | Shared economy slice — not a Bible row |

### Passives (trigger-based — separate scenario shape)

| Factory id | Passive | Scenario file | Tier 1 | Trigger setup |
|------------|---------|---------------|--------|----------------|
| `collision_retaliator` | Collision Retaliator | PLANNED | PLANNED | Enemy collision into knight |
| `thorny_carapace` | Thorny Carapace | PLANNED | PLANNED | Melee hit on knight |
| `concussive_shatter` | Concussive Shatter | PLANNED | PLANNED | Collision damage |
| `kinetic_momentum` | Kinetic Momentum | PLANNED | PLANNED | Collision → SHIELD / MOV refund |
| `stand_ground` | Stand Ground | PLANNED | PLANNED | Enemy PUSH/PULL attempt |
| `indestructible_bastion` | Indestructible Bastion | PLANNED | PLANNED | Lethal damage once |
| `shield_mastery` | Shield Mastery | PLANNED | PLANNED | Front-arc hit |
| `kinetic_armor` | Kinetic Armor | PLANNED | PLANNED | Damage while SHIELD active |
| `kinetic_converter` | Kinetic Converter | PLANNED | PLANNED | On hit → STR/MOV next turn |
| `kinetic_redirection` | Kinetic Redirection | PLANNED | PLANNED | Mitigate → stacked STR |
| `bulwark` | Bulwark | PLANNED | PLANNED | Adjacent unit count |
| `living_barricade` | Living Barricade | PLANNED | PLANNED | Ranged line vs ally behind |
| `shield_wall` | Shield Wall | PLANNED | PLANNED | Adjacent ally DEF / PULL immune |
| `rallying_presence` | Rallying Presence | PLANNED | PLANNED | Ally start turn adjacent |
| `intercept_tactics` | Intercept Tactics | PLANNED | PLANNED | After redirect skill |

**LOCK rule:** All factory rows `PASS` (or owner-documented `N/A`). Gate script **fails** until then.

Registry today: `tests/planning_skill_scenarios_test.gd` — expand to `tests/knight_scenario_registry.gd` (PLANNED) listing actives + passives.

---

## Scenario contract (per row)

Each `tests/skills/<id>_scenario.gd` (or `tests/passives/<id>_scenario.gd`) must:

1. Cite **Bible clause** in file header (one-line expected behavior).
2. Run **planning phases** where applicable (actives) or **sim-only trigger** (passives).
3. Assert **base** and **`[+]` upgrade** when `upgraded_effects` exist in factory data.
4. Use `PlanningChecklistHarness` / headless `Simulator` — no parallel preview path.
5. Register in knight scenario registry (not planning QA legacy tier).

**Promotion:** `HARNESS_ONLY` → `PASS` only after meta-critic approves adequacy for that row.

Passive scenarios **must** set up the trigger (collision, melee hit, lethal, turn start) — stat-only reads are insufficient for critic PASS.

---

## Fixture strategy (critic may recommend)

| Pattern | When |
|---------|------|
| **Multi-knight board** | Several promotion loadouts on one `PlayerGrid` — parallel rows per boot |
| **Larger grid** | 12×8+ for pull/push chains, formation auras, trample corridors |
| **Packed triggers** | One scenario sequence: collision → melee → turn advance (deterministic) |
| **Promotion param** | `build_knight_fixture(promotion_loadout: Array[StringName])` (PLANNED helper) |

Critic optimization examples: *“Add knight at (2,2) with Stand Ground only; enemy push from (3,2)”* — valid `Proposed infrastructure`.

---

## Commands

```powershell
# Tier 1 (Knight class — target bar for LOCK)
.\scripts\run_knight_qa_gate.ps1

# Interim harness only (does not prove matrix PASS)
godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd

# Gameplay-core only (NOT Knight LOCK)
.\scripts\run_planning_qa_gate.ps1
```

---

## P6 clone checklist

1. Copy `docs/KNIGHT_QA_GATE.md` → `docs/<CLASS>_QA_GATE.md`
2. Replace matrix from `<class>_factory.gd` + Bible section
3. Copy `run_knight_qa_gate.ps1` → `run_<class>_qa_gate.ps1`
4. Same meta-critic rubric; different ability ids
5. Do **not** modify planning QA gate or `live_planning_scene_test.gd`

---

## Gauntlet stub (Knight QA gate doc — K3-doc companion)

```text
GOAL: Knight class QA spec — full factory matrix, honest status legend, meta-critic contract, separate from planning QA
BAR: lint PASS (pillar knight-template); matrix lists all knight_factory ids; decision tree present; gate script exists on disk
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc
ARTIFACT: this file, docs/design/knight-template.md, core/factory/classes/knight_factory.gd, scripts/run_knight_qa_gate.ps1
```
