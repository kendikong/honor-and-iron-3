extends SceneTree

const OUT := "res://reports/logs/debug_bash_hover_seal.txt"


func _initialize() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var host := Node.new()
	root.add_child(host)
	PlanningDragE2EHarness.set_host(host)
	lines.append("start")
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	var cell: Vector2i = PlanningChecklistHarness.ENEMY_POS
	PlanningChecklistHarness.hover(fix, cell)
	var input: CombatPlanningInput = fix.input
	var bundle: PlanningHoverPreview = input.get_settled_hover_preview()
	lines.append("bundle_null=%s" % str(bundle == null))
	if bundle != null:
		lines.append("valid=%s" % bundle.valid)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
	lines.append("slots_invalid=%s reason=%s" % [PlanningChecklistHarness.slots_invalid(slots), str(slots.get("invalid", ""))])
	var enemy_id: int = int(fix.enemy.id) if fix.get("enemy") != null else -1
	var params: Dictionary = input._commit_interaction_params(cell, enemy_id)
	var fin: Dictionary = input._final_commit_slots_for_interaction(
		1, params.cell, params.waypoints, params.legal_move_tiles, params.preferred, -1, true,
	)
	lines.append("finalize=%s" % str(fin.get("invalid", "ok")))
	var preview: Dictionary = input._preview_from_commit_slots_at_cell(
		1, cell, params.waypoints, params.legal_move_tiles, params.preferred, -1,
	)
	lines.append("preview_invalid=%s has_board=%s" % [str(preview.get("invalid", false)), str(preview.get("temp_board") != null)])
	bundle = input.get_settled_hover_preview()
	if bundle != null:
		lines.append("post_preview valid=%s" % bundle.valid)
	PlanningDragE2EHarness.cleanup_all()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for line: String in lines:
		if f != null:
			f.store_line(line)
	quit(0)
