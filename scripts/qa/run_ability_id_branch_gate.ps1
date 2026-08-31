param(
	[string[]]$ScanRoots = @("presentation", "core")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "ssot_gate_helpers.ps1")

Write-Output "=== Ability ID branch SSOT gate (production) ==="
Write-Output "Forbids per-skill literal ability identity branches in presentation/ and core/."

$failures = New-Object System.Collections.Generic.List[string]

$contract = "ability_data_driven"
$owner = "AbilityData + AbilitySystem + DataLibrary predicates"
$forbidden = @(
	@{ Rule = "literal_if_identity"; Pattern = '\b(if|elif)\s+(?:action\.)?ability\.id\s*==\s*["&]' },
	@{ Rule = "literal_return_identity"; Pattern = '\breturn\s+(?:action\.)?ability\.id\s*==\s*["&]' },
	@{ Rule = "literal_membership_identity"; Pattern = '(?:action\.)?ability\.id\s+in\s*\[[^\]]*["&]' }
)

foreach ($rootName in $ScanRoots) {
	$root = if ([IO.Path]::IsPathRooted($rootName)) {
		$rootName
	} else {
		Join-Path $projectRoot $rootName
	}
	if (-not (Test-Path -LiteralPath $root)) {
		Add-SsotViolation $failures $contract "resource" "scan_root_missing" $rootName 0 `
			$owner "ability-id scan" "Restore the production scan root."
		continue
	}
	$files = Get-ChildItem -LiteralPath $root -Recurse -Filter "*.gd" -File
	foreach ($file in $files) {
		$rel = Get-SsotRelativePath $projectRoot $file.FullName
		$lines = Get-Content -LiteralPath $file.FullName
		for ($i = 0; $i -lt $lines.Count; $i++) {
			$line = $lines[$i]
			if ($line -match '^\s*#') { continue }
			foreach ($pat in $forbidden) {
				if ($line -match $pat.Pattern) {
					Add-SsotViolation $failures $contract "heuristic" $pat.Rule `
						$rel ($i + 1) $owner "literal ability-id branch in production" `
						"Use AbilityData fields or a shared DataLibrary/AbilitySystem predicate."
				}
			}
			if ($line -match '\bmatch\s+(?:action\.)?ability\.id\s*:') {
				for ($j = $i + 1; $j -lt [Math]::Min($i + 8, $lines.Count); $j++) {
					if ($lines[$j] -match '^\s*(?:&)?["][A-Za-z0-9_]+["]\s*:') {
						Add-SsotViolation $failures $contract "heuristic" "literal_match_identity" `
							$rel ($i + 1) $owner "literal ability-id match branch in production" `
							"Move the distinction into shared data or a category predicate."
						break
					}
					if ($lines[$j] -match '^\S' -and $lines[$j] -notmatch '^\s*#') {
						break
					}
				}
			}
		}
	}
}

Write-SsotGateResult "Ability ID branch gate" $failures
if ($failures.Count -gt 0) {
	exit 1
}
exit 0
