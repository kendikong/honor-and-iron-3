# Bruiser template (P6 — first class rollout)

**Status:** `LOCKED` *(B6-LOCK complete — canonical gate 31/31 PASS; full-matrix critic r20 **95/95 PASS**; commit `72414aeaa`+)*  
**Unattended run:** [`UNATTENDED_RUN.md`](UNATTENDED_RUN.md) *(ACTIVE — B6-LOCK)* · **Run card:** [`runs/B6-LOCK.md`](runs/B6-LOCK.md)  
**Pillar ID:** P6 (first class — clones P3)  
**Authority chain:** `class_abilities.txt` § Bruiser · `docs/BRUISER_QA_GATE.md` · `core/factory/classes/bruiser_factory.gd` · `docs/design/knight-template.md` (P3 LOCKED)

## Goal

Ship a **perfectly working Bruiser moveset**: every active skill, movement skill (`bruiser_push_through`), and passive in `bruiser_factory.gd` **100% tested** against the Bible, with a **meta-critic** that judges whether tests are adequate (not just green). On **LOCK**, remaining P6 classes clone this pipeline (`run_<class>_qa_gate.ps1` + coverage matrix + critic rubric).

**Gameplay-core QA is out of scope for Bruiser LOCK:** `run_planning_qa_gate.ps1` validates intent/UI/commit only. Do **not** change that suite for Bruiser coverage.

## Quality bar

### Doc gauntlet (B6-doc — first critic round)

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Bruiser QA spec** | `docs/BRUISER_QA_GATE.md` exists; matrix lists every `bruiser_factory.gd` id | — |
| **Meta-critic contract** | Points to Knight gate § Meta-critic + Global systems fidelity | — |
| **Planning separation** | Gate doc forbids changing `live_planning_scene_test.gd` | — |
| **Lint** | `.\scripts\lint_design_doc.ps1` PASS | — |
| **Gate script on disk** | `Test-Path scripts/run_bruiser_qa_gate.ps1` | — |

Doc gauntlet BAR = lint + cited paths + honest matrix — **not** 100% matrix PASS or LOCK.

### Implementation LOCK (B6-actives … B6-LOCK — separate gauntlet pieces)

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| **Coverage matrix** | `docs/BRUISER_QA_GATE.md` — every row `PASS` (meta-critic approved) | Owner agrees MVP = full factory list |
| **Bruiser QA gate** | `.\scripts\run_bruiser_qa_gate.ps1` → PASS (all rows PASS) | — |
| **Tier 1 scenarios** | One scenario per matrix row; registry lists actives + passives | Checklist phases 1–7 per **active** where planning applies |
| **Meta-critic** | Per-row adequacy ≥ 88; names fix `implementation` vs `qa_test` vs `fixture` | — |
| **Planning QA** (core edits only) | `run_planning_qa_gate.ps1` — **not** Bruiser LOCK | F5 core parity |

## Non-goals

- Knight re-work (P3 LOCKED)
- Using planning QA PASS as Bruiser sign-off
- Changing `live_planning_scene_test.gd` or `run_planning_qa_gate.ps1`
- Per-ability `if ability.id` branches in sim/presentation
- **Misusing global keywords** — see `docs/KNIGHT_QA_GATE.md` § Global systems fidelity (Suplex ≠ SWAP)

## Human-only worksheet

N/A — Bible + matrix are authoritative.

## Decomposition (gauntlet pieces)

| Piece | Owner | BAR | Status |
|-------|-------|-----|--------|
| **B6-doc** | Spec | lint + gate doc + gate script exist; honest 31-row matrix | **DONE** |
| B6-matrix | Coverage | All factory ids listed; status honest | **DONE** |
| B6-actives | Builder | One `tests/skills/<id>_scenario.gd` per active + movement | **DONE** (16/16 via harness) |
| B6-passives | Builder | One `tests/passives/<id>_scenario.gd` per passive | **DONE** (15/15 via harness) |
| B6-registry | Builder | `tests/bruiser_scenario_registry.gd` lists all rows | **DONE** |
| B6-gate | Builder | `run_bruiser_qa_gate.ps1` fails until matrix 100% PASS + manifest | **DONE** (exit 0; `qa_bruiser_gate_canonical.txt`) |
| B6-meta | Critic | Adequacy score per matrix row | **DONE** — r20 full-matrix **95/95 PASS** |
| **B6-LOCK** | Owner | Matrix 31/31 PASS + gate PASS + meta-critic ≥ 95 | **COMPLETE** — [`runs/B6-LOCK.md`](runs/B6-LOCK.md) |

**Implementation tally:** **31 / 31** factory rows · gate exit **0** · harness **PASS** · critic r20 **95/95 PASS**.

## Builder playbook

1. Read Bible § Bruiser + row in `docs/BRUISER_QA_GATE.md`.
2. **Map Bible → global system:** name exact `EffectType` / passive trigger in scenario header.
3. **Actives / movement:** copy `tests/skills/shield_bash_scenario.gd` → `tests/skills/bruiser_<id>_scenario.gd` (7-phase where planning applies).
4. **Passives:** copy `tests/passives/collision_retaliator_scenario.gd` pattern — **must trigger** passive via shared hook.
5. Wire data in `bruiser_factory.gd` — global systems only.
6. Register in `tests/bruiser_scenario_registry.gd`; run `run_bruiser_qa_gate.ps1`.
7. Submit **artifacts only** to meta-critic.
8. Core planning edits: run `run_planning_qa_gate.ps1` separately.

## Critic playbook (meta-QA)

```powershell
.\scripts\lint_design_doc.ps1
Test-Path docs/BRUISER_QA_GATE.md
Test-Path core/factory/classes/bruiser_factory.gd
Test-Path scripts/run_bruiser_qa_gate.ps1
.\scripts\run_bruiser_qa_gate.ps1
```

Judge per row: global systems fidelity (Rules A/B from Knight gate doc), Bible asserts, upgrade tier, trigger setup for passives.

## Gauntlet stub (B6-doc)

```text
GOAL: P6 Bruiser pillar spec — gate doc + honest 31-row matrix; planning QA out-of-scope
BAR: lint PASS; Test-Path docs/BRUISER_QA_GATE.md, bruiser_factory.gd, scripts/run_bruiser_qa_gate.ps1
PASS_THRESHOLD: 88
RULES: skill-global-rules.mdc, global-systems-first.mdc, knight-template.md
ARTIFACT: this file, docs/BRUISER_QA_GATE.md, bruiser_factory.gd, lint stdout
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| `class_abilities.txt` § Bruiser | Matrix rows | `BRUISER_QA_GATE.md` |
| `bruiser_factory.gd` | Ability/passive ids | Matrix authoritative list |
| Scenario `.gd` | Tier 1 harness / PASS | Meta-critic adequacy review |
| Bruiser LOCK | `docs/<CLASS>_QA_GATE.md` clone | P6 next class |

## Exit criteria

### B6-doc (promote to `LOOP_READY`)

- [x] `docs/BRUISER_QA_GATE.md` complete (matrix + meta-critic pointer)
- [x] `scripts/run_bruiser_qa_gate.ps1` on disk
- [ ] Doc gauntlet critic ≥ 88 on B6-doc stub
- [ ] `docs/design/bruiser-template.md` status → `LOOP_READY`

### B6-LOCK (promote to `LOCKED`)

- [ ] **100%** matrix rows `PASS` (31 rows; meta-critic approved per row)
- [ ] `.\scripts\run_bruiser_qa_gate.ps1` → PASS
- [ ] Meta-critic adequacy **≥ 95** on full matrix review
- [ ] Next P6 class can copy gate + matrix pattern

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
