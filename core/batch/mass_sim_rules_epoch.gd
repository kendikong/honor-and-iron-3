class_name MassSimRulesEpoch
extends RefCounted

const _C = preload("res://core/batch/mass_sim_constants.gd")

const LEGACY_EPOCH_ID := "legacy"
const ARCHIVE_DIR := "user://mass_sim_epochs/"
const _MONTH_NAMES: Array[String] = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]


static func fingerprint(setup: MassSimSkirmishSetup = null) -> String:
	var s: MassSimSkirmishSetup = setup if setup != null else MassSimSkirmishSetup.defaults()
	var skill_token: String = "all" if s.player_class_skill_count < 0 else str(s.player_class_skill_count)
	return "p%d_e%d_pl%d_el%d_pp%d_ps%s_rev%s" % [
		s.player_count,
		s.enemy_count,
		s.player_level,
		s.enemy_level,
		s.player_passive_count,
		skill_token,
		_C.RULES_REVISION,
	]


static func fingerprint_label(setup: MassSimSkirmishSetup = null) -> String:
	return detailed_rules_label(setup)


static func detailed_rules_label(setup: MassSimSkirmishSetup = null) -> String:
	var s: MassSimSkirmishSetup = setup if setup != null else MassSimSkirmishSetup.defaults()
	return "%s · rules rev %s" % [s.summary_label(), _C.RULES_REVISION]


static func setup_from_epoch(ep: Dictionary) -> MassSimSkirmishSetup:
	if ep.is_empty():
		return MassSimSkirmishSetup.defaults()
	if ep.has("skirmish_setup"):
		return MassSimSkirmishSetup.from_dict(ep.get("skirmish_setup", {}))
	return _legacy_setup_from_row_fields(ep)


static func _legacy_setup_from_row_fields(ep: Dictionary) -> MassSimSkirmishSetup:
	var s := MassSimSkirmishSetup.defaults()
	var note: String = String(ep.get("note", ""))
	if note.is_empty():
		return s
	return s


static func slugify(label: String) -> String:
	var s: String = label.strip_edges().to_lower()
	s = s.replace(" ", "_")
	var out: PackedStringArray = PackedStringArray()
	for i: int in range(s.length()):
		var c: String = s.substr(i, 1)
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			out.append(c)
		elif c == "-":
			out.append("_")
	return "_".join(out) if not out.is_empty() else "epoch"


static func make_epoch_id(label: String) -> String:
	var stamp: String = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true)
	stamp = stamp.replace(":", "").replace(" ", "_")
	return "%s_%s" % [slugify(label), stamp]


static func archive_log(source_path: String, epoch_label: String) -> String:
	DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)
	var base: String = slugify(epoch_label)
	if base.is_empty():
		base = "archived"
	var dest: String = ARCHIVE_DIR.path_join("%s.jsonl" % base)
	var counter: int = 1
	while FileAccess.file_exists(dest):
		dest = ARCHIVE_DIR.path_join("%s_%d.jsonl" % [base, counter])
		counter += 1
	if not FileAccess.file_exists(source_path):
		var empty: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
		if empty != null:
			empty.close()
		return dest
	var err: Error = DirAccess.copy_absolute(source_path, dest)
	if err != OK:
		printerr("[MassSimRulesEpoch] archive copy failed: %s" % str(err))
		return ""
	return dest


static func fresh_log_path(epoch_id: String) -> String:
	return "user://mass_sim_%s.jsonl" % slugify(epoch_id)


static func ensure_default_epoch(workspace: MassSimWorkspace) -> void:
	normalize_epochs(workspace)
	if not workspace.epochs.is_empty():
		return
	var ep: Dictionary = {
		"id": LEGACY_EPOCH_ID,
		"label": "Legacy (mixed / untagged)",
		"log_path": workspace.log_path,
		"fingerprint": "",
		"created_at": Time.get_unix_time_from_system(),
		"archived": true,
		"note": "Battles run before epoch tracking — not comparable to new epochs.",
	}
	workspace.epochs.append(ep)
	if workspace.active_epoch_id.is_empty():
		workspace.active_epoch_id = LEGACY_EPOCH_ID


static func start_new_epoch(workspace: MassSimWorkspace, change_label: String) -> Dictionary:
	var label: String = change_label.strip_edges()
	if label.is_empty():
		label = "Balance change"
	var setup: MassSimSkirmishSetup = MassSimSkirmishSetup.from_dict(workspace.skirmish_setup)
	setup.clamp()
	var epoch_id: String = make_epoch_id(label)
	var fp: String = fingerprint(setup)
	var archived_path: String = ""
	if FileAccess.file_exists(workspace.log_path):
		archived_path = archive_log(workspace.log_path, label)
		for i: int in range(workspace.epochs.size()):
			var old_ep: Dictionary = workspace.epochs[i] as Dictionary
			if String(old_ep.get("log_path", "")) == workspace.log_path and archived_path != "":
				old_ep["log_path"] = archived_path
				old_ep["archived"] = true
				workspace.epochs[i] = old_ep
		var wipe: FileAccess = FileAccess.open(workspace.log_path, FileAccess.WRITE)
		if wipe != null:
			wipe.close()
	var new_log: String = fresh_log_path(epoch_id)
	var entry: Dictionary = {
		"id": epoch_id,
		"label": label,
		"log_path": new_log,
		"fingerprint": fp,
		"skirmish_setup": setup.to_dict(),
		"created_at": Time.get_unix_time_from_system(),
		"archived": false,
		"archived_from": archived_path,
		"note": detailed_rules_label(setup),
	}
	for i: int in range(workspace.epochs.size()):
		var old: Dictionary = workspace.epochs[i] as Dictionary
		if not bool(old.get("archived", false)):
			old["archived"] = true
			workspace.epochs[i] = old
	workspace.epochs.append(entry)
	workspace.active_epoch_id = epoch_id
	workspace.log_path = new_log
	return entry


static func normalize_epochs(workspace: MassSimWorkspace) -> void:
	for i: int in range(workspace.epochs.size()):
		var ep: Dictionary = workspace.epochs[i] as Dictionary
		if int(ep.get("created_at", 0)) > 0:
			continue
		var parsed: int = _parse_created_at_from_epoch_id(String(ep.get("id", "")))
		if parsed > 0:
			ep["created_at"] = parsed
			workspace.epochs[i] = ep


static func epoch_created_at(ep: Dictionary) -> int:
	var created: int = int(ep.get("created_at", 0))
	if created > 0:
		return created
	return _parse_created_at_from_epoch_id(String(ep.get("id", "")))


static func format_created_at_date(ep: Dictionary) -> String:
	var created: int = epoch_created_at(ep)
	if created <= 0:
		if String(ep.get("id", "")) == LEGACY_EPOCH_ID:
			return "Before tracking"
		return "Date unknown"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(created)
	var month_idx: int = clampi(int(dt.month) - 1, 0, 11)
	return "%s %d, %d" % [_MONTH_NAMES[month_idx], int(dt.day), int(dt.year)]


static func display_label(ep: Dictionary, active: bool = false) -> String:
	var label: String = String(ep.get("label", ep.get("id", "Epoch")))
	var date_text: String = format_created_at_date(ep)
	var suffix: String = " (active)" if active else ""
	return "%s — %s%s" % [date_text, label, suffix]


static func _parse_created_at_from_epoch_id(epoch_id: String) -> int:
	var regex := RegEx.new()
	if regex.compile("(\\d{4})-(\\d{2})-(\\d{2})_(\\d{2})(\\d{2})(\\d{2})$") != OK:
		return 0
	var match: RegExMatch = regex.search(epoch_id)
	if match == null:
		return 0
	var dt: Dictionary = {
		"year": match.get_string(1).to_int(),
		"month": match.get_string(2).to_int(),
		"day": match.get_string(3).to_int(),
		"hour": match.get_string(4).to_int(),
		"minute": match.get_string(5).to_int(),
		"second": match.get_string(6).to_int(),
	}
	return Time.get_unix_time_from_datetime_dict(dt)


static func active_epoch(workspace: MassSimWorkspace) -> Dictionary:
	for ep: Variant in workspace.epochs:
		if ep is Dictionary and String((ep as Dictionary).get("id", "")) == workspace.active_epoch_id:
			return ep as Dictionary
	return {}


static func active_skirmish_setup(workspace: MassSimWorkspace) -> MassSimSkirmishSetup:
	return MassSimSkirmishSetup.from_dict(workspace.skirmish_setup)


static func locked_skirmish_setup(workspace: MassSimWorkspace) -> MassSimSkirmishSetup:
	var ep: Dictionary = active_epoch(workspace)
	if not ep.is_empty() and ep.has("skirmish_setup"):
		return MassSimSkirmishSetup.from_dict(ep.get("skirmish_setup", {}))
	return active_skirmish_setup(workspace)


static func row_epoch_id(row: Dictionary) -> String:
	if not row.has("rules_epoch_id"):
		return LEGACY_EPOCH_ID
	var eid: String = String(row.get("rules_epoch_id", ""))
	return LEGACY_EPOCH_ID if eid.is_empty() else eid


static func row_matches_epoch(row: Dictionary, epoch_id: String) -> bool:
	if epoch_id.is_empty():
		return true
	var row_id: String = row_epoch_id(row)
	if epoch_id == LEGACY_EPOCH_ID:
		return row_id == LEGACY_EPOCH_ID or row_id.is_empty() or not row.has("rules_epoch_id")
	return row_id == epoch_id


static func filter_epoch_rows(rows: Array, epoch_id: String) -> Array:
	if epoch_id.is_empty():
		return rows
	var out: Array = []
	for row: Variant in rows:
		if row is Dictionary and row_matches_epoch(row as Dictionary, epoch_id):
			out.append(row)
	return out


static func analyze_mix(rows: Array) -> Dictionary:
	var epoch_counts: Dictionary = {}
	var fingerprint_counts: Dictionary = {}
	var legacy: int = 0
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var rd: Dictionary = row as Dictionary
		if not rd.has("rules_epoch_id"):
			legacy += 1
			continue
		var eid: String = String(rd.get("rules_epoch_id", ""))
		epoch_counts[eid] = int(epoch_counts.get(eid, 0)) + 1
		var fp: String = String(rd.get("rules_fingerprint", ""))
		if not fp.is_empty():
			fingerprint_counts[fp] = int(fingerprint_counts.get(fp, 0)) + 1
	return {
		"legacy_untagged": legacy,
		"epoch_counts": epoch_counts,
		"fingerprint_counts": fingerprint_counts,
		"is_mixed": epoch_counts.size() > 1 or (legacy > 0 and epoch_counts.size() > 0),
		"fingerprint_mismatch": fingerprint_counts.size() > 1,
	}
