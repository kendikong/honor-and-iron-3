# Shim - forwards to scripts/qa/run_bible_alignment_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_bible_alignment_gate.ps1") @Rest
exit $LASTEXITCODE
