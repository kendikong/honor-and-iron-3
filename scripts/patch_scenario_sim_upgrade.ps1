# Shim - forwards to scripts/qa/patch_scenario_sim_upgrade.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\patch_scenario_sim_upgrade.ps1") @Rest
exit $LASTEXITCODE
