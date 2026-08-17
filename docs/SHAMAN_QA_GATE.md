# Shaman QA Gate

This gate validates the Shaman class against `class_abilities.txt` and
`docs/CLASS_QA_BIBLE.md`. It is a class gate, not a replacement for planning QA.

## Global systems fidelity

- **Rules A/B:** skills are authored as `AbilityModule` data and resolved through
  `AbilitySystem` → `Simulator`; no Shaman skill branches on ability IDs.
- **Layer A:** factory rows, module profiles, costs, targeting, upgrades, and
  promotion stat packages are checked by `ShamanQaHarness`.
- **Layer B:** every active row has a dedicated scenario that resolves through
  `Simulator`; shaped Bone Spear also checks its exact line footprint.
- **Layer C:** `run_shaman_live_qa.ps1` exercises the TestBattle preview/commit
  path for every Shaman ability.

## Tier status

| Tier | Runner | Required result |
|---|---|---|
| 1 | `scripts/run_shaman_qa_gate.ps1` | PASS |
| 2 | `scripts/run_shaman_live_qa.ps1` | PASS |
| 3 | Owner visual/manual review | Pending owner |

The Tier 1 gate also runs the typed conversion bar before gameplay scenarios:
`run_extra_rules_conversion_contract.gd`,
`run_class_library_schema_typed_fields_test.gd`, and
`run_ability_module_bridge_test.gd` must all exit successfully.

## Coverage matrix

| Factory row | Bible proof | Scenario | Status |
|---|---|---|---|
| `hexing_presence` | innate aura: STR/MAG/DEF, no SHIELD, upgrade range/MOV | `tests/passives/hexing_presence_scenario.gd` | PASS |
| `echoing_spirits` | Spirit Caller: double pulse and MAG/HP upgrade | `tests/passives/echoing_spirits_scenario.gd` | PASS |
| `spiritual_offering` | Spirit Caller: summon/HP SHIELD | `tests/passives/spiritual_offering_scenario.gd` | PASS |
| `spiritual_guardian` | Spirit Caller: adjacent DEF aura | `tests/passives/spiritual_guardian_scenario.gd` | PASS |
| `miasma_resonance` | Spirit Caller: DoT bonus and MOV penalty | `tests/passives/miasma_resonance_scenario.gd` | PASS |
| `voodoo_conduit` | Spirit Caller: Totem/Link/Debuff range/AOE | `tests/passives/voodoo_conduit_scenario.gd` | PASS |
| `voodoo_doll` | Bloodweaver: hit retaliation | `tests/passives/voodoo_doll_scenario.gd` | PASS |
| `spirit_link` | Bloodweaver: linked hit damage | `tests/passives/spirit_link_scenario.gd` | PASS |
| `pain_sharing` | Bloodweaver: linked damage bonus | `tests/passives/pain_sharing_scenario.gd` | PASS |
| `sympathetic_magic` | Bloodweaver: linked healing/MAG | `tests/passives/sympathetic_magic_scenario.gd` | PASS |
| `chain_reaction` | Bloodweaver: Linked Ripple PUSH propagation | `tests/passives/chain_reaction_scenario.gd` | PASS |
| `soul_collector` | Soulwalker: kill orbs and cap | `tests/passives/soul_collector_scenario.gd` | PASS |
| `hexing_touch` | Soulwalker: melee attacker permanent debuffs | `tests/passives/hexing_touch_scenario.gd` | PASS |
| `ritual_sacrifice` | Soulwalker: HP-for-AP skill economy | `tests/passives/ritual_sacrifice_scenario.gd` | PASS |
| `soul_burn` | Soulwalker: debuffed target damage/MOV | `tests/passives/soul_burn_scenario.gd` | PASS |
| `soul_weaver` | Soulwalker: debuff transfer on heal | `tests/passives/soul_weaver_scenario.gd` | PASS |
| `shaman_usher` | MP 2 ally reposition, upgrade Totem movement | `tests/skills/shaman_usher_scenario.gd` | PASS |
| `shaman_curse_of_weakness` | WEAKEN, STR/DEF reduction, Push Mitigation | `tests/skills/shaman_curse_of_weakness_scenario.gd` | PASS |
| `shaman_healing_totem` | Totem AOE 2 HEAL 1 pulse, CLEANSE upgrade | `tests/skills/shaman_healing_totem_scenario.gd` | PASS |
| `shaman_flame_totem` | Totem AOE 2 MAG ATK pulse and FIRE | `tests/skills/shaman_flame_totem_scenario.gd` | PASS |
| `shaman_bloodlust` | ally STR/DEF/MOV/HP economy and BLEED upgrade | `tests/skills/shaman_bloodlust_scenario.gd` | PASS |
| `shaman_hex` | WITHER missing-HP rule and Boss fallback | `tests/skills/shaman_hex_scenario.gd` | PASS |
| `shaman_voodoo_link` | two-enemy shared WPN damage and PUSH upgrade | `tests/skills/shaman_voodoo_link_scenario.gd` | PASS |
| `shaman_terrify` | debuffed FEAR and Boss fallback | `tests/skills/shaman_terrify_scenario.gd` | PASS |
| `shaman_miasma` | MAG ATK/POISON and spread upgrade | `tests/skills/shaman_miasma_scenario.gd` | PASS |
| `shaman_bone_spear` | SKEWER 4 ATK 2 and barricade | `tests/skills/shaman_bone_spear_scenario.gd` | PASS |
| `shaman_ancestral_spirit` | 1-HP Ghost Ally corpse summon | `tests/skills/shaman_ancestral_spirit_scenario.gd` | PASS |
| `shaman_totem_guard` | ranged reduction and melee DEF upgrade | `tests/skills/shaman_totem_guard_scenario.gd` | PASS |
| `shaman_sympathetic_bond` | ally/enemy bond and reciprocal effects | `tests/skills/shaman_sympathetic_bond_scenario.gd` | PASS |
| `shaman_earthbind_totem` | AOE 2 ROOT pulse and WEAKEN upgrade | `tests/skills/shaman_earthbind_totem_scenario.gd` | PASS |
| `shaman_soul_siphon` | debuff-scaled MAG ATK and HEAL upgrade | `tests/skills/shaman_soul_siphon_scenario.gd` | PASS |
| `shaman_pain_spike` | linked-target MAG ATK and BLIND upgrade | `tests/skills/shaman_pain_spike_scenario.gd` | PASS |

## Meta-critic contract

Every row has a named Bible clause, a dedicated source file, and a factory
modifier/module assertion. Rows remain PASS only while both Tier 1 and Tier 2
are green; a green data-only assertion cannot promote a row by itself.
