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
Write-Output "Spec: canvas 100% MATCH (FAIL=0, DATA-ONLY=0, MISSING=0); MATCH deltas must not admit invented./superset extras; every class_abilities (The X) Name: must appear on the canvas; canvas and factory display names must not add extras outside that class Bible set."

$canvasDrift = @()
$pattern = 'cls: "(?<cls>[^"]+)".*?skill: "(?<skill>[^"]+)".*?verdict: "(?<verdict>MATCH|FAIL|DATA-ONLY|MISSING)", delta: "(?<delta>[^"]*)"'
$rows = @()
if ($null -ne $canvas) {
	Write-Output "Canvas: $canvas"
	Select-String -LiteralPath $canvas -Pattern $pattern | ForEach-Object {
		$rows += [pscustomobject]@{
			cls = $_.Matches[0].Groups["cls"].Value
			skill = $_.Matches[0].Groups["skill"].Value
			verdict = $_.Matches[0].Groups["verdict"].Value
			delta = $_.Matches[0].Groups["delta"].Value
		}
	}
	$primaryKeys = @($rows | ForEach-Object { "{0}|{1}|{2}" -f $_.cls, $_.skill, $_.verdict } | Sort-Object)
	foreach ($other in $candidates) {
		if (-not $other -or $other -eq $canvas -or -not (Test-Path -LiteralPath $other)) {
			continue
		}
		$otherRows = @()
		Select-String -LiteralPath $other -Pattern $pattern | ForEach-Object {
			$otherRows += [pscustomobject]@{
				cls = $_.Matches[0].Groups["cls"].Value
				skill = $_.Matches[0].Groups["skill"].Value
				verdict = $_.Matches[0].Groups["verdict"].Value
			}
		}
		$otherKeys = @($otherRows | ForEach-Object { "{0}|{1}|{2}" -f $_.cls, $_.skill, $_.verdict } | Sort-Object)
		$onlyPrimary = @(Compare-Object $primaryKeys $otherKeys | Where-Object { $_.SideIndicator -eq "<=" })
		$onlyOther = @(Compare-Object $primaryKeys $otherKeys | Where-Object { $_.SideIndicator -eq "=>" })
		if ($onlyPrimary.Count -gt 0 -or $onlyOther.Count -gt 0) {
			$canvasDrift += [pscustomobject]@{
				path = $other
				only_gated = @($onlyPrimary | Select-Object -First 5 | ForEach-Object { $_.InputObject })
				only_other = @($onlyOther | Select-Object -First 5 | ForEach-Object { $_.InputObject })
			}
		}
	}
	Write-Output ("CANVAS COPY DRIFT: {0}" -f $canvasDrift.Count)
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
$canvasExtras = @()
$factoryExtras = @()
$requiredNames = @()
$biblePath = Join-Path $projectRoot "class_abilities.txt"
$bibleByClass = @{}
if (Test-Path -LiteralPath $biblePath) {
	$bibleLines = Get-Content -LiteralPath $biblePath
	$classPattern = '^\d+\.\s+(Knight|Bruiser|Mercenary|Rogue|Monk|Beast Rider|Mage|Archer|Cleric|Shaman|Lancer|Engineer)\s*$'
	$namePattern = '^\(The [^)]+\)\s+([^:]+):'
	$innatePattern = '^Innate Trait:\s+(.+)$'
	$repositionPattern = '^Reposition Skill:\s+([^(]+)'
	$basicAttackPattern = '^Basic Attack \(([^)]+)\):'
	$currentClass = $null
	$requiredNames = @()
	foreach ($line in $bibleLines) {
		if ($line -match $classPattern) {
			$currentClass = $Matches[1]
			if (-not $bibleByClass.ContainsKey($currentClass)) {
				$bibleByClass[$currentClass] = New-Object 'System.Collections.Generic.HashSet[string]'
			}
			continue
		}
		if ($null -eq $currentClass) {
			continue
		}
		$set = $bibleByClass[$currentClass]
		if ($line -match $namePattern) {
			$name = $Matches[1].Trim()
			$requiredNames += [pscustomobject]@{ cls = $currentClass; name = $name }
			[void]$set.Add($name)
		}
		elseif ($line -match $innatePattern) {
			[void]$set.Add($Matches[1].Trim())
		}
		elseif ($line -match $repositionPattern) {
			[void]$set.Add($Matches[1].Trim())
		}
		elseif ($line -match $basicAttackPattern) {
			[void]$set.Add($Matches[1].Trim())
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

	function Test-StructuralCanvasSkill([string]$skill) {
		return $skill -match '(?i)^(Stats\b)|promo|AIRBORNE'
	}

	foreach ($row in $rows) {
		if (-not $bibleByClass.ContainsKey($row.cls)) {
			continue
		}
		if (Test-StructuralCanvasSkill $row.skill) {
			continue
		}
		$base = ($row.skill -replace '\s*\([^)]+\)\s*$', '').Trim()
		if (-not $bibleByClass[$row.cls].Contains($base) -and -not $bibleByClass[$row.cls].Contains($row.skill)) {
			$canvasExtras += $row
		}
	}
	Write-Output ("CANVAS EXTRAS (not in class Bible set): {0}" -f $canvasExtras.Count)

	$ctorPattern = '(?s)(?:DataLibrary\.)?(?:_make_passive|_make_modular_ability|_passive|_ability|_attack_with_status|_attack_with_layer|_attack|_movement|_make_movement|_spell|_damage|_charge_skill|_self_status|_self_area_status)\(\s*&"[^"]+",\s*"([^"]+)"'
	$factoryMap = @{
		"knight_factory.gd" = "Knight"
		"bruiser_factory.gd" = "Bruiser"
		"mercenary_factory.gd" = "Mercenary"
		"rogue_factory.gd" = "Rogue"
		"monk_factory.gd" = "Monk"
		"beast_rider_factory.gd" = "Beast Rider"
		"mage_factory.gd" = "Mage"
		"archer_factory.gd" = "Archer"
		"cleric_factory.gd" = "Cleric"
		"shaman_factory.gd" = "Shaman"
		"lancer_factory.gd" = "Lancer"
		"engineer_factory.gd" = "Engineer"
	}
	$factoryDir = Join-Path $projectRoot "core\factory\classes"
	Get-ChildItem -LiteralPath $factoryDir -Filter "*_factory.gd" | ForEach-Object {
		$factoryFile = $_
		$clsName = $factoryMap[$factoryFile.Name]
		if (-not $clsName -or -not $bibleByClass.ContainsKey($clsName)) {
			return
		}
		$text = Get-Content -LiteralPath $factoryFile.FullName -Raw
		[regex]::Matches($text, $ctorPattern) | ForEach-Object {
			$display = $_.Groups[1].Value.Trim()
			if ($display -eq "" -or $display -eq $clsName -or $display -eq "Basic Attack") {
				return
			}
			if (-not $bibleByClass[$clsName].Contains($display)) {
				$factoryExtras += [pscustomobject]@{ cls = $clsName; name = $display; file = $factoryFile.Name }
			}
		}
	}
	$factoryExtras = @($factoryExtras | Sort-Object cls, name -Unique)
	Write-Output ("FACTORY DISPLAY EXTRAS (not in class Bible set): {0}" -f $factoryExtras.Count)
}

$docsDir = Join-Path $projectRoot "docs"
if (-not (Test-Path -LiteralPath $docsDir)) {
	New-Item -ItemType Directory -Path $docsDir | Out-Null
}
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $auditJson -Encoding utf8
Write-Output ""
Write-Output "Wrote $auditJson"

$reportsDir = Join-Path $projectRoot "reports"
if (-not (Test-Path -LiteralPath $reportsDir)) {
	New-Item -ItemType Directory -Path $reportsDir | Out-Null
}
$gateLog = Join-Path $reportsDir "bible_alignment_gate_latest.stdout.txt"
$matchCount = 0
if ($snapshot.counts.ContainsKey("MATCH")) {
	$matchCount = [int]$snapshot.counts["MATCH"]
}
$gateFailed = $fails.Count -gt 0 -or $dataOnly.Count -gt 0 -or $missing.Count -gt 0 -or $dishonestMatch.Count -gt 0 -or $missingBible.Count -gt 0 -or $canvasExtras.Count -gt 0 -or $factoryExtras.Count -gt 0 -or $canvasDrift.Count -gt 0
$logLines = @(
	"=== Bible alignment QA gate ==="
	("MATCH: {0}" -f $matchCount)
	("FAIL: {0}" -f $fails.Count)
	("DATA-ONLY: {0}" -f $dataOnly.Count)
	("MISSING: {0}" -f $missing.Count)
	("DISHONEST MATCH deltas: {0}" -f $dishonestMatch.Count)
	("Bible (The X) names: {0}" -f $requiredNames.Count)
	("BIBLE NAMES MISSING FROM CANVAS: {0}" -f $missingBible.Count)
	("CANVAS EXTRAS (not in class Bible set): {0}" -f $canvasExtras.Count)
	("FACTORY DISPLAY EXTRAS (not in class Bible set): {0}" -f $factoryExtras.Count)
	("CANVAS COPY DRIFT: {0}" -f $canvasDrift.Count)
)
if ($gateFailed) {
	$logLines += ("--- Bible alignment gate: FAIL (FAIL={0} DATA-ONLY={1} MISSING={2} DISHONEST={3} BIBLE-NAME={4} CANVAS-EXTRA={5} FACTORY-EXTRA={6} CANVAS-DRIFT={7}) ---" -f $fails.Count, $dataOnly.Count, $missing.Count, $dishonestMatch.Count, $missingBible.Count, $canvasExtras.Count, $factoryExtras.Count, $canvasDrift.Count)
} else {
	$logLines += "--- Bible alignment gate: PASS ---"
}
$logLines | Set-Content -LiteralPath $gateLog -Encoding utf8
Write-Output "Wrote $gateLog"

if ($gateFailed) {
	Write-Output ""
	Write-Output ("--- Bible alignment gate: FAIL (FAIL={0} DATA-ONLY={1} MISSING={2} DISHONEST={3} BIBLE-NAME={4} CANVAS-EXTRA={5} FACTORY-EXTRA={6} CANVAS-DRIFT={7}) ---" -f $fails.Count, $dataOnly.Count, $missing.Count, $dishonestMatch.Count, $missingBible.Count, $canvasExtras.Count, $factoryExtras.Count, $canvasDrift.Count)
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
	$canvasExtras | Select-Object -First 20 | ForEach-Object {
		Write-Output ("[CANVAS-EXTRA] {0} / {1}" -f $_.cls, $_.skill)
	}
	$canvasDrift | Select-Object -First 5 | ForEach-Object {
		Write-Output ("[CANVAS-DRIFT] {0}" -f $_.path)
	}
	exit 1
}

Write-Output "--- Bible alignment gate: PASS ---"
exit 0
