# Layer shape conversion gate (ER-2 anti-cheat)

**Status:** ACTIVE — prep for real module/layer refactor  
**Parent:** `IMPLEMENTATION_PLAN.md` ER-2 · **Binding matrix:** `EXTRA_RULES_TO_MODULES_PLAN.md`  
**Code:** `data/definitions/layer_shape_conversion_rules.gd`  
**Runner:** `tests/run_layer_shape_conversion_gate.gd`

---

## Problem

`extra_rules_conversion_contract.gd` proved **modifier ownership**, not **authoring shape**. Agents moved the legacy bag onto `AbilityModule` typed extras (Effect Knobs) and marked skills converted.

## Definition of converted (shape bar)

A skill is **actually converted** when factory data is **Swap-shaped**:

| Piece | Rule |
|-------|------|
| **Module** | One player click per step |
| **Layer** | Same-click riders (ON_KILL GRANT_AP, ON_COLLISION STAGGER, PER_TARGET_HIT HEAL, …) |
| **Keyword** | Bible bundles (TRAMPLE, BULLDOZE, GHOST, PIERCE) |
| **Typed extra** | **Only** ER-1 allowlist (hazard/spawn/motion-behavior knobs per matrix **New field**) |
| **Effect Knobs UI** | **Absent** for that skill (nothing non-default to edit) |

**Gold standard:** `knight_swap` — modules + layers, **zero** typed extras.

## Enforcement modes

| Mode | Behavior |
|------|----------|
| `--audit` | Print per-skill debt report; never fail |
| Default (`LAYER_MANDATE`) | **FAIL** if any `CONVERTED_SKILL_IDS` skill sets a **layer-mandate** typed extra (`frenzy_on_kill_ap`, `heal_if_targets_gte`, `violent_collision_recast`, …) |
| `STRICT_ALLOWLIST` (future CI) | **FAIL** on any typed extra not in ER-1 allowlist |

## Per-skill expectations

`LayerShapeConversionRules.CONVERSION_SHAPE_EXPECTATIONS` grows as each skill is **re**-converted. Example entries:

- `bruiser_frenzy` — forbid `frenzy_on_kill_ap`; require ON_KILL GRANT_AP layer on upgrade profile
- `bruiser_crimson_whirlwind` — forbid `heal_if_targets_gte`; require HEAL layer on upgrade
- `bruiser_violent_collision` — forbid `violent_collision_recast`; require ≥2 modules

## Agent workflow (one skill per turn)

1. Read binding matrix **Solution** for that skill in `EXTRA_RULES_TO_MODULES_PLAN.md`
2. Change factory: layers/keywords/modules per Solution; **delete** forbidden typed extras
3. Add/update row in `CONVERSION_SHAPE_EXPECTATIONS`
4. Run `run_layer_shape_conversion_gate.gd` — skill’s failures must clear before re-adding to trusted list
5. Only then touch `CONVERTED_SKILL_IDS` or IMPLEMENTATION_PLAN ☑

## Forbidden without owner approval

- New `@export` on `AbilityModule`
- Effect Knobs / editor UX work instead of factory shape fixes
- Marking IMPLEMENTATION_PLAN ☑ while shape gate fails for that skill
- Adding typed field when matrix says **Existing layer**

## QA commands

```text
godot --headless --path . --script res://tests/run_layer_shape_conversion_gate.gd -- --audit
godot --headless --path . --script res://tests/run_layer_shape_conversion_gate.gd
```

**Expected today:** default gate **FAIL** until skills are re-converted. Audit mode shows debt.

## IMPLEMENTATION_PLAN matrix

ER-2 ☑ rows are **frozen** until this gate passes per skill. Notes like “Typed kill AP field” describe the **cheat**, not completion.
