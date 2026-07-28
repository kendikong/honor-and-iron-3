param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[switch]$Headless
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$captureDir = Join-Path $projectRoot "tests\captures"
$jsonPath = Join-Path $captureDir "mass_sim_snapshot.json"
$pngPath = Join-Path $captureDir "mass_sim_dashboard.png"

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
	exit 1
}

New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

$godotArgs = @("--path", $projectRoot, "--script", "res://tests/capture_mass_sim_dashboard.gd")
if ($Headless) {
	$godotArgs = @("--headless") + $godotArgs
}

& $GodotPath @godotArgs
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

if (-not (Test-Path $jsonPath)) {
	Write-Error "Capture JSON missing: $jsonPath"
	exit 1
}
if (-not (Test-Path $pngPath)) {
	Write-Warning "Capture PNG missing (use capture without -Headless for pixels). JSON still available."
}

Write-Output "--- mass_sim_snapshot.json ---"
Get-Content $jsonPath
Write-Output "--- screenshot: $pngPath ---"
exit 0
