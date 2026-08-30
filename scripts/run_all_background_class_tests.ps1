# Shim - forwards to scripts/qa/run_all_background_class_tests.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_all_background_class_tests.ps1") @Rest
exit $LASTEXITCODE
