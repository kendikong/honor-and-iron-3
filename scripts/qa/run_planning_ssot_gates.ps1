param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

$gates = @(
	@{ name = "Hover preview carried"; script = "run_hover_preview_ssot_gate.ps1" },
	@{ name = "Action range latest stand"; script = "run_action_range_ssot_gate.ps1" },
	@{ name = "AOE footprint paint"; script = "run_footprint_ssot_gate.ps1" },
	@{ name = "Ability ID branches"; script = "run_ability_id_branch_gate.ps1" },
	@{ name = "Ability ID branch self-test"; script = "test_ability_id_branch_gate.ps1" }
)

foreach ($gate in $gates) {
	Write-Output ""
	Write-Output "=== $($gate.name) ==="
	$path = Join-Path $PSScriptRoot $gate.script
	& $path
	if ($LASTEXITCODE -ne 0) {
		Write-Output "--- Planning SSOT gates: FAIL at $($gate.name) ---"
		exit 1
	}
}

Write-Output ""
Write-Output "--- All planning SSOT structural gates: PASS ---"
exit 0
