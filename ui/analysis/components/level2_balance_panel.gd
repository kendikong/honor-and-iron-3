class_name Level2BalancePanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var _tier_tree: Tree
var _detail: RichTextLabel
var _empty: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 2: Balance & Synergy"
	MassSimTheme.style_section(title)
	add_child(title)

	_empty = Label.new()
	_empty.text = "Run a batch to generate tier lists."
	MassSimTheme.style_muted(_empty)
	add_child(_empty)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	var tier_vbox := VBoxContainer.new()
	tier_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(tier_vbox)

	var tier_lbl := Label.new()
	tier_lbl.text = "Algorithmic Sâ€“F Tier List"
	MassSimTheme.style_muted(tier_lbl)
	tier_vbox.add_child(tier_lbl)

	_tier_tree = Tree.new()
	_tier_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tier_tree.hide_root = true
	_tier_tree.column_titles_visible = false
	_tier_tree.item_selected.connect(_on_tier_selected)
	tier_vbox.add_child(_tier_tree)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail)


func bind_report(report: MassSimBatchReport) -> void:
	_tier_tree.clear()
	var has_data: bool = report != null and not report.tier_rows.is_empty()
	_empty.visible = not has_data
	if not has_data:
		_detail.text = report.sample_gate_label("tier list") if report != null else ""
		return

	var root := _tier_tree.create_item()
	for row: Dictionary in report.tier_rows:
		var item := _tier_tree.create_item(root)
		var tags: Array = row.get("tags", [])
		var tag_text: String = ""
		if not tags.is_empty():
			tag_text = " [%s]" % ", ".join(tags)
		item.set_text(
			0,
			"%s-Tier: %s (%.1f%% Â· n=%d)%s"
			% [
				String(row["tier"]),
				report.class_display_name(row["class_id"]),
				float(row["win_rate"]),
				int(row["appearances"]),
				tag_text,
			],
		)
		item.set_metadata(0, row)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Distribution Highlights[/b]")
	for snippet: Dictionary in report.matchup_snippets:
		lines.append("â€¢ %s â€” %s" % [snippet["label"], snippet["detail"]])
	lines.append("")
	lines.append("[b]Counterplay Index (heuristic)[/b]")
	if report.tier_rows.size() >= 2:
		var worst: Dictionary = report.tier_rows[report.tier_rows.size() - 1]
		lines.append(
			"â€¢ %s flagged â€” %.1f%% WR, review hard counters."
			% [report.class_display_name(worst["class_id"]), float(worst["win_rate"])]
		)
	_detail.text = "\n".join(lines)


func _on_tier_selected() -> void:
	var item: TreeItem = _tier_tree.get_selected()
	if item == null:
		return
	var row: Variant = item.get_metadata(0)
	if row is Dictionary:
		var d: Dictionary = row as Dictionary
		inspect_requested.emit(
			"Class: %s" % str(d.get("class_id", "")),
			"Tier %s Â· Win rate %.1f%% Â· %d appearances"
			% [d.get("tier", "?"), float(d.get("win_rate", 0.0)), int(d.get("appearances", 0))],
			d,
		)
