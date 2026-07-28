# Mass Sim captures & interpretation (agent + owner)

## After you run a mass simulation

Every time a batch finishes **or** you click **Reload**, the dashboard writes a **full statistics bundle** for AI interpretation:

| File | Contents |
|------|----------|
| `mass_sim_interpretation.json` | **All L1–L7 stats** + **skill meta** + **Commander AI holds/commits** + class combat per turn |
| `mass_sim_interpretation.md` | Same data in readable markdown |

Also copied to `user://mass_sim_interpretation.json` (Godot userdata).

**Tell the agent:** “interpret my mass sim” — it reads these files and gives analysis.

## Optional visual snapshot (layout check)

```powershell
.\scripts\capture_mass_sim_dashboard.ps1
```

| File | Purpose |
|------|---------|
| `mass_sim_dashboard.png` | Screenshot at 1280×720 |
| `mass_sim_snapshot.json` | Visible UI text at capture time |

Use **interpretation JSON** for stats; use **PNG** only if layout looks wrong.

These files are gitignored except this README.
