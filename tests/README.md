# Tests layout

| Folder | What |
|--------|------|
| `skills/` | One `*_scenario.gd` per active skill |
| `passives/` | One `*_scenario.gd` per passive |
| `runners/` | Headless CLI entry scripts (`run_*.gd`, `extends SceneTree`) |
| `live/` | Tier-2 live GdUnit class tests (`live_*_class_test.gd`) |
| `harness/` | Shared runners, registries, harness libs, contract tests |
| `gates/` | GdUnit scene entry points (`*QaGate.tscn`, `T3MimicHeadless.tscn`) |
| `fixtures/`, `captures/` | Fixtures + screenshot captures |

## Running gates

```powershell
# Class (scene)
godot --headless --path . res://tests/gates/KnightQaGate.tscn

# Headless script
godot --headless --path . --script res://tests/runners/run_t3_mimic_headless.gd
```

PowerShell wrappers: `scripts/run_*.ps1` (shims → `scripts/qa/`).
