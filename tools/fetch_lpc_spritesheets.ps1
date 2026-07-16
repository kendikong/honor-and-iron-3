# Sparse-clones LPC sprite PNGs into _lpc_sparse/ (outside res:// — no Godot import).
# Run from repo root: powershell -ExecutionPolicy Bypass -File tools/fetch_lpc_spritesheets.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Sparse = Join-Path $Root "_lpc_sparse"
$LegacyJunction = Join-Path $Root "Assets\LPC\spritesheets"
$Repo = "https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator.git"

$SparsePaths = @(
    "spritesheets"
)

if (-not (Test-Path $Sparse)) {
    Write-Host "Cloning LPC repo (sparse)..."
    git clone --depth 1 --filter=blob:none --sparse $Repo $Sparse
    Push-Location $Sparse
    git sparse-checkout init --cone
    git sparse-checkout set @SparsePaths
    git checkout
    Pop-Location
} else {
    Write-Host "Updating sparse checkout paths..."
    Push-Location $Sparse
    git sparse-checkout init --cone
    git sparse-checkout set @SparsePaths
    git checkout
    Pop-Location
}

function Ensure-GdIgnore([string]$Dir) {
    if (-not (Test-Path $Dir)) { return }
    $Flag = Join-Path $Dir ".gdignore"
    if (-not (Test-Path $Flag)) {
        New-Item -ItemType File -Path $Flag -Force | Out-Null
        Write-Host "Created .gdignore in $Dir"
    }
}

Ensure-GdIgnore $Sparse
Ensure-GdIgnore (Join-Path $Root "Universal-LPC-Spritesheet-Character-Generator-master")

if (Test-Path $LegacyJunction) {
    Write-Host "Removing legacy res:// junction (stops Godot importing ~61k PNGs)..."
    cmd /c rmdir "$LegacyJunction"
}

Write-Host "LPC sprites: $Sparse\spritesheets"
Write-Host "Done. If Godot import cache is corrupt, close editor and run tools/clear_godot_import_cache.ps1"
