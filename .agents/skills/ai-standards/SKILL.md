---
name: ai-standards
description: GDScript standards, naming conventions, scene/node references, component philosophy, error handling, refactoring policy, and documentation requirements.
---

# AI Development Rules & Coding Standards

## Core Engineering Principles
- **Systems > Features**: Favor generalized, data-driven frameworks over specialized scripts for each individual ability or enemy.
- **Pre-Implementation Checklist**:
  1. Does this system already exist? (If yes, extend it; do not duplicate it).
  2. Can this become data? (Prefer Resources over code).
  3. Can this mechanic be previewed by the simulator? (If not, redesign it).
  4. Can multiplayer remain deterministic?
  5. Can another ability/unit reuse this logic? (If yes, generalize it).
  6. **Global rules first (skills)**: Does this skill fit existing economy, targeting, effects, and timeline rules? If not, **warn the project owner and get acceptance** before adding a new global rule or per-skill exception (see `class_abilities.txt` § Global Rules First).

## GDScript Standards
- **Static Typing**: Always use static typing and explicit return types (e.g. `func deal_damage(target: Unit, amount: int) -> void:`). Avoid dynamic typing.
- **Enums & Consts**: Use enums over strings, and constants over magic numbers.
- **Scene Standards**: Every scene must have one responsibility (e.g. `KnightVisual`, `EnemyHealthBar`, `TimelinePanel`).
- **Node References**: Avoid deep scene traversal (e.g. `get_parent().get_parent()`). Use signals, dependency injection, or manager references.
- **Managers**: Coordinate systems and emit events. They do not own visual objects, play sounds, or instantiate particles directly.

## Object & Component Philosophy
- **Component Composition**: Units and game entities must be assembled from small, independent capabilities/components (e.g. `HealthComponent`, `MovementComponent`, `BreakComponent`, `ReactionComponent`, `StatusComponent`) rather than deep inheritance trees.
- **Data-Driven Content**: Adding a new ability, enemy, or class should only require creating a new Resource (`.tres` file) and visual assets (sprites, animations), never engine edits.

## Error Handling & Debugging
- **Fail Loudly**: Assert on resource, timeline, or state validations; do not silently ignore errors.
- **Developer Tools**: Maintain diagnostic features (grid/coordinate displays, preview collision paths, intent visualizers, stepping timeline controls, desync checkers).

## Code Quality & Refactoring
- **Clarity > Cleverness**: Prefer 100 lines of simple, easily readable code over 20 lines of obscure, compact code.
- **Descriptive Names**: Class and variable names must explicitly reflect their purpose (e.g. `GhostSimulation`, `BreakComponent`, `CollisionResolver`). Avoid names like `Utils`, `Misc`, or `Helper`.
- **Refactor Early**: If a cleaner architecture is identified, refactor immediately. Do not accumulate technical debt.
- **Documentation**: Every public class must document its purpose, responsibilities, dependencies, signals, and expected lifecycle in a brief header comment.
