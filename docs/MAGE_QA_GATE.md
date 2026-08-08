# Mage QA Gate

**Scope:** Class validation — Mage factory, 15 actives + Blink + 15 passives + innate (`class_abilities.txt` §7). **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Mage LOCK):** 100% matrix rows **PASS** + `run_mage_qa_gate.ps1` PASS + `run_mage_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

---

## Gate status (honest — 2026-08-08)

| Field | Value |
|-------|-------|
| **LOCK** | **NO** — **do not** treat `IMPLEMENTATION_STATUS.md` “Mage QA LOCK” as owner sign-off |
| **Summary** | **0 / 32** meta-critic `PASS` · **32** `HARNESS_ONLY` · **0** `PLANNED` |
| **Implementation** | Factory + sim paths largely complete |
| **QA depth** | `tests/mage_qa_gate.gd` factory/smoke; `tests/live_mage_class_test.gd` commit smoke — **no** per-skill scenarios, **no** AOE tile-footprint or overlay asserts |

**Previous docs marked “PASS” per row for headless/live smoke — relabeled `HARNESS_ONLY` here.**

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_mage_qa_gate.ps1` | **HARNESS_ONLY** |
| **2 — Live** | `.\scripts\run_mage_live_qa.ps1` → `tests/live_mage_class_test.gd` | **HARNESS_ONLY** |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required until matrix `PASS` |

---

## Meta-critic

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. Mage AOE skills (Fireball, Ice Shard STEAM, Meteor, Black Hole, etc.) require **tile-set** proof — not `upgraded_target_shape_size == 3` alone.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md).

---

## Coverage matrix (factory rows — all **HARNESS_ONLY** until `tests/skills/mage_*_scenario.gd` exist)

| Group | Factory IDs | Headless today | Live today | Target Tier 1 |
|-------|-------------|----------------|------------|---------------|
| Innate | `arcane_overchannel` | HARNESS_ONLY smoke | spell cast indirect | `tests/passives/arcane_overchannel_scenario.gd` |
| Reposition | `mage_blink` | HARNESS_ONLY | commit smoke | `tests/skills/mage_blink_scenario.gd` |
| Actives | `mage_fireball`, `mage_ice_shard`, `mage_chain_lightning`, `mage_arcane_push`, `mage_teleport`, `mage_meteor`, `mage_black_hole`, `mage_time_warp`, `mage_mana_shield`, `mage_disintegrate`, `mage_gravity_well`, `mage_elemental_surge`, `mage_earth_spike`, `mage_density_shift`, `mage_arcane_barrage` | HARNESS_ONLY | commit smoke | one scenario file each |
| Geomancer passives | `elementalist`, `feedback`, `elemental_master`, `lasting_terrain`, `surface_syphoner` | HARNESS_ONLY | — | per-passive scenario |
| Archmage passives | `mana_leak`, `arcane_overdrive`, `mana_well`, `mana_siphon`, `overload` | HARNESS_ONLY | — | per-passive scenario |
| Graviturge passives | `wild_magic`, `arcane_tether`, `arcane_mastery`, `arcane_attunement`, `gravity_anchor` | HARNESS_ONLY | — | per-passive scenario |

---

## Commands

```powershell
.\scripts\run_mage_qa_gate.ps1
.\scripts\run_mage_live_qa.ps1
```
