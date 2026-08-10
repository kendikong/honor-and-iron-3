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
		$errors += "manifest pass_threshold $([int]$manifest.pass_threshold) -gt gate minimum $MinScore"
	}
	if ($null -ne $manifest.last_score -and [int]$manifest.last_score -lt $MinScore) {
		$errors += "manifest last_score $([int]$manifest.last_score) -lt minimum $MinScore"
	}
	if ($manifest.last_result -ne 'PASS') {
		$errors += "manifest last_result is not PASS"
	}
	return $errors
}

function Get-DelegateHarnessBody {
	param(
		[string]$ProjectRoot,
		[string]$ScenarioText
	)
	$delegateMatch = [regex]::Match(
		$ScenarioText,
		'##\s*Data/Sim delegate:\s*([^\r\n]+)'
	)
	if (-not $delegateMatch.Success) { return $null }
	$spec = $delegateMatch.Groups[1].Value.Trim()
	$pathFunc = [regex]::Match($spec, '([^:\s]+\.gd)\s*::\s*(\w+)')
	if (-not $pathFunc.Success) { return $null }
	$rel = $pathFunc.Groups[1].Value -replace '\\', '/'
	if ($rel -notmatch '^res://') {
		if ($rel -notmatch '^tests/') { $rel = "tests/$rel" }
	}
	$full = if ($rel -match '^res://') {
		Join-Path $ProjectRoot ($rel -replace '^res://', '' -replace '/', '\')
	} else {
		Join-Path $ProjectRoot ($rel -replace '/', '\')
	}
	if (-not (Test-Path $full)) { return $null }
	$funcName = $pathFunc.Groups[2].Value
	$harnessText = Get-Content -Path $full -Raw
	$funcMatch = [regex]::Match(
		$harnessText,
		"(?ms)static func $funcName\s*\([^\)]*\)\s*->\s*void:\s*(.*?)(?=\nstatic func |\z)"
	)
	if (-not $funcMatch.Success) { return $null }
	return @{
		RelPath = $rel
		FuncName = $funcName
		Body = $funcMatch.Groups[1].Value
	}
}

function Test-TextHasLayerBProof {
	param([string]$Text)
	return (
		$Text -match 'Simulator\.|AbilitySystem\.|simulate_player_turn|simulate_plan|SimResult|run_sim_|_sim_base|run_bash_|run_single_passive|final_state\.|unit_hp\(|assert_.*dmg|assert_.*damage|get_unit_by_id'
	)
}

function Test-TextHasLayerCCommitProof {
	param([string]$Text)
	return (
		$Text -match 'assert_commit_no_jump|assert_slots_match_preview_commit|run_planning_commit_smoke|movement_planning_smoke|assert_red_contract|assert_move_preview|assert_committed_ghost|wire_board\s*\('
		-or ($Text -match '_phase[1-9]' -and $Text -match 'PlanningChecklistHarness')
	)
}

function Test-ScenarioContractShallow {
	param(
		[string]$ScenarioRelPath,
		[string]$FullPath,
		[string]$ProjectRoot = ''
	)
	$errors = @()
	if (-not (Test-Path $FullPath)) {
		return @("${ScenarioRelPath}: missing file")
	}
	$text = Get-Content -Path $FullPath -Raw
	$isSkill = $ScenarioRelPath -match 'tests/skills/'
	$isPassive = $ScenarioRelPath -match 'tests/passives/'
	$hasLayerA = $text -match '_data_contract|_sim_contract|##\s*Data/Sim delegate:'
	$hasDelegateHeader = $text -match '##\s*Data/Sim delegate:'
	$delegateInfo = $null
	if ($hasDelegateHeader -and $ProjectRoot -ne '') {
		$delegateInfo = Get-DelegateHarnessBody -ProjectRoot $ProjectRoot -ScenarioText $text
	}
	$delegateBody = if ($null -ne $delegateInfo) { $delegateInfo.Body } else { '' }
	$hasLayerBLocal = Test-TextHasLayerBProof -Text $text
	$hasLayerBDelegate = Test-TextHasLayerBProof -Text $delegateBody
	$hasLayerB = $hasLayerBLocal -or $hasLayerBDelegate
	$hasLayerCLocal = Test-TextHasLayerCCommitProof -Text $text
	$hasLayerC = $hasLayerCLocal
	$thinDelegate = (
		($text -match 'run_ability_row\s*\(' -and -not $hasDelegateHeader -and -not $hasLayerA) -or
		($text -match 'run_single_ability\s*\(' -and -not $hasDelegateHeader -and -not $hasLayerA) -or
		($text -match 'factory_passive\s*\([^)]+\)\s*!=\s*null' -and -not $hasLayerB)
	)
	$runAllLines = ([regex]::Matches($text, '(?ms)static func run_all.*?(?=static func|\z)')).Value
	$runAllBody = if ($runAllLines.Count -gt 0) { $runAllLines[0] } else { $text }
	$runAllOnlyDelegate = (
		$runAllBody -match 'run_ability_row|run_single_ability' -and
		$runAllBody -notmatch 'assert_|_sim_contract|_data_contract|_phase|PlanningChecklistHarness|movement_planning_smoke|wire_board'
	)
	$abilityUsedOnly = (
		$text -match 'ABILITY_USED' -and
		-not (Test-TextHasLayerBProof -Text $text) -and
		-not $hasLayerBDelegate
	)
	if ($thinDelegate -or $runAllOnlyDelegate) {
		$errors += "${ScenarioRelPath}: thin harness delegate"
	}
	if ($abilityUsedOnly) {
		$errors += "${ScenarioRelPath}: ABILITY_USED-only smoke (no outcome proof)"
	}
	if ($hasDelegateHeader -and $null -eq $delegateInfo) {
		$errors += "${ScenarioRelPath}: Data/Sim delegate header missing or unparseable harness function"
	}
	if ($hasDelegateHeader -and $null -ne $delegateInfo -and -not $hasLayerBDelegate) {
		$errors += "${ScenarioRelPath}: delegate $($delegateInfo.FuncName) in $($delegateInfo.RelPath) lacks sim/outcome proof"
	}
	if ($isSkill -and -not $hasLayerA) {
		$errors += "${ScenarioRelPath}: missing Layer A (_data_contract, _sim_contract, or Data/Sim delegate header)"
	}
	if ($isSkill -and -not $hasLayerB) {
		$errors += "${ScenarioRelPath}: missing Layer B sim/outcome proof (local or delegate harness)"
	}
	if ($isSkill -and -not $hasLayerC) {
		$errors += "${ScenarioRelPath}: missing Layer C planning commit proof (assert_commit_no_jump, assert_slots_match_preview_commit, movement_planning_smoke, or Tier A phases)"
	}
	if ($isPassive -and -not $hasLayerB) {
		$errors += "${ScenarioRelPath}: passive missing sim trigger/outcome proof"
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
		$errors += Test-ScenarioContractShallow -ScenarioRelPath $rel -FullPath $full -ProjectRoot $ProjectRoot
	}
	return $errors
}
