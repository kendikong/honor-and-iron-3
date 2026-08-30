# Repository layout

Where things live and why. **Game code paths are stable** (`core/`, `presentation/`, `data/`, `scenes/`). This doc covers docs, QA, and tests.

## Top level (keep visible)

| Path | Purpose |
|------|---------|
| `ROADMAP.md` | Phased build plan |
| `IMPLEMENTATION_STATUS.md` | Phase progress + audits |
| `IMPLEMENTATION_PLAN.md` | Pointer to ROADMAP |
| `class_abilities.txt` | Master Bible (high ref count — stays at root) |
| `AGENTS.md` | Agent / headless CLI entry points |
| `project.godot` | Godot project |

## `docs/`

| Folder | Contents |
|--------|----------|
| `docs/design/` | **Stable SSOT** — move preview rules, action range, cloud sync, class rollout |
| `docs/design/logs/` | Gauntlet rounds, implementation logs (ephemeral) |
| `docs/qa/classes/` | Per-class `*_QA_GATE.md` matrices |
| `docs/qa/manifests/` | `*_meta_critic_manifest.json` |
| `docs/qa/planning/` | Planning QA gate + checklists |
| `docs/qa/` | `CLASS_QA_BIBLE.md`, templates, signoff, bug workflow |
| `docs/reference/` | Engine refs — tiles, grid API, asset manifest |
| `docs/audits/` | Bible alignment audits |
| `docs/extracted/` | Asset extraction scratch |

**Moved:** `sandbox_map_system.md` (repo root) → `docs/design/sandbox_map_system.md`

## `scripts/`

| Folder | Contents |
|--------|----------|
| `scripts/*.gd` | **Runtime** — map, LPC, effects, editor tools |
| `scripts/qa/` | **All QA PowerShell** — gates, live runners, linters |
| `scripts/*.ps1` (root) | **Shims** → forward to `scripts/qa/` (old paths still work) |
| `scripts/sync_local_remote.ps1` | Git push/pull (not under `qa/`) |

## `tests/`

| Folder | Contents |
|--------|----------|
| `tests/skills/` | Per-skill scenario `.gd` |
| `tests/passives/` | Per-passive scenario `.gd` |
| `tests/gates/` | `*QaGate.tscn`, `T3MimicHeadless.tscn` (GdUnit / headless scene entry) |
| `tests/fixtures/`, `tests/captures/` | Fixtures + screenshot captures |
| `tests/` (root) | Runners (`run_*.gd`), harnesses, registries, live class tests |

**Why root is still busy:** `res://tests/run_*.gd` and scenario preloads are referenced hundreds of times. Runners stay flat until a mechanical path migration.

See `tests/README.md` for naming conventions.

## `reports/`

Generated output — prefer **not** committing. `reports/bug_reports/` is **fixed** (`debug_report_service.gd` writes here).

| Folder | Contents |
|--------|----------|
| `reports/qa/` | Gate logs (`qa_*_gate_latest.txt`) when scripts write here |
| `reports/live_planning_trace/` | Planning trace PNGs |
| `reports/bug_reports/` | Owner bug JSON |

## `tools/`

One-off dev scripts (`reorganize_repo_layout.ps1`, `fetch_lpc`, etc.)

## Do not move without code changes

- `reports/bug_reports/` — autoload path
- `class_abilities.txt` — UI + factory Bible refs
- `res://tests/skills/` and `res://tests/passives/` — scenario preloads

## Re-run layout migration

```powershell
powershell -File tools/reorganize_repo_layout.ps1
```

Idempotent for already-moved paths (skips missing sources).
