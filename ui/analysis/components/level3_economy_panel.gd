class_name Level3EconomyPanel
extends VBoxContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

const _TIP_USES := "Average times this skill fires per unit-turn (alive turn for that class)."
const _TIP_PICK := "Player Commander AI only: uses ÷ turns skill was legal (capped 100%)."
const _TIP_DMG := "Damage credited to this skill per unit-turn."
const _TIP_HEAL := "Healing credited to this skill per unit-turn."
const _TIP_KILL := "Kills credited to this skill per unit-turn."
const _TIP_PASSIVE_WR := "Player win rate when this passive was randomly assigned to a roster unit."

const _COLOR_PLAYER := Color(0.45, 0.82, 1.0)
const _COLOR_ENEMY := Color(1.0, 0.55, 0.45)
const _COLOR_HEADER := Color(0.85, 0.88, 0.95)
const _COLOR_MUTED := Color(0.65, 0.68, 0.72)

var _scroll: ScrollContainer
var _tree: Tree
var _rules_label: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Level 3: Skill Meta, AI & Combat Math"
	MassSimTheme.style_section(title)
	add_child(title)
	_rules_label = Label.new()
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MassSimTheme.style_muted(_rules_label)
	add_child(_rules_label)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 420)
	add_child(_scroll)
	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 7
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.set_column_title(0, "Skill / Passive")
	_tree.set_column_title(1, "Uses/T")
	_tree.set_column_title(2, "Pick%")
	_tree.set_column_title(3, "Dmg/T")
	_tree.set_column_title(4, "Heal/T")
	_tree.set_column_title(5, "Kill/T")
	_tree.set_column_title(6, "Notes")
	_tree.set_column_expand_ratio(0, 3)
	for col: int in range(1, 7):
		_tree.set_column_expand_ratio(col, 1)
	_scroll.add_child(_tree)


func bind_report(report: MassSimBatchReport) -> void:
	_tree.clear()
	_tree.create_item()
	if report == null or report.is_empty():
		_rules_label.text = "Run a batch (New Epoch recommended) to populate skill meta."
		return
	_rules_label.text = MassSimRulesEpoch.detailed_rules_label()
	_add_commander_section(report)
	_add_skill_sections(report)
	_add_passive_section(report)
	_add_economy_section(report)


func _add_commander_section(report: MassSimBatchReport) -> void:
	var root := _tree.get_root()
	var hdr := _tree.create_item(root)
	hdr.set_text(0, "Commander AI (per sim turn)")
	hdr.set_custom_color(0, _COLOR_HEADER)
	if report.ai_commander_meta.is_empty():
		var empty := _tree.create_item(hdr)
		empty.set_text(0, "No AI meta — run a new batch after this update.")
		return
	var ai: Dictionary = report.ai_commander_meta
	var row := _tree.create_item(hdr)
	row.set_text(0, "Utility / turn")
	row.set_text(1, "%.2f" % float(ai.get("avg_utility_per_turn", 0.0)))
	row.set_tooltip_text(1, "Average Commander utility score per planning turn.")
	var row2 := _tree.create_item(hdr)
	row2.set_text(0, "Holds / turn")
	row2.set_text(1, "%.2f" % float(ai.get("holds_per_turn", 0.0)))
	row2.set_tooltip_text(1, "Times AI skipped a legal skill per sim turn.")
	var row3 := _tree.create_item(hdr)
	row3.set_text(0, "Skill commits / turn")
	row3.set_text(1, "%.2f" % float(ai.get("skill_commits_per_turn", 0.0)))
	row3.set_tooltip_text(1, "Ability actions committed per sim turn.")


func _add_skill_sections(report: MassSimBatchReport) -> void:
	var by_team_class: Dictionary = {}
	for row: Dictionary in report.skill_meta_rows:
		var team: int = int(row.get("team", GameEnums.Team.PLAYER))
		var class_id: String = String(row.get("class_id", ""))
		if class_id.is_empty():
			continue
		var bucket_key: String = "%d:%s" % [team, class_id]
		if not by_team_class.has(bucket_key):
			by_team_class[bucket_key] = {"team": team, "class_id": class_id, "skills": []}
		(by_team_class[bucket_key] as Dictionary)["skills"].append(row)
	_add_team_block(report, GameEnums.Team.PLAYER, "PLAYER SKILLS", _COLOR_PLAYER, by_team_class)
	_add_team_block(report, GameEnums.Team.ENEMY, "ENEMY SKILLS", _COLOR_ENEMY, by_team_class)


func _add_team_block(
	report: MassSimBatchReport,
	team: int,
	title: String,
	color: Color,
	by_team_class: Dictionary,
) -> void:
	var root := _tree.get_root()
	var team_hdr := _tree.create_item(root)
	team_hdr.set_text(0, title)
	team_hdr.set_custom_color(0, color)
	var class_keys: Array = []
	for k: Variant in by_team_class.keys():
		var bucket: Dictionary = by_team_class[k] as Dictionary
		if int(bucket.get("team", -1)) == team:
			class_keys.append(k)
	class_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca: String = String((by_team_class[a] as Dictionary).get("class_id", ""))
		var cb: String = String((by_team_class[b] as Dictionary).get("class_id", ""))
		return report.class_display_name(ca) < report.class_display_name(cb)
	)
	if class_keys.is_empty():
		var empty := _tree.create_item(team_hdr)
		empty.set_text(0, "(no skill telemetry — run a new batch)")
		return
	for ck: Variant in class_keys:
		var bucket: Dictionary = by_team_class[ck] as Dictionary
		var class_id: String = String(bucket.get("class_id", ""))
		var skills: Array = bucket.get("skills", [])
		skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("uses_per_turn", 0.0)) > float(b.get("uses_per_turn", 0.0))
		)
		var class_hdr := _tree.create_item(team_hdr)
		class_hdr.set_text(0, report.class_display_name(class_id))
		class_hdr.set_custom_color(0, color.lightened(0.15))
		class_hdr.set_tooltip_text(0, "All skills tracked for this class in %s roster." % ("player" if team == GameEnums.Team.PLAYER else "enemy"))
		for sk: Variant in skills:
			if not sk is Dictionary:
				continue
			_add_skill_row(report, class_hdr, sk as Dictionary, team)


func _add_skill_row(report: MassSimBatchReport, parent: TreeItem, row: Dictionary, team: int) -> void:
	var item := _tree.create_item(parent)
	var name: String = String(row.get("display_name", row.get("ability_id", "?")))
	item.set_text(0, name)
	item.set_text(1, "%.3f" % float(row.get("uses_per_turn", 0.0)))
	item.set_tooltip_text(1, _TIP_USES)
	var pick: float = float(row.get("pick_rate_when_legal_pct", -1.0))
	if team == GameEnums.Team.PLAYER and pick >= 0.0:
		item.set_text(2, "%.0f%%" % pick)
		item.set_tooltip_text(2, _TIP_PICK)
	else:
		item.set_text(2, "—")
		item.set_tooltip_text(2, "Pick% only tracked for player Commander AI skills.")
	item.set_text(3, "%.2f" % float(row.get("damage_per_turn", 0.0)))
	item.set_tooltip_text(3, _TIP_DMG)
	item.set_text(4, "%.2f" % float(row.get("heal_per_turn", 0.0)))
	item.set_tooltip_text(4, _TIP_HEAL)
	item.set_text(5, "%.3f" % float(row.get("kills_per_turn", 0.0)))
	item.set_tooltip_text(5, _TIP_KILL)
	var notes: PackedStringArray = PackedStringArray()
	if int(row.get("action_failed", 0)) > 0:
		notes.append("fails %d" % int(row.get("action_failed", 0)))
	if int(row.get("turns_legal", 0)) > 0 and team == GameEnums.Team.PLAYER:
		notes.append("legal %d turns" % int(row.get("turns_legal", 0)))
	item.set_text(6, ", ".join(notes))


func _add_passive_section(report: MassSimBatchReport) -> void:
	var root := _tree.get_root()
	var hdr := _tree.create_item(root)
	hdr.set_text(0, "PASSIVES (random assignment · player WR)")
	hdr.set_custom_color(0, _COLOR_HEADER)
	if report.passive_meta_rows.is_empty():
		var empty := _tree.create_item(hdr)
		empty.set_text(0, "No passive data — run a new batch (roster_meta required).")
		return
	for row: Dictionary in report.passive_meta_rows:
		var item := _tree.create_item(hdr)
		var pid: String = String(row.get("passive_id", ""))
		item.set_text(0, _format_passive_name(pid))
		item.set_text(1, "%d units" % int(row.get("unit_appearances", 0)))
		item.set_text(2, "%.1f%% WR" % float(row.get("player_win_pct", 0.0)))
		item.set_tooltip_text(2, _TIP_PASSIVE_WR)
		var classes: Dictionary = row.get("classes", {}) as Dictionary
		var class_bits: PackedStringArray = PackedStringArray()
		for cid: Variant in classes.keys():
			class_bits.append("%s×%d" % [report.class_display_name(str(cid)), int(classes[cid])])
		item.set_text(6, ", ".join(class_bits))


func _add_economy_section(report: MassSimBatchReport) -> void:
	var eco: Dictionary = report.economy_per_turn
	if eco.is_empty():
		return
	var root := _tree.get_root()
	var hdr := _tree.create_item(root)
	hdr.set_text(0, "ECONOMY WASTE (per sim turn)")
	hdr.set_custom_color(0, _COLOR_MUTED)
	var rows: Array[Dictionary] = [
		{"label": "Assisted damage / turn", "value": "%.2f" % float(eco.get("assisted_damage_per_turn", 0.0)), "tip": "Total assisted damage divided by sim turns."},
		{"label": "Shields / turn", "value": "%.2f" % float(eco.get("assisted_shields_per_turn", 0.0)), "tip": "Shields granted per sim turn."},
		{"label": "Overkill / turn", "value": "%.2f" % float(eco.get("overkill_per_turn", 0.0)), "tip": "Wasted overkill damage per sim turn."},
		{"label": "Floated AP / turn", "value": "%.2f" % float(eco.get("floated_ap_per_turn", 0.0)), "tip": "Unused AP banked per sim turn."},
		{"label": "Whiff battles", "value": "%.1f%%" % float(eco.get("whiff_battle_pct", 0.0)), "tip": "% of battles with at least one execution whiff."},
	]
	for spec: Dictionary in rows:
		var item := _tree.create_item(hdr)
		item.set_text(0, String(spec.get("label", "")))
		item.set_text(1, String(spec.get("value", "")))
		item.set_tooltip_text(1, String(spec.get("tip", "")))


func _format_passive_name(passive_id: String) -> String:
	return passive_id.replace("_", " ").capitalize()
