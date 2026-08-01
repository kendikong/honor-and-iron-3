param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath"
}

Write-Host ""
Write-Host "K4 visual compare - Godot window stays open."
Write-Host "Walk loop end (4,2): red ON, AP 1"
Write-Host "Run trigger (3,2): red OFF, AP 0"
Write-Host "PNG output: reports\k4_preview\"
Write-Host ""

& $GodotPath --path $projectRoot res://tests/k4_preview_compare_runner.tscn
exit $LASTEXITCODE
