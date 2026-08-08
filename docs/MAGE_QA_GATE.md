# Mage QA Gate

This gate validates the Mage factory, shared simulation systems, and live planning
intent. The Bible source is `class_abilities.txt` §7.

## Required factory rows

| Group | Factory IDs | Headless | Live |
|---|---|---:|---:|
| Innate | `arcane_overchannel` | PASS | Triggered through spell casts |
| Reposition | `mage_blink` | PASS | Preview, commit, teleport |
| Geomancer / Archmage active | `mage_fireball` | PASS | Damage + FIRE terrain |
| Geomancer / Graviturge active | `mage_ice_shard` | PASS | Damage + movement debuff + FROZEN |
| Geomancer / Graviturge active | `mage_chain_lightning` | PASS | Primary + bounce data |
| Graviturge / Geomancer active | `mage_arcane_push` | PASS | Damage + PUSH |
| Graviturge / Archmage active | `mage_teleport` | PASS | Preview, commit, teleport |
| Archmage active | `mage_meteor` | PASS | Delayed-effect queue |
| Graviturge / Geomancer active | `mage_black_hole` | PASS | PULL |
| Archmage / Graviturge active | `mage_time_warp` | PASS | Self-cost + ally AP |
| Archmage active | `mage_mana_shield` | PASS | MAG-to-SHIELD |
| Archmage active | `mage_disintegrate` | PASS | Damage + corpse marker |
| Graviturge active | `mage_gravity_well` | PASS | ROOT |
| Geomancer / Archmage active | `mage_elemental_surge` | PASS | Next-spell modifiers |
| Geomancer active | `mage_earth_spike` | PASS | Obsidian Wall spawn |
| Graviturge active | `mage_density_shift` | PASS | STURDY / WEAKEN data |
| Archmage active | `mage_arcane_barrage` | PASS | Three-hit data |
| Geomancer passives | `elementalist`, `feedback`, `elemental_master`, `lasting_terrain`, `surface_syphoner` | PASS | Trigger smoke |
| Archmage passives | `mana_leak`, `arcane_overdrive`, `mana_well`, `mana_siphon`, `overload` | PASS | Modifier and trigger smoke |
| Graviturge passives | `wild_magic`, `arcane_tether`, `arcane_mastery`, `arcane_attunement`, `gravity_anchor` | PASS | Modifier and trigger smoke |

The two runner scripts are:

- `scripts/run_mage_qa_gate.ps1`
- `scripts/run_mage_live_qa.ps1`

The live suite is `tests/live_mage_class_test.gd`; it uses `TestBattle.tscn`,
the shared commit-slot builder, `CombatDirector.commit_from_slots`, and
`Simulator.simulate`.
