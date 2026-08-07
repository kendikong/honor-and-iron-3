# Archer QA Gate

The Archer gate is a headless, deterministic class contract. It covers all 14
active skills and all 16 passive rows from `class_abilities.txt`.

## Acceptance contract

- The Archer is built by `ArcherFactory` and all active skills use modular
  `AbilityModule` definitions compiled by `AbilityModuleBridge`.
- Every active skill verifies its range, targeting flags, primary effect,
  target shape, upgrade profile, and a valid `Simulator` execution.
- AOE geometry is checked directly: `AOE XxX` is a square footprint, `AOE X`
  is a cardinal cross, and `ARC` is the perpendicular three-tile sweep.
- Passive rows are registered with data modifiers and shared-system smoke tests
  cover Lightfoot movement, Patient Hunter damage, and Zone Control reaction.
- The live gate must additionally exercise every skill through the
  `CombatPlanningInput` preview/commit path.

Run the headless gate with:

```powershell
.\scripts\run_archer_qa_gate.ps1 -GodotPath "<godot.exe>"
```
