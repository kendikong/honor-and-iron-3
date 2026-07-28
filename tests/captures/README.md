# Mass Sim — simple owner workflow

You are **not** expected to read JSON or code. Use the dashboard + one sentence to the agent.

## The 3-step loop (balance changes)

1. **Configure skirmish** — click **Skirmish Setup** (player/enemy count, levels, passives, class skills).
2. **Before you change game rules** — click **New Epoch** (locks setup + archives old log).
3. **Run battles** — **+500** → **Run Queue**.
4. **Get interpretation** — tell the agent: **"interpret my mass sim"**

**Skirmish Setup limits:** 1–8 players · 1–12 enemies · levels 1–99 · up to 6 passives · class skills 0–98 or **99 = full kit**.

**Rule of thumb:** Only compare stats **inside one epoch**. Changing setup without **New Epoch** mixes incomparable data.

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
