# Shim - forwards to scripts/qa/run_k4_preview_compare.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_k4_preview_compare.ps1") @Rest
exit $LASTEXITCODE
