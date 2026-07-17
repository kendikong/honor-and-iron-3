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

That script ensures `.gdignore` exists on `_lpc_sparse/`, `Universal-LPC-.../`, and `node_modules/`, **deletes every `.import` stub under those trees** (can be 140k+ files if Godot imported LPC once), then deletes `.godot/` so the editor rebuilds import cache for ~1k Mana Seed files only — not 280k+ LPC PNGs.

**Both** `_lpc_sparse/` and `Universal-LPC-.../` must be ignored. Protecting only the generator folder while `_lpc_sparse` still has `.import` files causes the same RID / `texture_storage` / `render_scene_buffers_rd` spam.

**Never delete `.godot/` by hand** unless those `.gdignore` files exist first.

**If you still have `Assets/LPC/spritesheets/`** (old junction), delete it or re-run the fetch script.

Generator metadata stays in `Universal-LPC-Spritesheet-Character-Generator-master/` (gitignored, `.gdignore`).
