# Shim - forwards to scripts/qa/validate_qa_mutations.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\validate_qa_mutations.ps1") @Rest
exit $LASTEXITCODE
