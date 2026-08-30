# Shim - forwards to scripts/qa/run_hover_preview_ssot_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_hover_preview_ssot_gate.ps1") @Rest
exit $LASTEXITCODE
