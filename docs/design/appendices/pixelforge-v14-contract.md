# PixelForge v14 contract (appendix)

**Status:** `DRAFT`  
**Pillar ID:** P7 support  
**Authority chain:** PixelForge v14 Master Implementation Specification (owner `.docx`) · `docs/asset_manifest.md` · `docs/tile_registry.md`

## Goal

Distilled agent contract for PixelForge: visual memory, CANON lifecycle, pixel pipeline, Godot sync — without duplicating full v14 doc.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Promoted asset | Row in `asset_manifest.md` | Owner CANON approve |
| Pipeline | 16×16 nearest, palette snap | Compositor F5 |
| Godot sync | `res://` path loads in scene | — |

## Non-goals

- AI overwriting CANON without owner
- Full v14 doc paste into repo

## Human-only worksheet

N/A — CANON promote = owner always.

## Pipeline (summary)

1. **Collect** → reference tiles/sprites  
2. **Analyze / Curate** → ASSET_SPECIFICATION  
3. **Propose** → candidate PNG  
4. **Post-process** → quantize, palette snap, alpha cleanup  
5. **Promote** → owner sets CANON  
6. **Evolve** → manifest + Godot import  

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| ASSET_SPECIFICATION | Candidate assets | PixelForge workspace |
| CANON_BOARD | `res://` exports | `docs/asset_manifest.md` row |
| `docs/tile_registry.md` | Tile id registry | Map generators / TileMap |
| `docs/asset_manifest.md` | Disk truth | All map work |

## Decomposition

1. This contract LOCK  
2. P7 implements first CANON promote loop  
3. Capture reference for compositor gauntlet

## Builder playbook

1. Propose only — never set CANON in agent commits without owner flag.
2. Update manifest on promote.
3. F5 compositor gate.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Compare manifest entry vs file on disk; REFERENCE PNG for visual.

## Gauntlet stub

```text
GOAL: CANON asset promoted with manifest + F5 PASS
BAR: manifest row + compositor
PASS_THRESHOLD: 88
RULES: living-sandbox-architect.mdc, phase-audit.mdc
ARTIFACT: docs/asset_manifest.md, this file
REFERENCE: reports/<capture>.png
```

## Exit criteria

- [ ] I/O chain documented
- [ ] Matches v14 entities (workspace, CANON, pipeline phases)

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
