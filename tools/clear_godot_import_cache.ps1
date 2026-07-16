# Deletes .godot/ after ensuring LPC trees are excluded from Godot import.
# Close Godot completely before running:
#   powershell -ExecutionPolicy Bypass -File tools/clear_godot_import_cache.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Ensure-GdIgnore([string]$Dir) {
	if (-not (Test-Path $Dir)) { return }
	$Flag = Join-Path $Dir ".gdignore"
	if (-not (Test-Path $Flag)) {
		New-Item -ItemType File -Path $Flag -Force | Out-Null
		Write-Host "Created .gdignore in $Dir"
	}
}

Ensure-GdIgnore (Join-Path $Root "_lpc_sparse")
Ensure-GdIgnore (Join-Path $Root "Universal-LPC-Spritesheet-Character-Generator-master")
Ensure-GdIgnore (Join-Path $Root "node_modules")

$GodotCache = Join-Path $Root ".godot"
if (-not (Test-Path $GodotCache)) {
	Write-Host "No .godot/ folder - nothing to clear."
	exit 0
}

Write-Host "Removing $GodotCache ..."
Remove-Item -Recurse -Force $GodotCache
Write-Host "Done. Re-open the project in Godot (imports Mana Seed assets only)."
