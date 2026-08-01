# World assets and map (P7)

**Status:** `DRAFT` — **blocked on owner worksheet (art)**  
**Pillar ID:** P7  
**Authority chain:** `ROADMAP.md` · `sandbox_map_system.md` · `docs/asset_manifest.md` · `docs/design/appendices/pixelforge-v14-contract.md`

## Goal

Mana Seed → custom asset path with PixelForge handoff, living-map phase completion, manifest truth, compositor gates.

## Quality bar

| Deliverable | Machine check | Human check |
|-------------|---------------|-------------|
| Manifest | Every `res://` art ref in manifest + on disk | Art direction |
| Compositor | F5 gates per `phase-audit.mdc` | Boredom test |
| PixelForge | CANON promote → manifest row | Owner promote only |

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

## Decomposition

1. Owner worksheet → art direction LOCK
2. PixelForge MVP per appendix
3. ROADMAP living-map remaining phases
4. Compositor audit

## Builder playbook

1. Read `docs/asset_manifest.md` only.
2. PixelForge proposes → owner promotes CANON.
3. Run map scene 10s — no shader errors.

## Critic playbook

```powershell
.\scripts\lint_design_doc.ps1
```

Visual: REFERENCE PNG + capture under `reports/`.

## Gauntlet stub

```text
GOAL: Asset in manifest + F5 compositor PASS
BAR: manifest grep + 10s runtime
PASS_THRESHOLD: 88
RULES: living-sandbox-architect.mdc, phase-audit.mdc
ARTIFACT: this file, lint stdout, docs/asset_manifest.md grep
REFERENCE: reports/<capture>.png
```

## Tooling I/O

| Input | Output | Consumer |
|-------|--------|----------|
| PixelForge ASSET_SPEC | `res://` paths | TileMap layers |
| manifest.md | Disk audit list | All map work |

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
