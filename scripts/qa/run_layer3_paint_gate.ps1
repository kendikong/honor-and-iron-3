param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "qa_suspend_guard.ps1"); Assert-QaNotSuspended

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $projectRoot
try {
	& $GodotPath --headless --path . res://tests/gates/Layer3PaintGate.tscn
	if ($?) { exit 0 } else { exit 1 }
} finally {
	Pop-Location
}
