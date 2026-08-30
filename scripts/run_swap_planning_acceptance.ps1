# Shim - forwards to scripts/qa/run_swap_planning_acceptance.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_swap_planning_acceptance.ps1") @Rest
exit $LASTEXITCODE
