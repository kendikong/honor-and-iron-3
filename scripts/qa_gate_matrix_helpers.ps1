# Shared matrix + manifest enforcement for class QA gate scripts.

function Test-MatrixScenarioFiles {
	param(
		[string]$ProjectRoot,
		[string]$MatrixDocPath,
		[string[]]$RequiredFactoryIds
	)
	$missing = @()
	if (-not (Test-Path $MatrixDocPath)) {
		return @("missing matrix doc: $MatrixDocPath")
	}
	$matrixText = Get-Content -Path $MatrixDocPath -Raw
	foreach ($id in $RequiredFactoryIds) {
		$escaped = [regex]::Escape($id)
		$rowLine = (
			$matrixText -split "`n" |
			Where-Object {
				$_ -match ('`\s*' + $escaped + '\s*`') -and $_ -match '\|' -and $_ -match '\|\s*PASS\s*\|'
			} |
			Select-Object -First 1
		)
		if ($null -eq $rowLine) { continue }
		$pathMatch = [regex]::Match($rowLine, '`(tests/(?:skills|passives)/[^`]+\.gd)`')
		if (-not $pathMatch.Success) {
			$missing += "${id}: no scenario path in PASS row"
			continue
		}
		$rel = $pathMatch.Groups[1].Value
		$full = Join-Path $ProjectRoot ($rel -replace '/', '\')
		if (-not (Test-Path $full)) {
			$missing += "${id}: missing $rel"
		}
	}
	return $missing
}

function Test-ManifestScore {
	param(
		[string]$ManifestPath,
		[int]$MinScore = 88
	)
	if (-not (Test-Path $ManifestPath)) {
		return @("missing manifest: $ManifestPath")
	}
	$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
	$errors = @()
	if ($null -ne $manifest.pass_threshold -and [int]$manifest.pass_threshold -gt $MinScore) {
		$errors += "manifest pass_threshold $([int]$manifest.pass_threshold) > gate minimum $MinScore"
	}
	if ($null -ne $manifest.last_score -and [int]$manifest.last_score -lt $MinScore) {
		$errors += "manifest last_score $([int]$manifest.last_score) < minimum $MinScore"
	}
	if ($manifest.last_result -ne 'PASS') {
		$errors += "manifest last_result is not PASS"
	}
	return $errors
}

function Test-ScenarioContractShallow {
	param(
		[string]$ScenarioRelPath,
		[string]$FullPath
	)
	$errors = @()
	if (-not (Test-Path $FullPath)) {
		return @("${ScenarioRelPath}: missing file")
	}
	$text = Get-Content -Path $FullPath -Raw
	$isSkill = $ScenarioRelPath -match 'tests/skills/'
	$isPassive = $ScenarioRelPath -match 'tests/passives/'
	$hasLayerA = $text -match '_data_contract|_sim_contract|Data/Sim delegate:'
	$hasLayerB = $text -match 'Simulator\.|AbilitySystem\.|simulate_player_turn|run_sim_|_sim_base|run_bash_|run_single_passive|_Scenarios\.run_'
	$hasLayerC = $text -match '_planning_proof|_phase[0-9]|run_planning_commit_smoke|PlanningChecklistHarness|ClassPlanningChecklistHarness|movement_planning_smoke'
	$hasDelegateHeader = $text -match 'Data/Sim delegate:'
	$thinDelegate = (
		($text -match 'run_ability_row\s*\(' -and -not $hasDelegateHeader -and -not $hasLayerA) -or
		($text -match 'run_single_ability\s*\(' -and -not $hasDelegateHeader -and -not $hasLayerA) -or
		($text -match 'factory_passive\s*\([^)]+\)\s*!=\s*null' -and -not $hasLayerB)
	)
	$runAllLines = ([regex]::Matches($text, '(?ms)static func run_all.*?(?=static func|\z)')).Value
	$runAllBody = if ($runAllLines.Count -gt 0) { $runAllLines[0] } else { $text }
	$runAllOnlyDelegate = (
		$runAllBody -match 'run_ability_row|run_single_ability' -and
		$runAllBody -notmatch 'assert_|_sim_contract|_data_contract|_phase|PlanningChecklistHarness'
	)
	if ($thinDelegate -or $runAllOnlyDelegate) {
		$errors += "${ScenarioRelPath}: thin harness delegate"
	}
	if ($isSkill -and -not $hasLayerA) {
		$errors += "${ScenarioRelPath}: missing Layer A (_data_contract or _sim_contract)"
	}
	if ($isSkill -and -not $hasLayerC) {
		$errors += "${ScenarioRelPath}: missing Layer C planning proof"
	}
	if ($isPassive -and -not $hasLayerB) {
		$errors += "${ScenarioRelPath}: passive missing sim trigger"
	}
	return $errors
}

function Test-PassRowScenarioContracts {
	param(
		[string]$ProjectRoot,
		[string]$MatrixDocPath
	)
	$errors = @()
	if (-not (Test-Path $MatrixDocPath)) {
		return @("missing matrix doc: $MatrixDocPath")
	}
	$matrixText = Get-Content -Path $MatrixDocPath -Raw
	$lines = $matrixText -split "`n"
	foreach ($line in $lines) {
		if ($line -notmatch '\|\s*PASS\s*\|') { continue }
		$pathMatch = [regex]::Match($line, '`(tests/(?:skills|passives)/[^`]+\.gd)`')
		if (-not $pathMatch.Success) { continue }
		$rel = $pathMatch.Groups[1].Value
		$full = Join-Path $ProjectRoot ($rel -replace '/', '\')
		$errors += Test-ScenarioContractShallow -ScenarioRelPath $rel -FullPath $full
	}
	return $errors
}
