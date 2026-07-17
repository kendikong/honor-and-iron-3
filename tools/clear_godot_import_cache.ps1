# Deletes .godot/ after ensuring LPC trees are excluded from Godot import.
# Also removes stale .import stubs under those trees (141k+ files if import ran once).
# Close Godot completely before running:
#   powershell -ExecutionPolicy Bypass -File tools/clear_godot_import_cache.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$ExcludeDirs = @(
	"_lpc_sparse",
	"Universal-LPC-Spritesheet-Character-Generator-master",
	"node_modules"
)

function Ensure-GdIgnore([string]$Dir) {
	if (-not (Test-Path $Dir)) { return }
	$Flag = Join-Path $Dir ".gdignore"
	if (-not (Test-Path $Flag)) {
		New-Item -ItemType File -Path $Flag -Force | Out-Null
		Write-Host "Created .gdignore in $Dir"
	} else {
		Write-Host ".gdignore already present: $Dir"
	}
}

function Remove-ImportStubs([string]$Dir) {
	if (-not (Test-Path $Dir)) { return }
	$imports = Get-ChildItem $Dir -Recurse -Filter "*.import" -File -ErrorAction SilentlyContinue
	$count = @($imports).Count
	if ($count -eq 0) {
		Write-Host "No .import stubs under $Dir"
		return
	}
	Write-Host "Removing $count .import stubs under $Dir ..."
	foreach ($file in $imports) {
		Remove-Item -LiteralPath $file.FullName -Force
	}
}

foreach ($rel in $ExcludeDirs) {
	$abs = Join-Path $Root $rel
	Ensure-GdIgnore $abs
	Remove-ImportStubs $abs
}

$GodotCache = Join-Path $Root ".godot"
if (-not (Test-Path $GodotCache)) {
	Write-Host "No .godot/ folder - nothing to clear."
	exit 0
}

Write-Host "Removing $GodotCache ..."
Remove-Item -Recurse -Force $GodotCache
Write-Host "Done. Re-open the project in Godot (imports Mana Seed assets only)."
