# Validate the canonical planning-preview truth matrix and its executable owners.
# Usage: .\scripts\lint_planning_truth_matrix.ps1
param(
	[string]$MatrixPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "canvases\planning-preview-truth-matrix.canvas.tsx")
)

$ErrorActionPreference = "Stop"
$failures = @()

if (-not (Test-Path $MatrixPath)) {
	$failures += "matrix file missing: $MatrixPath"
} else {
	$content = Get-Content -Path $MatrixPath -Raw
	$scenarioMatches = [regex]::Matches(
		$content,
		'(?m)^\s*\["(?<id>[^"]+)"\s*,\s*"[^"]*"\s*,\s*"(?<owner>[^"]+)"\s*\]'
	)
	$scenarioIds = @($scenarioMatches | ForEach-Object { $_.Groups["id"].Value })
	foreach ($match in $scenarioMatches) {
		$scenarioId = $match.Groups["id"].Value
		$owner = $match.Groups["owner"].Value
		if ($owner -notmatch '^tests/[^:]+::[^:]+$') {
			$failures += "$scenarioId : missing concrete file::function owner"
		}
	}
	$checkpointBlock = [regex]::Match(
		$content,
		'const checkpoints = \[(?<body>.*?)\];',
		[Text.RegularExpressions.RegexOptions]::Singleline
	).Groups["body"].Value
	$dimensionBlock = [regex]::Match(
		$content,
		'const atomicDimensions = \[(?<body>.*?)\];',
		[Text.RegularExpressions.RegexOptions]::Singleline
	).Groups["body"].Value
	$checkpointCount = @([regex]::Matches($checkpointBlock, '"[^"]+"')).Count
	$dimensionCount = @([regex]::Matches($dimensionBlock, '"[^"]+"')).Count
	if ($content -notmatch 'const scenarioFacts') {
		$failures += "scenarioFacts bank missing"
	}
	if ($content -notmatch 'const atomicRows') {
		$failures += "atomic row enumeration missing"
	}

	if ($scenarioIds.Count -ne 41) {
		$failures += "expected 41 scenarios, found $($scenarioIds.Count)"
	}
	if ($checkpointCount -ne 17) {
		$failures += "expected 17 checkpoints, found $checkpointCount"
	}
	if ($dimensionCount -ne 40) {
		$failures += "expected 40 dimensions, found $dimensionCount"
	}
	$total = $scenarioIds.Count * $checkpointCount * $dimensionCount
	if ($total -ne 27880) {
		$failures += "expected 27,880 atomic rows, calculated $total"
	}

	$ownerMatches = [regex]::Matches($content, '"(?<owner>tests/[^"]+::[^"]+)"')
	foreach ($match in $ownerMatches) {
		$owner = $match.Groups["owner"].Value
		$parts = $owner -split "::", 2
		$relativePath = $parts[0]
		$functionName = $parts[1]
		$absolutePath = Join-Path (Split-Path -Parent $PSScriptRoot) $relativePath
		if (-not (Test-Path $absolutePath)) {
			$failures += "$owner : owner file missing"
			continue
		}
		$ownerContent = Get-Content -Path $absolutePath -Raw
		if ($ownerContent -notmatch "(?m)\bfunc\s+$([regex]::Escape($functionName))\s*\(") {
			$failures += "$owner : owner function missing"
		}
	}
}

if ($failures.Count -gt 0) {
	Write-Output "[FAIL] lint_planning_truth_matrix: $($failures.Count) issue(s)"
	$failures | ForEach-Object { Write-Output "  $_" }
	exit 1
}

Write-Output "[PASS] lint_planning_truth_matrix: 41 scenarios × 17 checkpoints × 40 dimensions; owners resolve"
exit 0
