# Shim - forwards to scripts/qa/validate_live_planning_mutation.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\validate_live_planning_mutation.ps1") @Rest
exit $LASTEXITCODE
