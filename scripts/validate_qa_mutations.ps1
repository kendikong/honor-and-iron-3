param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-QaGate {
	$outFile = Join-Path $env:TEMP ("qa_gate_{0}.txt" -f [guid]::NewGuid().ToString("N"))
	$errFile = "$outFile.err"
	$p = Start-Process -FilePath $GodotPath `
		-ArgumentList @("--headless", "--path", $root, "--script", "res://tests/run_planning_qa_gate.gd") `
		-Wait -PassThru -NoNewWindow `
		-RedirectStandardOutput $outFile `
		-RedirectStandardError $errFile
	$all = ""
	if (Test-Path $outFile) {
		$raw = Get-Content $outFile -Raw
		if ($null -ne $raw) { $all = $raw }
		Remove-Item $outFile -Force -ErrorAction SilentlyContinue
	}
	if (Test-Path $errFile) {
		$rawErr = Get-Content $errFile -Raw
		if ($null -ne $rawErr) { $all += "`n" + $rawErr }
		Remove-Item $errFile -Force -ErrorAction SilentlyContinue
	}
	$fails = @([regex]::Matches($all, '\[FAIL\][^\r\n]*') | ForEach-Object { $_.Value })
	return @{ Exit = $p.ExitCode; Fails = $fails; Count = $fails.Count; Output = $all }
}

function Normalize-Newlines([string]$text) {
	return $text -replace "`r`n", "`n"
}

function Set-Patch($rel, $old, $new) {
	$path = Join-Path $root $rel
	$c = Normalize-Newlines ([IO.File]::ReadAllText($path))
	$o = Normalize-Newlines $old
	$n = Normalize-Newlines $new
	if (-not $c.Contains($o)) { throw "Anchor not found in $rel`n--- expected ---`n$o" }
	[IO.File]::WriteAllText($path, $c.Replace($o, $n))
}

Write-Host "=== Baseline ===" -ForegroundColor Cyan
$base = Invoke-QaGate
if ($base.Exit -ne 0) {
	Write-Host $base.Output
	throw "Baseline must PASS (exit $($base.Exit), $($base.Count) fails)"
}
Write-Host "PASS (exit 0)"

$mutations = @(
	@{
		Name = "1_red_always_visible"
		File = "presentation/combat_planning_input.gd"
		Old = @"
	if ability == null or AbilitySystem.is_run_ability(ability) or AbilitySystem.is_wait_ability(ability):
		return false
	var stand: Vector2i = action_range_intent_stand_cell(unit_id)
"@
		New = @"
	if ability == null or AbilitySystem.is_run_ability(ability) or AbilitySystem.is_wait_ability(ability):
		return false
	return true  # QA_MUT
	var stand: Vector2i = action_range_intent_stand_cell(unit_id)
"@
		ExpectMinFails = 3
	},
	@{
		Name = "2_bash_no_approach"
		File = "presentation/combat_director.gd"
		Old = "	return _find_approach_tile(proj, actor, target.position, rng, preferred_tile)"
		New = "	return actor.position  # QA_MUT"
		ExpectMinFails = 3
	},
	@{
		Name = "3_no_ap_spend"
		File = "core/systems/ability_system.gd"
		Old = @"
		GameEnums.AbilityKind.CLASS_SKILL:
			actor.ability.points_left -= ap_cost
"@
		New = @"
		GameEnums.AbilityKind.CLASS_SKILL:
			pass  # QA_MUT
"@
		ExpectMinFails = 2
	},
	@{
		Name = "4_skip_promote"
		File = "presentation/combat_planning_input.gd"
		Old = @"
func _promote_intent_preview_after_commit() -> void:
	_suppress_post_commit_hover_refresh = true
"@
		New = @"
func _promote_intent_preview_after_commit() -> void:
	return  # QA_MUT
	_suppress_post_commit_hover_refresh = true
"@
		ExpectMinFails = 2
	},
	@{
		Name = "5_push_reversed"
		File = "core/systems/physics_system.gd"
		Old = @"
static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
"@
		New = @"
static func push(board: BoardState, target: UnitState, direction: Vector2i, distance: int, events: Array[SimEvent], pusher: UnitState = null, ability_id: StringName = &"", collision_immune_id: int = -1) -> void:
	direction = -direction  # QA_MUT
	if target == null or not target.is_alive() or direction == Vector2i.ZERO or distance <= 0:
"@
		ExpectMinFails = 4
	},
	@{
		Name = "6_hook_wrong_stand"
		File = "presentation/combat_director.gd"
		Old = @"
	if GridSystem.manhattan(actor.position, target.position) <= rng:
		return actor.position
"@
		New = @"
	if GridSystem.manhattan(actor.position, target.position) <= rng:
		return preferred_tile  # QA_MUT
"@
		ExpectMinFails = 2
	}
)

$report = @()
foreach ($m in $mutations) {
	Write-Host "`n=== $($m.Name) ===" -ForegroundColor Yellow
	Set-Patch $m.File $m.Old $m.New
	try {
		$r = Invoke-QaGate
		$ok = ($r.Exit -ne 0) -and ($r.Count -ge $m.ExpectMinFails)
		$report += [pscustomobject]@{
			Mutation = $m.Name
			Exit = $r.Exit
			FailCount = $r.Count
			Expected = $(if ($ok) { "CAUGHT" } else { "MISSED" })
			Sample = ($r.Fails | Select-Object -First 3) -join " | "
		}
		if ($ok) { Write-Host "CAUGHT ($($r.Count) failures)" -ForegroundColor Green }
		else {
			Write-Host "MISSED (exit=$($r.Exit) fails=$($r.Count), need >=$($m.ExpectMinFails))" -ForegroundColor Red
			if ($r.Count -gt 0) { $r.Fails | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" } }
		}
	}
	finally {
		Set-Patch $m.File $m.New $m.Old
	}
}

Write-Host "`n=== Post-revert baseline ===" -ForegroundColor Cyan
$final = Invoke-QaGate
if ($final.Exit -ne 0) { throw "Revert incomplete (exit $($final.Exit))" }
Write-Host "PASS"

$report | Format-Table -AutoSize
$report | ConvertTo-Json | Set-Content (Join-Path $root "tests/qa_mutation_report.json")
$missed = @($report | Where-Object { $_.Expected -eq "MISSED" })
if ($missed.Count -gt 0) {
	Write-Host "`n$($missed.Count) mutation(s) MISSED - QA gap" -ForegroundColor Red
	exit 1
}
Write-Host "`nAll mutations caught by QA gate." -ForegroundColor Green
exit 0
