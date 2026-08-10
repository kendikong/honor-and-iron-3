# Cleric QA Gate

**Scope:** Class validation — every Cleric **active skill**, **movement skill**, **innate passive**, and **promotion passive** in `core/factory/classes/cleric_factory.gd` per `class_abilities.txt` § Cleric. **Not** gameplay-core planning/UI (see [`PLANNING_QA_GATE.md`](PLANNING_QA_GATE.md)).

**End state (Cleric LOCK):** 100% matrix rows **PASS** (meta-critic approved) + `run_cleric_qa_gate.ps1` PASS + `run_cleric_live_qa.ps1` PASS.

**Authority:** [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) · [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md) · [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) · [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc)

**Owner QA sign-off:** **NOT PASS** — see [`CLASS_QA_SIGNOFF.md`](CLASS_QA_SIGNOFF.md).

---

## Gate status (honest — 2026-08-09)

| Field | Value |
|-------|-------|
| **Owner sign-off** | **NOT PASS** |
| **LOCK** | **NO** |
| **Summary** | **31 / 31** meta-critic `PASS` · **0** `HARNESS_ONLY` · **0** `PLANNED` |
| **What runs today** | `tests/cleric_qa_harness.gd` data contract + `selfless_siphon` sim + `tests/live_cleric_class_test.gd` |
| **Manifest** | `docs/cleric_meta_critic_manifest.json` |

---

## Three tiers

| Tier | Runner | Status |
|------|--------|--------|
| **1 — Headless** | `.\scripts\run_cleric_qa_gate.ps1` | **PASS** (automated) |
| **2 — Live** | `.\scripts\run_cleric_live_qa.ps1` → `tests/live_cleric_class_test.gd` | **PASS** (automated) |
| **Manual** | `docs/PLANNING_SKILL_QA_CHECKLIST.md` | Required for feel until owner sign-off |

---

## Meta-critic

Same as [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) § Meta-critic. **Manifest:** `docs/cleric_meta_critic_manifest.json`.

---

## Global systems fidelity

Copy Rules A/B from [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md).

---

## Coverage matrix (`cleric_factory.gd`)

### Movement + actives

| Factory id | Type | Harness | Tier 1 | Notes |
|------------|------|---------|--------|-------|
| `cleric_guardian_step` | Movement | `tests/cleric_qa_harness.gd` | PASS | PRE_MOVE warp adjacent; `[+]` cleanse |
| `cleric_holy_light` | Active | `tests/cleric_qa_harness.gd` | PASS | MAG HEAL |
| `cleric_smite` | Active | `tests/cleric_qa_harness.gd` | PASS | Holy DAMAGE |
| `cleric_cleansing_aura` | Active | `tests/cleric_qa_harness.gd` | PASS | AOE cleanse |
| `cleric_sanctuary` | Active | `tests/cleric_qa_harness.gd` | PASS | Sanctuary terrain |
| `cleric_blinding_ray` | Active | `tests/cleric_qa_harness.gd` | PASS | BLIND status |
| `cleric_divine_hammer` | Active | `tests/cleric_qa_harness.gd` | PASS | Spawn hammer |
| `cleric_life_link` | Active | `tests/cleric_qa_harness.gd` | PASS | Link HEAL |
| `cleric_prayer_of_fortitude` | Active | `tests/cleric_qa_harness.gd` | PASS | Ally buff |
| `cleric_resurrection` | Active | `tests/cleric_qa_harness.gd` | PASS | Revive |
| `cleric_consecrate_ground` | Active | `tests/cleric_qa_harness.gd` | PASS | Holy ground terrain |
| `cleric_holy_wrath` | Active | `tests/cleric_qa_harness.gd` | PASS | AOE holy |
| `cleric_divine_guidance` | Active | `tests/cleric_qa_harness.gd` | PASS | Guidance buff |
| `cleric_shield_of_faith` | Active | `tests/cleric_qa_harness.gd` | PASS | SHIELD |
| `cleric_martyrs_chains` | Active | `tests/cleric_qa_harness.gd` | PASS | ROOT chains |

### Innate + passives

| Factory id | Passive | Harness | Tier 1 | Notes |
|------------|---------|---------|--------|-------|
| `selfless_siphon` | Selfless Siphon | `tests/cleric_qa_harness.gd` | PASS | Sim heal splits to self |
| `blood_donation` | Blood Donation | `tests/cleric_qa_harness.gd` | PASS | Paladin promotion |
| `sacred_shield` | Sacred Shield | `tests/cleric_qa_harness.gd` | PASS | Paladin |
| `divine_blessing` | Divine Blessing | `tests/cleric_qa_harness.gd` | PASS | Paladin |
| `frontline_medic` | Frontline Medic | `tests/cleric_qa_harness.gd` | PASS | Paladin |
| `armor_of_faith` | Armor of Faith | `tests/cleric_qa_harness.gd` | PASS | Paladin |
| `divine_overflow` | Divine Overflow | `tests/cleric_qa_harness.gd` | PASS | Seraph |
| `divine_intervention` | Divine Intervention | `tests/cleric_qa_harness.gd` | PASS | Seraph |
| `holy_ground` | Holy Ground | `tests/cleric_qa_harness.gd` | PASS | Seraph |
| `prayer` | Prayer | `tests/cleric_qa_harness.gd` | PASS | Seraph |
| `purity` | Purity | `tests/cleric_qa_harness.gd` | PASS | Seraph |
| `martyrs_blood` | Martyr's Blood | `tests/cleric_qa_harness.gd` | PASS | Zealot |
| `divine_retribution` | Divine Retribution | `tests/cleric_qa_harness.gd` | PASS | Zealot |
| `holy_radiance` | Holy Radiance | `tests/cleric_qa_harness.gd` | PASS | Zealot |
| `retribution` | Retribution | `tests/cleric_qa_harness.gd` | PASS | Zealot |
| `zealous_protection` | Zealous Protection | `tests/cleric_qa_harness.gd` | PASS | Zealot |

---

## Commands

```powershell
.\scripts\run_cleric_qa_gate.ps1 -GodotPath "<godot.exe>"
.\scripts\run_cleric_live_qa.ps1 -GodotPath "<godot.exe>"
```
