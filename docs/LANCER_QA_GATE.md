# Lancer QA Gate

**Scope:** Class validation for the renamed base class `Lancer`, including the
Push movement skill, 13 active skills, and 15 promotion passives from
`class_abilities.txt`. Promotion names remain Cavalier, Skystriker, and
Halberdier.

**Runner:** `.\scripts\run_lancer_qa_gate.ps1`. This is a class gate and is
separate from planning QA.

## Acceptance contract

The Tier 1 suite checks:

- Lancer identity and Bible base stats: CON 5, MOV 3, STR 4, DEF 3, MAG 1.
- Exactly 14 authored abilities (Push plus 13 active skills) and 15 passives.
- Every ability has non-empty base and `[+]` `AbilityModule` profiles.
- The module bridge compiles each profile to the expected primary effect.
- Every passive is registered with promotion ownership in data, not an
  ability-id branch.
- The modular Push effect resolves through `Simulator` → `AbilitySystem` →
  `PhysicsSystem`.

The registry contains one row for each Bible factory id:

| Group | Rows |
|---|---:|
| Movement + active skills | 14 |
| Promotion passives | 15 |
| **Total** | **29** |

The shared scenario file is `tests/lancer_class_scenario.gd`; the registry
retains the source path for each Bible row so the matrix stays auditable while
the common contract remains single-source.

## Required follow-up

Manual Layer B checks still belong to the owner: preview/commit parity, jump
presentation, facing, path feel, and pixel output. The headless gate does not
replace the planning QA gate when planning code changes.
