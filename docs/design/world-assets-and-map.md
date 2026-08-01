# World assets and map (P7)

**Status:** `DRAFT` *(doc gauntlet PASS 91/88 — worksheet gates LOOP_READY)*  
**Pillar ID:** P7  
**Authority chain:** `ROADMAP.md` · `sandbox_map_system.md` · `docs/asset_manifest.md` · `docs/design/appendices/pixelforge-v14-contract.md`

## Goal

Mana Seed → custom asset path with PixelForge handoff, living-map phase completion, manifest truth, compositor gates. **Doc gauntlet PASS** = spec + paths; **LOOP_READY** requires art worksheet filled.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Manifest | `docs/asset_manifest.md` exists on disk | Art direction |
| Compositor | `PLANNED — F5 compositor gate (.cursor/rules/phase-audit.mdc)` | Boredom test |
| PixelForge contract | `docs/design/appendices/pixelforge-v14-contract.md` | Owner CANON promote only |
| Reference map scene | `scenes/test_map.tscn` on disk | Compositor audit |

## Non-goals

- Hallucinated assets not in manifest
- UV-warp environmental motion
- Agent-set CANON without owner

## Human-only worksheet

| Decision | Your answer |
|----------|-------------|
| Replace Mana Seed vs augment | |
| PixelForge CANON promote authority | *(default: you only)* |
| Reference mood boards / PNG paths | |
| Seasonal / biome priority order | |

**Human gate rule:** Doc gauntlet BAR = `lint_design_doc.ps1` only. Empty worksheet must not FAIL critic; gates **`LOOP_READY`** only.

## Path inventory

| Asset | Path |
|-------|------|
| Manifest | `docs/asset_manifest.md` |
| Tile registry | `docs/tile_registry.md` |
| Reference map | `scenes/test_map.tscn` |
| PixelForge contract | `docs/design/appendices/pixelforge-v14-contract.md` |
| Compositor rules | `.cursor/rules/phase-audit.mdc` |

## Decomposition

1. Owner worksheet → art direction LOCK
2. PixelForge MVP per appendix
3. ROADMAP living-map remaining phases
4. Compositor audit

## Builder playbook

1. **Stop** if worksheet empty — status stays `DRAFT`.
2. Read `docs/asset_manifest.md` only.
3. PixelForge proposes → owner promotes CANON.
4. Run map scene 10s — no shader errors.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Visual: REFERENCE PNG + capture under `reports/`.

## Gauntlet stub

```text
GOAL: P7 spec + paths; LOOP_READY requires worksheet filled
BAR: lint PASS; docs/asset_manifest.md exists
PASS_THRESHOLD: 88
RULES: living-sandbox-architect.mdc, phase-audit.mdc
ARTIFACT: this file, lint stdout, docs/asset_manifest.md grep
REFERENCE: reports/<capture>.png
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| PixelForge ASSET_SPEC | `res://` paths | TileMap layers |
| `docs/asset_manifest.md` | Disk audit list | All map work |

## Exit criteria

- [ ] Worksheet filled
- [ ] No missing manifest entries for shipped map
- [ ] Compositor gates PASS

## Doc polish scorecard

*(Critic fills — do not self-grade.)*

| Dimension | /10 |
|-----------|-----|
| Covers scope | |
| Machine bars | |
| No duplication | |
| Agent-executable | |
| Human boundaries | |
| Sequencing | |
| Tooling I/O | |
| Loop-polishable | |
