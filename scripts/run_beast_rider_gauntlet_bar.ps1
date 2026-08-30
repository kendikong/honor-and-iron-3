# Shim - forwards to scripts/qa/run_beast_rider_gauntlet_bar.ps1
param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
& (Join-Path $PSScriptRoot "qa\run_beast_rider_gauntlet_bar.ps1") @Rest
exit $LASTEXITCODE
