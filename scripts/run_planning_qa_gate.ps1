# Shim - forwards to scripts/qa/run_planning_qa_gate.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
$gate = Join-Path $PSScriptRoot "qa\run_planning_qa_gate.ps1"
if ($null -eq $Rest -or @($Rest).Count -eq 0) {
	& $gate
} else {
	& $gate @Rest
}
exit $LASTEXITCODE
