# Shim - forwards to scripts/qa/run_bruiser_live_qa.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_bruiser_live_qa.ps1") @Rest
exit $LASTEXITCODE
