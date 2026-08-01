# Gauntlet review — design suite (2026-08-01)

**Lint:** `.\scripts\lint_design_doc.ps1` → **PASS** (all pillar + appendix files)

Individual **`gauntlet-critic`** passes (harsh /100). Threshold: **88** pillar · **90** meta.

| Document | C1 | C2 | Threshold | Result | Largest gap |
|----------|----|----|-----------|--------|-------------|
| `00-remaining-work-suite-plan.md` | — | **91** (C6) | 90 | **PASS** | *(prior session)* |
| `01-doc-polish-protocol.md` | 66 | **86** | 90 | FAIL | Rule 6b banner spec incomplete |
| `REMAINING_WORK_MAP.md` | 47 | — | 88 | FAIL | Primary commands not paths *(fixed post-C1)* |
| `verification-matrix.md` | 41 | — | 88 | FAIL | Prose primary bars *(fixed post-C1)* |
| `combat-core-closeout.md` | 72 | — | 88 | FAIL | Too much parity duplication *(partial fix)* |
| `knight-template.md` | 76 | — | 88 | FAIL | Tier 3 vs skill scenario gate split |
| `roguelike-run.md` | 61 | — | 88 | FAIL | Self-scorecard; stub threshold 85 |
| `enemy-design.md` | 62 | — | 88 | FAIL | Scaffold; self-scorecard |
| `class-rollout.md` | *pending* | — | 88 | — | — |
| `world-assets-and-map.md` | *pending* | — | 88 | — | — |
| `presentation-audio-ui.md` | *pending* | — | 88 | — | — |
| `appendices/encounter-fixture-format.md` | *pending* | — | 88 | — | — |
| `appendices/pixelforge-v14-contract.md` | *pending* | — | 88 | — | — |
| `appendices/mass-sim-balance.md` | *pending* | — | 88 | — | — |
| `appendices/gauntlet-prompt-library.md` | *pending* | — | 88 | — | — |

## Post-C1 fixes applied (same session)

- `REMAINING_WORK_MAP.md` — primary commands → real paths or `PLANNED — …`
- `verification-matrix.md` — same
- `01-doc-polish-protocol.md` — promotion table, 4b/4c/6b summary, blank scorecard
- `combat-core-closeout.md` — gauntlet piece table, trim duplication
- `lint_design_doc.ps1` — scans `appendices/`

## Next loop actions

1. Re-critic **map + matrix + doc-polish** after fixes
2. Strip self-scorecards from all pillars; fix `PASS_THRESHOLD: 88` in stubs
3. **knight-template:** document Tier 3 vs legacy skill scenarios in quality bar
4. Run C1 on remaining 6 files
5. Owner: fill P4/P7 worksheets before those pillars go `LOOP_READY`
