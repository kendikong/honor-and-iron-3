# Shim - forwards to scripts/qa/lint_planning_truth_matrix.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\lint_planning_truth_matrix.ps1") @Rest
exit $LASTEXITCODE
