# Shim - forwards to scripts/qa/run_lancer_qa_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_lancer_qa_gate.ps1") @Rest
exit $LASTEXITCODE
