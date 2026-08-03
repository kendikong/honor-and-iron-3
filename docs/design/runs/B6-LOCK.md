# Gauntlet run card — B6-LOCK

**Parent:** [`../UNATTENDED_RUN.md`](../UNATTENDED_RUN.md) (ACTIVE)  
**Pillar:** [`../bruiser-template.md`](../bruiser-template.md)  
**Matrix:** [`../../BRUISER_QA_GATE.md`](../../BRUISER_QA_GATE.md)  
**Manifest:** [`../../bruiser_meta_critic_manifest.json`](../../bruiser_meta_critic_manifest.json)  
**P3 clone:** [`../knight-template.md`](../knight-template.md) · [`../../KNIGHT_QA_GATE.md`](../../KNIGHT_QA_GATE.md)

---

## One-line goal

**LOCK the Bruiser template** — 31/31 factory rows meta-critic approved, `run_bruiser_qa_gate.ps1` exit 0, full-matrix gauntlet-critic **≥ 95**.

---

## Start the loop (owner)

1. Confirm Godot path in `UNATTENDED_RUN.md` works on this PC.
2. Open **Agent** (Composer 2.5) in this repo.
3. Paste and send:

```text
/loop 20m UNATTENDED GAUNTLET — bruiser-b6-lock

Read docs/design/UNATTENDED_RUN.md (ACTIVE B6-LOCK).
Read docs/design/runs/B6-LOCK.md.
Read docs/design/00-gauntlet-loop-cursor.md Rules 4, 5c, 6b, §5.4.
Read docs/design/workbench.md — continue from last round.

You are the LEAD. Do not ask the owner questions.

Each tick: one PLANNED row → builder → run_bruiser_qa_gate.ps1 → gauntlet-critic → score banner → workbench STOP_CONDITION_MET → commit.

FORBIDDEN: knight regression; planning QA edits; self-grade manifest.

Stop only when STOP_ON success (31/31, gate exit 0, critic ≥95) or BLOCKER requiring owner.
```

4. Leave Cursor open; PC awake.
5. Morning: check `workbench.md` **Score ticker** and `STOP_CONDITION_MET`.

---

## What “done” looks like

| Check | Target |
|-------|--------|
| `run_bruiser_qa_gate.ps1` | Exit **0**, stdout `[PASS] Bruiser QA gate` |
| Matrix | `31 / 31` PASS in `BRUISER_QA_GATE.md` |
| Manifest | 31 `approved_rows` in `bruiser_meta_critic_manifest.json` |
| Critic | Full-matrix `RESULT: PASS`, `SCORE ≥ 95`, `Infrastructure: ADEQUATE` |
| Template | `bruiser-template.md` status **`LOCKED`** |
| Workbench | `STOP_CONDITION_MET: yes` |

---

## Recommended build order (lead)

| Wave | Rows | Rationale |
|------|------|-----------|
| 1 | `bruiser_push_through`, `bruiser_suplex`, `bruiser_concussion_blow` | Movement + Rule B anchors (THROW_BEHIND ≠ SWAP) |
| 2 | `bruiser_charge_strike`, `bruiser_violent_collision`, `bruiser_breaching_dash` | DASH / collision pipeline |
| 3 | `momentum_of_titan`, `battering_ram`, `momentum_transfer` | PUSH passive cluster |
| 4 | Remaining actives | AOE, self-cost, ally SWAP |
| 5 | Remaining passives | Turn-start, on-damage, scaling |

---

## Tick strategy

Same flow as [`K3-LOCK.md`](K3-LOCK.md) — pick PLANNED row → scenario + sim asserts → per-row critic ≥ 88 → manifest → periodic full-matrix critic ≥ 95.

---

## Prior run

**K3-LOCK** closed owner 2026-08-02 — Knight template **LOCKED**. Do not regress Knight gate or scenarios.
