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

| Factory id | Type | Scenario file | Tier 1 | Notes |
|------------|------|---------------|--------|-------|
| `arcane_overchannel` | Innate | `tests/passives/arcane_overchannel_scenario.gd` | PASS | Overchannel innate |
| `mage_blink` | Reposition | `tests/skills/mage_blink_scenario.gd` | PASS | TELEPORT + movement smoke |
| `mage_fireball` | Active | `tests/skills/mage_fireball_scenario.gd` | PASS | AOE resolve |
| `mage_ice_shard` | Active | `tests/skills/mage_ice_shard_scenario.gd` | PASS | STEAM / shard |
| `mage_chain_lightning` | Active | `tests/skills/mage_chain_lightning_scenario.gd` | PASS | Chain DAMAGE |
| `mage_arcane_push` | Active | `tests/skills/mage_arcane_push_scenario.gd` | PASS | PUSH |
| `mage_teleport` | Active | `tests/skills/mage_teleport_scenario.gd` | PASS | TELEPORT |
| `mage_meteor` | Active | `tests/skills/mage_meteor_scenario.gd` | PASS | AOE meteor |
| `mage_black_hole` | Active | `tests/skills/mage_black_hole_scenario.gd` | PASS | Pull well |
| `mage_time_warp` | Active | `tests/skills/mage_time_warp_scenario.gd` | PASS | Timeline modifier |
| `mage_mana_shield` | Active | `tests/skills/mage_mana_shield_scenario.gd` | PASS | SHIELD |
| `mage_disintegrate` | Active | `tests/skills/mage_disintegrate_scenario.gd` | PASS | Execute threshold |
| `mage_gravity_well` | Active | `tests/skills/mage_gravity_well_scenario.gd` | PASS | Gravity AOE |
| `mage_elemental_surge` | Active | `tests/skills/mage_elemental_surge_scenario.gd` | PASS | Surge buff |
| `mage_earth_spike` | Active | `tests/skills/mage_earth_spike_scenario.gd` | PASS | Spike hazard |
| `mage_density_shift` | Active | `tests/skills/mage_density_shift_scenario.gd` | PASS | Density terrain |
| `mage_arcane_barrage` | Active | `tests/skills/mage_arcane_barrage_scenario.gd` | PASS | Multi-hit |
| `elementalist` | Passive | `tests/passives/elementalist_scenario.gd` | PASS | Element synergy |
| `feedback` | Passive | `tests/passives/feedback_scenario.gd` | PASS | Shield feedback |
| `elemental_master` | Passive | `tests/passives/elemental_master_scenario.gd` | PASS | Element mastery |
| `lasting_terrain` | Passive | `tests/passives/lasting_terrain_scenario.gd` | PASS | Terrain duration |
| `surface_syphoner` | Passive | `tests/passives/surface_syphoner_scenario.gd` | PASS | Surface drain |
| `mana_leak` | Passive | `tests/passives/mana_leak_scenario.gd` | PASS | Mana leak |
| `arcane_overdrive` | Passive | `tests/passives/arcane_overdrive_scenario.gd` | PASS | HP trade MAG |
| `mana_well` | Passive | `tests/passives/mana_well_scenario.gd` | PASS | Mana regen |
| `mana_siphon` | Passive | `tests/passives/mana_siphon_scenario.gd` | PASS | Siphon |
| `overload` | Passive | `tests/passives/overload_scenario.gd` | PASS | Overload tick |
| `wild_magic` | Passive | `tests/passives/wild_magic_scenario.gd` | PASS | Wild proc |
| `arcane_tether` | Passive | `tests/passives/arcane_tether_scenario.gd` | PASS | Tether link |
| `arcane_mastery` | Passive | `tests/passives/arcane_mastery_scenario.gd` | PASS | Mastery radius |
| `arcane_attunement` | Passive | `tests/passives/arcane_attunement_scenario.gd` | PASS | Attunement |
| `gravity_anchor` | Passive | `tests/passives/gravity_anchor_scenario.gd` | PASS | Anchor ROOT |

Registry: `tests/mage_scenario_registry.gd` (32 per-row scenario files).

---

## Commands

```powershell
.\scripts\run_mage_qa_gate.ps1
.\scripts\run_mage_live_qa.ps1
```
