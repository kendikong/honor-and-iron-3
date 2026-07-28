class_name Level3EconomyPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _scroll: ScrollContainer
var _body: RichTextLabel


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 3: Skill Meta, AI & Combat Math"
	MassSimTheme.style_section(title)
	add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)


func bind_report(report: MassSimBatchReport) -> void:
	if report == null or report.is_empty():
		_body.text = "[i]Run a batch to populate skill meta and combat telemetry.[/i]"
		return
	var lines: PackedStringArray = PackedStringArray()
	var whiff_pct: float = float(report.battles_with_whiffs) / float(maxi(report.total_battles, 1)) * 100.0

	lines.append("[b]Commander AI (player sprites)[/b]")
	if report.ai_commander_meta.is_empty():
		lines.append("[i]No AI commander meta — run a new batch after this update.[/i]")
	else:
		var ai: Dictionary = report.ai_commander_meta
		lines.append(
			"• Avg utility/turn: [b]%.2f[/b] · Holds/turn: %.2f · Skill commits/turn: %.2f"
			% [
				float(ai.get("avg_utility_per_turn", 0.0)),
				float(ai.get("holds_per_turn", 0.0)),
				float(ai.get("skill_commits_per_turn", 0.0)),
			]
		)
		lines.append(
			"• Total holds: %d · Pruned turns: %d · Battles w/ meta: %d"
			% [int(ai.get("total_holds", 0)), int(ai.get("pruned_turns", 0)), int(ai.get("battles_with_meta", 0))]
		)
	lines.append("")
	lines.append("[b]Class combat (per unit-turn)[/b]")
	if report.class_combat_rows.is_empty():
		lines.append("[i]No class combat rows yet.[/i]")
	else:
		for row: Dictionary in report.class_combat_rows.slice(0, 14):
			var class_name: String = report.class_display_name(row.get("class_id", ""))
			lines.append(
				"• %s — dmg %.2f · taken %.2f · heal %.2f · kills %.3f · AI hold %.0f%%"
				% [
					class_name,
					float(row.get("damage_dealt_per_turn", 0.0)),
					float(row.get("damage_taken_per_turn", 0.0)),
					float(row.get("healing_per_turn", 0.0)),
					float(row.get("kills_per_turn", 0.0)),
					float(row.get("ai_hold_rate_pct", 0.0)),
				]
			)
	lines.append("")
	lines.append("[b]Skill usage (per unit-turn · pick rate when legal)[/b]")
	if report.skill_meta_rows.is_empty():
		lines.append("[i]No skill usage rows — run a new batch.[/i]")
	else:
		for row: Dictionary in report.skill_meta_rows.slice(0, 24):
			lines.append(
				"• %s / [i]%s[/i] — uses %.3f · pick %.0f%% · dmg %.2f · heal %.2f · kills %d"
				% [
					report.class_display_name(row.get("class_id", "")),
					String(row.get("display_name", row.get("ability_id", "?"))),
					float(row.get("uses_per_turn", 0.0)),
					float(row.get("pick_rate_when_legal_pct", 0.0)),
					float(row.get("damage_per_turn", 0.0)),
					float(row.get("heal_per_turn", 0.0)),
					int(row.get("kills", 0)),
				]
			)
	lines.append("")
	lines.append("[b]Economy waste[/b]")
	lines.append(
		"• Assisted damage: %d · Shields: %d · Whiff battles: %.1f%% · Overkill: %d"
		% [report.total_assisted_damage, report.total_assisted_shields, whiff_pct, report.total_overkill]
	)
	_body.text = "\n".join(lines)
