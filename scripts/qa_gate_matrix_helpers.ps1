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
