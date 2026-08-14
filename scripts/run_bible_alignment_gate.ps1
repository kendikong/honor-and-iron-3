param(
	[string]$CanvasPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$auditJson = Join-Path $projectRoot "docs\bible_alignment_audit.json"

$candidates = @()
if ($CanvasPath -ne "") {
	$candidates += $CanvasPath
}
$candidates += @(
	(Join-Path $projectRoot "docs\bible_skill_alignment_audit.canvas.tsx"),
	(Join-Path $env:USERPROFILE ".cursor\projects\c-Users-Kendy-Downloads-honor-and-iron-3\canvases\bible-skill-alignment-audit.canvas.tsx")
)

$canvas = $null
foreach ($path in $candidates) {
	if ($path -and (Test-Path -LiteralPath $path)) {
		$canvas = $path
		break
	}
}

Write-Output "=== Bible alignment QA gate ==="
Write-Output "Spec: canvas/JSON FAIL rows must be 0 for bible-to-code."

$rows = @()
if ($null -ne $canvas) {
	Write-Output "Canvas: $canvas"
	$pattern = 'cls: "(?<cls>[^"]+)".*?skill: "(?<skill>[^"]+)".*?verdict: "(?<verdict>MATCH|FAIL|DATA-ONLY|MISSING)"'
	Select-String -LiteralPath $canvas -Pattern $pattern | ForEach-Object {
		$rows += [pscustomobject]@{
			cls = $_.Matches[0].Groups["cls"].Value
			skill = $_.Matches[0].Groups["skill"].Value
			verdict = $_.Matches[0].Groups["verdict"].Value
		}
	}
} elseif (Test-Path -LiteralPath $auditJson) {
	Write-Output "Canvas missing; reading $auditJson"
	$parsed = Get-Content -LiteralPath $auditJson -Raw | ConvertFrom-Json
	foreach ($item in $parsed.rows) {
		$rows += [pscustomobject]@{
			cls = $item.cls
			skill = $item.skill
			verdict = $item.verdict
		}
	}
} else {
	Write-Output "[FAIL] No canvas and no docs/bible_alignment_audit.json"
	exit 1
}

if ($rows.Count -eq 0) {
	Write-Output "[FAIL] Parsed 0 audit rows"
	exit 1
}

$snapshot = [pscustomobject]@{
	generated = (Get-Date).ToString("s")
	source = $(if ($null -ne $canvas) { $canvas } else { $auditJson })
	counts = @{}
	rows = $rows
}
$byVerdict = $rows | Group-Object verdict
foreach ($group in $byVerdict) {
	$snapshot.counts[$group.Name] = $group.Count
	Write-Output ("{0}: {1}" -f $group.Name, $group.Count)
}

$fails = @($rows | Where-Object { $_.verdict -eq "FAIL" })
$byClass = $fails | Group-Object cls | Sort-Object Count -Descending
Write-Output ""
Write-Output "FAIL by class:"
if ($byClass.Count -eq 0) {
	Write-Output "(none)"
} else {
	foreach ($group in $byClass) {
		Write-Output ("  {0}: {1}" -f $group.Name, $group.Count)
	}
}

$docsDir = Join-Path $projectRoot "docs"
if (-not (Test-Path -LiteralPath $docsDir)) {
	New-Item -ItemType Directory -Path $docsDir | Out-Null
}
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $auditJson -Encoding utf8
Write-Output ""
Write-Output "Wrote $auditJson"

if ($fails.Count -gt 0) {
	Write-Output ""
	Write-Output ("--- Bible alignment gate: FAIL ({0} rows) ---" -f $fails.Count)
	$fails | Select-Object -First 20 | ForEach-Object {
		Write-Output ("[FAIL] {0} / {1}" -f $_.cls, $_.skill)
	}
	exit 1
}

Write-Output "--- Bible alignment gate: PASS ---"
exit 0
