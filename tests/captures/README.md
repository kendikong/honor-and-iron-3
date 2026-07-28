# Mass Sim Dashboard captures (agent + owner parity)

Agents must run this before claiming the Mass Simulation Analytics UI works:

```powershell
.\scripts\capture_mass_sim_dashboard.ps1
```

Outputs (regenerated each run):

| File | Purpose |
|------|---------|
| `mass_sim_dashboard.png` | Pixel screenshot at 1280×720 — **open this image** to see what the user sees |
| `mass_sim_snapshot.json` | Status line, active tab, queue, report stats, triage titles, visible UI text |

Default Godot path matches `BUG_REPORT.md`. Override with `-GodotPath`.

These files are gitignored; they live only on disk after capture.
