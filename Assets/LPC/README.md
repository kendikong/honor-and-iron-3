# LPC spritesheets (no Godot import)

PNG art lives **outside** `res://` import via `Image.load()`. Folders that must never be imported need an empty **`.gdignore`** file (Godot skips them; `.gitignore` is not enough).

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch_lpc_spritesheets.ps1
```

That sparse-clones into `_lpc_sparse/spritesheets/` and creates `.gdignore` on LPC trees.

**If Godot crashes or RID errors on project open**

1. Close Godot completely.
2. Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/clear_godot_import_cache.ps1
```

That script ensures `.gdignore` exists on `_lpc_sparse/`, `Universal-LPC-.../`, and `node_modules/`, then deletes `.godot/` so the editor rebuilds import cache for ~1k Mana Seed files only — not 400k+ LPC PNGs.

**Never delete `.godot/` by hand** unless those `.gdignore` files exist first.

**If you still have `Assets/LPC/spritesheets/`** (old junction), delete it or re-run the fetch script.

Generator metadata stays in `Universal-LPC-Spritesheet-Character-Generator-master/` (gitignored, `.gdignore`).
