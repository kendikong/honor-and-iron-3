class_name CompendiumScreen
extends Control

var _selected_unit: UnitData
var overlay_mode: bool = false

func _ready() -> void:
	# Clear placeholder
	if has_node("PlaceholderLabel"):
		$PlaceholderLabel.queue_free()
		
	$BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)
	_build_layout()
	
	if DataLibrary.get_all_player_units().size() > 0:
		_select_unit(DataLibrary.get_all_player_units()[0])

func _on_back_pressed() -> void:
	if overlay_mode:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _build_layout() -> void:
	var split := HSplitContainer.new()
	split.anchor_right = 1.0
	split.anchor_bottom = 1.0
	split.offset_top = 120 # Below title
	split.offset_bottom = -40
	split.offset_left = 40
	split.offset_right = -40
	add_child(split)
	
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(300, 0)
	split.add_child(sidebar)
	
	var scroll := ScrollContainer.new()
	sidebar.add_child(scroll)
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	_add_header(list, "Reference")
	_add_nav_button(list, "Glossary", _select_glossary)
	_add_nav_button(list, "Formulas", _select_formulas)
	
	_add_header(list, "Player Classes")
	for u in DataLibrary.get_all_player_units():
		_add_unit_button(list, u)
		
	_add_header(list, "Enemy Archetypes")
	for u in DataLibrary.get_all_enemy_units():
		_add_unit_button(list, u)
		
	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)
	
	var d_scroll := ScrollContainer.new()
	detail_panel.add_child(d_scroll)
	
	var d_vbox := VBoxContainer.new()
	d_vbox.name = "DetailVBox"
	d_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_vbox.add_theme_constant_override("separation", 20)
	d_scroll.add_child(d_vbox)

func _add_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

func _add_nav_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _add_unit_button(parent: Control, unit: UnitData) -> void:
	var btn := Button.new()
	btn.text = unit.display_name
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): _select_unit(unit))
	parent.add_child(btn)

func _clear_detail() -> VBoxContainer:
	var vbox: VBoxContainer = find_child("DetailVBox", true, false)
	if vbox:
		for c in vbox.get_children():
			c.queue_free()
	return vbox

func _add_detail_title(vbox: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

func _add_detail_subtitle(vbox: VBoxContainer, text: String) -> void:
	var subtitle := Label.new()
	subtitle.text = text
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.modulate = Color(0.75, 0.8, 0.9)
	vbox.add_child(subtitle)

func _add_glossary_entry(vbox: VBoxContainer, keyword: String, definition: String) -> void:
	var box := PanelContainer.new()
	vbox.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var name_lbl := RichTextLabel.new()
	name_lbl.bbcode_enabled = true
	name_lbl.fit_content = true
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.text = _kw(keyword)
	row.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = definition
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.modulate = Color(0.85, 0.85, 0.85)
	row.add_child(desc_lbl)

func _add_formula_entry(vbox: VBoxContainer, name: String, formula: String) -> void:
	var box := PanelContainer.new()
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	box.add_child(inner)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.modulate = Color(0.9, 0.95, 1.0)
	inner.add_child(name_lbl)
	var formula_lbl := Label.new()
	formula_lbl.text = formula
	formula_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formula_lbl.modulate = Color(0.75, 0.8, 0.75)
	inner.add_child(formula_lbl)

func _get_manual_keywords() -> Dictionary:
	return {
		"AOE ATK": "Deals damage to all units within the target shape.",
		"AOE": "Area effect — hits multiple tiles.",
		"AP": "Action Points consumed to use an ability.",
		"ATK": "Reduces target HP. Armor absorbs damage before HP.",
		"CLEANSE": "Removes all negative status effects from the target.",
		"COLLISION": "Damage dealt when displacement hits a wall or another unit.",
		"COUNTER ATTACK": "Retaliates against the attacker for listed ATK power, scaled by STR and weapon.",
		"DASH": "Moves in a straight line; may apply effects on each tile entered.",
		"DESTROY OBSTACLE": "Instantly removes a wall, trap, or destructible terrain.",
		"EXPLODE": "Deals damage to all units in adjacent cardinal tiles.",
		"HEAL": "Restores target HP, capped at Max HP.",
		"MOV": "Movement Points available per turn.",
		"MOVE": "Movement Points available per turn.",
		"PULL": "Displaces target towards caster. Collisions deal damage.",
		"PUSH": "Displaces target away from caster. Collisions deal damage.",
		"PURGE": "Removes all positive buffs and shields from the target.",
		"RANGE": "Maximum targeting or effect distance in tiles.",
		"SHIELD": "Grants temporary armor that absorbs damage before HP.",
		"SPAWN": "Creates a new unit on the target tile.",
		"SWAP": "Caster and target exchange tile positions.",
		"TELEPORT": "Moves instantly, ignoring pathing constraints.",
		"TRAMPLE": "Pass through enemy tiles; PUSH 1 when passing through or stopping on them.",
		"WPN": "Weapon Might — added to ability base power in the damage formula.",
		"DEF": "Defense — reduces incoming physical damage.",
		"STR": "Strength — increases physical attack power.",
		"MAG": "Magic — increases magical attack power and mitigates magical damage.",
	}

func _select_glossary() -> void:
	_selected_unit = null
	var vbox := _clear_detail()
	if vbox == null:
		return
	_add_detail_title(vbox, "Glossary")
	_add_detail_subtitle(vbox, "Keywords & Status Effects")
	var manual := _get_manual_keywords()
	var manual_keys: Array = manual.keys()
	manual_keys.sort()
	_add_detail_subtitle(vbox, "Effect Keywords & Stats")
	for k in manual_keys:
		_add_glossary_entry(vbox, String(k), manual[k])
	_add_detail_subtitle(vbox, "Status Effects")
	var status_keys: Array = GameEnums.StatusType.keys()
	status_keys.sort()
	for k in status_keys:
		if k == "NONE":
			continue
		var status_type: GameEnums.StatusType = GameEnums.StatusType[k]
		_add_glossary_entry(vbox, _get_status_name(status_type), _get_status_desc(status_type))

func _select_formulas() -> void:
	_selected_unit = null
	var vbox := _clear_detail()
	if vbox == null:
		return
	_add_detail_title(vbox, "Formulas")
	_add_detail_subtitle(vbox, "Core Stats")
	_add_formula_entry(vbox, "Max HP", "Max HP = CON × 5 (+ weapon HP bonus)")
	_add_detail_subtitle(vbox, "Damage")
	_add_formula_entry(
		vbox,
		"Physical / Magical ATK",
		"Raw = floor((Base + WPN) × (1 + STAT / 5))\nSTAT = STR for physical, MAG for magical."
	)
	_add_formula_entry(
		vbox,
		"Mitigation",
		"Physical attacks subtract target DEF.\nMagical attacks subtract target MAG.\nTile Fortitude is subtracted after DEF/MAG."
	)
	_add_formula_entry(
		vbox,
		"Incoming Damage",
		"Incoming = max(0, Raw − Mitigation − Fortitude)\nArmor absorbs Incoming before HP is reduced."
	)
	_add_formula_entry(vbox, "Backstab", "Raw + 2 when attacking from directly behind the target's facing.")
	_add_formula_entry(vbox, "Electrified", "Raw + 1 while the target has ELECTRIFIED.")
	_add_formula_entry(vbox, "Pierce", "Ignores DEF/MAG and Fortitude mitigation.")
	_add_formula_entry(vbox, "Weaken", "Reduces STR and MAG by 2 while active (lowers scaled ATK).")
	_add_formula_entry(
		vbox,
		"Collision Damage",
		"BASE = 1 + floor(excess_push / 3) + bonus\nRaw = floor(0.75 × (BASE + WPN) × (1 + STR / 5))\nexcess_push = push distance minus tiles actually moved."
	)
	_add_formula_entry(
		vbox,
		"Counter Attack",
		"Uses the Physical ATK formula with the listed ATK power as Base."
	)
	_add_detail_subtitle(vbox, "Healing")
	_add_formula_entry(vbox, "Flat Heal", "Restores the listed amount, capped at Max HP.")
	_add_formula_entry(
		vbox,
		"MAG-Scaled Heal",
		"floor((Base + WPN) × (1 + MAG / 5) × 0.20 + Max HP × 0.20)"
	)
	_add_formula_entry(vbox, "% Max HP Heal", "floor(Base × 0.1 × Max HP)")
	_add_formula_entry(vbox, "Poison Penalty", "Healing received is reduced by 50% (rounded down).")
	_add_detail_subtitle(vbox, "Shield (Armor)")
	_add_formula_entry(vbox, "Flat Shield", "Adds the listed amount to armor.")
	_add_formula_entry(vbox, "% Max HP Shield", "floor(Base × 0.1 × Max HP)")
	_add_formula_entry(vbox, "DEF Shield", "floor(Base + DEF)")
	_add_formula_entry(vbox, "Missing HP Shield", "floor(Base + (Max HP − Current HP))")
	_add_detail_subtitle(vbox, "Damage Over Time")
	_add_formula_entry(vbox, "Burn", "X unmitigated damage at start of turn (X = status value).")
	_add_formula_entry(vbox, "Poison", "ceil(Max HP × 10%) unmitigated damage at start of turn. Blocks healing.")
	_add_formula_entry(vbox, "Bleed", "X unmitigated damage whenever the unit moves (X = status value).")

func _select_unit(unit: UnitData) -> void:
	_selected_unit = unit
	var vbox := _clear_detail()
	if vbox == null:
		return
	
	# --- Title ---
	var title := Label.new()
	title.text = unit.display_name
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)
	
	# --- Core Stats ---
	var stats := Label.new()
	stats.text = "Level %d  |  HP: %d  |  Move: %d  |  AP: %d" % [unit.level, (unit.base_constitution * 5), unit.move_points, unit.action_points]
	stats.add_theme_font_size_override("font_size", 24)
	vbox.add_child(stats)
	
	# --- Combat Stats (STR / MAG / DEF) ---
	var combat_stats := Label.new()
	combat_stats.text = "STR: %d  |  MAG: %d  |  DEF: %d" % [unit.base_strength, unit.base_magic, unit.base_defense]
	combat_stats.add_theme_font_size_override("font_size", 22)
	combat_stats.modulate = Color(0.8, 0.9, 1.0)
	vbox.add_child(combat_stats)
	
	# --- Equipped Weapon ---
	var wpn_header := Label.new()
	wpn_header.text = "Equipment"
	wpn_header.add_theme_font_size_override("font_size", 32)
	vbox.add_child(wpn_header)
	
	if unit.equipped_weapon != null:
		var wpn_box := PanelContainer.new()
		vbox.add_child(wpn_box)
		var wpn_vbox := VBoxContainer.new()
		wpn_box.add_child(wpn_vbox)
		var wpn_name := Label.new()
		wpn_name.text = unit.equipped_weapon.display_name
		wpn_name.add_theme_font_size_override("font_size", 24)
		wpn_vbox.add_child(wpn_name)
		var bonuses: Array[String] = []
		if unit.equipped_weapon.bonus_strength != 0:
			bonuses.append("STR +%d" % unit.equipped_weapon.bonus_strength)
		if unit.equipped_weapon.bonus_magic != 0:
			bonuses.append("MAG +%d" % unit.equipped_weapon.bonus_magic)
		if unit.equipped_weapon.bonus_defense != 0:
			bonuses.append("DEF +%d" % unit.equipped_weapon.bonus_defense)
		if unit.equipped_weapon.bonus_max_hp != 0:
			bonuses.append("HP +%d" % unit.equipped_weapon.bonus_max_hp)
		if unit.equipped_weapon.bonus_move != 0:
			bonuses.append("MOV +%d" % unit.equipped_weapon.bonus_move)
		if bonuses.is_empty():
			bonuses.append("No stat bonuses")
		var wpn_stats := Label.new()
		wpn_stats.text = "  " + ", ".join(bonuses)
		wpn_stats.modulate = Color(0.7, 0.7, 0.7)
		wpn_vbox.add_child(wpn_stats)
	else:
		var no_wpn := Label.new()
		no_wpn.text = "None"
		vbox.add_child(no_wpn)
	
	# --- Passives ---
	var pas_header := Label.new()
	pas_header.text = "Passives"
	pas_header.add_theme_font_size_override("font_size", 32)
	vbox.add_child(pas_header)
	
	if unit.passives.is_empty():
		var no_pas := Label.new()
		no_pas.text = "None"
		vbox.add_child(no_pas)
	else:
		for pas in unit.passives:
			var pas_box := PanelContainer.new()
			vbox.add_child(pas_box)
			var pas_vbox := VBoxContainer.new()
			pas_box.add_child(pas_vbox)
			var pas_name := Label.new()
			pas_name.text = pas.display_name
			pas_name.add_theme_font_size_override("font_size", 24)
			pas_vbox.add_child(pas_name)
			var pas_desc := RichTextLabel.new()
			pas_desc.bbcode_enabled = true
			pas_desc.fit_content = true
			pas_desc.text = "  " + _parse_keywords(pas.description)
			pas_desc.modulate = Color(0.7, 0.85, 0.7)
			pas_vbox.add_child(pas_desc)
	
	# --- AI Behavior (enemies) ---
	if unit.behavior != null:
		var ai := Label.new()
		ai.text = "AI Strategy: " + String(unit.behavior.strategy)
		ai.modulate = Color(1.0, 0.5, 0.5)
		vbox.add_child(ai)
		if unit.behavior.attack != null:
			var atk_header := Label.new()
			atk_header.text = "Attack"
			atk_header.add_theme_font_size_override("font_size", 32)
			vbox.add_child(atk_header)
			_add_ability_panel(vbox, unit.behavior.attack)
	
	# --- Abilities ---
	var ab_header := Label.new()
	ab_header.text = "Abilities"
	ab_header.add_theme_font_size_override("font_size", 32)
	vbox.add_child(ab_header)
	
	if unit.abilities.is_empty():
		var none := Label.new()
		none.text = "None"
		vbox.add_child(none)
	
	for ab in unit.abilities:
		_add_ability_panel(vbox, ab)

func _add_ability_panel(parent: Control, ab: AbilityData) -> void:
	var a_box := PanelContainer.new()
	parent.add_child(a_box)
	
	var a_vbox := VBoxContainer.new()
	a_box.add_child(a_vbox)
	
	var scaling_text := ""
	match ab.scaling_stat:
		GameEnums.StatType.PHYSICAL: scaling_text = " [STR]"
		GameEnums.StatType.MAGICAL: scaling_text = " [MAG]"
	
	var a_title := RichTextLabel.new()
	a_title.bbcode_enabled = true
	a_title.fit_content = true
	a_title.text = "[font_size=24]%s ([hint=The maximum distance in tiles this ability can target.]Range[/hint]: %d, [hint=Action Points consumed by this ability.]AP[/hint]: %d)%s[/font_size]" % [ab.display_name, ab.range_tiles, ab.action_point_cost, scaling_text]
	a_vbox.add_child(a_title)
	
	for eff in ab.effects:
		var e_lbl := RichTextLabel.new()
		e_lbl.bbcode_enabled = true
		e_lbl.fit_content = true
		e_lbl.text = "  - " + _effect_to_string(eff)
		a_vbox.add_child(e_lbl)

func _get_status_desc(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.STURDY: return "Ignores the next displacement effect (push/pull)."
		GameEnums.StatusType.MARK: return "Next attack against this unit will Backstab."
		GameEnums.StatusType.INTERCEPT: return "Takes damage in place of adjacent allies."
		GameEnums.StatusType.STEALTH: return "Cannot be targeted by direct attacks."
		GameEnums.StatusType.PIERCE: return "Attacks ignore armor."
		GameEnums.StatusType.PACIFY: return "Cannot use attack abilities."
		GameEnums.StatusType.TAUNT: return "Forced to move towards and attack the taunter."
		GameEnums.StatusType.BURN: return "Takes 1 damage per turn. Spread to adjacent allies on contact."
		GameEnums.StatusType.ELECTRIFIED: return "Spreads damage to adjacent units."
		GameEnums.StatusType.POISON: return "Takes damage at end of turn. Cannot heal."
		GameEnums.StatusType.BLEED: return "Takes 1 damage whenever moving."
		GameEnums.StatusType.STUN: return "Cannot act or move."
		GameEnums.StatusType.STAGGER: return "Action Points (AP) reduced by 1 next turn."
		GameEnums.StatusType.INVULNERABLE: return "Cannot take damage."
		GameEnums.StatusType.WEAK_TRAP: return "Triggers a trap when stepped on."
		GameEnums.StatusType.WEAKEN: return "Deals less damage with physical attacks."
		GameEnums.StatusType.VULNERABLE: return "Takes additional damage from attacks."
		GameEnums.StatusType.SILENCE: return "Cannot use magical abilities."
		GameEnums.StatusType.BLIND: return "Attack range is severely reduced."
		GameEnums.StatusType.FEAR: return "Forced to run away from the source of fear."
		GameEnums.StatusType.ROOT: return "Cannot move."
		GameEnums.StatusType.CONFUSION: return "Abilities will target friendly units instead."
		GameEnums.StatusType.GHOST: return "Can move through other units and solid obstacles."
		GameEnums.StatusType.TRAMPLE: return "Move through enemies; PUSH 1 per enemy entered."
		GameEnums.StatusType.AIRBORNE: return "Ignores ground hazards and terrain effects."
		GameEnums.StatusType.CANTO: return "Can use remaining movement points after taking an action."
		GameEnums.StatusType.POLYMORPH: return "Transformed into a harmless creature, cannot act."
		GameEnums.StatusType.RETALIATION_PROTOCOL: return "Can strike targets anywhere on the map."
		GameEnums.StatusType.INDOMITABLE_WILL: return "Immune to displacement and debuffs."
		GameEnums.StatusType.THORNS: return "Reflects physical damage back to attacker."
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Defense is halved."
		GameEnums.StatusType.STAT_BUFF_STR: return "Increases Strength."
		GameEnums.StatusType.STAT_BUFF_MAG: return "Increases Magic."
		GameEnums.StatusType.STAT_BUFF_DEF: return "Increases Defense."
		GameEnums.StatusType.STAT_BUFF_MOV: return "Increases Movement."
		GameEnums.StatusType.STAT_DEBUFF_DEF: return "Decreases Defense."
		GameEnums.StatusType.STAT_DEBUFF_ACC: return "Decreases Accuracy."
		GameEnums.StatusType.STAT_DEBUFF_MOV: return "Decreases Movement."
	return "Status Effect"

func _get_status_name(t: GameEnums.StatusType) -> String:
	match t:
		GameEnums.StatusType.IRON_GRIP_DEBUFF: return "Iron Grip"
		GameEnums.StatusType.RETALIATION_PROTOCOL: return "Retaliation Protocol"
		GameEnums.StatusType.INDOMITABLE_WILL: return "Indomitable Will"
		GameEnums.StatusType.THORNS: return "Thorns"
		GameEnums.StatusType.STAT_BUFF_STR: return "STR UP"
		GameEnums.StatusType.STAT_BUFF_MAG: return "MAG UP"
		GameEnums.StatusType.STAT_BUFF_DEF: return "DEF UP"
		GameEnums.StatusType.STAT_BUFF_MOV: return "MOV UP"
		GameEnums.StatusType.STAT_BUFF_ACC: return "ACC UP"
		GameEnums.StatusType.STAT_DEBUFF_DEF: return "DEF DOWN"
		GameEnums.StatusType.STAT_DEBUFF_ACC: return "ACC DOWN"
		GameEnums.StatusType.STAT_DEBUFF_MOV: return "MOV DOWN"
	return GameEnums.StatusType.keys()[t].capitalize()

func _get_amount_string(eff: EffectData) -> String:
	var stat_str = ""
	if eff.scaling_stat != GameEnums.StatType.NONE:
		stat_str = "[%s]" % GameEnums.StatType.keys()[eff.scaling_stat]
	
	if eff.amount == 0 and stat_str != "":
		return stat_str
	elif eff.amount > 0 and stat_str != "":
		return "%d + %s" % [eff.amount, stat_str]
	else:
		return str(eff.amount)

func _kw(word: String) -> String:
	var icon := PlanningIcons.keyword_icon(word)
	if icon != "":
		return "[color=#FBBF24]%s %s[/color]" % [icon, word]
	return "[color=#FBBF24]%s[/color]" % word

func _effect_to_string(eff: EffectData) -> String:
	match eff.type:
		GameEnums.EffectType.DAMAGE: return "[hint=\"Reduces target's current HP. Resisted by Armor.\"]%s[/hint] %s" % [_kw("ATK"), _get_amount_string(eff)]
		GameEnums.EffectType.HEAL: return "[hint=\"Restores target's current HP.\"]%s[/hint] %s" % [_kw("HEAL"), _get_amount_string(eff)]
		GameEnums.EffectType.PUSH: return "[hint=\"Displaces target away from caster. Collisions deal damage.\"]%s[/hint] %s" % [_kw("PUSH"), _get_amount_string(eff)]
		GameEnums.EffectType.PULL: return "[hint=\"Displaces target towards caster. Collisions deal damage.\"]%s[/hint] %s" % [_kw("PULL"), _get_amount_string(eff)]
		GameEnums.EffectType.SWAP: return "[hint=\"Caster and target exchange tile positions.\"]%s[/hint]" % _kw("SWAP")
		GameEnums.EffectType.ARMOR_UP: return "[hint=\"Grants temporary hit points that absorb damage before HP.\"]%s[/hint] %s" % [_kw("SHIELD"), _get_amount_string(eff)]
		GameEnums.EffectType.EXPLODE: return "[hint=\"Deals damage to all units in the 4 adjacent cardinal tiles.\"]%s[/hint] %s" % [_kw("EXPLODE"), _get_amount_string(eff)]
		GameEnums.EffectType.RANGED_EXPLODE: return "[hint=\"Deals damage to all units within the target shape.\"]%s[/hint] %s" % [_kw("AOE ATK"), _get_amount_string(eff)]
		GameEnums.EffectType.SPAWN: return "[hint=\"Creates a new unit on the target tile.\"]%s[/hint] %s" % [_kw("SPAWN"), str(eff.spawn_unit_id).capitalize()]
		GameEnums.EffectType.ADD_STATUS: 
			var dur = "" if eff.status_duration == 1 else " (%d turns)" % eff.status_duration
			var hint = _get_status_desc(eff.status_type)
			var amount_str = _get_amount_string(eff)
			if amount_str != "0" and amount_str != "":
				match eff.status_type:
					GameEnums.StatusType.STAT_BUFF_STR: hint = "Increases Strength (STR) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_MAG: hint = "Increases Magic (MAG) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_DEF: hint = "Increases Defense (DEF) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_MOV: hint = "Increases Movement Points (MP) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_ACC: hint = "Increases Accuracy (ACC) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_DEF: hint = "Decreases Defense (DEF) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_MOV: hint = "Decreases Movement Points (MP) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_ACC: hint = "Decreases Accuracy (ACC) by %s." % amount_str
			return "Apply [hint=\"%s\"]%s[/hint]%s" % [hint, _kw(_get_status_name(eff.status_type)), dur]
		GameEnums.EffectType.ADD_STATUS_SELF:
			var dur = "" if eff.status_duration == 1 else " (%d turns)" % eff.status_duration
			var hint = _get_status_desc(eff.status_type)
			var amount_str = _get_amount_string(eff)
			if amount_str != "0" and amount_str != "":
				match eff.status_type:
					GameEnums.StatusType.STAT_BUFF_STR: hint = "Increases Strength (STR) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_MAG: hint = "Increases Magic (MAG) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_DEF: hint = "Increases Defense (DEF) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_MOV: hint = "Increases Movement Points (MP) by %s." % amount_str
					GameEnums.StatusType.STAT_BUFF_ACC: hint = "Increases Accuracy (ACC) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_DEF: hint = "Decreases Defense (DEF) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_MOV: hint = "Decreases Movement Points (MP) by %s." % amount_str
					GameEnums.StatusType.STAT_DEBUFF_ACC: hint = "Decreases Accuracy (ACC) by %s." % amount_str
			return "Self [hint=\"%s\"]%s[/hint]%s" % [hint, _kw(_get_status_name(eff.status_type)), dur]
		GameEnums.EffectType.DAMAGE_SELF: return "Self [hint=\"Ignores Armor and deals direct damage to caster.\"]%s[/hint] %s" % [_kw("ATK"), _get_amount_string(eff)]
		GameEnums.EffectType.CLEANSE: return "[hint=\"Removes all negative status effects from target.\"]%s[/hint]" % _kw("CLEANSE")
		GameEnums.EffectType.PURGE: return "[hint=\"Removes all positive buffs and shields from target.\"]%s[/hint]" % _kw("PURGE")
		GameEnums.EffectType.DASH: return "[hint=\"Caster moves in a straight line until blocked, applying effects to units collided with.\"]%s[/hint]" % _kw("DASH")
		GameEnums.EffectType.DESTROY_OBSTACLE: return "[hint=\"Instantly removes a wall, trap, or destructible terrain.\"]%s[/hint]" % _kw("DESTROY OBSTACLE")
		GameEnums.EffectType.TELEPORT_CASTER: return "[hint=\"Instantly moves caster to the target tile, ignoring pathing constraints.\"]%s[/hint]" % _kw("TELEPORT")
	return "Unknown Effect"

func _highlight_counter_attack_keywords(text: String) -> String:
	var rx := RegEx.new()
	if rx.compile("COUNTER ATTACK \\d+") != OK:
		return text
	var result := text
	var matches := rx.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var phrase := m.get_string()
		var hint := "Retaliates against the attacker for the listed ATK power (scaled by STR and weapon)."
		result = result.substr(0, m.get_start()) + "[hint=\"%s\"]%s[/hint]" % [hint, _kw(phrase)] + result.substr(m.get_end())
	return result

func _parse_keywords(text: String) -> String:
	var result = _highlight_counter_attack_keywords(text)
	var manual := _get_manual_keywords()
	var keys: Array = manual.keys()
	keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	for k in keys:
		result = result.replace(String(k), "[hint=\"%s\"]%s[/hint]" % [manual[k], _kw(String(k))])
	for k in GameEnums.StatusType.keys():
		if k == "NONE": continue
		var d = _get_status_desc(GameEnums.StatusType[k])
		result = result.replace(k, "[hint=\"%s\"]%s[/hint]" % [d, _kw(k)])
	return result
