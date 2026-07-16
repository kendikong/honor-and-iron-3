---
name: identity
description: Rules and guidelines about the Honor & Iron core design constitution, pillars, mission statement, game inspirations, and overall design philosophy.
---

# Project Identity & Design Constitution

Honor & Iron is not a Fire Emblem clone, nor is it Into the Breach or Slay the Spire. It is a deterministic cooperative tactical roguelike where players collaboratively manipulate future board states to solve spatial combat puzzles. When making design decisions, optimize for that identity—not for similarity to its inspirations.

## Mission Statement
- Deterministic cooperative tactical roguelike built around collaborative puzzle solving rather than probability management.
- Players should feel like battlefield tacticians programming an elaborate chain reaction rather than gamblers hoping for favorable outcomes.
- Every encounter should present a deterministic puzzle with multiple valid solutions.
- Every run should gradually expand the player's toolbox until increasingly complex interactions become possible.
- Co-op communication is non-verbal first. The game must support rich planning signals (pings, paths, intent sharing) to enable seamless co-op without requiring voice chat.

### Inspirations
- Deterministic combat from Into the Breach
- Timeline programming from Breach Wizards
- Positioning mechanics from Fire Emblem Heroes
- Build variety from Slay the Spire
- Puzzle bosses from Mewgenics
- Environmental interactions from Baldur's Gate 3

## Core Gameplay Loop
1. Observe enemy intentions (destinations, targets, order, damage, etc.).
2. Discuss strategy with teammates.
3. Program a shared action timeline.
4. Preview resulting future board state live.
5. Modify timeline actions until satisfied.
6. Execute timeline and watch deterministic chain reactions.
7. Receive progression rewards.
8. Repeat.

## Design Philosophy
The game is fundamentally about solving spatial puzzles.
- **The game rewards**: Planning, positioning, cooperation, sequencing, environmental manipulation, enemy manipulation, and creative problem solving.
- **The game avoids**: Randomness, hidden information, unavoidable damage, stat checking, repetitive optimization, and passive waiting.

## Non-Negotiable Design Principles
- **Deterministic Combat**: No RNG exists during combat (no hit/dodge chance, critical hits, random damage, or random status effects). If an attack deals 5 damage or shoves 2 tiles, it always does exactly that.
- **Perfect Information**: Enemy intentions are always public (destination, target, attack, execution order, predicted effects). No uncertainty.
- **Board State > HP**: Damage is only one method of solving encounters. Positioning is equally valuable (e.g. shoving enemies into each other, redirecting attacks, delaying actions, blocking movement, exploiting terrain).
- **Weaknesses Alter the Puzzle**: Weaknesses are not primarily damage multipliers. Breaking a weakness should alter the board state (e.g. cancel attack, remove shove immunity, interrupt spell, delay initiative, crash flying enemy).
- **Enemies Create Puzzles**: Variety comes from movement patterns, attack geometry, support abilities, formation behavior, and timeline interactions—not from inflated stats.
- **Cooperative Symbiosis**: Cooperative design is central. Mechanics must emphasize cross-player synergies (e.g. pushing a teammate out of danger, placing elements for a partner to detonate, combining attacks in the same tile).

## AI Decision Framework
Whenever adding a mechanic, ask:
1. Does it improve positioning?
2. Does it create interesting timeline decisions?
3. Does it interact with other mechanics?
4. Does it encourage teamwork?
5. Does it create new chain reactions?
6. Does it change the board state?
7. Does it increase build diversity?
*If fewer than three answers are YES, the mechanic does not belong.*
