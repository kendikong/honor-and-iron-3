# Tests layout

## Organized subfolders

| Path | What |
|------|------|
| `skills/` | One `*_scenario.gd` per active skill |
| `passives/` | One `*_scenario.gd` per passive |
| `gates/` | GdUnit / scene-tree QA entry scenes (`*QaGate.tscn`, `T3MimicHeadless.tscn`) |
| `fixtures/` | Board / planning fixtures |
| `captures/` | Screenshot captures (gitignored except README) |

## Flat at `tests/` root (intentional for now)

| Pattern | Role |
|---------|------|
| `run_*.gd` | **Headless CLI** entry (`extends SceneTree`) — see `AGENTS.md` table |
| `*_runner.gd` | RefCounted harness libs — **do not** `--script` directly |
| `*_harness*.gd` | Shared planning / class harness code |
| `*_scenario_registry.gd` | Per-class scenario lists |
| `live_*_class_test.gd` | Tier-2 live GdUnit tests |
| `planning_qa_gate_test.gd` | Large planning contract suite |

## Running gates

```powershell
# Class (scene)
godot --headless --path . res://tests/gates/KnightQaGate.tscn

# Planning mimic (scene)
godot --headless --path . res://tests/gates/T3MimicHeadless.tscn

# Headless script (runner at tests/ root)
godot --headless --path . --script res://tests/run_t3_mimic_headless.gd
```

PowerShell wrappers live in `scripts/qa/`; shims at `scripts/run_*.ps1` preserve old commands.
