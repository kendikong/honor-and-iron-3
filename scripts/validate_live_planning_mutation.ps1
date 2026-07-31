param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sceneGate = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
$owner = Join-Path $projectRoot "presentation\combat_planning_input.gd"
$anchor = "(?m)^(?<indent>[ \t]*)if ability == null or AbilitySystem\.is_run_ability\(ability\) or AbilitySystem\.is_wait_ability\(ability\):\r?\n[ \t]+return false"

function Invoke-SceneGate {
	& $sceneGate -GodotPath $GodotPath | Out-Host
	return $LASTEXITCODE
}

if ((Invoke-SceneGate) -ne 0) {
	throw "Tier 3 baseline must PASS before live mutation validation."
}

$original = [IO.File]::ReadAllText($owner)
$match = [regex]::Match($original, $anchor)
if (-not $match.Success) {
	throw "Live mutation anchor not found in presentation/combat_planning_input.gd."
}

try {
	$mutated = $original.Remove($match.Index, $match.Length).Insert(
		$match.Index,
		"$($match.Value)`n$($match.Groups['indent'].Value)return true # QA_LIVE_MUT"
	)
	[IO.File]::WriteAllText($owner, $mutated)
	$mutatedExit = Invoke-SceneGate
	if ($mutatedExit -eq 0) {
		throw "Live red-range mutation escaped Tier 3 acceptance."
	}
	Write-Output "[CAUGHT] Tier 3 live red-range mutation"
}
finally {
	[IO.File]::WriteAllText($owner, $original)
}

if ((Invoke-SceneGate) -ne 0) {
	throw "Tier 3 acceptance did not recover after restoring the live mutation."
}
Write-Output "[PASS] Tier 3 mutation restored and acceptance recovered"
