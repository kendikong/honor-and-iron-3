# Shim - forwards to scripts/qa/qa_window_placement.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\qa_window_placement.ps1") @Rest
exit $LASTEXITCODE
