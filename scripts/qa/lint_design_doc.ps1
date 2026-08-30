# Minimal design-doc linter for docs/design/ gauntlet W1 bar.
# Usage: .\scripts\lint_design_doc.ps1
param(
	[string]$DesignDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "docs\design")
)

$ErrorActionPreference = "Stop"
$failures = @()

$exempt = @(
	"workbench.md",
	"UNATTENDED_RUN.md",
	"README.md",
	"00-gauntlet-loop-cursor.md",
	"_TEMPLATE.md",
	"GAUNTLET_REVIEW_RESULTS.md"
)

$requiredHeadings = @("## Goal", "## Quality bar")

$dirs = @(
	$DesignDir,
	(Join-Path $DesignDir "appendices")
)

foreach ($dir in $dirs) {
	if (-not (Test-Path $dir)) { continue }
	Get-ChildItem -Path $dir -Filter "*.md" -File | ForEach-Object {
	$name = $_.Name
	if ($exempt -contains $name) {
		return
	}
	$content = Get-Content -Path $_.FullName -Raw
	if ($content -notmatch '\*\*Status:\*\*') {
		$failures += "$name : missing **Status:** line"
	}
	foreach ($h in $requiredHeadings) {
		if ($content -notmatch [regex]::Escape($h)) {
			$failures += "$name : missing heading $h"
		}
	}
	}
}

if ($failures.Count -gt 0) {
	Write-Output "[FAIL] lint_design_doc: $($failures.Count) issue(s)"
	$failures | ForEach-Object { Write-Output "  $_" }
	exit 1
}

Write-Output "[PASS] lint_design_doc: exempt list OK; pillar files will be checked when added"
exit 0
