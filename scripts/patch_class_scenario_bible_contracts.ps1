# Shim - forwards to scripts/qa/patch_class_scenario_bible_contracts.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\patch_class_scenario_bible_contracts.ps1") @Rest
exit $LASTEXITCODE
