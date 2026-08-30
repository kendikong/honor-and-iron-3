# Regenerate scripts/*.ps1 shims that forward to scripts/qa/
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$qaDir = Join-Path $root "scripts\qa"
Get-ChildItem $qaDir -File -Filter "*.ps1" | ForEach-Object {
	$name = $_.Name
	$shimPath = Join-Path $root "scripts\$name"
	$lines = @(
		"# Shim - forwards to scripts/qa/$name",
		"param([Parameter(ValueFromRemainingArguments = `$true)]`$Rest)",
		"& (Join-Path `$PSScriptRoot ""qa\$name"") @Rest",
		"exit `$LASTEXITCODE"
	)
	[System.IO.File]::WriteAllLines($shimPath, $lines)
	Write-Output "fixed shim scripts/$name"
}
