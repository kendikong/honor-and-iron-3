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
	$effective_min = $MinScore
	if (-not $PSBoundParameters.ContainsKey("MinScore") -and $null -ne $manifest.pass_threshold) {
		$effective_min = [int]$manifest.pass_threshold
	}
	if ($null -ne $manifest.pass_threshold -and [int]$manifest.pass_threshold -gt $effective_min) {
		$errors += "manifest pass_threshold $([int]$manifest.pass_threshold) -gt gate minimum $effective_min"
	}
	if ($null -ne $manifest.last_score -and [int]$manifest.last_score -lt $effective_min) {
		$errors += "manifest last_score $([int]$manifest.last_score) -lt minimum $effective_min"
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

function Get-FuncBodyFromGdFile {
	param(
		[string]$FullPath,
		[string]$FuncName
	)
	if (-not (Test-Path $FullPath)) { return '' }
	$harnessText = Get-Content -Path $FullPath -Raw
	$funcMatch = [regex]::Match(
		$harnessText,
		"(?ms)static func $FuncName\s*\([^\)]*\)\s*->\s*void:\s*(.*?)(?=\nstatic func |\z)"
	)
	if (-not $funcMatch.Success) { return '' }
	return $funcMatch.Groups[1].Value
}

function Get-ScenarioPreloadMap {
	param([string]$ScenarioText)
	$map = @{}
	$matches = [regex]::Matches($ScenarioText, 'const\s+(\w+)\s*:=\s*preload\("([^"]+)"\)')
	foreach ($m in $matches) {
		$map[$m.Groups[1].Value] = $m.Groups[2].Value
	}
	return $map
}

function Get-ScenarioEffectiveSimText {
	param(
		[string]$ProjectRoot,
		[string]$ScenarioText,
		[string]$DelegateBody
	)
	$combined = $ScenarioText + "`n" + $DelegateBody
	$preloadMap = Get-ScenarioPreloadMap -ScenarioText $ScenarioText
	$simBlockMatch = [regex]::Match(
		$ScenarioText,
		'(?ms)static func _sim_(?:contract|trigger|upgrade)\s*\([^\)]*\)\s*->\s*void:\s*(.*?)(?=\nstatic func |\z)'
	)
	$simBlock = if ($simBlockMatch.Success) { $simBlockMatch.Groups[1].Value } else { $ScenarioText }
	$callMatches = [regex]::Matches($simBlock, '(\w+)\.(run_[A-Za-z0-9_]+)\s*\(')
	foreach ($call in $callMatches) {
		$alias = $call.Groups[1].Value
		$func = $call.Groups[2].Value
		if (-not $preloadMap.ContainsKey($alias)) { continue }
		$rel = $preloadMap[$alias] -replace '^res://', '' -replace '/', '\'
		$full = Join-Path $ProjectRoot $rel
		$body = Get-FuncBodyFromGdFile -FullPath $full -FuncName $func
		$body = Expand-NestedHarnessBodies -FullPath $full -Body $body -Depth 0
		$combined += "`n" + $body
	}
	$idMatch = [regex]::Match($ScenarioText, 'run_for_factory\(failures,\s*&"([^"]+)"\)')
	if ($idMatch.Success) {
		$factoryId = $idMatch.Groups[1].Value
		$class = ($factoryId -split '_')[0]
		$row = $factoryId -replace "^${class}_", ''
		$upgradeRel = "tests\${class}_qa_harness_upgrades.gd"
		$upgradeFull = Join-Path $ProjectRoot $upgradeRel
		if (Test-Path $upgradeFull) {
			$combined += "`n" + (Get-FuncBodyFromGdFile -FullPath $upgradeFull -FuncName 'run_upgrade_for')
			$combined += "`n" + (Get-FuncBodyFromGdFile -FullPath $upgradeFull -FuncName ("run_${row}_upgrade"))
		}
	}
	return $combined
}

function Expand-NestedHarnessBodies {
	param(
		[string]$FullPath,
		[string]$Body,
		[int]$Depth
	)
	if ($Depth -gt 4 -or [string]::IsNullOrWhiteSpace($Body)) { return $Body }
	$expanded = $Body
	$nested = [regex]::Matches($Body, '\b(_sim_[A-Za-z0-9_]+|_sim_basic_attack_with_passive|_assert_[A-Za-z0-9_]+|_run_passive_trigger|_run_passive_blocks|run_single_passive|_simulate_active_ability)\s*\(')
	foreach ($n in $nested) {
		$fname = $n.Groups[1].Value
		$nestedBody = Get-FuncBodyFromGdFile -FullPath $FullPath -FuncName $fname
		if ($nestedBody -ne '') {
			$expanded += "`n" + (Expand-NestedHarnessBodies -FullPath $FullPath -Body $nestedBody -Depth ($Depth + 1))
		}
	}
	return $expanded
}

function Test-TextHasOutcomeProof {
	param([string]$Text)
	# Dead-code heal tokens in cleric harness do not count without outcome/heal assert path.
	if ($Text -match 'UNIT_HEALED' -and $Text -notmatch 'outcome/heal|sim/.+/outcome/heal|ClassScenarioSimOutcome') {
		if ($Text -match '_assert_cleric_outcome' -and $Text -notmatch 'has_heal_effect|outcome/heal') {
			# Allow only when heal branch is structurally present in expanded harness text.
		}
	}
	$pattern = 'unit_hp|health\.current_hp|dmg_dealt|damage_dealt|enemy_damage|UNIT_DAMAGED|has_status|get_affected_tiles|assert_sim_footprint|assert_grid_footprint|footprint|simulate_plan|final_state\.get_unit|AbilitySystem\.execute|get_ability_range|outcome/|_assert_live_outcome|_assert_cleric_outcome|ClassScenarioSimOutcome|get_dynamic_strength|aoe_hits|outside_excluded|with_upgraded_ability|is_ability_upgraded|upgrade/profile|outcome/heal|has_heal_effect'
	if ($Text -match $pattern) { return $true }
	if ($Text -match 'UNIT_HEALED') { return $false }
	return $false
}

function Test-TextHasPassiveOutcomeProof {
	param([string]$Text)
	if (Test-TextHasOutcomeProof -Text $Text) { return $true }
	if ($Text -match '_sim_basic_attack_with_passive') { return $false }
	# Metadata-only factory checks are not passive outcome proof (CLASS_QA_BIBLE §3 Layer B).
	if ($Text -match 'modifiers\.has\(|modifiers\.get\(|passive/\S+/promotion|factory/passive') {
		if (-not ($Text -match 'Simulator\.|simulate_player_turn|AbilitySystem\.(execute|can_use)|CombatSystem\.|MovementSystem\.|UNIT_DAMAGED|UNIT_HEALED|health\.current_hp|has_status|passive_flags|_recalculate_stats|get_ability_range|terrain_payloads')) {
			return $false
		}
	}
	return (
		$Text -match 'Simulator\.|simulate_player_turn|AbilitySystem\.(execute|can_use)|CombatSystem\.|MovementSystem\.|UNIT_DAMAGED|UNIT_HEALED|health\.current_hp|has_status|passive_flags|get_ability_range|terrain_payloads|final_state\.get_unit|run_[a-z_]+_proof'
	)
}

function Test-TextHasUpgradeProof {
	param([string]$Text)
	if (-not ($Text -match '_sim_upgrade|ClassScenarioUpgradeRegistry|run_upgrade_for|run_.*_upgrade|run_upgrade_sim_for')) {
		return $false
	}
	if ($Text -match 'upgrade/compiled' -and -not (Test-TextHasOutcomeProof -Text $Text)) {
		return $false
	}
	return $true
}

function Test-TextHasFootprintProof {
	param([string]$Text)
	return (
		$Text -match 'get_affected_tiles|assert_sim_footprint|assert_grid_footprint|assert_footprint|AoeFootprintQaHarness|assert_red_contract|footprint|aoe_hits|outside_excluded|footprint_tiles'
	)
}

function Get-FactoryHasUpgrade {
	param(
		[string]$ProjectRoot,
		[string]$FactoryId
	)
	if ([string]::IsNullOrWhiteSpace($FactoryId)) { return $false }
	$class = ($FactoryId -split '_')[0]
	$row = $FactoryId -replace "^${class}_", ''
	$factoryPath = Join-Path $ProjectRoot ("core\factory\classes\${class}_factory.gd")
	if (-not (Test-Path $factoryPath)) { return $false }
	$text = Get-Content -Path $factoryPath -Raw
	$funcPattern = "(?ms)func\s+_$row\s*\([^\)]*\)[^{]*\{[\s\S]{0,6000}?(upgraded_effects|upgraded_modules|upgrade_description)"
	if ($text -match $funcPattern) { return $true }
	$escaped = [regex]::Escape($FactoryId)
	return ($text -match "(?ms)&`"$escaped`"[\s\S]{0,4000}?(upgraded_effects|upgraded_modules|upgrade_description)")
}

function Get-FactoryIsShaped {
	param(
		[string]$ProjectRoot,
		[string]$FactoryId
	)
	if ([string]::IsNullOrWhiteSpace($FactoryId)) { return $false }
	$class = ($FactoryId -split '_')[0]
	$row = $FactoryId -replace "^${class}_", ''
	$factoryPath = Join-Path $ProjectRoot ("core\factory\classes\${class}_factory.gd")
	if (-not (Test-Path $factoryPath)) { return $false }
	$text = Get-Content -Path $factoryPath -Raw
	$funcPattern = "(?ms)func\s+_$row\s*\([^\)]*\)[^{]*\{[\s\S]{0,8000}?target_shape\s*=\s*GameEnums\.TargetShape\.(\w+)"
	if ($text -match $funcPattern) {
		$shape = $Matches[1]
		return ($shape -ne 'SINGLE')
	}
	return $false
}

function Test-TextHasLayerBProof {
	param([string]$Text)
	if (Test-TextHasOutcomeProof -Text $Text) { return $true }
	$structural = 'Simulator\.|simulate_plan|run_.*_base_sim|run_bash_|_Scenarios\.run_|_Passives\.run_|get_affected_tiles|final_state\.|assert_sim_footprint'
	return ($Text -match $structural)
}

function Test-TextHasBlueTileProof {
	param([string]$Text)
	return (
		$Text -match 'collect_blue_tiles|blue_move|blue_tiles|movement_planning_smoke|assert_move_preview_origin|run_premove|_phase3_pathing|_phase7|wire_board|class_scenario_planning_contract|_Planning\.run_for_factory'
	)
}

function Test-TextHasPremoveProof {
	param([string]$Text)
	return (
		$Text -match 'movement_planning_smoke|run_premove|premove_planner|premove|_phase7|ModulePhase\.ON_PRE|assert_move_preview_origin|class_scenario_planning_contract|_Planning\.run_for_factory'
	)
}

function Test-TextHasPostmoveProof {
	param([string]$Text)
	# _Planning.run_for_factory alone is insufficient — require explicit post-move leg proof.
	if ($Text -match '_Planning\.run_for_factory') {
		return (
			$Text -match 'postmove_cell|commit_run_postmove|_run_postmove|run_planning_postmove|MovementPlanningSmokeRegistry\.run_for_factory_id'
		)
	}
	return (
		$Text -match 'postmove|ON_POST|commit_run_postmove|postmove_cell|assert_move_preview_origin|movement_planning_smoke|MovementPlanningSmokeRegistry'
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
	$idMarker = "&`"$escaped`""
	$idPos = $text.IndexOf($idMarker)
	if ($idPos -lt 0) { return $none }
	$start = $text.LastIndexOf("static func _", $idPos)
	if ($start -lt 0) { $start = 0 }
	$nextFunc = $text.IndexOf("static func _", $idPos + $idMarker.Length)
	$snippet = if ($nextFunc -ge 0) {
		$text.Substring($start, $nextFunc - $start)
	} else {
		$text.Substring($start)
	}
	$isPreMove = $snippet -match 'PlannerGroup\.PRE_MOVE'
	$hasOnPre = $snippet -match 'ModulePhase\.ON_PRE'
	$hasOnPost = $snippet -match 'ModulePhase\.ON_POST'
	$hasMoveEffect = $snippet -match 'EffectType\.(MOVE|MOVE_INTO_AND_PUSH|DASH)\b'
	$hasNewAim = $snippet -match 'AimBinding\.NEW_AIM'
	$isAction = $snippet -match 'PlannerGroup\.ACTION'
	return @{
		NeedsBlue = ($isPreMove -or $hasMoveEffect -or $hasOnPre)
		NeedsPremove = ($isPreMove -or $hasOnPre)
		NeedsPostmove = ($hasOnPost -or ($isAction -and $hasMoveEffect -and $hasNewAim))
	}
}

function Test-TextHasLayerCCommitProof {
	param([string]$Text)
	$commitPattern = 'assert_commit_no_jump|assert_slots_match_preview_commit|run_planning_commit_smoke|movement_planning_smoke|assert_red_contract|assert_move_preview|assert_committed_ghost|wire_board'
	$intentPattern = 'PlanningIntentContractE2ETest|run_planning_select_smoke|_planning_bowling|planning intent E2E|class_scenario_planning_contract|_Planning\.run_for_factory'
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
		[string]$FactoryId = '',
		[bool]$KnightPlanningViaFixtureSuite = $false
	)
	$errors = @()
	if (-not (Test-Path $FullPath)) {
		return @("${ScenarioRelPath}: missing file")
	}
	$text = Get-Content -Path $FullPath -Raw
	$isSkill = $ScenarioRelPath -match 'tests/skills/'
	$isPassive = $ScenarioRelPath -match 'tests/passives/'
	$hasLayerA = $text -match '_data_contract|_sim_contract|_sim_trigger|__sim_contract|__sim_trigger|##\s*Data/Sim delegate:'
	$hasDelegateHeader = $text -match '##\s*Data/Sim delegate:'
	$delegateInfo = $null
	if ($hasDelegateHeader -and $ProjectRoot -ne '') {
		$delegateInfo = Get-DelegateHarnessBody -ProjectRoot $ProjectRoot -ScenarioText $text
	}
	$delegateBody = if ($null -ne $delegateInfo) { $delegateInfo.Body } else { '' }
	$effectiveSimText = if ($ProjectRoot -ne '') {
		Get-ScenarioEffectiveSimText -ProjectRoot $ProjectRoot -ScenarioText $text -DelegateBody $delegateBody
	} else {
		$text + "`n" + $delegateBody
	}
	$planningText = $text + "`n" + $delegateBody
	$factoryFlags = if ($ProjectRoot -ne '' -and $FactoryId -ne '') {
		Get-FactoryPlanningFlags -ProjectRoot $ProjectRoot -FactoryId $FactoryId
	} else {
		@{ NeedsBlue = $false; NeedsPremove = $false; NeedsPostmove = $false }
	}
	$hasLayerBLocal = Test-TextHasLayerBProof -Text $effectiveSimText
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
		($effectiveSimText -match '_sim_ability_used|events_have_ability|run_single_ability|run_ability_row') -and
		-not (Test-TextHasOutcomeProof -Text $effectiveSimText)
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
	if ($isSkill -and -not $KnightPlanningViaFixtureSuite -and -not $hasLayerC) {
		$errors += "${ScenarioRelPath}: missing Layer C planning commit proof (assert_commit_no_jump, assert_slots_match_preview_commit, movement_planning_smoke, Tier A phases, or Tier C intent E2E)"
	}
	if ($isSkill -and -not $KnightPlanningViaFixtureSuite -and $factoryFlags.NeedsBlue -and -not (Test-TextHasBlueTileProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory requires blue move-tile proof (collect_blue_tiles, movement_planning_smoke, or assert_move_preview_origin)"
	}
	if ($isSkill -and -not $KnightPlanningViaFixtureSuite -and $factoryFlags.NeedsPremove -and -not (Test-TextHasPremoveProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory PRE_MOVE/ON_PRE requires premove planning proof"
	}
	if ($isSkill -and -not $KnightPlanningViaFixtureSuite -and $factoryFlags.NeedsPostmove -and -not (Test-TextHasPostmoveProof -Text $planningText)) {
		$errors += "${ScenarioRelPath}: factory ON_POST/MOVE+skill requires postmove planning proof"
	}
	if ($isPassive -and -not (Test-TextHasPassiveOutcomeProof -Text $effectiveSimText)) {
		$errors += "${ScenarioRelPath}: passive missing sim trigger/outcome proof"
	}
	if ($isSkill -and (Get-FactoryHasUpgrade -ProjectRoot $ProjectRoot -FactoryId $FactoryId) -and -not (Test-TextHasUpgradeProof -Text ($text + "`n" + $effectiveSimText))) {
		$errors += "${ScenarioRelPath}: factory has [+] upgrade data but scenario lacks _sim_upgrade / upgrade sim proof"
	}
	if ($isSkill -and (Get-FactoryIsShaped -ProjectRoot $ProjectRoot -FactoryId $FactoryId) -and -not (Test-TextHasFootprintProof -Text ($effectiveSimText + "`n" + $text))) {
		$errors += "${ScenarioRelPath}: shaped factory row lacks footprint / blast tile proof"
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
	$knightPlanningViaFixture = $MatrixDocPath -match 'KNIGHT_QA_GATE'
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
		$errors += Test-ScenarioContractShallow -ScenarioRelPath $rel -FullPath $full -ProjectRoot $ProjectRoot -FactoryId $factoryId -KnightPlanningViaFixtureSuite:$knightPlanningViaFixture
	}
	return $errors
}
