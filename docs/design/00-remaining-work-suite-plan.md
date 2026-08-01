# Remaining Work — Design Suite Implementation Plan (v3)

**Status:** `LOOP_READY` (plan artifact — not yet `LOCKED`)  
**Authority:** User goals (map, SFX, UI, classes, run, Knight, enemies, agent looping, PixelForge)  
**Gauntlet spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md)  
**Progress log:** [`workbench.md`](workbench.md)

This file is the **implementation plan for creating all remaining-work documents**. It is loop-polished via the doc-polish gauntlet (Rounds 1–3 below). Game work itself lives in pillar specs once written — starting with [`REMAINING_WORK_MAP.md`](REMAINING_WORK_MAP.md) (Wave W1).

---

## Doc-polish gauntlet ledger

| Round | Critic focus | Score | Largest gap | Status |
|-------|--------------|-------|-------------|--------|
| 1 | Structure (v1 → master map + 9 pillars) | 6.5 → 8.0 | No single master map | v2 drafted (prior chat) |
| 2 | Completeness vs repo + user scope | 7.2 | P0 duplicated gauntlet doc; critical path not tied to parity Phases 10–14 | **v3 this file** |
| 3 | Executability (real paths, waves) | 8.4 | `lint_design_doc.ps1` missing — staged doc bar | **v3 this file** |
| 4 | Owner alignment | TBD | Lock `REMAINING_WORK_MAP.md` + roguelike worksheet | **pending you** |

**Pass rule (suite plan):** avg ≥ 8.0, no dimension &lt; 6, ≤2 open items documented with target wave.

---

## Round 2 — Critic (completeness)

**Artifact judged:** Plan v2 (9 pillars, 4 waves, three layers).

| # | Dimension | v2 | Gap |
|---|-----------|-----|-----|
| 1 | Covers user-named areas | 8 | Networking/co-op correctly deferred; **triage/autobattler** only in appendix — add row in verification matrix |
| 2 | Objective bars per pillar | 7 | Matrix described, not **filled** with repo script paths |
| 3 | Sequencing | 6 | Critical path generic; must anchor **Parity Plan Phases 10–14** before roguelike |
| 4 | Avoids sprawl / duplication | 8 | Good delta rule; **P0 overlaps** `00-gauntlet-loop-cursor.md` |
| 5 | Agent-executable | 8 | Gauntlet + critic exist on disk; doc suite had no single plan file |
| 6 | Human vs agent boundaries | 7 | Roguelike worksheet named but **empty template** missing |
| 7 | Tooling (PixelForge) | 8 | Appendix correct; needs `docs/asset_manifest.md` + `tile_registry.md` in I/O chain |
| 8 | Loop-polishable | 5 | v2 lived only in chat — **not on disk** |

**Round 2 result: FAIL** (avg 7.1; dimensions 3 and 8 below threshold)

**Largest gap:** Plan was not executable against **current repo truth** (parity phase numbers, existing gauntlet infra, real QA commands).

---

## Round 3 — Critic (executability)

| Check | Result |
|-------|--------|
| `run_planning_qa_gate.ps1` exists | PASS |
| `run_regression_tests.ps1` exists | PASS |
| `planning_skill_scenarios_test.gd` in gate | PASS (`tests/run_planning_qa_gate.gd`) |
| `PLANNING_SKILL_QA_CHECKLIST.md` (7 phases) | PASS |
| `mass_sim_*` + `run_mass_sim_test.gd` | PASS (no PS1 wrapper — doc bar uses Godot CLI) |
| `lint_design_doc.ps1` | FAIL — **not on disk**; Wave W1 creates minimal linter |
| P0 duplicate of gauntlet doc | FAIL — merge strategy required |
| Suite plan file on disk | FAIL before this commit |

**Round 3 result: PASS with 2 deferred** (lint script → W1; owner lock → Round 4)

---

## Design principle: three layers

```
Layer 0 — MASTER MAP       REMAINING_WORK_MAP.md (game milestones, one page)
Layer 1 — PILLAR SPECS     ~9 agent contracts (deltas only)
Layer 2 — APPENDICES       tools, formats, prompt library
```

**Canonical docs are not replaced.** Pillar specs link **authority chain** and add **goal + bar + gauntlet stub** only.

| Keep authoritative | Pillar adds |
|--------------------|-------------|
| `ROADMAP.md` | Living-map remaining phases + compositor gates |
| `docs/TACTICAL_COMBAT_PARITY_PLAN.md` | Open items Phases 10–14 + retirement checklist |
| `class_abilities.txt` | Per-class rollout checklists |
| `docs/PLANNING_QA_GATE.md` | Pointers only — never duplicate Tier 3 |
| `IMPLEMENTATION_STATUS.md` | Status row per pillar when work starts |
| `docs/design/00-gauntlet-loop-cursor.md` | **Runtime gauntlet OS** — not duplicated |

---

## Critical path (repo-aligned)

Current truth: **Phase 9 FAIL**; **Parity Plan Phases 10–14** are the combat spine; roguelike is not started.

```mermaid
flowchart TD
  P10[Parity Phase 10-13 combat core] --> P14[Phase 14 Knight MVP re-gate]
  P14 --> KT[Knight template LOCK - P3]
  KT --> RUN[Roguelike run v1 - P4 human worksheet]
  RUN --> EN[Enemy puzzle kit - P5]
  EN --> CR[Class rollout 2+ - P6]
  MAP[Map assets + PixelForge MVP - P7] --> LM[Living map ROADMAP close]
  UI[Presentation shell - P8] --> UII[UI gauntlets]
  P14 --> CR
  RUN --> CR
```

**Bar for Layer 0 map:** Every node = **one pillar doc** + **one primary command** (see verification matrix).

---

## File tree (v3 — consolidated)

```
docs/design/
├── README.md                              # Index + polish status table (W1)
├── 00-remaining-work-suite-plan.md        # THIS FILE — how to create the suite
├── 00-gauntlet-loop-cursor.md             # EXISTS — runtime gauntlet OS (≈ P0 runtime)
├── 01-doc-polish-protocol.md              # P1 — how any doc reaches POLISHED (W1)
├── UNATTENDED_RUN.md                      # EXISTS
├── workbench.md                           # EXISTS
├── _TEMPLATE.md                           # Mandatory pillar sections (W1)
├── REMAINING_WORK_MAP.md                  # Layer 0 master map (W1)
├── verification-matrix.md                 # P9 — machine bars (W1)
│
├── combat-core-closeout.md                # P2 — parity Ph10-14 open deltas (W2)
├── knight-template.md                     # P3 (W2)
├── roguelike-run.md                       # P4 + human worksheet (W2)
├── enemy-design.md                        # P5 (W3)
├── class-rollout.md                       # P6 (W3)
├── world-assets-and-map.md                # P7 (W3)
├── presentation-audio-ui.md               # P8 (W3)
│
└── appendices/
    ├── pixelforge-v14-contract.md           # W3
    ├── mass-sim-balance.md                # W4
    ├── encounter-fixture-format.md        # W2 stub → W3 expand
    └── gauntlet-prompt-library.md         # W4
```

**P0 naming:** Do **not** add `00-agentic-operating-system.md`. Pillar P0 = **`00-gauntlet-loop-cursor.md`** + **`01-doc-polish-protocol.md`**.

**Deferred appendices until needed:** co-op, tutorial, autobattler HUD (Parity Phase 15).

---

## Shared template (`_TEMPLATE.md`) — W1

Every pillar spec **must** include:

1. **Pillar ID** (P2–P9) + link from `REMAINING_WORK_MAP.md`
2. **Status:** `DRAFT | LOOP_READY | POLISHED | LOCKED`
3. **Authority chain** (bullets — no prose duplication of Bible/ROADMAP)
4. **Goal / non-goals** (≤5 bullets each)
5. **Quality bar table:** `Deliverable | Machine check | Human check`
6. **Human-only worksheet** (table or `N/A`)
7. **Decomposition** (independently verifiable chunks)
8. **Builder playbook** (ordered; files/systems)
9. **Critic playbook** (commands only)
10. **Gauntlet stub** (lead prompt, 3 paragraphs max)
11. **Tooling I/O** (inputs → outputs → consumer path)
12. **Exit criteria** (checkboxes)
13. **Doc polish scorecard** (8 dimensions before POLISHED)

---

## Verification matrix (draft — P9; expand in W1)

| Pillar | Primary machine bar | Secondary | Human gate |
|--------|---------------------|-----------|------------|
| **P2** combat closeout | `.\scripts\run_regression_tests.ps1` PASS | `.\scripts\run_planning_qa_gate.ps1` PASS | F5 Phase 10–14 manual lists in parity plan |
| **P3** knight template | Planning QA PASS + skill row in `tests/planning_skill_scenarios_test.gd` | Checklist phases 1–7 in `docs/PLANNING_SKILL_QA_CHECKLIST.md` | 60s Boredom / play feel |
| **P4** roguelike run | Named test path in spec (TBD until `RunState` exists) | — | **Worksheet required** (below) |
| **P5** enemy design | Encounter fixture loads → `EncounterBuilder` → headless sim smoke | `bridge_test_runner.gd` green | Puzzle fun / difficulty |
| **P6** class rollout | Per-class: P3 bar + optional `godot --headless --script res://tests/run_mass_sim_test.gd` | `mass_sim_interpretation.json` epoch compare | Balance taste |
| **P7** world/map | `docs/asset_manifest.md` entries match disk; F5 compositor gates | PixelForge CANON promote log | Art direction |
| **P8** presentation | Event→SFX map complete; no missing `SfxPlayer` hooks for listed events | UI screen inventory vs scenes | Layout / typography taste |
| **P9** matrix | Every row cites a path that exists on disk | `scripts/lint_design_doc.ps1` PASS (W1) | — |
| **Docs (meta)** | `lint_design_doc.ps1` on `docs/design/*.md` | `gauntlet-critic` `RESULT: PASS` | Owner LOCK on master map |

**Mass sim CLI (document in appendix):**

```text
godot --headless --path <repo> --script res://tests/run_mass_sim_test.gd
```

---

## Human-only worksheets (templates)

### P4 — Roguelike run (you fill before P4 = LOOP_READY)

| Decision | Your answer |
|----------|-------------|
| Run length (rooms / floors / time) | |
| Map structure (linear / branching / grid) | |
| Death rules (permadeath / checkpoint) | |
| Meta-progression (yes/no; what persists) | |
| Co-op in v1 run loop (yes/no) | |
| Save model (`user://` schema owner) | |

### P7 — Art direction (you fill before P7 = LOOP_READY)

| Decision | Your answer |
|----------|-------------|
| Replace Mana Seed vs augment | |
| PixelForge CANON promote authority | *(default: you only)* |
| Reference mood boards / PNG paths | |
| Seasonal / biome priority order | |

---

## Wave delivery (implementation order)

### W1 — Spine + meta (first unattended chunk)

| Output | Bar |
|--------|-----|
| `README.md`, `_TEMPLATE.md`, `01-doc-polish-protocol.md` | Template sections present |
| `REMAINING_WORK_MAP.md` | Every milestone → pillar + command |
| `verification-matrix.md` | All paths exist or marked `PLANNED` |
| `scripts/lint_design_doc.ps1` | Fails if pillar missing required H2s |

**W1 gauntlet:** builder writes → **`/gauntlet-critic`** with BAR = lint script + matrix path grep → fix largest gap → repeat until PASS.

### W2 — Combat spine docs

| Output | Bar |
|--------|-----|
| P2, P3, P4 | P3 cites Shield Bash scenario + checklist phases |
| `appendices/encounter-fixture-format.md` (stub) | Schema fields listed |

**Depends on:** W1 LOCK or LOOP_READY.

### W3 — Content + world

| Output | Bar |
|--------|-----|
| P5, P6, P7, P8 | P7 I/O: PixelForge → `asset_manifest.md` |
| `appendices/pixelforge-v14-contract.md` | Matches v14 `.docx` entities (distilled) |

### W4 — Prompt library + balance

| Output | Bar |
|--------|-----|
| `appendices/gauntlet-prompt-library.md`, `mass-sim-balance.md` | Prompts run without editing |

**Human gate between waves:** you read `REMAINING_WORK_MAP.md` + P4/P7 worksheets only.

---

## Doc-polish protocol (P1 summary — full file in W1)

For **any** design doc (including this plan):

1. **Builder** drafts from authority docs + grep — not from memory.
2. **Lead** invokes **`gauntlet-critic`** (readonly) with §9 handoff from `00-gauntlet-loop-cursor.md` — **no builder chat log**.
3. **Critic** returns `RESULT: PASS | FAIL` + largest gap + evidence.
4. **Builder** fixes one gap → repeat until PASS or `MAX_ROUNDS_PER_PIECE` → `FAILURE_REPORT.md`.
5. **Status promotion:** `DRAFT` → `LOOP_READY` (critic PASS once) → `POLISHED` (scorecard ≥8 avg) → `LOCKED` (owner).

**Doc BAR (until custom linter ships):**

| Stage | Machine check |
|-------|----------------|
| LOOP_READY | All `_TEMPLATE.md` H2s present; ≥1 machine bar per deliverable |
| POLISHED | `gauntlet-critic` PASS + 8-dimension scorecard in doc footer |
| LOCKED | Owner reply + commit hash in doc header |

---

## `lint_design_doc.ps1` (W1 deliverable — spec)

Minimal checks (PowerShell):

- Every `docs/design/*.md` except `workbench.md` has: `**Status:**`, `## Goal`, `## Quality bar` OR is listed as exempt in README
- Pillar files match `P[0-9]` or named in README exempt list
- No pillar body pastes full `ROADMAP.md` / parity plan sections (&gt;40 consecutive lines from those files = FAIL)

---

## PixelForge placement

**Owner:** `appendices/pixelforge-v14-contract.md`

- `ASSET_SPECIFICATION` ↔ `docs/asset_manifest.md` + `docs/tile_registry.md`
- Export paths under `res://` that Godot scenes already reference
- **Bar:** promoted CANON → manifest row + nearest filter + F5 compositor gate
- **Agent rule:** propose only; CANON promote = human (v14)

---

## Anti-patterns (suite-specific)

| Anti-pattern | Fix |
|--------------|-----|
| Duplicating `00-gauntlet-loop-cursor.md` as P0 | Point to existing file |
| Self-grading plan v2 in chat only | This file on disk + critic PASS |
| Roguelike spec before worksheet filled | P4 stays DRAFT |
| Pillar pastes parity plan phases | Link + open-items table only |
| Claiming POLISHED without `gauntlet-critic` | workbench `Critic: yes` column |

---

## Suggested next action

| Option | What happens |
|--------|----------------|
| **W1 unattended** | Fill `UNATTENDED_RUN.md` for chunk `design-suite-w1`; lead runs gauntlet on W1 files |
| **Round 4 (you)** | Fill P4/P7 worksheets; reply LOCK on sequencing |
| **Adjust** | Change pillar list, wave order, or deferrals |

---

## Changelog (this document)

| Date | Change |
|------|--------|
| 2026-08-01 | v3: Rounds 2–3 gauntlet; repo-aligned path; P0 merge; verification matrix draft; W1 lint spec |
