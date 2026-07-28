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
const _TOL_USES := 0.05
const _TOL_PICK := 10.0
const _TOL_DMG := 1.5
const _TOL_HEAL := 0.1
const _TOL_KILL := 0.02

const _TOL_HP_TAKEN := 1.5
const _TOL_MITIGATED := 0.5
const _TOL_SURVIVAL := 1.5
const _TOL_END_HP := 8.0
const _TOL_WIN_RATE := 8.0

var _team_filter: int = GameEnums.Team.PLAYER
var _scroll: ScrollContainer
var _class_tree: Tree
var _tree: Tree
var _rules_label: Label


func _init(team: int = GameEnums.Team.PLAYER) -> void:
	_team_filter = team
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	if _team_filter == GameEnums.Team.PLAYER:
		title.text = "Level 3.1: Player Meta & Combat"
	else:
		title.text = "Level 3.2: Enemy Meta & Combat"
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
	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(scroll_vbox)
	var class_hdr := Label.new()
	class_hdr.text = "Class Survival & Damage"
	MassSimTheme.style_muted(class_hdr)
	scroll_vbox.add_child(class_hdr)
	_class_tree = Tree.new()
	_class_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_tree.custom_minimum_size = Vector2(0, 160)
	_class_tree.columns = 6
	_class_tree.column_titles_visible = true
	_class_tree.hide_root = true
	_class_tree.set_column_title(0, "Class")
	_class_tree.set_column_title(1, "WR%")
	_class_tree.set_column_title(2, "HP Dmg/T")
	_class_tree.set_column_title(3, "Mitig/T")
	_class_tree.set_column_title(4, "Survival")
	_class_tree.set_column_title(5, "End HP%")
	_class_tree.set_column_expand_ratio(0, 3)
	for col: int in range(1, 6):
		_class_tree.set_column_expand_ratio(col, 1)
	scroll_vbox.add_child(_class_tree)
	var skill_hdr := Label.new()
	skill_hdr.text = "Skill Meta"
	MassSimTheme.style_muted(skill_hdr)
	scroll_vbox.add_child(skill_hdr)
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
	scroll_vbox.add_child(_tree)


func bind_report(report: MassSimBatchReport) -> void:
	_class_tree.clear()
	_class_tree.create_item()
	_tree.clear()
	_tree.create_item()
	if report == null or report.is_empty():
		_rules_label.text = "Run a batch (New Epoch recommended) to populate skill meta."
		var empty_root := _class_tree.get_root()
		var class_empty := _class_tree.create_item(empty_root)
		class_empty.set_text(0, "No class combat data yet.")
		return
	_rules_label.text = MassSimRulesEpoch.detailed_rules_label(
		MassSimSkirmishSetup.from_dict(report.skirmish_setup),
	)
	_add_class_combat_sections(report)
	if _team_filter == GameEnums.Team.PLAYER:
		_add_commander_section(report)
	_add_skill_sections(report)
	if _team_filter == GameEnums.Team.PLAYER:
		_add_passive_section(report)
		_add_economy_section(report)


func _team_color() -> Color:
	return _COLOR_PLAYER if _team_filter == GameEnums.Team.PLAYER else _COLOR_ENEMY


func _add_class_combat_sections(report: MassSimBatchReport) -> void:
	var rows: Array[Dictionary] = []
	for row: Dictionary in report.class_combat_rows:
		if int(row.get("team", -1)) != _team_filter:
			continue
		rows.append(row)
	if rows.is_empty():
		var root := _class_tree.get_root()
		var empty := _class_tree.create_item(root)
		empty.set_text(0, "No class combat data — run a new batch after this update.")
		return
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return report.class_display_name(String(a.get("class_id", ""))) < report.class_display_name(String(b.get("class_id", "")))
	)
	var avgs: Dictionary = _class_combat_avgs(rows)
	var root := _class_tree.get_root()
	for row: Dictionary in rows:
		_add_class_combat_row(report, root, row, _team_filter, avgs, _team_color())


func _add_class_combat_row(
	report: MassSimBatchReport,
	parent: TreeItem,
	row: Dictionary,
	team: int,
	team_avgs: Dictionary,
	team_color: Color,
) -> void:
	var item := _class_tree.create_item(parent)
	var class_id: String = String(row.get("class_id", ""))
	var unit_turns: int = int(row.get("unit_turns", 0))
	var has_sample: bool = unit_turns > 0 or bool(row.get("has_survival_sample", false))
	var hp_taken: int = int(row.get("hp_damage_taken", 0))
	var mitigated: int = int(row.get("damage_mitigated", 0))
	var lifespan_samples: int = int(row.get("lifespan_samples", 0))
	var lifespan_sum: int = int(row.get("lifespan_turns_sum", 0))
	var end_hp_samples: int = int(row.get("end_hp_pct_samples", 0))
	var roster_apps: int = int(row.get("roster_appearances", 0))
	var roster_wins: int = int(row.get("roster_wins", 0))
	var has_win: bool = bool(row.get("has_win_sample", roster_apps > 0))
	item.set_text(0, report.class_display_name(class_id))
	item.set_custom_color(0, team_color.lightened(0.1))
	if has_win:
		var wr: float = float(row.get("win_rate_pct", 0.0))
		item.set_text(1, "%.1f%%" % wr)
		var wr_label: String = "player" if team == GameEnums.Team.PLAYER else "enemy"
		item.set_tooltip_text(1, "%d %s wins when class on roster ÷ %d appearances (%.1f%%)." % [
			roster_wins, wr_label, roster_apps, wr,
		])
		_color_metric(item, 1, wr, float(team_avgs.get("win_rate_pct", 0.0)), _TOL_WIN_RATE)
	else:
		item.set_text(1, "—")
		item.set_tooltip_text(1, "No sample — class never appeared on a roster in this batch.")
		_color_no_sample(item, 1)
	if has_sample:
		var hp_pt: float = float(row.get("hp_damage_taken_per_turn", 0.0))
		item.set_text(2, "%.2f" % hp_pt)
		item.set_tooltip_text(2, "%d HP damage taken over %d class unit-turns." % [hp_taken, unit_turns])
		_color_metric(item, 2, hp_pt, float(team_avgs.get("hp_damage_taken_per_turn", 0.0)), _TOL_HP_TAKEN, true)
		var mit_pt: float = float(row.get("damage_mitigated_per_turn", 0.0))
		item.set_text(3, "%.2f" % mit_pt)
		item.set_tooltip_text(3, "%d armor damage mitigated over %d class unit-turns." % [mitigated, unit_turns])
		_color_metric(item, 3, mit_pt, float(team_avgs.get("damage_mitigated_per_turn", 0.0)), _TOL_MITIGATED)
	else:
		for col: int in [2, 3]:
			item.set_text(col, "—")
			item.set_tooltip_text(col, "No sample — class did not appear in this batch.")
			_color_no_sample(item, col)
	if lifespan_samples > 0:
		var survival: float = float(row.get("avg_survival_turns", 0.0))
		item.set_text(4, "%.1f" % survival)
		item.set_tooltip_text(4, "%d total turns alive over %d unit instances." % [lifespan_sum, lifespan_samples])
		_color_metric(item, 4, survival, float(team_avgs.get("avg_survival_turns", 0.0)), _TOL_SURVIVAL)
	else:
		item.set_text(4, "—")
		item.set_tooltip_text(4, "No sample — run a new batch to collect survival telemetry.")
		_color_no_sample(item, 4)
	if end_hp_samples > 0:
		var end_hp: float = float(row.get("avg_end_hp_pct", 0.0))
		item.set_text(5, "%.0f%%" % end_hp)
		item.set_tooltip_text(5, "%.1f%% average end HP across %d unit instances (0%% if dead)." % [end_hp, end_hp_samples])
		_color_metric(item, 5, end_hp, float(team_avgs.get("avg_end_hp_pct", 0.0)), _TOL_END_HP)
	else:
		item.set_text(5, "—")
		item.set_tooltip_text(5, "No sample — run a new batch to collect end-of-battle HP telemetry.")
		_color_no_sample(item, 5)


func _class_combat_avgs(rows: Array[Dictionary]) -> Dictionary:
	var hp_vals: Array[float] = []
	var mit_vals: Array[float] = []
	var survival_vals: Array[float] = []
	var end_hp_vals: Array[float] = []
	var wr_vals: Array[float] = []
	for row: Dictionary in rows:
		if int(row.get("unit_turns", 0)) > 0:
			hp_vals.append(float(row.get("hp_damage_taken_per_turn", 0.0)))
			mit_vals.append(float(row.get("damage_mitigated_per_turn", 0.0)))
		if int(row.get("lifespan_samples", 0)) > 0:
			survival_vals.append(float(row.get("avg_survival_turns", 0.0)))
		if int(row.get("end_hp_pct_samples", 0)) > 0:
			end_hp_vals.append(float(row.get("avg_end_hp_pct", 0.0)))
		if bool(row.get("has_win_sample", int(row.get("roster_appearances", 0)) > 0)):
			wr_vals.append(float(row.get("win_rate_pct", 0.0)))
	return {
		"win_rate_pct": _avg_floats(wr_vals),
		"hp_damage_taken_per_turn": _avg_floats(hp_vals),
		"damage_mitigated_per_turn": _avg_floats(mit_vals),
		"avg_survival_turns": _avg_floats(survival_vals),
		"avg_end_hp_pct": _avg_floats(end_hp_vals),
	}


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
	var sample_turns: int = int(ai.get("sample_turns", 0))
	var sim_turns: int = maxi(report.total_sim_turns, 1)
	var row := _tree.create_item(hdr)
	row.set_text(0, "Utility / turn")
	row.set_text(1, "%.2f" % float(ai.get("avg_utility_per_turn", 0.0)))
	row.set_tooltip_text(1, "%.1f total utility over %d Commander planning turns.\n%s" % [
		float(ai.get("utility_sum", 0.0)), sample_turns, "Average Commander utility score per planning turn.",
	])
	var row2 := _tree.create_item(hdr)
	row2.set_text(0, "Holds / turn")
	row2.set_text(1, "%.2f" % float(ai.get("holds_per_turn", 0.0)))
	row2.set_tooltip_text(1, "%d holds over %d sim turns.\nTimes AI skipped a legal skill per sim turn." % [
		int(ai.get("total_holds", 0)), sim_turns,
	])
	var row3 := _tree.create_item(hdr)
	row3.set_text(0, "Skill commits / turn")
	row3.set_text(1, "%.2f" % float(ai.get("skill_commits_per_turn", 0.0)))
	row3.set_tooltip_text(1, "%d skill commits over %d sim turns.\nAbility actions committed per sim turn." % [
		int(ai.get("total_skill_commits", 0)), sim_turns,
	])


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
	var team_title: String = "PLAYER SKILLS" if _team_filter == GameEnums.Team.PLAYER else "ENEMY SKILLS"
	_add_team_block(report, _team_filter, team_title, _team_color(), by_team_class)


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
			_add_skill_row(report, class_hdr, sk as Dictionary, team, _class_skill_avgs(skills, team))


func _add_skill_row(
	report: MassSimBatchReport,
	parent: TreeItem,
	row: Dictionary,
	team: int,
	class_avgs: Dictionary,
) -> void:
	var item := _tree.create_item(parent)
	var name: String = String(row.get("display_name", row.get("ability_id", "?")))
	var ability_id: String = String(row.get("ability_id", ""))
	var uses: int = int(row.get("uses", 0))
	var legal: int = int(row.get("turns_legal", 0))
	var unit_turns: int = int(row.get("class_unit_turns", 0))
	var has_roster: bool = bool(row.get("has_roster_sample", unit_turns > 0 or uses > 0 or legal > 0))
	var has_pick: bool = bool(row.get("has_pick_sample", team == GameEnums.Team.PLAYER and legal > 0))
	var dmg: int = int(row.get("damage_dealt", 0))
	var heal: int = int(row.get("healing_done", 0))
	var kills: int = int(row.get("kills", 0))
	item.set_text(0, name)
	var ability_tip: String = MassSimAbilityText.tooltip_for_ability_id(ability_id)
	if not ability_tip.is_empty():
		item.set_tooltip_text(0, ability_tip)
	if has_roster:
		var uses_pt: float = float(row.get("uses_per_turn", 0.0))
		item.set_text(1, "%.3f" % uses_pt)
		item.set_tooltip_text(1, "%d uses over %d class unit-turns.\n%s" % [uses, unit_turns, _TIP_USES])
		_color_metric(item, 1, uses_pt, float(class_avgs.get("uses_per_turn", 0.0)), _TOL_USES)
	else:
		item.set_text(1, "—")
		item.set_tooltip_text(1, "No sample — skill never appeared on a roster in this batch.")
		_color_no_sample(item, 1)
	if has_pick:
		var pick: float = float(row.get("pick_rate_when_legal_pct", 0.0))
		item.set_text(2, "%.0f%%" % pick)
		item.set_tooltip_text(2, "%d uses when legal ÷ %d turns legal (%.0f%%).\n%s" % [uses, legal, pick, _TIP_PICK])
		_color_metric(item, 2, pick, float(class_avgs.get("pick_rate_when_legal_pct", 0.0)), _TOL_PICK)
	else:
		item.set_text(2, "—")
		if team != GameEnums.Team.PLAYER:
			item.set_tooltip_text(2, "Pick% only tracked for player Commander AI skills.")
		elif not has_roster:
			item.set_tooltip_text(2, "No sample — skill was not on any roster in this batch.")
		else:
			item.set_tooltip_text(2, "No sample — skill was never a legal Commander option in this batch.")
		_color_no_sample(item, 2)
	if has_roster:
		var dmg_pt: float = float(row.get("damage_per_turn", 0.0))
		var heal_pt: float = float(row.get("heal_per_turn", 0.0))
		var kill_pt: float = float(row.get("kills_per_turn", 0.0))
		item.set_text(3, "%.2f" % dmg_pt)
		item.set_tooltip_text(3, "%d total damage over %d class unit-turns.\n%s" % [dmg, unit_turns, _TIP_DMG])
		_color_metric(item, 3, dmg_pt, float(class_avgs.get("damage_per_turn", 0.0)), _TOL_DMG)
		item.set_text(4, "%.2f" % heal_pt)
		item.set_tooltip_text(4, "%d total healing over %d class unit-turns.\n%s" % [heal, unit_turns, _TIP_HEAL])
		_color_metric(item, 4, heal_pt, float(class_avgs.get("heal_per_turn", 0.0)), _TOL_HEAL)
		item.set_text(5, "%.3f" % kill_pt)
		item.set_tooltip_text(5, "%d total kills over %d class unit-turns.\n%s" % [kills, unit_turns, _TIP_KILL])
		_color_metric(item, 5, kill_pt, float(class_avgs.get("kills_per_turn", 0.0)), _TOL_KILL)
	else:
		for col: int in [3, 4, 5]:
			item.set_text(col, "—")
			item.set_tooltip_text(col, "No sample — skill never appeared on a roster in this batch.")
			_color_no_sample(item, col)
	var notes: PackedStringArray = PackedStringArray()
	if int(row.get("action_failed", 0)) > 0:
		notes.append("fails %d" % int(row.get("action_failed", 0)))
	if legal > 0 and team == GameEnums.Team.PLAYER:
		notes.append("legal %d turns" % legal)
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
		var appearances: int = int(row.get("unit_appearances", 0))
		var wins: int = int(row.get("player_wins", 0))
		item.set_text(0, _format_passive_name(pid))
		var passive_tip: String = MassSimAbilityText.tooltip_for_passive_id(pid)
		if not passive_tip.is_empty():
			item.set_tooltip_text(0, passive_tip)
		if appearances > 0:
			var wr: float = float(row.get("player_win_pct", 0.0))
			item.set_text(1, "%d units" % appearances)
			item.set_tooltip_text(1, "Appeared on %d player roster slots in this batch." % appearances)
			item.set_text(2, "%.1f%% WR" % wr)
			item.set_tooltip_text(2, "%d wins with this passive ÷ %d appearances (%.1f%%).\n%s" % [
				wins, appearances, wr, _TIP_PASSIVE_WR,
			])
			_color_metric(item, 2, wr, report.player_win_pct, 8.0)
		else:
			item.set_text(1, "—")
			item.set_tooltip_text(1, "No sample — passive never rolled onto a roster in this batch.")
			item.set_text(2, "—")
			item.set_tooltip_text(2, "No sample — passive never rolled onto a roster in this batch.")
			_color_no_sample(item, 1)
			_color_no_sample(item, 2)
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
	var turns: int = int(eco.get("total_sim_turns", maxi(report.total_sim_turns, 1)))
	var battles: int = int(eco.get("total_battles", maxi(report.total_battles, 1)))
	var rows: Array[Dictionary] = [
		{
			"label": "Assisted damage / turn",
			"value": "%.2f" % float(eco.get("assisted_damage_per_turn", 0.0)),
			"tip": "%d total assisted damage ÷ %d sim turns." % [int(eco.get("total_assisted_damage", 0)), turns],
			"skip_color": true,
		},
		{
			"label": "Shields / turn",
			"value": "%.2f" % float(eco.get("assisted_shields_per_turn", 0.0)),
			"tip": "%d total shields granted ÷ %d sim turns." % [int(eco.get("total_assisted_shields", 0)), turns],
			"skip_color": true,
		},
		{
			"label": "Overkill / turn",
			"value": "%.2f" % float(eco.get("overkill_per_turn", 0.0)),
			"tip": "%d total overkill damage ÷ %d sim turns." % [int(eco.get("total_overkill", 0)), turns],
			"metric": float(eco.get("overkill_per_turn", 0.0)),
			"target": 0.0,
			"tolerance": 0.5,
			"invert": true,
		},
		{
			"label": "Floated AP / turn",
			"value": "%.2f" % float(eco.get("floated_ap_per_turn", 0.0)),
			"tip": "%d total unused AP banked ÷ %d sim turns." % [int(eco.get("total_floated_ap", 0)), turns],
			"metric": float(eco.get("floated_ap_per_turn", 0.0)),
			"target": 0.0,
			"tolerance": 0.15,
			"invert": true,
		},
		{
			"label": "Whiff battles",
			"value": "%.1f%%" % float(eco.get("whiff_battle_pct", 0.0)),
			"tip": "%d battles with whiffs ÷ %d battles (%.1f%%)." % [
				int(eco.get("battles_with_whiffs", 0)), battles, float(eco.get("whiff_battle_pct", 0.0)),
			],
			"metric": float(eco.get("whiff_battle_pct", 0.0)),
			"target": MassSimConstants.TARGET_WHIFF_BATTLES_PCT,
			"tolerance": 5.0,
			"invert": true,
		},
	]
	for spec: Dictionary in rows:
		var item := _tree.create_item(hdr)
		item.set_text(0, String(spec.get("label", "")))
		item.set_text(1, String(spec.get("value", "")))
		item.set_tooltip_text(1, String(spec.get("tip", "")))
		if bool(spec.get("skip_color", false)):
			continue
		var metric: float = float(spec.get("metric", 0.0))
		var target: float = float(spec.get("target", metric))
		var tol: float = float(spec.get("tolerance", 1.0))
		var invert: bool = bool(spec.get("invert", false))
		if invert:
			_color_metric(item, 1, metric, target, tol, true)
		else:
			_color_metric(item, 1, metric, target, tol)


func _format_passive_name(passive_id: String) -> String:
	return passive_id.replace("_", " ").capitalize()


func _class_skill_avgs(skills: Array, team: int) -> Dictionary:
	var uses_vals: Array[float] = []
	var pick_vals: Array[float] = []
	var dmg_vals: Array[float] = []
	var heal_vals: Array[float] = []
	var kill_vals: Array[float] = []
	for sk: Variant in skills:
		if not sk is Dictionary:
			continue
		var row: Dictionary = sk as Dictionary
		var legal: int = int(row.get("turns_legal", 0))
		var uses: int = int(row.get("uses", 0))
		var unit_turns: int = int(row.get("class_unit_turns", 0))
		var has_roster: bool = bool(row.get("has_roster_sample", unit_turns > 0 or uses > 0 or legal > 0))
		var has_pick: bool = bool(row.get("has_pick_sample", team == GameEnums.Team.PLAYER and legal > 0))
		if has_roster:
			uses_vals.append(float(row.get("uses_per_turn", 0.0)))
			dmg_vals.append(float(row.get("damage_per_turn", 0.0)))
			heal_vals.append(float(row.get("heal_per_turn", 0.0)))
			kill_vals.append(float(row.get("kills_per_turn", 0.0)))
		if has_pick:
			pick_vals.append(float(row.get("pick_rate_when_legal_pct", 0.0)))
	return {
		"uses_per_turn": _avg_floats(uses_vals),
		"pick_rate_when_legal_pct": _avg_floats(pick_vals),
		"damage_per_turn": _avg_floats(dmg_vals),
		"heal_per_turn": _avg_floats(heal_vals),
		"kills_per_turn": _avg_floats(kill_vals),
	}


func _avg_floats(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


func _color_metric(
	item: TreeItem,
	column: int,
	value: float,
	average: float,
	tolerance: float,
	invert: bool = false,
) -> void:
	var color: Color = (
		MassSimTheme.directional_color_inverted(value, average, tolerance)
		if invert
		else MassSimTheme.directional_color(value, average, tolerance)
	)
	item.set_custom_color(column, color)


func _color_no_sample(item: TreeItem, column: int) -> void:
	item.set_custom_color(column, _COLOR_MUTED)
