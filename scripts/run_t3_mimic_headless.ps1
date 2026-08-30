# Shim - forwards to scripts/qa/run_t3_mimic_headless.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_t3_mimic_headless.ps1") @Rest
exit $LASTEXITCODE
