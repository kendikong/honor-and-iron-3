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
	$pattern = 'Simulator\.|AbilitySystem\.|simulate_player_turn|simulate_plan|SimResult|run_sim_|_sim_base|run_bash_|run_single_passive|final_state\.|unit_hp|assert_.*dmg|assert_.*damage|get_unit_by_id'
	return ($Text -match $pattern)
}

function Test-TextHasBlueTileProof {
	param([string]$Text)
	return (
		$Text -match 'collect_blue_tiles|blue_move|blue_tiles|movement_planning_smoke|assert_move_preview_origin|run_premove|_phase3_pathing|_phase7|wire_board'
	)
}

function Test-TextHasPremoveProof {
	param([string]$Text)
	return (
		$Text -match 'movement_planning_smoke|run_premove|premove_planner|premove|_phase7|ModulePhase\.ON_PRE|assert_move_preview_origin'
	)
}

function Test-TextHasPostmoveProof {
	param([string]$Text)
	return (
		$Text -match 'postmove|ON_POST|assert_move_preview_origin|movement_planning_smoke|_run_postmove'
	)
}

function Get-FactoryPlanningFlags {
	param(
		[string]$ProjectRoot,
		[string]$FactoryId
	)
	$none = @{
		NeedsBlue = $false
		NeedsPremove = $false
		NeedsPostmove = $false
	}
	if ([string]::IsNullOrWhiteSpace($FactoryId)) { return $none }
	$class = ($FactoryId -split '_')[0]
	$factoryPath = Join-Path $ProjectRoot ("core\factory\classes\${class}_factory.gd")
	if (-not (Test-Path $factoryPath)) { return $none }
	$text = Get-Content -Path $factoryPath -Raw
	$escaped = [regex]::Escape($FactoryId)
	$match = [regex]::Match($text, "(?ms)(.{0,2000})&`"$escaped`"\s*,[^\)]*\)")
	if (-not $match.Success) { return $none }
	$snippet = $match.Groups[1].Value + $match.Value
	$isPreMove = $snippet -match 'PlannerGroup\.PRE_MOVE'
	$hasOnPre = $snippet -match 'ModulePhase\.ON_PRE'
	$hasOnPost = $snippet -match 'ModulePhase\.ON_POST'
	$hasMoveEffect = $snippet -match 'EffectType\.(MOVE|MOVE_INTO_AND_PUSH|DASH)\b'
	$isAction = $snippet -match 'PlannerGroup\.ACTION'
	return @{
		NeedsBlue = ($isPreMove -or $hasMoveEffect -or $hasOnPre)
		NeedsPremove = ($isPreMove -or $hasOnPre)
		NeedsPostmove = ($hasOnPost -or ($isAction -and $hasMoveEffect))
	}
}

function Test-TextHasLayerCCommitProof {
	param([string]$Text)
	$commitPattern = 'assert_commit_no_jump|assert_slots_match_preview_commit|run_planning_commit_smoke|movement_planning_smoke|assert_red_contract|assert_move_preview|assert_committed_ghost|wire_board'
	$intentPattern = 'PlanningIntentContractE2ETest|run_planning_select_smoke|_planning_bowling|planning intent E2E'
	return (
		($Text -match $commitPattern) -or
		(($Text -match '_phase[1-9]') -and ($Text -match 'PlanningChecklistHarness')) -or
		($Text -match $intentPattern)
	)
}

function Test-ScenarioContractShallow {
	param(
		[string]$ScenarioRelPath,
		[string]$FullPath,
		[string]$ProjectRoot = '',
		[string]$FactoryId = ''
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
	$planningText = $text + "`n" + $delegateBody
	$factoryFlags = if ($ProjectRoot -ne '' -and $FactoryId -ne '') {
		Get-FactoryPlanningFlags -ProjectRoot $ProjectRoot -FactoryId $FactoryId
	} else {
		@{ NeedsBlue = $false; NeedsPremove = $false; NeedsPostmove = $false }
	}
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
		$errors += "${ScenarioRelPath}: missing Layer C planning commit proof (assert_commit_no_jump, assert_slots_match_preview_commit, movement_planning_smoke, Tier A phases, or Tier C intent E2E)"
	}
	if ($isSkill -and $factoryFlags.NeedsBlue -and -not (Test-TextHasBlueTileProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory requires blue move-tile proof (collect_blue_tiles, movement_planning_smoke, or assert_move_preview_origin)"
	}
	if ($isSkill -and $factoryFlags.NeedsPremove -and -not (Test-TextHasPremoveProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory PRE_MOVE/ON_PRE requires premove planning proof"
	}
	if ($isSkill -and $factoryFlags.NeedsPostmove -and -not (Test-TextHasPostmoveProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory ON_POST/MOVE+skill requires postmove planning proof"
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
		$factoryId = ''
		$idMatch = [regex]::Match($line, '`\s*([a-z][a-z0-9_]*)\s*`')
		if ($idMatch.Success) { $factoryId = $idMatch.Groups[1].Value }
		$errors += Test-ScenarioContractShallow -ScenarioRelPath $rel -FullPath $full -ProjectRoot $ProjectRoot -FactoryId $factoryId
	}
	return $errors
}
