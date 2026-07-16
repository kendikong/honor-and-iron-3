---
name: roadmap
description: Development milestones, prototype success criteria, playtest philosophy, scope management, and the definition of a finished feature.
---

# Implementation Roadmap & Milestones

## Development Philosophy
The goal is not to build a complete game, but to discover whether the core gameplay loop is genuinely fun. Postpone everything else.
- Validate mechanics before expanding content.
- Never solve problems that may disappear after iteration.
- **Priority Order**: Core loop > Player decisions > Enemy puzzles > Roguelike progression > Content quantity > Visual polish.

## Current Milestones (Master Bible Rollout)

We are actively implementing the classes and systemic foundation as strictly defined by the **Master AI Bible** and **Class Abilities & Passives Document**.

### Phase 6: Core Math, Physics & Universal Systems
Implement universal collision, bounding boxes, damage calculation laws (Zero-RNG, Weaker Rounding), and basic keywords (`PIERCE`, `STURDY`).

### Phase 7: Status Effects & Terrain Hazards
Implement core logic for DoTs (`BURN`, `BLEED`, `POISON`), Stat Manipulations, Hard/Soft CC (`STUN`, `ROOT`, `TAUNT`, etc.), and surface terrain effects (`FIRE`, `WATER`, etc.).

### Phase 8: Advanced Keywords & Constructs
Implement movement keywords (`GHOST`, `TRAMPLE`, `AIRBORNE`, `CANTO`), defensive keywords (`STEALTH`, `INTERCEPT`), and the `SPAWN` system for constructs with Max HP scaling.

### Phase 9: The Knight
Implement the core data and engine gameplay hooks for the Knight class (Sentinel, Juggernaut, Cataphract).

### Phase 10: The Bruiser
Implement the core data and engine gameplay hooks for the Bruiser class (Bloodrager, Behemoth, Siegebreaker).

### Phase 11: The Cavalier (Lancer)
Implement the core data and engine gameplay hooks for the Cavalier class (Cavalier, Skystriker, Halberdier).

### Phase 12: The Mercenary
Implement the core data and engine gameplay hooks for the Mercenary class (Swordmaster, Blade Dancer, Headhunter).

### Phase 13: The Rogue
Implement the core data and engine gameplay hooks for the Rogue class (Assassin, Ninja, Saboteur).

### Phase 14: The Beast Rider
Implement the core data and engine gameplay hooks for the Beast Rider class (Griffin Rider, Wyvern Lord, Apex Predator).

### Phase 15: The Archer
Implement the core data and engine gameplay hooks for the Archer class.

### Phase 16: The Mage
Implement the core data and engine gameplay hooks for the Mage class.

### Phase 17: The Cleric
Implement the core data and engine gameplay hooks for the Cleric class.

### Phase 18: The Monk
Implement the core data and engine gameplay hooks for the Monk class.

### Phase 19: The Engineer
Implement the core data and engine gameplay hooks for the Engineer class.

### Phase 20: The Shaman
Implement the core data and engine gameplay hooks for the Shaman class.

### Phase 21: The Paladin
Implement the core data and engine gameplay hooks for the Paladin class.

## Scope & Playtest Philosophy
- **Feature Lifecycle**: Concept -> Prototype -> Playtest -> Iteration -> Production -> Polish. (Never polish before iteration).
- **Definition of "Finished"**: A feature is finished when it integrates cleanly with the architecture, is deterministic, previewable by the simulator, data-driven, has been playtested, and creates meaningful decisions.

## Class Implementation Execution Breakdown
For EACH REMAINING CLASS, the workflow must strictly follow this phased approach:
- **PHASE XA** - ADD SKILLS AND PASSIVES (Base level)
- **PHASE XAa** - AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE
- **PHASE XAb** - REDUNDANT AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE
- **PHASE XAc** - REDUNDANT AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE. ADDITIONAL AUDITS NEEDED UNTIL ONLY 2 OR LESS ITEMS ARE FOUND IN AUDIT.
- **PHASE XB** - ADD UPGRADES TO SKILLS AND PASSIVES AND ADD THE 3 ADVANCED PROMOTION CLASSES
- **PHASE XBa** - AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE
- **PHASE XBb** - REDUNDANT AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE
- **PHASE XBc** - REDUNDANT AUDIT CHECK TO CHECK 100% ADHERENCE TO CODE. ADDITIONAL AUDITS NEEDED UNTIL ONLY 2 OR LESS ITEMS ARE FOUND IN AUDIT.
