# Wire _sim_upgrade tier into non-Knight skill scenarios (CLASS_QA_BIBLE.md §3 Layer B [+]).
param(
	[string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$KnightSkip = '^(knight_|shield_|bowling_|chain_|phalanx_|fortify|indomitable_|redirect_|retaliation_|seismic_|taunting_|trampling_|iron_grip|defensive_formation|run_economy)'

Get-ChildItem -Path (Join-Path $ProjectRoot 'tests\skills') -Filter '*_scenario.gd' | ForEach-Object {
	$name = $_.BaseName -replace '_scenario$', ''
	if ($name -match $KnightSkip) { return }
	$text = Get-Content -Path $_.FullName -Raw
	if ($text -match '_sim_upgrade|ClassScenarioUpgradeRegistry') { return }
	if ($text -notmatch '_sim_contract') { return }

	$factoryId = $name
	$upgradeConst = "const _Upgrades := preload(`"res://tests/class_scenario_upgrade_registry.gd`")`n`n"
	if ($text -notmatch 'ClassScenarioUpgradeRegistry') {
		if ($text -match '(const _Planning[^\n]+\n)') {
			$text = $text -replace '(const _Planning[^\n]+\n)', "`$1$upgradeConst"
		} elseif ($text -match '(const _H[^\n]+\n)') {
			$text = $text -replace '(const _H[^\n]+\n)', "`$1$upgradeConst"
		} else {
			return
		}
	}

	if ($text -match '(?ms)(static func _sim_contract\([^\)]*\)\s*->\s*void:\s*)(.*?)(\r?\n\r?\nstatic func|\r?\nstatic func _|\z)') {
		$prefix = $Matches[1]
		$body = $Matches[2].TrimEnd()
		$rest = $Matches[3]
		if ($body -notmatch '_sim_upgrade') {
			$newBody = $body + "`n`t_sim_upgrade(failures)"
			$upgradeFunc = @"

static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &$factoryId)

"@
			$text = $text -replace [regex]::Escape($prefix + $body), ($prefix + $newBody)
			if ($text -notmatch 'static func _sim_upgrade') {
				$text = $text -replace '(static func _sim_contract.*?\n)(static func )', "`$1$upgradeFunc`$2"
			}
		}
	}

	Set-Content -Path $_.FullName -Value $text -NoNewline
	Write-Output "patched $($_.Name)"
}
