# One-shot repo layout migration — docs/qa, scripts/qa shims, tests/gates scenes.
# Run from repo root: powershell -File tools/reorganize_repo_layout.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Ensure-Dir([string]$Rel) {
	$full = Join-Path $root $Rel
	if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}

function Move-RepoFile([string]$From, [string]$To) {
	$src = Join-Path $root $From
	$dst = Join-Path $root $To
	if (-not (Test-Path -LiteralPath $src)) {
		if (Test-Path -LiteralPath $dst) { return }
		return
	}
	Ensure-Dir (Split-Path $To -Parent)
	if (Test-Path -LiteralPath $dst) { return }
	$tracked = git ls-files -- "$From" 2>$null
	if ($tracked) {
		git mv -- $src $dst 2>&1 | Out-Null
		if ($LASTEXITCODE -eq 0) {
			Write-Output "moved $From -> $To"
			return
		}
	}
	try {
		Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
		Write-Output "moved $From -> $To"
	} catch {
		Write-Output "skip locked $From"
	}
}

function Register-PathMove([hashtable]$Map, [string]$From, [string]$To) {
	$fromNorm = $From -replace '\\', '/'
	$toNorm = $To -replace '\\', '/'
	$Map[$fromNorm] = $toNorm
	if ($fromNorm -match '\.(gd|tscn|md)$') {
		$leaf = Split-Path $fromNorm -Leaf
		$Map["res://$fromNorm"] = "res://$toNorm"
		$Map["tests/$leaf"] = $toNorm
	}
	Move-RepoFile $From $To
}

function Replace-InTree([string[]]$Globs, [hashtable]$Map) {
	$files = @()
	foreach ($g in $Globs) {
		$files += Get-ChildItem -Path $root -Recurse -File -Include $g -ErrorAction SilentlyContinue |
			Where-Object {
				$_.FullName -notmatch '\\\.git\\' -and
				$_.FullName -notmatch '\\\.godot\\' -and
				$_.FullName -notmatch 'Universal-LPC-Spritesheet' -and
				$_.FullName -notmatch '\\addons\\'
			}
	}
	$files = $files | Sort-Object FullName -Unique
	foreach ($f in $files) {
		if (-not (Test-Path -LiteralPath $f.FullName)) { continue }
		$text = [System.IO.File]::ReadAllText($f.FullName)
		$orig = $text
		foreach ($k in ($Map.Keys | Sort-Object { $_.Length } -Descending)) {
			$text = $text.Replace($k, $Map[$k])
		}
		if ($text -ne $orig) {
			[System.IO.File]::WriteAllText($f.FullName, $text)
			Write-Output "updated $($f.FullName.Substring($root.Length + 1))"
		}
	}
}

Write-Output "=== Creating directories ==="
@(
	"docs/qa/classes", "docs/qa/manifests", "docs/qa/planning", "docs/qa",
	"docs/reference", "docs/audits", "docs/design/logs",
	"scripts/qa", "tests/gates", "reports/qa"
) | ForEach-Object { Ensure-Dir $_ }

Write-Output "=== Moving docs ==="
Get-ChildItem (Join-Path $root "docs") -File -Filter "*_QA_GATE.md" |
	Where-Object { $_.Name -ne "PLANNING_QA_GATE.md" } |
	ForEach-Object {
	Move-RepoFile "docs/$($_.Name)" "docs/qa/classes/$($_.Name)"
}
Get-ChildItem (Join-Path $root "docs") -File -Filter "*_meta_critic_manifest.json" | ForEach-Object {
	Move-RepoFile "docs/$($_.Name)" "docs/qa/manifests/$($_.Name)"
}
@(
	@("docs/PLANNING_QA_GATE.md", "docs/qa/planning/PLANNING_QA_GATE.md"),
	@("docs/PLANNING_SKILL_QA_CHECKLIST.md", "docs/qa/planning/PLANNING_SKILL_QA_CHECKLIST.md"),
	@("docs/qa/planning/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md", "docs/qa/planning/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md"),
	@("docs/qa/CLASS_QA_BIBLE.md", "docs/qa/CLASS_QA_BIBLE.md"),
	@("docs/qa/_CLASS_QA_GATE_TEMPLATE.md", "docs/qa/_CLASS_QA_GATE_TEMPLATE.md"),
	@("docs/qa/CLASS_QA_SIGNOFF.md", "docs/qa/CLASS_QA_SIGNOFF.md"),
	@("docs/qa/BUG_REPORT_WORKFLOW.md", "docs/qa/BUG_REPORT_WORKFLOW.md"),
	@("docs/reference/player_grid_api.md", "docs/reference/player_grid_api.md"),
	@("docs/reference/tile_registry.md", "docs/reference/tile_registry.md"),
	@("docs/reference/tile_terrain_peering.md", "docs/reference/tile_terrain_peering.md"),
	@("docs/reference/asset_manifest.md", "docs/reference/asset_manifest.md"),
	@("docs/audits/ARCHER_BIBLE_AUDIT.md", "docs/audits/ARCHER_BIBLE_AUDIT.md"),
	@("docs/bible_alignment_audit.json", "docs/audits/bible_alignment_audit.json"),
	@("docs/bible_skill_alignment_audit.canvas.tsx", "docs/audits/bible_skill_alignment_audit.canvas.tsx"),
	@("docs/design/TACTICAL_COMBAT_PARITY_PLAN.md", "docs/design/TACTICAL_COMBAT_PARITY_PLAN.md"),
	@("docs/design/sandbox_map_system.md", "docs/design/sandbox_map_system.md"),
	@("docs/design/logs/PLANNING_GAUNTLET_ROUND31.md", "docs/design/logs/PLANNING_GAUNTLET_ROUND31.md"),
	@("docs/design/logs/PLANNING_GAUNTLET_BACKLOG.md", "docs/design/logs/PLANNING_GAUNTLET_BACKLOG.md"),
	@("docs/design/logs/PLANNING_GAUNTLET_LOOP.md", "docs/design/logs/PLANNING_GAUNTLET_LOOP.md"),
	@("docs/design/logs/MOVE_PREVIEW_IMPLEMENTATION_LOG.md", "docs/design/logs/MOVE_PREVIEW_IMPLEMENTATION_LOG.md")
) | ForEach-Object { Move-RepoFile $_[0] $_[1] }

Write-Output "=== Moving test gate scenes ==="
Get-ChildItem (Join-Path $root "tests") -File -Filter "*QaGate.tscn" | ForEach-Object {
	Move-RepoFile "tests/$($_.Name)" "tests/gates/$($_.Name)"
}
Move-RepoFile "tests/gates/T3MimicHeadless.tscn" "tests/gates/T3MimicHeadless.tscn"

Write-Output "=== Moving QA PowerShell to scripts/qa ==="
$qaPs1 = @(
	"run_*_qa_gate.ps1", "run_*_live_qa.ps1",
	"run_planning_qa_gate.ps1", "run_t3_mimic_headless.ps1",
	"run_hover_preview_ssot_gate.ps1", "run_aoe_footprint_qa_gate.ps1",
	"run_swap_planning_acceptance.ps1", "run_planning_headless_contracts.ps1",
	"run_planning_scene_acceptance.ps1", "run_planning_scene_acceptance_compare.ps1",
	"run_regression_tests.ps1", "run_full_qa.ps1", "run_all_background_class_tests.ps1",
	"run_bible_alignment_gate.ps1", "run_er3_exit_gate.ps1", "run_k4_preview_compare.ps1",
	"run_layer_shape_conversion_gate.ps1", "run_beast_rider_gauntlet_bar.ps1",
	"qa_window_placement.ps1", "qa_gate_matrix_helpers.ps1",
	"lint_design_doc.ps1", "lint_planning_truth_matrix.ps1",
	"validate_qa_mutations.ps1", "validate_live_planning_mutation.ps1",
	"patch_scenario_sim_upgrade.ps1", "patch_class_scenario_bible_contracts.ps1"
)
foreach ($pat in $qaPs1) {
	Get-ChildItem (Join-Path $root "scripts") -File -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
		$name = $_.Name
		if (Test-Path (Join-Path $root "scripts/qa/$name")) { return }
		Move-RepoFile "scripts/$name" "scripts/qa/$name"
	}
}

Write-Output "=== Creating script shims ==="
Get-ChildItem (Join-Path $root "scripts/qa") -File -Filter "*.ps1" | ForEach-Object {
	$shim = Join-Path $root "scripts/$($_.Name)"
	if (Test-Path -LiteralPath $shim) { return }
	@(
		"# Shim - forwards to scripts/qa/$($_.Name)",
		"param([Parameter(ValueFromRemainingArguments = `$true)]`$Rest)",
		"& (Join-Path `$PSScriptRoot ""qa\$($_.Name)"") @Rest",
		"exit `$LASTEXITCODE"
	) | ForEach-Object { $_ } | Set-Content -Path $shim -Encoding utf8
	Write-Output "shim scripts/$($_.Name)"
}

Write-Output "=== Fixing projectRoot in scripts/qa/*.ps1 ==="
Get-ChildItem (Join-Path $root "scripts/qa") -File -Filter "*.ps1" | ForEach-Object {
	$text = [System.IO.File]::ReadAllText($_.FullName)
	if ($text -match '\$projectRoot = Split-Path -Parent \$PSScriptRoot' -and
		$text -notmatch 'Split-Path -Parent \(Split-Path -Parent') {
		$text = $text.Replace(
			'$projectRoot = Split-Path -Parent $PSScriptRoot',
			'$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)'
		)
		[System.IO.File]::WriteAllText($_.FullName, $text)
		Write-Output "fixed projectRoot in scripts/qa/$($_.Name)"
	}
}

Write-Output "=== Global reference updates ==="
$refMap = [ordered]@{
	"docs/qa/classes/KNIGHT_QA_GATE.md" = "docs/qa/classes/KNIGHT_QA_GATE.md"
	"docs/qa/classes/ARCHER_QA_GATE.md" = "docs/qa/classes/ARCHER_QA_GATE.md"
	"docs/qa/classes/BRUISER_QA_GATE.md" = "docs/qa/classes/BRUISER_QA_GATE.md"
	"docs/qa/classes/LANCER_QA_GATE.md" = "docs/qa/classes/LANCER_QA_GATE.md"
	"docs/qa/classes/MAGE_QA_GATE.md" = "docs/qa/classes/MAGE_QA_GATE.md"
	"docs/qa/classes/CLERIC_QA_GATE.md" = "docs/qa/classes/CLERIC_QA_GATE.md"
	"docs/qa/classes/ROGUE_QA_GATE.md" = "docs/qa/classes/ROGUE_QA_GATE.md"
	"docs/qa/classes/MONK_QA_GATE.md" = "docs/qa/classes/MONK_QA_GATE.md"
	"docs/qa/classes/SHAMAN_QA_GATE.md" = "docs/qa/classes/SHAMAN_QA_GATE.md"
	"docs/qa/classes/ENGINEER_QA_GATE.md" = "docs/qa/classes/ENGINEER_QA_GATE.md"
	"docs/qa/classes/MERCENARY_QA_GATE.md" = "docs/qa/classes/MERCENARY_QA_GATE.md"
	"docs/qa/classes/BEAST_RIDER_QA_GATE.md" = "docs/qa/classes/BEAST_RIDER_QA_GATE.md"
	"docs/qa/planning/PLANNING_QA_GATE.md" = "docs/qa/planning/PLANNING_QA_GATE.md"
	"docs/qa/manifests/knight_meta_critic_manifest.json" = "docs/qa/manifests/knight_meta_critic_manifest.json"
	"docs/qa/manifests/archer_meta_critic_manifest.json" = "docs/qa/manifests/archer_meta_critic_manifest.json"
	"docs/qa/manifests/bruiser_meta_critic_manifest.json" = "docs/qa/manifests/bruiser_meta_critic_manifest.json"
	"docs/qa/manifests/lancer_meta_critic_manifest.json" = "docs/qa/manifests/lancer_meta_critic_manifest.json"
	"docs/qa/manifests/mage_meta_critic_manifest.json" = "docs/qa/manifests/mage_meta_critic_manifest.json"
	"docs/qa/manifests/cleric_meta_critic_manifest.json" = "docs/qa/manifests/cleric_meta_critic_manifest.json"
	"docs/qa/manifests/rogue_meta_critic_manifest.json" = "docs/qa/manifests/rogue_meta_critic_manifest.json"
	"docs/qa/manifests/monk_meta_critic_manifest.json" = "docs/qa/manifests/monk_meta_critic_manifest.json"
	"docs/qa/manifests/shaman_meta_critic_manifest.json" = "docs/qa/manifests/shaman_meta_critic_manifest.json"
	"docs/qa/manifests/engineer_meta_critic_manifest.json" = "docs/qa/manifests/engineer_meta_critic_manifest.json"
	"docs/qa/manifests/mercenary_meta_critic_manifest.json" = "docs/qa/manifests/mercenary_meta_critic_manifest.json"
	"docs/qa/manifests/beast_rider_meta_critic_manifest.json" = "docs/qa/manifests/beast_rider_meta_critic_manifest.json"
	"docs/qa/planning/PLANNING_SKILL_QA_CHECKLIST.md" = "docs/qa/planning/PLANNING_SKILL_QA_CHECKLIST.md"
	"docs/qa/planning/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md" = "docs/qa/planning/PLANNING_T3_LIVE_HEADLESS_PARITY_CHECKLIST.md"
	"docs/qa/CLASS_QA_BIBLE.md" = "docs/qa/CLASS_QA_BIBLE.md"
	"docs/qa/_CLASS_QA_GATE_TEMPLATE.md" = "docs/qa/_CLASS_QA_GATE_TEMPLATE.md"
	"docs/qa/CLASS_QA_SIGNOFF.md" = "docs/qa/CLASS_QA_SIGNOFF.md"
	"docs/qa/BUG_REPORT_WORKFLOW.md" = "docs/qa/BUG_REPORT_WORKFLOW.md"
	"docs/reference/player_grid_api.md" = "docs/reference/player_grid_api.md"
	"docs/reference/tile_registry.md" = "docs/reference/tile_registry.md"
	"docs/reference/tile_terrain_peering.md" = "docs/reference/tile_terrain_peering.md"
	"docs/reference/asset_manifest.md" = "docs/reference/asset_manifest.md"
	"docs/audits/ARCHER_BIBLE_AUDIT.md" = "docs/audits/ARCHER_BIBLE_AUDIT.md"
	"docs/design/TACTICAL_COMBAT_PARITY_PLAN.md" = "docs/design/TACTICAL_COMBAT_PARITY_PLAN.md"
	"docs/design/sandbox_map_system.md" = "docs/design/sandbox_map_system.md"
	"docs/design/logs/PLANNING_GAUNTLET_ROUND31.md" = "docs/design/logs/PLANNING_GAUNTLET_ROUND31.md"
	"docs/design/logs/PLANNING_GAUNTLET_BACKLOG.md" = "docs/design/logs/PLANNING_GAUNTLET_BACKLOG.md"
	"docs/design/logs/PLANNING_GAUNTLET_LOOP.md" = "docs/design/logs/PLANNING_GAUNTLET_LOOP.md"
	"docs/design/logs/MOVE_PREVIEW_IMPLEMENTATION_LOG.md" = "docs/design/logs/MOVE_PREVIEW_IMPLEMENTATION_LOG.md"
	"res://tests/gates/KnightQaGate.tscn" = "res://tests/gates/KnightQaGate.tscn"
	"res://tests/gates/ArcherQaGate.tscn" = "res://tests/gates/ArcherQaGate.tscn"
	"res://tests/gates/BruiserQaGate.tscn" = "res://tests/gates/BruiserQaGate.tscn"
	"res://tests/gates/LancerQaGate.tscn" = "res://tests/gates/LancerQaGate.tscn"
	"res://tests/gates/MageQaGate.tscn" = "res://tests/gates/MageQaGate.tscn"
	"res://tests/gates/ClericQaGate.tscn" = "res://tests/gates/ClericQaGate.tscn"
	"res://tests/gates/RogueQaGate.tscn" = "res://tests/gates/RogueQaGate.tscn"
	"res://tests/gates/MonkQaGate.tscn" = "res://tests/gates/MonkQaGate.tscn"
	"res://tests/gates/ShamanQaGate.tscn" = "res://tests/gates/ShamanQaGate.tscn"
	"res://tests/gates/EngineerQaGate.tscn" = "res://tests/gates/EngineerQaGate.tscn"
	"res://tests/gates/MercenaryQaGate.tscn" = "res://tests/gates/MercenaryQaGate.tscn"
	"res://tests/gates/BeastRiderQaGate.tscn" = "res://tests/gates/BeastRiderQaGate.tscn"
	"res://tests/gates/PlanningQaGate.tscn" = "res://tests/gates/PlanningQaGate.tscn"
	"res://tests/gates/AoeFootprintQaGate.tscn" = "res://tests/gates/AoeFootprintQaGate.tscn"
	"res://tests/gates/T3MimicHeadless.tscn" = "res://tests/gates/T3MimicHeadless.tscn"
	"tests/gates/KnightQaGate.tscn" = "tests/gates/KnightQaGate.tscn"
	"tests/gates/PlanningQaGate.tscn" = "tests/gates/PlanningQaGate.tscn"
	"tests/gates/T3MimicHeadless.tscn" = "tests/gates/T3MimicHeadless.tscn"
	"docs\qa\classes\KNIGHT_QA_GATE.md" = "docs\qa\classes\KNIGHT_QA_GATE.md"
	"docs\qa\manifests\knight_meta_critic_manifest.json" = "docs\qa\manifests\knight_meta_critic_manifest.json"
}
Replace-InTree @("*.md", "*.mdc", "*.ps1", "*.gd", "*.tscn", "*.json", "*.tsx") $refMap

Write-Output "=== Fixing relative doc links under docs/qa ==="
Get-ChildItem (Join-Path $root "docs/qa") -Recurse -File -Include "*.md" | ForEach-Object {
	$text = [System.IO.File]::ReadAllText($_.FullName)
	$orig = $text
	$text = $text -replace '\]\(design/', '](../../design/'
	$text = $text -replace '\]\(\.\./\.cursor/', '](../../../.cursor/'
	$text = $text -replace '\]\(CLASS_QA_BIBLE\.md\)', '](../CLASS_QA_BIBLE.md)'
	$text = $text -replace '\]\(_CLASS_QA_GATE_TEMPLATE\.md\)', '](../_CLASS_QA_GATE_TEMPLATE.md)'
	$text = $text -replace '\]\(CLASS_QA_SIGNOFF\.md\)', '](../CLASS_QA_SIGNOFF.md)'
	if ($text -ne $orig) {
		[System.IO.File]::WriteAllText($_.FullName, $text)
		Write-Output "fixed links in $($_.FullName.Substring($root.Length + 1))"
	}
}

Write-Output "=== Phase 2: reports/logs (loose root files) ==="
Ensure-Dir "reports/logs"
Get-ChildItem (Join-Path $root "reports") -File -ErrorAction SilentlyContinue |
	Where-Object { $_.Name -ne "reorganize_layout.log" } |
	ForEach-Object {
	Move-RepoFile "reports/$($_.Name)" "reports/logs/$($_.Name)"
}

Write-Output "=== Phase 2: tests/runners, tests/live, tests/harness ==="
@("tests/runners", "tests/live", "tests/harness") | ForEach-Object { Ensure-Dir $_ }
$testMap = [ordered]@{}

Get-ChildItem (Join-Path $root "tests") -File -Filter "run_*.gd" | ForEach-Object {
	Register-PathMove $testMap "tests/$($_.Name)" "tests/runners/$($_.Name)"
	$uid = "tests/$($_.BaseName).gd.uid"
	if (Test-Path (Join-Path $root $uid)) { Register-PathMove $testMap $uid "tests/runners/$($_.BaseName).gd.uid" }
}
Get-ChildItem (Join-Path $root "tests") -File -Filter "live_*.gd" | ForEach-Object {
	Register-PathMove $testMap "tests/$($_.Name)" "tests/live/$($_.Name)"
	$uid = "tests/$($_.BaseName).gd.uid"
	if (Test-Path (Join-Path $root $uid)) { Register-PathMove $testMap $uid "tests/live/$($_.BaseName).gd.uid" }
}
Get-ChildItem (Join-Path $root "tests") -File -Filter "*.tscn" | ForEach-Object {
	Register-PathMove $testMap "tests/$($_.Name)" "tests/gates/$($_.Name)"
}
Get-ChildItem (Join-Path $root "tests") -File | Where-Object {
	$_.Name -ne "README.md" -and $_.Extension -in @(".gd", ".uid")
} | ForEach-Object {
	Register-PathMove $testMap "tests/$($_.Name)" "tests/harness/$($_.Name)"
}
if ($testMap.Count -gt 0) {
	Replace-InTree @("*.md", "*.mdc", "*.ps1", "*.gd", "*.tscn", "*.json", "*.uid") $testMap
}

Write-Output "=== Phase 2: docs/design subfolders ==="
@("docs/design/planning", "docs/design/combat", "docs/design/classes", "docs/design/process") | ForEach-Object { Ensure-Dir $_ }
$designMap = [ordered]@{}
@(
	@("docs/design/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md", "docs/design/planning/HOVER_PREVIEW_CARRIED_SSOT_PLAN.md"),
	@("docs/design/MOVE_PREVIEW_RULES.md", "docs/design/planning/MOVE_PREVIEW_RULES.md"),
	@("docs/design/PLANNING_VOLUNTARY_WALK_MILESTONE.md", "docs/design/planning/PLANNING_VOLUNTARY_WALK_MILESTONE.md"),
	@("docs/design/PLANNING_REFACTOR_MATRIX.md", "docs/design/planning/PLANNING_REFACTOR_MATRIX.md"),
	@("docs/design/ACTION_RANGE_LATEST_STAND.md", "docs/design/planning/ACTION_RANGE_LATEST_STAND.md"),
	@("docs/design/intent_architecture_evidence.md", "docs/design/planning/intent_architecture_evidence.md"),
	@("docs/design/TACTICAL_COMBAT_PARITY_PLAN.md", "docs/design/combat/TACTICAL_COMBAT_PARITY_PLAN.md"),
	@("docs/design/combat-core-closeout.md", "docs/design/combat/combat-core-closeout.md"),
	@("docs/design/ability-data.md", "docs/design/combat/ability-data.md"),
	@("docs/design/enemy-design.md", "docs/design/combat/enemy-design.md"),
	@("docs/design/roguelike-run.md", "docs/design/combat/roguelike-run.md"),
	@("docs/design/presentation-audio-ui.md", "docs/design/combat/presentation-audio-ui.md"),
	@("docs/design/world-assets-and-map.md", "docs/design/combat/world-assets-and-map.md"),
	@("docs/design/knight-template.md", "docs/design/classes/knight-template.md"),
	@("docs/design/bruiser-template.md", "docs/design/classes/bruiser-template.md"),
	@("docs/design/class-rollout.md", "docs/design/classes/class-rollout.md"),
	@("docs/design/00-gauntlet-loop-cursor.md", "docs/design/process/00-gauntlet-loop-cursor.md"),
	@("docs/design/00-remaining-work-suite-plan.md", "docs/design/process/00-remaining-work-suite-plan.md"),
	@("docs/design/GAUNTLET_REVIEW_RESULTS.md", "docs/design/process/GAUNTLET_REVIEW_RESULTS.md"),
	@("docs/design/LOCAL_CLOUD_SYNC.md", "docs/design/process/LOCAL_CLOUD_SYNC.md"),
	@("docs/design/UNATTENDED_RUN.md", "docs/design/process/UNATTENDED_RUN.md"),
	@("docs/design/UNATTENDED_RUN.template.md", "docs/design/process/UNATTENDED_RUN.template.md"),
	@("docs/design/verification-matrix.md", "docs/design/process/verification-matrix.md"),
	@("docs/design/REMAINING_WORK_MAP.md", "docs/design/process/REMAINING_WORK_MAP.md"),
	@("docs/design/workbench.md", "docs/design/process/workbench.md"),
	@("docs/design/01-doc-polish-protocol.md", "docs/design/process/01-doc-polish-protocol.md"),
	@("docs/design/EXTRA_RULES_TO_MODULES_PLAN.md", "docs/design/process/EXTRA_RULES_TO_MODULES_PLAN.md"),
	@("docs/design/LAYER_SHAPE_CONVERSION_GATE.md", "docs/design/process/LAYER_SHAPE_CONVERSION_GATE.md"),
	@("docs/design/_TEMPLATE.md", "docs/design/process/_TEMPLATE.md")
) | ForEach-Object { Register-PathMove $designMap $_[0] $_[1] }
if ($designMap.Count -gt 0) {
	Replace-InTree @("*.md", "*.mdc", "*.ps1", "*.gd", "*.tscn", "*.json", "*.tsx") $designMap
}

Write-Output "=== Cleanup scratch files ==="
@(
	".tmp_patch4.py", ".tmp_patch5.py", ".tmp_patch6.py", ".tmp_patch7.py",
	".tmp_piece1e_patch.ps1", ".tmp_piece1f_patch.ps1",
	"scripts/_patch_hover_ssot_phase1.ps1", "scripts/_patch_hover_ssot_phase1b.ps1",
	"scripts/_patch_hover_ssot_phase2.ps1"
) | ForEach-Object {
	$p = Join-Path $root $_
	if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Write-Output "deleted $_" }
}

Write-Output "=== Done ==="
