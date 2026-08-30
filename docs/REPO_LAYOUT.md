# Repository layout

## Repo root (keep minimal)

| File | Purpose |
|------|---------|
| `project.godot` | Godot project |
| `ROADMAP.md`, `IMPLEMENTATION_STATUS.md`, `IMPLEMENTATION_PLAN.md` | Planning |
| `class_abilities.txt` | Master Bible (many refs — stays here) |
| `AGENTS.md`, `BUG_REPORT.md` | Agent / bug workflow |
| `icon.svg` | App icon |

**Not at root:** QA logs (`reports/qa/`), scratch scripts (`tools/`), design docs (`docs/`).

## `docs/`

| Folder | Contents |
|--------|----------|
| `docs/design/planning/` | Move preview, hover SSOT, action range |
| `docs/design/combat/` | Combat parity, abilities, world assets |
| `docs/design/classes/` | Class rollout templates |
| `docs/design/process/` | Gauntlet, cloud sync, verification |
| `docs/design/logs/` | Ephemeral gauntlet / implementation logs |
| `docs/qa/classes/` | Per-class `*_QA_GATE.md` |
| `docs/qa/manifests/` | Meta-critic JSON |
| `docs/qa/planning/` | Planning QA gate + checklists |
| `docs/reference/` | Tiles, assets, owner `.docx` references |

## `tests/`

See `tests/README.md`. Scenarios stay in `skills/` and `passives/`; everything else is in subfolders.

## `reports/`

| Folder | Contents |
|--------|----------|
| `reports/qa/` | Class gate logs (`qa_*_gate_latest.txt`) |
| `reports/logs/` | Other generated stdout/stderr captures |
| `reports/bug_reports/` | Bug JSON (fixed path — do not move) |
| `reports/live_planning_trace/` | Planning trace PNGs |

## `scripts/`

| Folder | Contents |
|--------|----------|
| `scripts/qa/` | QA PowerShell (real scripts) |
| `scripts/*.ps1` | Thin shims → `scripts/qa/` |
| `scripts/*.gd` | Runtime map / effects code |
| `tools/` | One-off maintenance scripts |
