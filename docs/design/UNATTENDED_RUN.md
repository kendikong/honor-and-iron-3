# Unattended Gauntlet Run — K3-LOCK (COMPLETE)

**Status:** **COMPLETE** — owner LOCK 2026-08-02 · `knight-template.md` → **`LOCKED`**  
**Run card:** [`runs/K3-LOCK.md`](runs/K3-LOCK.md)  
**Spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) §5.4 · **Progress:** [`workbench.md`](workbench.md)  
**Template for future runs:** [`UNATTENDED_RUN.template.md`](UNATTENDED_RUN.template.md)

The lead agent must **not** ask the owner questions during this run. It stops only when **STOP_ON** is satisfied or a **boundary** fires.

---

## Run identity

| Field | Value |
|-------|-------|
| **CHUNK_ID** | `knight-k3-lock-2026-08-01` |
| **PIECE_ID** | `K3-LOCK` (full 30-row Knight matrix — one gauntlet piece) |
| **GOAL** | Promote `docs/design/knight-template.md` from `LOOP_READY` → **`LOCKED`**: every `knight_factory.gd` row meta-critic `PASS`, matrix 30/30, gate exit **0**, full-matrix critic **≥ 95** |
| **PASS_THRESHOLD** | **95** (owner override — full-matrix critic only) |
| **BAR** | See **Machine bar** below |
| **Started (UTC)** | 2026-08-01 |
| **Godot** | `C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe` |

### Machine bar (all must be true to claim STOP_ON success)

1. `.\scripts\run_knight_qa_gate.ps1` → exit **0** (30/30 matrix `PASS` + Tier 1 harness green + manifest aligned)
2. `docs/KNIGHT_QA_GATE.md` summary line matches **30 / 30** meta-critic `PASS`
3. `docs/knight_meta_critic_manifest.json` — **30** `approved_rows`; no matrix `PASS` without manifest entry
4. Fresh **`gauntlet-critic`** on **full matrix** returns `RESULT: PASS`, `SCORE ≥ 95`, `Infrastructure: ADEQUATE`
5. `docs/design/knight-template.md` status → **`LOCKED`**

### Current baseline (tick 0 — do not regress)

| Metric | Value |
|--------|-------|
| Matrix PASS | **30 / 30** |
| HARNESS_ONLY | **0** |
| Manifest approved | **30** rows |
| Last full-matrix critic | r37 — **92/95 FAIL** |
| Tier 1 harness | **PASS** (gate exit **0**) |

---

## Boundaries (safety — not the primary stop condition)

| Boundary | Value |
|----------|-------|
| **MAX_ROUNDS_PER_PIECE** | `40` *(full K3-LOCK piece — on exhaust write `FAILURE_REPORT.md`)* |
| **MAX_SUBPIECE_ROUNDS** | `4` *(per matrix row promotion attempt — then skip row, pick next HARNESS_ONLY)* |
| **MAX_WALL_CLOCK** | `24h` *(optional owner stop)* |
| **ROWS_PER_TICK** | `1–2` *(promote or deepen — never batch-manifest without per-row critic evidence)* |

---

## Scope lock

### ALLOWED_PATHS

```
core/systems/**
core/factory/**
core/simulation/**
data/**
tests/knight_qa_harness.gd
tests/knight_qa_runner.gd
tests/knight_scenario_registry.gd
tests/skills/**
tests/passives/**
tests/run_skill_scenarios_only.gd
docs/KNIGHT_QA_GATE.md
docs/knight_meta_critic_manifest.json
docs/design/knight-template.md
docs/design/workbench.md
docs/design/runs/K3-LOCK.md
scripts/run_knight_qa_gate.ps1
```

### FORBIDDEN (hard stop — write `docs/design/FAILURE_REPORT.md` and exit)

| Rule | Detail |
|------|--------|
| **Planning QA scope** | Do **not** edit `tests/live_planning_scene_test.gd`, `scripts/run_planning_qa_gate.ps1`, or planning gate for Knight coverage |
| **No-regression skills** | Do **not** weaken or replace production/harness/scenario paths for `knight_bowling_charge`, `knight_trampling_advance` (see `KNIGHT_QA_GATE.md` § Owner no-regression). Assert deepening only. |
| **Self-grade** | Lead must **not** add manifest rows or matrix `PASS` without `gauntlet-critic` approval for that row |
| **Global bypass** | No new per-skill `if ability.id == …` branches; no new global rules without owner ⚠ exception |
| **Wrong owner** | No `presentation/board_view.gd` tactical fixes |
| **Fake stop** | Harness green, 14/30, or score climb **≠** completion (Rule 5c) |
| **Scope creep** | P4/P5/P7 worksheets, other classes, planning parity refactors |

---

## MANDATORY_COMMANDS

Run after **every tick** that changes gameplay or test code.

| Order | Command | When |
|-------|---------|------|
| 1 | `.\scripts\run_knight_qa_gate.ps1` | **Always** — primary BAR |
| 2 | `.\scripts\run_regression_tests.ps1 -GodotPath "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"` | Only if `core/simulation/` or `core/systems/` changed |

**Do not** run planning QA gate unless `presentation/combat_planning_input.gd` was edited (not expected this run).

### Exit code interpretation

| Exit | Meaning | Lead action |
|------|---------|-------------|
| **0** | LOCK ready — run full-matrix critic | If critic ≥ 95 → STOP_ON success |
| **1** | Tier 1 harness FAIL | Fix asserts/scenarios — do not promote matrix |
| **2** | Harness OK, matrix incomplete | Expected until 30/30 — continue loop |
| **3** | Matrix PASS without manifest | Revert self-grade — critic manifest only |

---

## Per-tick workflow (lead — mandatory)

1. Read `workbench.md` + this file + `runs/K3-LOCK.md` queue.
2. Pick **one** HARNESS_ONLY row from queue (or deepen weakest existing PASS row if critic named it).
3. **Builder:** deepen `tests/knight_qa_harness.gd` / `*_scenario.gd` / data — Bible base + `[+]` via shared sim path.
4. Run **MANDATORY_COMMANDS**.
5. Spawn **readonly `gauntlet-critic`**:
   - **Per-row** when promoting a single factory id (threshold **88** for row adequacy).
   - **Full matrix** when manifest count changes or every **5** ticks — threshold **95**.
6. **Manifest update:** only append row when critic returns `RESULT: PASS` for that `factory_id`; then set matrix row `PASS` in `KNIGHT_QA_GATE.md`.
7. **Score banner** first line (Rule 6b); update `workbench.md` ticker + `STOP_CONDITION_MET`.
8. Commit if files changed (`auto-commit-absolute.mdc`).

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | Machine bar **all true** + full-matrix critic `PASS` **≥ 95** + `Infrastructure: ADEQUATE` → set `knight-template.md` **LOCKED** → `workbench.md` `STOP_CONDITION_MET: yes` → full backup commit → **stop** |
| **Failure** | `MAX_ROUNDS_PER_PIECE` exhausted, or FORBIDDEN triggered → `docs/design/FAILURE_REPORT.md` → `STOP_CONDITION_MET: no` → stop |
| **Blocked** | Godot missing, critic subagent unavailable, auth — `BLOCKER:` one owner-only item → stop (no fake PASS) |
| **Not a stop** | Exit 2, score &lt; 95, 16 HARNESS_ONLY remaining — **continue** (`/loop` next tick) |

---

## HARNESS_ONLY queue (promotion order)

Skip no-regression rows unless deepening asserts **without** behavior change.

| Priority | Factory id | Notes |
|----------|------------|-------|
| 1 | `knight_phalanx_stance` | Base/`[+]` sim present — deepen + 7-phase if needed |
| 2 | `knight_seismic_stomp` | CRACKED terrain `[+]` |
| 3 | `knight_iron_grip` | AP refund `[+]` |
| 4 | `knight_indomitable_will` | Status `[+]` |
| 5 | `knight_defensive_formation` | ARMOR_UP `[+]` |
| 6 | `knight_taunting_strike` | PULL2 `[+]` |
| 7 | `knight_redirect_strike` | INTERCEPT `[+]` DEF |
| 8 | `kinetic_armor` | Mitigation pipeline |
| 9 | `kinetic_redirection` | PIERCE `[+]` stub → implement |
| 10 | `bulwark` | Trigger pipeline not stat read |
| 11 | `living_barricade` | Ally DEF `[+]` |
| 12 | `shield_wall` | Range-2 `[+]` |
| 13 | `rallying_presence` | MOV `[+]` |
| 14 | `intercept_tactics` | DEF `[+]` |
| — | `knight_bowling_charge` | **No-regression** — promote only via assert depth, no path changes |
| — | `knight_trampling_advance` | **No-regression** — same |

Also deepen **14 existing PASS** rows if full-matrix critic cites shallow asserts (e.g. `shield_mastery` 80 at promotion).

---

## Copy-paste: `/loop` start (local Agent)

```text
/loop 20m UNATTENDED GAUNTLET — knight-k3-lock

Read docs/design/UNATTENDED_RUN.md (ACTIVE K3-LOCK).
Read docs/design/runs/K3-LOCK.md.
Read docs/design/00-gauntlet-loop-cursor.md Rules 4, 5c, 6b, §5.4.
Read docs/design/workbench.md — continue from last round.

You are the LEAD. Do not ask the owner questions.

Each tick: one row from HARNESS_ONLY queue → builder → run_knight_qa_gate.ps1 → gauntlet-critic (per-row or full matrix) → score banner → workbench STOP_CONDITION_MET → commit.

FORBIDDEN: knight_bowling_charge / knight_trampling_advance regression; planning QA edits; self-grade manifest.

Stop only when STOP_ON success (30/30, gate exit 0, critic ≥95) or BLOCKER requiring owner.
```

---

## Copy-paste: critic handoff (full matrix)

```text
PIECE: K3-LOCK — Knight factory 30-row coverage matrix
GOAL: Every knight_factory.gd id PASS per KNIGHT_QA_GATE.md scenario contract; manifest-aligned; P6-cloneable
BAR: .\scripts\run_knight_qa_gate.ps1 (paste stdout); docs/KNIGHT_QA_GATE.md matrix; docs/knight_meta_critic_manifest.json
PASS_THRESHOLD: 95
RULES: skill-global-rules.mdc, global-systems-first.mdc, move-preview-intent-truth.mdc, qa-after-gameplay-changes.mdc
ARTIFACT: gate stdout, matrix summary line, manifest approved_rows count, git diff --stat for tests/ and core/
Judge: Rule A/B fidelity, per-row base/[+] asserts, no planning QA conflation, no-regression skills untouched.
Do not implement. SCORE/100 + PASS or FAIL + Infrastructure + largest gap + evidence.
```
