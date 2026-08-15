class_name CharacterRoller
extends RefCounted

## Seeded weighted random picks from LpcCatalog + CharacterGenProfile.


static func _is_naked_colored(cloth: String, skin: String) -> bool:
	if cloth == skin:
		return true
	var dark_skins = ["brown", "bronze", "amber", "taupe"]
	var brown_cloth = ["brown", "leather"]
	if skin in dark_skins and cloth in brown_cloth:
		return true
	if skin == "light" and cloth == "white":
		return true
	if skin in ["zombie", "green"] and cloth == "green":
		return true
	if skin == "blue" and cloth in ["blue", "navy"]:
		return true
	if skin == "black" and cloth == "black":
		return true
	return false


static func roll(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	seed: int = -1,
	class_id: String = "",
) -> CharacterRecipe:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed < 0:
		seed = profile.seed
	rng.seed = seed
	var recipe: CharacterRecipe = CharacterRecipe.new()
	recipe.body_type = _pick_body_type(catalog, profile, rng)
	
	var implied_gender: String = "neutral"
	var m_w: float = float(profile.body_type_weights.get("male", 1.0))
	var f_w: float = float(profile.body_type_weights.get("female", 1.0))
	if recipe.body_type == "male" or recipe.body_type == "muscular":
		implied_gender = "male"
	elif recipe.body_type == "female" or recipe.body_type == "pregnant":
		implied_gender = "female"
	else:
		if m_w > 0 and f_w <= 0:
			implied_gender = "male"
		elif f_w > 0 and m_w <= 0:
			implied_gender = "female"
		elif m_w <= 0 and f_w <= 0:
			implied_gender = "neutral"
		else:
			implied_gender = "male" if rng.randf() < (m_w / (m_w + f_w)) else "female"
			
	var skin: String = _pick_recolor(catalog.skin_recolors, rng, profile, "skin")
	var hair_color: String = _pick_recolor(catalog.hair_recolors, rng, profile, "hair")
	var primary_cloth_color: String = _pick_recolor(catalog.cloth_recolors, rng, profile, "cloth")
	var p_attempts = 0
	while _is_naked_colored(primary_cloth_color, skin) and p_attempts < 15:
		primary_cloth_color = _pick_recolor(catalog.cloth_recolors, rng, profile, "cloth")
		p_attempts += 1
		
	var hair_ext_chance: float = profile.slot_fill_chance("hairextl", catalog.default_fill_chance("hairextl"))
	var want_hair_ext: bool = rng.randf() < hair_ext_chance
	var picked_hair_ext: String = ""
	
	for type_name: String in catalog.slot_names():
		var should_fill: bool = false
		if type_name == "hairextl" or type_name == "hairextr":
			should_fill = want_hair_ext and (rng.randf() < 0.99)
		elif type_name == "shoes_toe":
			should_fill = _should_fill_slot(catalog, profile, type_name, rng, class_id)
			if should_fill:
				var has_boots: bool = false
				if recipe.selections.has("shoes"):
					var shoe_id: String = recipe.selections["shoes"]["id"]
					if "boots" in shoe_id or "armour" in shoe_id:
						has_boots = true
				if not has_boots:
					should_fill = false
		else:
			should_fill = _should_fill_slot(catalog, profile, type_name, rng, class_id)
			
		if not should_fill:
			continue
			
		var item: Dictionary = {}
		var forced_item_id: String = (
			profile.class_forced_item(class_id, type_name) if not class_id.is_empty() else ""
		)
		if not forced_item_id.is_empty():
			var found: Dictionary = catalog.find_item(forced_item_id)
			if not found.is_empty():
				item = found["item"] as Dictionary
			else:
				push_warning(
					"LPC class loadout: missing item '%s' for class '%s' slot '%s'"
					% [forced_item_id, class_id, type_name]
				)
		elif type_name == "hairextr" and picked_hair_ext != "":
			var target_id: String = picked_hair_ext.substr(0, picked_hair_ext.length() - 1) + "r"
			for raw: Variant in catalog.items_for_slot("hairextr"):
				if typeof(raw) == TYPE_DICTIONARY and str(raw.get("id", "")) == target_id:
					if LpcPath.item_supports_body(raw as Dictionary, recipe.body_type):
						item = raw as Dictionary
					break
			if item.is_empty():
				item = _pick_item(catalog, profile, type_name, recipe.body_type, implied_gender, rng)
		else:
			item = _pick_item(catalog, profile, type_name, recipe.body_type, implied_gender, rng)
			
		if type_name == "hairextl" and not item.is_empty():
			picked_hair_ext = str(item.get("id", ""))
			
		if item.is_empty():
			if catalog.is_required_slot(type_name):
				push_warning(
					"LPC roll: no compatible item for required slot '%s' (body=%s)"
					% [type_name, recipe.body_type]
				)
			continue
		var selection: Dictionary = _build_selection_entry(
			catalog,
			profile,
			item,
			type_name,
			recipe.body_type,
			skin,
			hair_color,
			primary_cloth_color,
			rng,
		)
		if selection.is_empty():
			if catalog.is_required_slot(type_name):
				push_warning(
					"LPC roll: item '%s' has no sprite path for body=%s (slot=%s)"
					% [str(item.get("id", "")), recipe.body_type, type_name]
				)
			continue
		recipe.selections[type_name] = selection
		
	# --- Cleanup / Validation Pass ---
	var tag_counts: Dictionary = {}
	
	# Helper lambda to extract tags for a single item dict
	var extract_tags = func(sel: Dictionary, slot_name: String) -> Dictionary:
		var out := {}
		out[slot_name] = true
		var t_list: Variant = sel.get("tags", [])
		if typeof(t_list) == TYPE_ARRAY:
			for t: Variant in t_list:
				out[str(t)] = true
		var id_str: String = str(sel.get("id", ""))
		var id_words := id_str.split("_")
		for word in id_words:
			var clean := word.strip_edges()
			if not clean.is_empty():
				out[clean] = true
		return out
		
	# 1. Collect all tags and their counts
	for slot: String in recipe.selections.keys():
		var sel: Dictionary = recipe.selections[slot]
		var tags: Dictionary = extract_tags.call(sel, slot) as Dictionary
		for t in tags.keys():
			tag_counts[t] = tag_counts.get(t, 0) + 1
			
	# 2. Remove items whose requirements are not met (Cascading)
	var removed_any := true
	while removed_any:
		removed_any = false
		var invalid_slots: Array[String] = []
		
		for slot: String in recipe.selections.keys():
			var sel: Dictionary = recipe.selections[slot]
			
			# Check requirements
			var reqs: Variant = sel.get("requires_tags", [])
			if typeof(reqs) == TYPE_ARRAY and not reqs.is_empty():
				var my_tags: Dictionary = extract_tags.call(sel, slot) as Dictionary
				var valid: bool = true
				for r: Variant in reqs:
					var str_r = str(r)
					var available: int = tag_counts.get(str_r, 0)
					if my_tags.has(str_r):
						available -= 1 # Do not count ourselves!
					if available <= 0:
						valid = false
						break
				if not valid and not invalid_slots.has(slot):
					invalid_slots.append(slot)
					
			# Check exclusions
			var excludes: Variant = sel.get("excludes_tags", [])
			if typeof(excludes) == TYPE_ARRAY and not excludes.is_empty():
				for ex: Variant in excludes:
					var str_ex = str(ex)
					for slot2: String in recipe.selections.keys():
						if slot == slot2 or invalid_slots.has(slot2): continue
						var sel2: Dictionary = recipe.selections[slot2]
						var my_tags2: Dictionary = extract_tags.call(sel2, slot2) as Dictionary
						if my_tags2.has(str_ex):
							invalid_slots.append(slot2)
					
		for slot: String in invalid_slots:
			var sel: Dictionary = recipe.selections[slot]
			var my_tags: Dictionary = extract_tags.call(sel, slot) as Dictionary
			for t in my_tags.keys():
				tag_counts[t] -= 1 # Remove our tags from the global pool
			recipe.selections.erase(slot)
			removed_any = true
		
	# 4. Exclusions / Hiding
	if tag_counts.get("helmet", 0) > 0:
		recipe.selections.erase("hair")
		recipe.selections.erase("hairextl")
		recipe.selections.erase("hairextr")

	_apply_class_forced_items(
		catalog,
		profile,
		class_id,
		recipe,
		skin,
		hair_color,
		primary_cloth_color,
		rng,
	)
		
	_warn_missing_required_slots(catalog, recipe, seed)
	if not recipe.selections.has("head"):
		push_warning(
			"LPC roll: no head in recipe (body=%s seed=%d) — face will be invisible"
			% [recipe.body_type, seed]
		)
	return recipe


static func _warn_missing_required_slots(
	catalog: LpcCatalog,
	recipe: CharacterRecipe,
	seed: int,
) -> void:
	for type_name: String in catalog.slot_names():
		if not catalog.is_required_slot(type_name):
			continue
		if recipe.selections.has(type_name):
			continue
		push_warning(
			"LPC roll missing required slot '%s' (body=%s seed=%d)"
			% [type_name, recipe.body_type, seed]
		)


static func _pick_body_type(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	rng: RandomNumberGenerator,
) -> String:
	var pool: PackedStringArray = catalog.body_types
	if pool.is_empty():
		pool = LpcConstants.BODY_TYPES
	var total: float = 0.0
	for bt: String in pool:
		total += float(profile.body_type_weights.get(bt, 1.0))
	var roll: float = rng.randf() * total
	for bt: String in pool:
		roll -= float(profile.body_type_weights.get(bt, 1.0))
		if roll <= 0.0:
			return bt
	return pool[0]


static func _should_fill_slot(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	type_name: String,
	rng: RandomNumberGenerator,
	class_id: String = "",
) -> bool:
	if not class_id.is_empty():
		var forced_id: String = profile.class_forced_item(class_id, type_name)
		if not forced_id.is_empty():
			var forced_chance: float = profile.class_slot_fill_chance(class_id, type_name, 1.0)
			return rng.randf() < forced_chance
	if catalog.is_required_slot(type_name):
		return true
	var default_chance: float = catalog.default_fill_chance(type_name)
	var chance: float = profile.slot_fill_chance(type_name, default_chance)
	if not class_id.is_empty():
		chance = profile.class_slot_fill_chance(class_id, type_name, chance)
	return rng.randf() < chance


static func _build_selection_entry(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	item: Dictionary,
	type_name: String,
	body_type: String,
	skin: String,
	hair_color: String,
	primary_cloth_color: String,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var prefix: String = LpcPath.path_prefix_for_item(item, body_type)
	if prefix == "":
		return {}
	var bg_prefix: String = LpcPath.path_prefix_for_bg_item(item, body_type)
	var recolor_kind: String = str(item.get("recolor_kind", "none"))
	var recolor: String = ""
	var variant: String = ""
	var variants: Variant = item.get("variants", [])
	if recolor_kind == "skin" or bool(item.get("match_body_color", false)):
		recolor = skin
	elif recolor_kind == "hair":
		recolor = hair_color
	elif recolor_kind == "cloth":
		if type_name == "clothes" or type_name == "sleeves":
			recolor = primary_cloth_color
		else:
			recolor = _pick_recolor(catalog.cloth_recolors, rng, profile, "cloth")
			var c_attempts: int = 0
			while _is_naked_colored(recolor, skin) and c_attempts < 15:
				recolor = _pick_recolor(catalog.cloth_recolors, rng, profile, "cloth")
				c_attempts += 1
	elif typeof(variants) == TYPE_ARRAY and not variants.is_empty():
		variant = str(variants[rng.randi_range(0, variants.size() - 1)])
	return {
		"id": str(item.get("id", "")),
		"z_pos": int(item.get("z_pos", 0)),
		"path_prefix": prefix,
		"bg_path_prefix": bg_prefix,
		"recolor_kind": recolor_kind,
		"recolor": recolor,
		"variant": variant,
		"palette_base": str(item.get("palette_base", "")),
		"tags": item.get("tags", []),
		"requires_tags": item.get("requires_tags", []),
		"excludes_tags": item.get("excludes_tags", []),
	}


static func _apply_class_forced_items(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	class_id: String,
	recipe: CharacterRecipe,
	skin: String,
	hair_color: String,
	primary_cloth_color: String,
	rng: RandomNumberGenerator,
) -> void:
	if class_id.is_empty():
		return
	var loadout: Dictionary = profile.class_loadout(class_id)
	var forced: Variant = loadout.get("forced_items", {})
	if typeof(forced) != TYPE_DICTIONARY:
		return
	for slot_name: Variant in forced.keys():
		var item_id: String = str(forced[slot_name])
		if item_id.is_empty():
			continue
		var found: Dictionary = catalog.find_item(item_id)
		if found.is_empty():
			push_warning(
				"LPC class loadout: cannot apply missing item '%s' for class '%s'"
				% [item_id, class_id]
			)
			continue
		var slot: String = str(found.get("slot", slot_name))
		var fill_chance: float = profile.class_slot_fill_chance(class_id, str(slot_name), 1.0)
		## Optional flavor (fill < 1) only re-asserts if the roll already kept it.
		if fill_chance < 1.0 and not recipe.selections.has(slot):
			continue
		var item: Dictionary = found["item"] as Dictionary
		var selection: Dictionary = _build_selection_entry(
			catalog,
			profile,
			item,
			slot,
			recipe.body_type,
			skin,
			hair_color,
			primary_cloth_color,
			rng,
		)
		if selection.is_empty():
			push_warning(
				"LPC class loadout: item '%s' incompatible with body=%s for class '%s'"
				% [item_id, recipe.body_type, class_id]
			)
			continue
		recipe.selections[slot] = selection


static func _pick_item(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	type_name: String,
	body_type: String,
	implied_gender: String,
	rng: RandomNumberGenerator,
) -> Dictionary:
	return CharacterWeightManager.pick_item(catalog, profile, type_name, body_type, implied_gender, rng)



static func _pick_recolor(pool: PackedStringArray, rng: RandomNumberGenerator, profile: CharacterGenProfile, prefix: String) -> String:
	if pool.is_empty():
		return ""
		
	var weights: Array[float] = []
	var total: float = 0.0
	for r in pool:
		var w: float = profile.item_weights.get(prefix + ":" + r, 1.0)
		weights.append(w)
		total += w
		
	if total <= 0.0:
		# Fall back to uniform if all colors are banned, or maybe just return the first one?
		# Returning uniform random here since recolors are usually required.
		return pool[rng.randi_range(0, pool.size() - 1)]
		
	var roll: float = rng.randf() * total
	for i in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[-1]
