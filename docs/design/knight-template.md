# Knight template (P3)

**Status:** `LOOP_READY` *(K3-doc gauntlet PASS 90/88 — implementation gates LOCK)*  
**Pillar ID:** P3  
**Authority chain:** `class_abilities.txt` § Knight · `docs/KNIGHT_QA_GATE.md` · `core/factory/classes/knight_factory.gd` · `data/` factories

## Goal

Ship a **perfectly working Knight moveset**: every active skill, movement skill (`knight_swap`), and passive in `knight_factory.gd` **100% tested** against the Bible, with a **meta-critic** that judges whether tests are adequate (not just green). On **LOCK**, P6 **clones** this pipeline per class (`run_<class>_qa_gate.ps1` + coverage matrix + critic rubric).

**Gameplay-core QA is out of scope for Knight LOCK:** `run_planning_qa_gate.ps1` validates intent/UI/commit only (Knights as fixtures). Do **not** change that suite for Knight coverage.

## Quality bar

### Doc gauntlet (K3-doc — this critic round)

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Knight QA spec** | `docs/KNIGHT_QA_GATE.md` exists; matrix lists every `knight_factory.gd` id | — |
| **Meta-critic contract** | Decision tree + fix-target taxonomy in gate doc | — |
| **Planning separation** | Both docs forbid changing `live_planning_scene_test.gd` | — |
| **Lint** | `.\scripts\lint_design_doc.ps1` PASS | — |
| **Gate script on disk** | `Test-Path scripts/run_knight_qa_gate.ps1` | — |

Doc gauntlet BAR = lint + cited paths + honest matrix — **not** 100% matrix PASS or LOCK.

### Implementation LOCK (K3-actives … K3-LOCK — separate gauntlet pieces)

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Coverage matrix** | `docs/KNIGHT_QA_GATE.md` — every row `PASS` (meta-critic approved) | Owner agrees MVP = full factory list |
| **Knight QA gate** | `.\scripts\run_knight_qa_gate.ps1` → PASS (all rows PASS) | — |
| **Tier 1 scenarios** | One scenario per matrix row; registry lists actives + passives | Checklist phases 1–7 per **active** |
| **Meta-critic** | Per-row adequacy ≥ 88; names fix `implementation` vs `qa_test` vs `fixture` | — |
| **Planning QA** (core edits only) | `run_planning_qa_gate.ps1` — **not** Knight LOCK | F5 core parity |

**Human gate rule:** Doc gauntlet BAR = `lint_design_doc.ps1` + `Test-Path` on `docs/KNIGHT_QA_GATE.md`, `core/factory/classes/knight_factory.gd`, `scripts/run_knight_qa_gate.ps1`. Unchecked implementation exit criteria, incomplete matrix (`PLANNED` / `HARNESS_ONLY` rows), and **0/31 meta-critic PASS** must **not** FAIL the **K3-doc** critic round. Matrix **100% PASS** gates **`LOCKED`** only — not `LOOP_READY`.

## Non-goals

- Using planning QA PASS as Knight sign-off
- Changing `live_planning_scene_test.gd` or `run_planning_qa_gate.ps1`
- Testing non-Knight classes (P6)
- Per-ability `if ability.id` branches in sim/presentation
- Critic-only PASS without deterministic scenario asserts
- **Misusing global keywords** (e.g. SWAP for Bible “behind caster” reposition) — see `docs/KNIGHT_QA_GATE.md` § Global systems fidelity
- **Heuristic one-off skill logic** that future abilities cannot reuse without new branches

## Human-only worksheet

N/A — Bible + matrix are authoritative. Owner defers rows only via explicit `N/A` in matrix with reason.

## Decomposition (gauntlet pieces)

| Piece | Owner | BAR | Status |
|-------|-------|-----|--------|
| **K3-doc** | Spec | lint + gate doc + gate script exist; honest matrix; meta-critic contract | **PASS** (90/88) |
| K3-matrix | Coverage | All factory ids listed; status honest | In K3-doc |
| K3-actives | Builder | One `tests/skills/<id>_scenario.gd` per active + swap | **DONE** (Tier 1 green) |
| K3-passives | Builder | One `tests/passives/<id>_scenario.gd` per passive (trigger setup) | **DONE** (factory smoke; deepen triggers) |
| K3-registry | Builder | `tests/knight_scenario_registry.gd` lists actives + passives | **DONE** |
| K3-gate | Builder | `run_knight_qa_gate.ps1` fails until matrix 100% PASS | **Tier 1 PASS** (exit 2 until matrix PASS) |
| K3-meta | Critic | Adequacy score per matrix row; fixture recommendations | **NEXT** |
| **K3-LOCK** | Owner | Matrix 100% PASS + gate PASS + meta-critic ≥ 88 | **IN PROGRESS** |

**Implementation tally:** **0 / 30** factory rows meta-critic `PASS` · **30** `HARNESS_ONLY` (Tier 1 harness green 2026-08-01). Next: meta-critic per row → promote to PASS.

## Builder playbook

1. Read Bible § Knight + row in `docs/KNIGHT_QA_GATE.md`.
2. **Map Bible → global system:** name exact `EffectType` / passive trigger in scenario header. If no exact global exists, add canonical effect in shared system (⚠ owner exception) — **never** pick a “close” keyword (see Rule B in gate doc; Suplex ≠ SWAP).
3. **Actives / swap:** copy `tests/skills/shield_bash_scenario.gd` → `tests/skills/<id>_scenario.gd` (7-phase where planning applies).
4. **Passives:** copy pattern from collision-style stub (PLANNED) — **must trigger** passive via shared hook (push, hit, lethal, turn start).
5. Wire data in `knight_factory.gd` / `.tres` — global systems only; no per-id sim/presentation branches.
6. Register in knight scenario registry; run `run_knight_qa_gate.ps1`.
7. Submit **artifacts only** to meta-critic: stdout, matrix row, scenario file path, Bible excerpt + named global effect(s).
8. If critic says `Fix target: qa_test` — deepen asserts or fixture; if `implementation` — fix game/data (wrong effect type = implementation).
9. Core planning edits: run `run_planning_qa_gate.ps1` separately.

## Critic playbook (meta-QA — owner proxy)

### K3-doc round (spec only)

```powershell
.\scripts\lint_design_doc.ps1
Test-Path docs/KNIGHT_QA_GATE.md
Test-Path core/factory/classes/knight_factory.gd
Test-Path scripts/run_knight_qa_gate.ps1
```

Judge: matrix completeness vs factory, meta-critic contract, planning≠Knight split. **Do not** FAIL for open implementation exit criteria or `HARNESS_ONLY` rows.

### Per-row rounds (after K3-doc)

```powershell
.\scripts\run_knight_qa_gate.ps1
# Read docs/KNIGHT_QA_GATE.md row vs tests/skills/ tests/passives/
```

Judge per row:

- **Global systems fidelity:** shared effect/trigger path (Rule A)? Bible-exact keyword — not misused SWAP/PUSH/etc. (Rule B)?
- Asserts cover Bible base + `[+]` when `upgraded_effects` exist
- Scenario header names expected `EffectType` or passive trigger
- Passive rows: real triggers via shared hooks, not stat-only
- Recommendations: larger map, multi-knight fixture, packed scenarios
- **Do not** conflate planning QA results with Knight score

Handoff payload: see `docs/KNIGHT_QA_GATE.md` § Meta-critic and § Global systems fidelity.

## Gauntlet stub (K3-doc — doc critic only)

```text
GOAL: P3 pillar spec — Knight QA gate doc + meta-critic contract + honest matrix; planning QA explicitly out-of-scope; P6-cloneable at LOCK
BAR: lint PASS; Test-Path docs/KNIGHT_QA_GATE.md, core/factory/classes/knight_factory.gd, scripts/run_knight_qa_gate.ps1; matrix lists all factory ids with honest status legend; unchecked LOCK exit criteria must not FAIL this round
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc, move-preview-intent-truth.mdc
ARTIFACT: this file, docs/KNIGHT_QA_GATE.md, knight_factory.gd, lint stdout, Test-Path gate script
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `class_abilities.txt` § Knight | Matrix rows | `KNIGHT_QA_GATE.md` |
| `knight_factory.gd` | Ability/passive ids | Matrix authoritative list |
| Scenario `.gd` | Tier 1 harness / PASS | Meta-critic adequacy review |
| Meta-critic report | Fix list (game vs QA vs fixture) | Builder next piece |
| Knight LOCK | `docs/<CLASS>_QA_GATE.md` clone | P6 |

## Exit criteria

### K3-doc (promote to `LOOP_READY`)

- [x] `docs/KNIGHT_QA_GATE.md` complete (matrix + meta-critic + tiers)
- [x] `scripts/run_knight_qa_gate.ps1` on disk (may FAIL until matrix complete)
- [x] Doc gauntlet critic ≥ 88 on K3-doc stub (90/88, round 1)
- [x] `docs/design/knight-template.md` status → `LOOP_READY`

### K3-LOCK (promote to `LOCKED`)

- [ ] **100%** matrix rows `PASS` (actives + passives + swap; meta-critic approved per row)
- [ ] `.\scripts\run_knight_qa_gate.ps1` → PASS
- [ ] Meta-critic adequacy **≥ 88** on full matrix review
- [ ] P6 can copy gate + matrix pattern without planning QA changes

## Doc polish scorecard

*(Critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| Covers scope | |
| Machine bars | |
| No duplication | |
| Agent-executable | |
| Human boundaries | |
| Sequencing | |
| Tooling I/O | |
| Loop-polishable | |
