# <CLASS> QA Gate

**Scope:** Class validation — every **active skill**, **movement skill**, and **passive** in `core/factory/classes/<class>_factory.gd` behaves per `class_abilities.txt` § <Class>. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (<CLASS> LOCK):** 100% coverage matrix rows **PASS** (meta-critic approved) + `run_<class>_qa_gate.ps1` PASS + `run_<class>_live_qa.ps1` PASS + meta-critic **≥ 88** on full matrix.

**Runner:** `scripts/run_<class>_qa_gate.ps1` — **does not** invoke or modify `run_planning_qa_gate.ps1`.

**Clone authority:** [`docs/CLASS_QA_BIBLE.md`](CLASS_QA_BIBLE.md) (universal spec) · [`docs/KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) (reference instance) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

---

## Gate status (update every matrix change)

| Field | Value |
|-------|-------|
| **LOCK** | `NO` until matrix 100% `PASS` |
| **Summary** | `0 / N` factory rows meta-critic `PASS` · `N` `HARNESS_ONLY` · `N` `PLANNED` |
| **Honest bar** | Headless harness green ≠ LOCK. See forbidden patterns in `class-qa-knight-bar.mdc`. |

---

## Three tiers

| Tier | Runner | Gate status |
|------|--------|-------------|
| **1 — Headless scenarios** | `.\scripts\run_<class>_qa_gate.ps1` | **Required** — per-ability/passive scenarios via harness + sim |
| **2 — Live acceptance** | `.\scripts\run_<class>_live_qa.ps1` → `tests/live_<class>_class_test.gd` | **Required for LOCK** — TestBattle, overlay tiles, preview/commit, sim |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` per ability | Required for feel/pixels Tier 1–2 cannot see |

**Only Tier 1+2 matrix `PASS` blocks <CLASS> LOCK.**

---

## Meta-critic (owner proxy)

Same contract as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic — Bible adherence, global systems fidelity (Rules A/B), test adequacy, coverage, fix target (`implementation` \| `qa_test` \| `fixture` \| `coverage_matrix`).

**Forbidden:** Using planning QA PASS as <CLASS> sign-off. **Forbidden:** Changing `live_planning_scene_test.gd` for <CLASS> coverage.

---

## Global systems fidelity (mandatory)

Copy **verbatim** from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Global systems fidelity (Rules A/B, QA enforcement, keyword table).

Add **<class>-specific** keyword reminders in a table when Bible text differs from generic globals.

---

## Coverage matrix (authoritative — `<class>_factory.gd`)

### Status legend

| Status | Meaning |
|--------|---------|
| `PLANNED` | No scenario file yet |
| `HARNESS_ONLY` | Monolithic harness or live smoke runs green but **fails meta-critic** (no per-row Bible/sim/overlay footprint asserts) |
| `PASS` | Meta-critic approved — Bible clause + base + `[+]` when `upgraded_effects` exist |
| `N/A` | Owner deferral with target phase |

### Movement + actives

| Bible / factory id | Type | Scenario file | Tier 1 | Notes |
|--------------------|------|---------------|--------|-------|
| `<class>_example` | Active | `tests/skills/<class>_example_scenario.gd` | PLANNED | |

### Passives

| Factory id | Passive | Scenario file | Tier 1 | Trigger setup |
|------------|---------|---------------|--------|----------------|
| `example_passive` | Example | `tests/passives/example_passive_scenario.gd` | PLANNED | |

**LOCK rule:** All factory rows `PASS` (or owner `N/A`). Gate script **fails** if doc claims LOCK while any row is `HARNESS_ONLY` without explicit deferral.

Registry: `tests/<class>_scenario_registry.gd` + `tests/<class>_qa_runner.gd`

---

## Scenario contract (per row)

Each scenario file must:

1. Cite **Bible clause** in file header.
2. Name **expected global effect(s) or passive trigger** (Rule B).
3. Run **planning phases** where applicable (actives) or **sim-only trigger** (passives).
4. Assert **base** and **`[+]`** when `upgraded_effects` exist in factory.
5. Assert via **`PlanningChecklistHarness` / `Simulator`** — no parallel test-only skill logic.
6. **AOE/shape:** assert **tile sets** (sim + live overlay at hover), not metadata only.

---

## Commands

```powershell
# Tier 1 (class — required every factory/scenario change)
.\scripts\run_<class>_qa_gate.ps1

# Tier 2 (class LOCK — required before owner sign-off)
.\scripts\run_<class>_live_qa.ps1

# Gameplay-core planning only (NOT class LOCK)
.\scripts\run_planning_qa_gate.ps1
```

---

## Changelog fields (agents)

When touching this class, report in turn Changelog:

- Matrix: `PASS` / `HARNESS_ONLY` / `PLANNED` counts
- Suites: `run_<class>_qa_gate.ps1` and `run_<class>_live_qa.ps1` — PASS/FAIL
- **LOCK claim:** only if 100% matrix `PASS`
