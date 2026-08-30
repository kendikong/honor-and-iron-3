# Shim - forwards to scripts/qa/run_regression_tests.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_regression_tests.ps1") @Rest
exit $LASTEXITCODE
