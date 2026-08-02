# Unattended Gauntlet Run — B6-REOPEN (ACTIVE)

**Status:** **ACTIVE** — B6-LOCK revoked; per-row critic restart  
**Prior run:** B6-LOCK **REVOKED** — see [`runs/B6-LOCK.md`](runs/B6-LOCK.md) (historical)  
**Run card:** [`runs/B6-REOPEN.md`](runs/B6-REOPEN.md)  
**Spec:** [`00-gauntlet-loop-cursor.md`](00-gauntlet-loop-cursor.md) §5.4 · **Progress:** [`workbench.md`](workbench.md)  
**Template for future runs:** [`UNATTENDED_RUN.template.md`](UNATTENDED_RUN.template.md)

The lead agent must **not** ask the owner questions during this run. It stops only when **STOP_ON** is satisfied or a **boundary** fires.

---

## Run identity

| Field | Value |
|-------|-------|
| **CHUNK_ID** | `bruiser-b6-reopen-2026-08-02` |
| **PIECE_ID** | `B6-REOPEN` (31-row Bruiser matrix — per-row critic) |
| **GOAL** | Re-earn **`LOCKED`**: every factory row meta-critic `PASS` (Bible base + `[+]`), matrix 31/31, gate exit **0**, full-matrix critic **≥ 95** |
| **PASS_THRESHOLD** | **88** per row · **95** full matrix |
| **BAR** | See **Machine bar** below |
| **Started (UTC)** | 2026-08-02 |
| **Godot** | `C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe` |

### Machine bar (all must be true to claim STOP_ON success)

1. `.\scripts\run_bruiser_qa_gate.ps1` → exit **0** (31/31 matrix `PASS` + Tier 1 harness green + manifest aligned)
2. `docs/BRUISER_QA_GATE.md` summary line matches **31 / 31** meta-critic `PASS`
3. `docs/bruiser_meta_critic_manifest.json` — **31** `approved_rows`; no matrix `PASS` without manifest entry
4. Fresh **`gauntlet-critic`** on **full matrix** returns `RESULT: PASS`, `SCORE ≥ 95`, `Infrastructure: ADEQUATE`
5. `docs/design/bruiser-template.md` status → **`LOCKED`**

### Current baseline (do not regress)

| Metric | Value |
|--------|-------|
| Matrix PASS | **27 / 31** |
| HARNESS_ONLY | **4** (deepened; await fresh critic) |
| Manifest approved | **27** rows |
| Remaining | blood_for_blood, momentum_transfer, battering_ram, unstoppable_force |
| Tier 1 harness | must stay **PASS** |
| Cloud handoff | [`LOCAL_CLOUD_SYNC.md`](LOCAL_CLOUD_SYNC.md) · [`prompts/B6-REOPEN-CLOUD.md`](prompts/B6-REOPEN-CLOUD.md) |

---

## Boundaries (safety — not the primary stop condition)

| Boundary | Value |
|----------|-------|
| **MAX_ROUNDS_PER_PIECE** | `40` |
| **MAX_SUBPIECE_ROUNDS** | `4` *(per matrix row — then pick next HARNESS_ONLY)* |
| **MAX_WALL_CLOCK** | `24h` *(optional owner stop)* |
| **ROWS_PER_TICK** | `1` |

---

## Scope lock

### ALLOWED_PATHS

```
core/systems/**
core/factory/**
core/simulation/**
data/**
tests/bruiser_qa_harness.gd
tests/bruiser_qa_harness_scenarios.gd
tests/bruiser_qa_harness_upgrades.gd
tests/bruiser_qa_runner.gd
tests/bruiser_scenario_registry.gd
tests/skills/bruiser_*
tests/passives/cellular_regeneration_scenario.gd
tests/passives/blood_for_blood_scenario.gd
tests/passives/adrenaline_junkie_scenario.gd
tests/passives/enraged_scenario.gd
tests/passives/last_stand_scenario.gd
tests/passives/colossal_mass_scenario.gd
tests/passives/overwhelming_bulk_scenario.gd
tests/passives/thrill_of_pain_scenario.gd
tests/passives/momentum_of_titan_scenario.gd
tests/passives/scar_tissue_scenario.gd
tests/passives/momentum_transfer_scenario.gd
tests/passives/crowd_breaker_scenario.gd
tests/passives/juggernaut_scenario.gd
tests/passives/battering_ram_scenario.gd
tests/passives/unstoppable_force_scenario.gd
tests/run_bruiser_scenarios_only.gd
tests/BruiserQaGate.tscn
docs/BRUISER_QA_GATE.md
docs/bruiser_meta_critic_manifest.json
docs/design/bruiser-template.md
docs/design/workbench.md
docs/design/runs/B6-REOPEN.md
scripts/run_bruiser_qa_gate.ps1
```

### FORBIDDEN (hard stop — write `docs/design/FAILURE_REPORT.md` and exit)

| Rule | Detail |
|------|--------|
| Knight regression | Do not weaken `knight_*` scenarios, manifest, or `run_knight_qa_gate.ps1` |
| Planning QA edits | Do not change `live_planning_scene_test.gd` / `run_planning_qa_gate.ps1` for Bruiser coverage |
| Self-grade manifest | Matrix `PASS` only after gauntlet-critic row approval |
| Global bypass | No per-skill `if ability.id` without owner ⚠ exception |

---

## MANDATORY_COMMANDS

| Order | Command | When |
|-------|---------|------|
| 1 | `.\scripts\run_bruiser_qa_gate.ps1` | Every tick after builder work |
| 2 | Spawn `gauntlet-critic` subagent | After BAR run; never self-grade |

---

## STOP_ON

| Condition | Action |
|-----------|--------|
| **Success** | All machine bar checks + critic ≥ 95 → `bruiser-template.md` LOCKED → commit → workbench `STOP_CONDITION_MET: yes` → stop |
| **Failure** | MAX_ROUNDS → `FAILURE_REPORT.md` → stop |
| **Blocked** | Godot missing → `BLOCKER:` → stop |

---

## Copy-paste: `/loop` prompt (Honor & Iron)

```text
UNATTENDED GAUNTLET — honor-and-iron-3 — B6-REOPEN

Read and obey docs/design/UNATTENDED_RUN.md (ACTIVE B6-REOPEN).
Read docs/design/runs/B6-REOPEN.md.
Read docs/design/00-gauntlet-loop-cursor.md Rules 4, 5c, 6b, §5.4.
Read docs/design/workbench.md — continue from last round.

You are the LEAD. Do not ask the owner questions.

Each tick:
1. Fix largest gap within ALLOWED_PATHS (1 HARNESS_ONLY row)
2. Run .\scripts\run_bruiser_qa_gate.ps1
3. Spawn separate readonly gauntlet-critic subagent on THAT ROW (never self-grade)
4. On row critic PASS ≥88: manifest + matrix PASS for that row only
5. First line = score banner; update workbench.md; commit

Stop only when STOP_ON in UNATTENDED_RUN.md is satisfied, or write BLOCKER: <one owner-only item>.

FORBIDDEN: knight regression; planning QA edits; self-grade manifest; matrix PASS without critic.
```
