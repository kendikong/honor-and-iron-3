# Class QA owner sign-off

**Authority:** [`.cursor/rules/class-qa-knight-bar.mdc`](../.cursor/rules/class-qa-knight-bar.mdc) · [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md)

**Owner rule (2026-08-08):** Only **Knight** has passed class QA to the point you do **not** need to hand-test every skill. **All other classes are NOT PASS** until their gates are **redone** to the Knight bar (per-skill scenarios, sim tile footprints, live overlay asserts, matrix 100% meta-critic `PASS`, Tier 2 live).

**Agents:** Do **not** claim class complete, LOCK, or owner sign-off for any row marked **NOT PASS** below. Headless script green ≠ pass.

---

## Sign-off registry

| Class | Implementation | **Owner QA sign-off** | Gate doc | Headless runner | Live runner | Notes |
|-------|----------------|----------------------|----------|-----------------|-------------|-------|
| **Knight** | Complete | **PASS** | [`KNIGHT_QA_GATE.md`](KNIGHT_QA_GATE.md) | `run_knight_qa_gate.ps1` | `PLANNED` (optional Tier 2) | P3 K3-LOCK — **only trusted class** |
| **Bruiser** | Complete | **NOT PASS** | [`BRUISER_QA_GATE.md`](BRUISER_QA_GATE.md) | `run_bruiser_qa_gate.ps1` | `run_bruiser_live_qa.ps1` | Tier 1+2 automated — owner manual sign-off pending |
| **Archer** | Complete | **NOT PASS** | [`ARCHER_QA_GATE.md`](ARCHER_QA_GATE.md) | `run_archer_qa_gate.ps1` | `run_archer_live_qa.ps1` | Harness-only — 0/31 matrix `PASS` |
| **Lancer** | Complete | **NOT PASS** | [`LANCER_QA_GATE.md`](LANCER_QA_GATE.md) | `run_lancer_qa_gate.ps1` | `run_lancer_live_qa.ps1` | Harness-only — 0/29 matrix `PASS` |
| **Mage** | Complete | **NOT PASS** | [`MAGE_QA_GATE.md`](MAGE_QA_GATE.md) | `run_mage_qa_gate.ps1` | `run_mage_live_qa.ps1` | Harness-only — 0/32 matrix `PASS` |
| **Cleric** | Complete | **NOT PASS** | [`CLERIC_QA_GATE.md`](CLERIC_QA_GATE.md) | `run_cleric_qa_gate.ps1` | `run_cleric_live_qa.ps1` | No Knight-shaped gate doc until upgrade |
| **All other Bible classes** | Not shipped | **NOT PASS** | Use [`_CLASS_QA_GATE_TEMPLATE.md`](_CLASS_QA_GATE_TEMPLATE.md) | — | — | Start from template at rollout |

---

## What “PASS” requires (Knight bar)

1. `docs/<CLASS>_QA_GATE.md` — full Knight structure + honest matrix  
2. **100%** factory rows meta-critic **`PASS`** (0 `HARNESS_ONLY` without owner `N/A`)  
3. One `tests/skills/<id>_scenario.gd` (or `tests/passives/`) per row  
4. `run_<class>_qa_gate.ps1` **and** `run_<class>_live_qa.ps1` PASS  
5. Live + planning: **overlay tile sets** + blast footprints at hover (not metadata-only)  
6. `IMPLEMENTATION_STATUS.md` updated — this table flipped to **PASS** only after owner criteria met  

---

## Promotion workflow

```
NOT PASS → implement scenarios + live asserts → matrix row HARNESS_ONLY → PASS
→ all rows PASS + both runners green → flip class row to PASS in this doc + IMPLEMENTATION_STATUS
```

**Forbidden:** Marking **PASS** in `IMPLEMENTATION_STATUS` or gate doc header while this registry says **NOT PASS**.
