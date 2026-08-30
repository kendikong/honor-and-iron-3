# Bulk-wrap non-Knight class scenarios to CLASS_QA_BIBLE contract shape.
param(
	[string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$KnightSkipPattern = '^(knight_|shield_|bowling_|chain_|phalanx_|fortify|indomitable_|redirect_|retaliation_|seismic_|taunting_|trampling_|iron_grip|defensive_formation|run_economy)'
$ClassPrefixPattern = '^(bruiser|archer|lancer|mage|cleric)_'

function Get-FactoryIdFromPath {
	param([string]$RelPath)
	$name = [System.IO.Path]::GetFileNameWithoutExtension($RelPath)
	if ($name -match '_scenario$') { $name = $name -replace '_scenario$', '' }
	return $name
}

function Should-SkipFile {
	param([string]$FileName)
	if ($FileName -match $KnightSkipPattern) { return $true }
	return $false
}

function Patch-ScenarioContent {
	param(
		[string]$Text,
		[string]$FactoryId,
		[bool]$IsSkill
	)
	if ($Text -match 'ClassScenarioPlanningContract') { return $null }
	if ($Text -notmatch '(?ms)(static func run_all\([^\)]*\)\s*->\s*void:\s*)(.*?)(\r?\n\r?\nstatic func|\r?\nstatic func _|\z)') {
		return $null
	}
	$runAllPrefix = $Matches[1]
	$body = $Matches[2].Trim()
	$rest = $Matches[3]
	if ($body -match '_sim_contract|_sim_trigger') { return $null }
	if ([string]::IsNullOrWhiteSpace($body)) { return $null }

	$planningConst = ""
	$planningCall = ""
	if ($IsSkill) {
		$planningConst = "const _Planning := preload(`"res://tests/class_scenario_planning_contract.gd`")`n`n"
		if ($Text -notmatch '## Planning tier:') {
			$planningConst += "## Planning tier: B`n"
		}
		$planningCall = "`n`t_Planning.run_for_factory(failures, &$FactoryId)"
	}

	$simFunc = if ($IsSkill) { '_sim_contract' } else { '_sim_trigger' }
	$newRunAll = @"
${runAllPrefix}_${simFunc}(failures)${planningCall}


static func _${simFunc}(failures: Array[String]) -> void:
	$($body -replace '(?m)^', "`t")
"@
	$insertAt = $Text.IndexOf($runAllPrefix)
	if ($insertAt -lt 0) { return $null }
	$before = $Text.Substring(0, $insertAt)
	$afterStart = $insertAt + $runAllPrefix.Length + $body.Length
	$after = $Text.Substring($afterStart)
	if (-not $before.Contains('class_scenario_planning_contract')) {
		if ($before -match '(const _[^\n]+\n)') {
			$before = $before -replace '(const _[^\n]+\n)', "`$1$planningConst"
		} else {
			$before = $before -replace '(extends RefCounted\n)', "`$1`n$planningConst"
		}
	}
	return $before + $newRunAll + $after
}

$patched = 0
$skipped = 0
$files = @()
$files += Get-ChildItem -Path (Join-Path $ProjectRoot 'tests\skills') -Filter '*_scenario.gd' -File -ErrorAction SilentlyContinue
$files += Get-ChildItem -Path (Join-Path $ProjectRoot 'tests\passives') -Filter '*_scenario.gd' -File -ErrorAction SilentlyContinue

	foreach ($file in $files) {
	if (Should-SkipFile $file.Name) { $skipped++; continue }
	$factoryId = Get-FactoryIdFromPath $file.Name
	$isSkill = $false
	if ($file.FullName -match '\\skills\\') { $isSkill = $true }
	$isPassiveDir = $file.FullName -match '\\passives\\'
	if (-not ($factoryId -match $ClassPrefixPattern) -and -not $isPassiveDir) {
		$skipped++
		continue
	}
	$text = Get-Content -Path $file.FullName -Raw
	$newText = Patch-ScenarioContent -Text $text -FactoryId $factoryId -IsSkill $isSkill
	if ($null -eq $newText) { $skipped++; continue }
	Set-Content -Path $file.FullName -Value $newText -NoNewline -Encoding utf8
	$patched++
	Write-Output "patched: $($file.Name)"
}

Write-Output "Patched $patched files, skipped $skipped"
