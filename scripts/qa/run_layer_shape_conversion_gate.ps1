param(
    [string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
    [switch]$Audit
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$script = "res://tests/runners/run_layer_shape_conversion_gate.gd"
$args = @("--headless", "--path", $repoRoot, "--script", $script)
if ($Audit) { $args += "--"; $args += "--audit" }
& $GodotPath @args
exit $LASTEXITCODE
