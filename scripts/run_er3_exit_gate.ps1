# Shim - forwards to scripts/qa/run_er3_exit_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_er3_exit_gate.ps1") @Rest
exit $LASTEXITCODE
