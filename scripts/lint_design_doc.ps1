# Shim - forwards to scripts/qa/lint_design_doc.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\lint_design_doc.ps1") @Rest
exit $LASTEXITCODE
