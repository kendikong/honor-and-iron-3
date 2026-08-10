# Mage QA Gate

**Scope:** Class validation — Mage factory, 15 actives + Blink + 15 passives + innate (`class_abilities.txt` §7). **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Mage LOCK):** 100% matrix rows **PASS** + `run_mage_qa_gate.ps1` PASS + `run_mage_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

**Owner QA sign-off:** **NOT PASS**

---

## Gate status (honest — 2026-08-09)

| Field | Value |
|-------|-------|
| **Owner sign-off** | **NOT PASS** |
| **LOCK** | **NO** |
| **Summary** | **32 / 32** meta-critic `PASS` · **0** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | `tests/mage_qa_gate.gd` factory matrix + active resolution + passive triggers + movement smoke + `tests/live_mage_class_test.gd` |
| **Manifest** | `docs/mage_meta_critic_manifest.json` |

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_mage_qa_gate.ps1` | **PASS** (automated) |
| **2 — Live** | `.\scripts\run_mage_live_qa.ps1` → `tests/live_mage_class_test.gd` | **PASS** (automated) |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required for feel until owner sign-off |

---

## Meta-critic

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. **Manifest:** `docs/mage_meta_critic_manifest.json`.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md).

---

## Coverage matrix (`mage_factory.gd`)

| Factory id | Type | Harness | Tier 1 | Notes |
|------------|------|---------|--------|-------|
| `arcane_overchannel` | Innate | `tests/mage_qa_gate.gd` | PASS | Overchannel spell scaling |
| `mage_blink` | Reposition | `tests/mage_qa_gate.gd` | PASS | TELEPORT + movement smoke |
| `mage_fireball` | Active | `tests/mage_qa_gate.gd` | PASS | AOE resolve |
| `mage_ice_shard` | Active | `tests/mage_qa_gate.gd` | PASS | STEAM / shard |
| `mage_chain_lightning` | Active | `tests/mage_qa_gate.gd` | PASS | Chain DAMAGE |
| `mage_arcane_push` | Active | `tests/mage_qa_gate.gd` | PASS | PUSH |
| `mage_teleport` | Active | `tests/mage_qa_gate.gd` | PASS | TELEPORT |
| `mage_meteor` | Active | `tests/mage_qa_gate.gd` | PASS | AOE meteor |
| `mage_black_hole` | Active | `tests/mage_qa_gate.gd` | PASS | Pull well |
| `mage_time_warp` | Active | `tests/mage_qa_gate.gd` | PASS | Timeline modifier |
| `mage_mana_shield` | Active | `tests/mage_qa_gate.gd` | PASS | SHIELD |
| `mage_disintegrate` | Active | `tests/mage_qa_gate.gd` | PASS | Execute threshold |
| `mage_gravity_well` | Active | `tests/mage_qa_gate.gd` | PASS | Gravity AOE |
| `mage_elemental_surge` | Active | `tests/mage_qa_gate.gd` | PASS | Surge buff |
| `mage_earth_spike` | Active | `tests/mage_qa_gate.gd` | PASS | Spike hazard |
| `mage_density_shift` | Active | `tests/mage_qa_gate.gd` | PASS | Density terrain |
| `mage_arcane_barrage` | Active | `tests/mage_qa_gate.gd` | PASS | Multi-hit |
| `elementalist` | Passive | `tests/mage_qa_gate.gd` | PASS | Element synergy |
| `feedback` | Passive | `tests/mage_qa_gate.gd` | PASS | Shield feedback |
| `elemental_master` | Passive | `tests/mage_qa_gate.gd` | PASS | Element mastery |
| `lasting_terrain` | Passive | `tests/mage_qa_gate.gd` | PASS | Terrain duration |
| `surface_syphoner` | Passive | `tests/mage_qa_gate.gd` | PASS | Surface drain |
| `mana_leak` | Passive | `tests/mage_qa_gate.gd` | PASS | Mana leak |
| `arcane_overdrive` | Passive | `tests/mage_qa_gate.gd` | PASS | HP trade MAG |
| `mana_well` | Passive | `tests/mage_qa_gate.gd` | PASS | Mana regen |
| `mana_siphon` | Passive | `tests/mage_qa_gate.gd` | PASS | Siphon |
| `overload` | Passive | `tests/mage_qa_gate.gd` | PASS | Overload tick |
| `wild_magic` | Passive | `tests/mage_qa_gate.gd` | PASS | Wild proc |
| `arcane_tether` | Passive | `tests/mage_qa_gate.gd` | PASS | Tether link |
| `arcane_mastery` | Passive | `tests/mage_qa_gate.gd` | PASS | Mastery radius |
| `arcane_attunement` | Passive | `tests/mage_qa_gate.gd` | PASS | Attunement |
| `gravity_anchor` | Passive | `tests/mage_qa_gate.gd` | PASS | Anchor ROOT |

---

## Commands

```powershell
.\scripts\run_mage_qa_gate.ps1
.\scripts\run_mage_live_qa.ps1
```
