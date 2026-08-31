$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate = Join-Path $PSScriptRoot "run_ability_id_branch_gate.ps1"
$fixtureRoot = Join-Path $PSScriptRoot "fixtures\ability_id"

Write-Output "=== Ability ID branch gate self-test ==="
$output = @(& $gate -ScanRoots $fixtureRoot 2>&1)
$exitCode = $LASTEXITCODE
$joined = $output -join "`n"

$requiredRules = @(
	"literal_if_identity",
	"literal_return_identity",
	"literal_membership_identity",
	"literal_match_identity"
)
$failures = New-Object System.Collections.Generic.List[string]
if ($exitCode -eq 0) {
	$failures.Add("[FAIL] fixture violations were not rejected")
}
foreach ($rule in $requiredRules) {
	if ($joined -notmatch ('rule="' + [regex]::Escape($rule) + '"')) {
		$failures.Add("[FAIL] missing fixture detection: $rule")
	}
}
if ($joined -match "allowed\.gd") {
	$failures.Add("[FAIL] allowed fixture produced a false positive")
}

if ($failures.Count -gt 0) {
	Write-Output "--- Ability ID branch self-test: FAIL ---"
	$failures | ForEach-Object { Write-Output $_ }
	exit 1
}

Write-Output "--- Ability ID branch self-test: PASS ---"
exit 0
