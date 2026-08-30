# Shim - forwards to scripts/qa/run_layer_shape_conversion_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_layer_shape_conversion_gate.ps1") @Rest
exit $LASTEXITCODE
