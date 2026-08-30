# Shim - forwards to scripts/qa/run_monk_live_qa.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_monk_live_qa.ps1") @Rest
exit $LASTEXITCODE
