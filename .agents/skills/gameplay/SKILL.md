---
name: gameplay
description: Gameplay design rules, turn structure, combat logic, timeline programming, player classes, element interactions, terrain, and roguelike progression for Honor & Iron.
---

# Gameplay Systems & Combat Design

## Turn Structure
- **Planning Phase**: Unlimited time. Players collaboratively move units, schedule abilities, reorder/cancel actions, and preview outcomes. In co-op, planning is concurrent: both players edit the same shared planning timeline, send visual pings, and draw strategies. No resources are consumed, and unlimited undo/redo is available.
- **Co-op Ready Check**: The Planning Phase only transitions to the Execution Phase when all connected players confirm they are ready. Individual ready toggles are visible to all players.
- **Execution Phase**: Planning UI locks, the timeline is locked, simulation runs, and visual animations play. No player input is accepted during this phase.

## Action Timeline
The timeline is the central hub of actions.
- Every action exists as an ordered entry.
- Players can freely insert, remove, reorder, swap, or duplicate action previews before execution.
- Action entries display which player scheduled them (via color/icon badges).

## Action Economy
- **Movement Points (MP)**: Used only for movement.
- **Action Points (AP)**: Used only for abilities.
- Units can alternate between movement and actions in any order (e.g. Move -> Attack -> Move).

## Ghost Preview System
- **Mandatory Preview**: Any timeline change must trigger a live local simulation that calculates future positions, facing, terrain, status, and predicted collisions.
- The UI must display these ghost previews immediately for all players so the shared outcome is clear before execution.
- Teammate cursor coordinates, selections, and target previews are rendered in real-time using distinctive player colors.

## Enemy Intent System
- Every enemy broadcasts: Destination, target, attack area, execution order, predicted damage, displacement, and status effects.

## Combat Systems & Mechanics
- **Player Classes**: Each class must have a distinct movement type, weapon type, core passive, unique positioning tools, and a distinct upgrade pool.
- **Reactions**: Deterministic opportunity attacks, counter attacks, projectile intercepts, or ally protection that reward positioning without requiring player input.
- **Positioning Assists**: Swap, reposition, draw back, shove, pull, rotate, launch.
- **Terrain System**: Terrain permanently affects combat (Forest blocks movement, Ice causes sliding, Fire deals damage, Water conducts electricity, Mud slows movement, Wall stops displacement).
- **Surface Chemistry**: Elements interact dynamically (e.g. Water + Ice = Sliding surface; Water + Lightning = Electrified area; Poison + Fire = Explosion; Oil + Fire = Persistent flames).
- **Chain Reactions**: Combine displacement, elements, terrain, and reactions to trigger complex deterministic outcomes.

## Progression & Build Philosophy
- **Progression**: Encounters reward new abilities, passives, relics, or class upgrades.
- **Build Archetypes**: Support distinct build strategies like displacement, reactions, terrain manipulation, support, summons, and timeline manipulation.

## Skill Implementation (Global Rules First)
- **Default**: Every skill uses shared global rules — `AbilityKind`, AP/MP costs, timeline columns, `EffectData` types, targeting modes, `AbilitySystem` / `Simulator` paths, and preview parity. No per-skill `if ability.id == …` branches unless the Master Bible explicitly requires it.
- **New rule required?** If a skill cannot be implemented without a new global rule, timeline exception, or one-off code path, **stop and warn the project owner first**: describe what conflicts, what rule you propose, and ask if it is acceptable. Do not implement silent exceptions.
- **Authoritative source**: `class_abilities.txt` § Skill & Passive Design Criteria — "Global Rules First (Skill Implementation Mandate)".
