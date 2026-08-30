# Archer Bible Audit

Source: `class_abilities.txt`, Archer section (lines 795–871). The factory is
the data source; shared systems consume modifiers without Archer-specific ID
branches.

| Bible row | Data definition | Runtime owner | QA |
|---|---|---|---|
| Lightfoot | `lightfoot` | `MovementSystem.step_mp_cost`, `TerrainSystem` | Tier 1 + live |
| Overwatch | `overwatch` | `MovementSystem._resolve_zone_of_control` | contract + runtime |
| High Ground | `high_ground` | `AbilitySystem.can_use` and damage mitigation | contract |
| Patient Hunter | `patient_hunter` | `AbilitySystem` damage calculation | Tier 1 |
| True Sight | `true_sight` | `AbilitySystem.can_use` / cover mitigation | contract |
| Piercing Momentum | `piercing_momentum` | `AbilitySystem` long-shot damage | contract |
| Camouflage | `camouflage` | `AbilitySystem.execute` stealth application | contract |
| Area Denial | `area_denial` | `CREATE_HAZARD` payload + `TerrainSystem` | contract |
| Caltrop Expert | `caltrop_expert` | `AbilitySystem.get_action_point_cost` + terrain payload | contract |
| Zone Control | `zone_control` | `MovementSystem` enemy-entry reaction | Tier 1 |
| Sticky Mud | `sticky_mud` | terrain payload + movement/status stages | contract |
| Fletching Hoarder | `fletching_hoarder` | `MovementSystem` corpse crossing + attack | contract |
| Prey Sighted | `prey_sighted` | `AbilitySystem` target-condition damage | contract |
| Barrage | `barrage` | `CombatSystem` exact-lethal follow-up | contract |
| Target Painter | `target_painter` | `AbilitySystem` debuff-condition damage | contract |
| Rapid Fire | `rapid_fire` | `AbilitySystem.execute` post-attack MP | contract |
| Power Shot | `archer_power_shot` | modular damage + push collision payload | Tier 1 + live |
| Volley | `archer_volley` | modular square AOE + terrain payload | Tier 1 + live |
| Pinning Arrow | `archer_pinning_arrow` | modular damage + ROOT status | Tier 1 + live |
| Piercing Shot | `archer_piercing_shot` | modular LINE + PIERCE status | Tier 1 + live |
| Toxic Spore Arrow | `archer_toxic_spore_arrow` | modular damage/status spread | Tier 1 + live |
| Grapple Arrow | `archer_grapple_arrow` | shared PULL wall/enemy handling | Tier 1 + live |
| Explosive Arrow | `archer_explosive_arrow` | modular cross AOE + terrain destruction | Tier 1 + live |
| Hunter's Mark | `archer_hunters_mark` | modular MARK + shared marked-target rules | Tier 1 + live |
| Repelling Shot | `archer_repelling_shot` | shared ally/enemy targeting + PUSH | Tier 1 + live |
| Bear Trap | `archer_bear_trap` | hazard terrain entry payload | Tier 1 + live |
| Suppressing Fire | `archer_suppressing_fire` | ARC hazard crossing payload | Tier 1 + live |
| Caltrop Trap | `archer_caltrop_trap` | zero-AP hazard placement + entry payload | Tier 1 + live |
| Parting Shot | `archer_parting_shot` | damage plus shared MOVE layer | Tier 1 + live |
| Scout's Eye | `archer_scouts_eye` | PURGE plus VULNERABLE upgrade layer | Tier 1 + live |

Known limitation for the first verification pass: the headless and live
commands require the local Godot executable. They are recorded as required
gates and must pass before this slice is declared complete.
