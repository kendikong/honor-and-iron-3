# Shim - forwards to scripts/qa/run_beast_rider_qa_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_beast_rider_qa_gate.ps1") @Rest
exit $LASTEXITCODE
