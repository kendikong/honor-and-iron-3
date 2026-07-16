class_name AITelemetryHUD
extends Window

var _tree: Tree
var _root: TreeItem

func _ready() -> void:
	title = "AI Telemetry & Debug HUD"
	size = Vector2(500, 600)
	min_size = Vector2(400, 300)
	visible = false
	close_requested.connect(func(): visible = false)
	
	_tree = Tree.new()
	_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree.columns = 2
	_tree.set_column_title(0, "Metric / Sub-Term")
	_tree.set_column_title(1, "Value")
	_tree.set_column_titles_visible(true)
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 120)
	
	add_child(_tree)
	
	if EventBus.has_user_signal("ai_telemetry_generated"):
		EventBus.ai_telemetry_generated.connect(_on_telemetry_generated)

func _on_telemetry_generated(telemetry: Dictionary) -> void:
	_tree.clear()
	_root = _tree.create_item()
	_tree.hide_root = true
	
	# LEVEL 0: Root Decision
	var lvl0 = _tree.create_item(_root)
	lvl0.set_text(0, "Chosen Team Vector")
	lvl0.set_text(1, "Score: %.2f" % telemetry.get("total", 0.0))
	lvl0.set_custom_color(0, Color.GOLD)
	lvl0.set_custom_color(1, Color.GOLD)
	
	if telemetry.has("actions"):
		var act_node = _tree.create_item(lvl0)
		act_node.set_text(0, "Actions (%d)" % telemetry.actions.size())
		for act in telemetry.actions:
			var act_i = _tree.create_item(act_node)
			if act.type == GameEnums.ActionType.MOVE:
				act_i.set_text(0, "Move to %s" % str(act.target_coord))
			else:
				var aname = act.ability.display_name if (act.ability and "display_name" in act.ability) else "Ability"
				act_i.set_text(0, "Use %s on Target %d" % [aname, act.target_unit_id])
			
	# LEVEL 1: Dynamic Context (Mood)
	if telemetry.has("context"):
		var ctx = telemetry.context
		var lvl1 = _tree.create_item(_root)
		lvl1.set_text(0, "Level 1: Dynamic Context (Mood)")
		lvl1.set_custom_color(0, Color.LIGHT_BLUE)
		
		var a = _tree.create_item(lvl1)
		a.set_text(0, "Aggression Slider (A)")
		a.set_text(1, "%.2f" % ctx.get("aggression", 0.0))
		
		var w_l = _tree.create_item(lvl1)
		w_l.set_text(0, "w_lethality")
		w_l.set_text(1, "%.2f" % ctx.get("w_lethality", 1.0))
		
		var w_s = _tree.create_item(lvl1)
		w_s.set_text(0, "w_survivability")
		w_s.set_text(1, "%.2f" % ctx.get("w_survivability", 1.0))
		
		var w_p = _tree.create_item(lvl1)
		w_p.set_text(0, "w_position")
		w_p.set_text(1, "%.2f" % ctx.get("w_position", 1.0))
		
	# LEVEL 2, 3, 4: Objective Metric Breakdown
	var leth = telemetry.get("lethality", {})
	var surv = telemetry.get("survivability", {})
	var pos = telemetry.get("position", {})
	var pot = telemetry.get("potential", {})
	var pens = telemetry.get("penalties", {})
	
	var ctx = telemetry.get("context", {})
	var w_leth = ctx.get("w_lethality", 1.0)
	var w_surv = ctx.get("w_survivability", 1.0)
	var w_pos = ctx.get("w_position", 1.0)
	
	# Metric A: Lethality
	var n_leth = _tree.create_item(_root)
	n_leth.set_text(0, "Metric A: Lethality (x%.2f)" % w_leth)
	n_leth.set_text(1, "%.2f" % (leth.get("total", 0.0) * w_leth))
	n_leth.set_tooltip_text(0, "Base Sum: %.2f | Final Sum: %.2f" % [leth.get("b_sum", 0.0), leth.get("f_sum", 0.0)])
	
	if leth.has("enemies"):
		for en in leth.enemies:
			var n_en = _tree.create_item(n_leth)
			n_en.set_text(0, "Enemy ID %d (%s)" % [en.id, en.class])
			n_en.set_text(1, "Δ %.2f" % en.delta)
			var tt = "Base (Eff HP: %.1f | Threat: %.2f | Exec: %.2f = %.1f)\n" % [en.b_eff, en.b_threat, en.b_exec, en.b_tot]
			tt += "Final (Eff HP: %.1f | Threat: %.2f | Exec: %.2f = %.1f)" % [en.f_eff, en.f_threat, en.f_exec, en.f_tot]
			n_en.set_tooltip_text(0, tt)
			
	# Metric B: Survivability
	var n_surv = _tree.create_item(_root)
	n_surv.set_text(0, "Metric B: Survivability (x%.2f)" % w_surv)
	n_surv.set_text(1, "%.2f" % (surv.get("total", 0.0) * w_surv))
	n_surv.set_tooltip_text(0, "Base Sum: %.2f | Final Sum: %.2f" % [surv.get("b_sum", 0.0), surv.get("f_sum", 0.0)])
	
	if surv.has("allies"):
		for al in surv.allies:
			var n_al = _tree.create_item(n_surv)
			n_al.set_text(0, "Ally ID %d (%s)" % [al.id, al.class])
			n_al.set_text(1, "Δ %.2f" % al.delta)
			var tt = "Base (Val: %.1f | Inc Dmg: %.1f | Post: %.1f)\n" % [al.b_val, al.b_inc, al.b_post]
			tt += "Final (Val: %.1f | Inc Dmg: %.1f | Post: %.1f)" % [al.f_val, al.f_inc, al.f_post]
			if al.f_death_pen: tt += "\nDEATH PENALTY APPLIED!"
			n_al.set_tooltip_text(0, tt)
			
	# Metric C: Positioning
	var n_pos = _tree.create_item(_root)
	n_pos.set_text(0, "Metric C: Positioning (x%.2f)" % w_pos)
	n_pos.set_text(1, "%.2f" % (pos.get("total", 0.0) * w_pos))
	
	var c_coh = _tree.create_item(n_pos)
	c_coh.set_text(0, "Cohesion Penalty")
	c_coh.set_text(1, "%.2f" % pos.get("cohesion_tot", 0.0))
	if pos.has("cohesion_data"):
		var tt = ""
		for cd in pos.cohesion_data:
			tt += "ID %d: Blend %.2f%s\n" % [cd.id, cd.blend, " (ISOLATED)" if cd.is_iso else ""]
		c_coh.set_tooltip_text(0, tt.strip_edges())
		
	var c_ter = _tree.create_item(n_pos)
	c_ter.set_text(0, "Terrain / Hazards")
	c_ter.set_text(1, "%.2f" % pos.get("terrain_tot", 0.0))
	
	var c_sw = _tree.create_item(n_pos)
	c_sw.set_text(0, "Sweet Spot Bonus")
	c_sw.set_text(1, "%.2f" % pos.get("sweet_tot", 0.0))
	
	var c_item = _tree.create_item(n_pos)
	c_item.set_text(0, "Item Magnetism")
	c_item.set_text(1, "%.2f" % pos.get("item_tot", 0.0))
	
	# Metric D: Potential
	var n_pot = _tree.create_item(_root)
	n_pot.set_text(0, "Metric D: Potential (x1.00)")
	n_pot.set_text(1, "%.2f" % pot.get("total", 0.0))
	
	var p_st = _tree.create_item(n_pot)
	p_st.set_text(0, "Persistent Statuses")
	p_st.set_text(1, "%.2f" % pot.get("stat_tot", 0.0))
	
	var p_co = _tree.create_item(n_pot)
	p_co.set_text(0, "Constructs")
	p_co.set_text(1, "%.2f" % pot.get("construct_tot", 0.0))

	var p_res = _tree.create_item(n_pot)
	p_res.set_text(0, "Resource Gen")
	p_res.set_text(1, "%.2f" % pot.get("resource_tot", 0.0))
	
	# Penalties
	var n_pen = _tree.create_item(_root)
	n_pen.set_text(0, "Action Penalties")
	n_pen.set_text(1, "-%.2f" % pens.get("total", 0.0))
	n_pen.set_custom_color(0, Color.ORANGE_RED)
	n_pen.set_custom_color(1, Color.ORANGE_RED)
	
	var pen_ap = _tree.create_item(n_pen)
	pen_ap.set_text(0, "AP Tax")
	pen_ap.set_text(1, "-%.2f" % pens.get("ap_tax", 0.0))
	
	var pen_mov = _tree.create_item(n_pen)
	pen_mov.set_text(0, "MOV Tax")
	pen_mov.set_text(1, "-%.2f" % pens.get("mov_tax", 0.0))
	
	var pen_disp = _tree.create_item(n_pen)
	pen_disp.set_text(0, "Displacement Loop")
	pen_disp.set_text(1, "-%.2f" % pens.get("disp_pen", 0.0))

	var pen_lim = _tree.create_item(n_pen)
	pen_lim.set_text(0, "Limited Use Tax")
	pen_lim.set_text(1, "-%.2f" % pens.get("limited_use_tax", 0.0))
	
	# Level 5 attribution info (Extracted from telemetry attribution)
	var lvl5 = _tree.create_item(_root)
	lvl5.set_text(0, "Level 5: Per-Actor Contribution")
	lvl5.set_custom_color(0, Color.WEB_GRAY)
	
	var attr = telemetry.get("attribution", {})
	for a_id in attr.keys():
		var ad = attr[a_id]
		var act_i = _tree.create_item(lvl5)
		act_i.set_text(0, "Actor ID %d" % a_id)
		
		var stats_str = "Dmg: %.1f | Heal: %.1f | Mv: %d" % [ad.get("dmg_dealt", 0), ad.get("heal_shield", 0), ad.get("moved", 0)]
		act_i.set_text(1, stats_str)
			
	visible = true
