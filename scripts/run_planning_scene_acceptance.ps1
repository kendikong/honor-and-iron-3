# Shim - forwards to scripts/qa/run_planning_scene_acceptance.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_planning_scene_acceptance.ps1") @Rest
exit $LASTEXITCODE
