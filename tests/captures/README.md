# Mass Sim — simple owner workflow

You are **not** expected to read JSON or code. Use the dashboard + one sentence to the agent.

## The 3-step loop (balance changes)

1. **Before you change game rules** (knight buff, enemy count, AI tweak)  
   Open **Main Menu → Mass Simulation Analytics** → click **New Epoch**.  
   Type what changed (e.g. `Knight damage +2`).  
   Old battles are **archived**; the dashboard starts a **clean log** for the new rules.

2. **Run battles**  
   Click **+500** (or **+100** for a quick check) → **Run Queue**.  
   Wait until the status bar says the batch is done.

3. **Get interpretation**  
   Tell the agent: **"interpret my mass sim"**  
   It reads `tests/captures/mass_sim_interpretation.json` (full stats, skill meta, AI holds).

**Rule of thumb:** Only compare stats **inside one epoch**. Do not mix old 700-battle files with a new knight buff — use **New Epoch** first.

---

## Balance epoch dropdown

- **Legacy (mixed / untagged)** — your old runs before epoch tracking. Good for history, **not** for comparing to a new balance pass.
- **Named epochs** — each balance change you labeled. The dashboard only counts battles that belong to the selected epoch.

Yellow banner text warns you if the log still mixes rule sets.

---

## When you change skirmish size or a big rules pass

In code (or ask the agent), bump `RULES_REVISION` in `core/batch/mass_sim_constants.gd` and set `SKIRMISH_PLAYER_COUNT` / `SKIRMISH_ENEMY_COUNT` if needed. Then **New Epoch** so fingerprints stay honest.

---

## Files the agent uses

| File | When |
|------|------|
| `tests/captures/mass_sim_interpretation.json` | **Primary** — all L1–L7 stats + skill meta + Commander AI |
| `tests/captures/mass_sim_interpretation.md` | Same data, human-readable |
| `user://mass_sim_epochs/` | Archived logs from past epochs |
| `tests/captures/mass_sim_dashboard.png` | Optional layout screenshot |

Optional capture script:

```powershell
.\scripts\capture_mass_sim_dashboard.ps1
```

Tell the agent **"interpret my mass sim"** — not "read my screenshot" — unless the UI looks broken.

These capture files are gitignored except this README.
