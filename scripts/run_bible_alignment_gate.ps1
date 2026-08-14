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
Write-Output "Spec: canvas 100% MATCH (FAIL=0, DATA-ONLY=0, MISSING=0); MATCH deltas must not admit invented./superset extras; every class_abilities (The X) Name: must appear on the canvas."

$rows = @()
if ($null -ne $canvas) {
	Write-Output "Canvas: $canvas"
	$pattern = 'cls: "(?<cls>[^"]+)".*?skill: "(?<skill>[^"]+)".*?verdict: "(?<verdict>MATCH|FAIL|DATA-ONLY|MISSING)", delta: "(?<delta>[^"]*)"'
	Select-String -LiteralPath $canvas -Pattern $pattern | ForEach-Object {
		$rows += [pscustomobject]@{
			cls = $_.Matches[0].Groups["cls"].Value
			skill = $_.Matches[0].Groups["skill"].Value
			verdict = $_.Matches[0].Groups["verdict"].Value
			delta = $_.Matches[0].Groups["delta"].Value
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
$dataOnly = @($rows | Where-Object { $_.verdict -eq "DATA-ONLY" })
$missing = @($rows | Where-Object { $_.verdict -eq "MISSING" })
$dishonestMatch = @($rows | Where-Object {
	$_.verdict -eq "MATCH" -and
	$_.delta -match 'invented\.|superset' -and
	$_.delta -notmatch '(?i)no invented'
})
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
Write-Output ("DATA-ONLY: {0}" -f $dataOnly.Count)
Write-Output ("MISSING: {0}" -f $missing.Count)
Write-Output ("DISHONEST MATCH deltas: {0}" -f $dishonestMatch.Count)

$missingBible = @()
$biblePath = Join-Path $projectRoot "class_abilities.txt"
if (Test-Path -LiteralPath $biblePath) {
	$bibleLines = Get-Content -LiteralPath $biblePath
	$classPattern = '^\d+\.\s+(Knight|Bruiser|Mercenary|Rogue|Monk|Beast Rider|Mage|Archer|Cleric|Shaman|Lancer|Engineer)\s*$'
	$namePattern = '^\(The [^)]+\)\s+([^:]+):'
	$currentClass = $null
	$requiredNames = @()
	foreach ($line in $bibleLines) {
		if ($line -match $classPattern) {
			$currentClass = $Matches[1]
			continue
		}
		if ($null -eq $currentClass) {
			continue
		}
		if ($line -match $namePattern) {
			$requiredNames += [pscustomobject]@{ cls = $currentClass; name = $Matches[1].Trim() }
		}
	}
	foreach ($req in $requiredNames) {
		$hits = @($rows | Where-Object {
			$base = $_.skill -replace '\s*\([^)]+\)\s*$', ''
			$_.cls -eq $req.cls -and ($base.Trim() -eq $req.name -or $_.skill -eq $req.name)
		})
		if ($hits.Count -eq 0) {
			$missingBible += $req
		}
	}
	Write-Output ("Bible (The X) names: {0}" -f $requiredNames.Count)
	Write-Output ("BIBLE NAMES MISSING FROM CANVAS: {0}" -f $missingBible.Count)
}

$docsDir = Join-Path $projectRoot "docs"
if (-not (Test-Path -LiteralPath $docsDir)) {
	New-Item -ItemType Directory -Path $docsDir | Out-Null
}
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $auditJson -Encoding utf8
Write-Output ""
Write-Output "Wrote $auditJson"

if ($fails.Count -gt 0 -or $dataOnly.Count -gt 0 -or $missing.Count -gt 0 -or $dishonestMatch.Count -gt 0 -or $missingBible.Count -gt 0) {
	Write-Output ""
	Write-Output ("--- Bible alignment gate: FAIL (FAIL={0} DATA-ONLY={1} MISSING={2} DISHONEST={3} BIBLE-NAME={4}) ---" -f $fails.Count, $dataOnly.Count, $missing.Count, $dishonestMatch.Count, $missingBible.Count)
	$fails | Select-Object -First 20 | ForEach-Object {
		Write-Output ("[FAIL] {0} / {1}" -f $_.cls, $_.skill)
	}
	$dataOnly | Select-Object -First 10 | ForEach-Object {
		Write-Output ("[DATA-ONLY] {0} / {1}" -f $_.cls, $_.skill)
	}
	$missing | Select-Object -First 10 | ForEach-Object {
		Write-Output ("[MISSING] {0} / {1}" -f $_.cls, $_.skill)
	}
	$dishonestMatch | Select-Object -First 10 | ForEach-Object {
		Write-Output ("[DISHONEST] {0} / {1}: {2}" -f $_.cls, $_.skill, $_.delta)
	}
	$missingBible | Select-Object -First 20 | ForEach-Object {
		Write-Output ("[BIBLE-NAME] {0} / {1}" -f $_.cls, $_.name)
	}
	exit 1
}

Write-Output "--- Bible alignment gate: PASS ---"
exit 0
