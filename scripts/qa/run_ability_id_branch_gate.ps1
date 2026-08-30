param(
	[string[]]$ScanRoots = @("presentation", "core")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Output "=== Ability ID branch SSOT gate (production) ==="
Write-Output "Forbids per-skill literal ability.id branches in presentation/ and core/."

$failures = New-Object System.Collections.Generic.List[string]

$forbidden = @(
	'if\s+ability\.id\s*==\s*["&]'
	'if\s+action\.ability\.id\s*==\s*["&]'
	'elif\s+ability\.id\s*==\s*["&]'
	'match\s+ability\.id\s*:'
)

$allowedFiles = @(
	"core/systems/mercenary_systems.gd"
)

foreach ($rootName in $ScanRoots) {
	$root = Join-Path $projectRoot $rootName
	if (-not (Test-Path -LiteralPath $root)) { continue }
	$files = Get-ChildItem -LiteralPath $root -Recurse -Filter "*.gd" -File
	foreach ($file in $files) {
		$rel = $file.FullName.Substring($projectRoot.Length + 1) -replace '\\', '/'
		if ($allowedFiles -contains $rel) { continue }
		$lines = Get-Content -LiteralPath $file.FullName
		for ($i = 0; $i -lt $lines.Count; $i++) {
			$line = $lines[$i]
			if ($line -match '^\s*#') { continue }
			foreach ($pat in $forbidden) {
				if ($line -match $pat) {
					$failures.Add("[FAIL] ${rel}:$($i + 1): per-skill ability.id branch - $line")
				}
			}
		}
	}
}

if ($failures.Count -gt 0) {
	Write-Output "--- Ability ID branch gate: FAIL ($($failures.Count)) ---"
	foreach ($line in $failures) { Write-Output $line }
	exit 1
}

Write-Output "--- Ability ID branch gate: PASS ---"
exit 0
