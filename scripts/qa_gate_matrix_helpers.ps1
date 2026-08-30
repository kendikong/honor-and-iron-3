# Shim - forwards to scripts/qa/qa_gate_matrix_helpers.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\qa_gate_matrix_helpers.ps1") @Rest
exit $LASTEXITCODE
