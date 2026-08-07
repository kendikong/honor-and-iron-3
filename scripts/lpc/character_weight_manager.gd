class_name CharacterWeightManager
extends RefCounted

## Provides weightedâ€‘random selection based on userâ€‘defined slot and item weights.

static func get_weight(item_id: String, slot_name: String, profile: CharacterGenProfile) -> float:
	var slot_w: float = profile.slot_weights.get(slot_name, 1.0)
	var item_w: float = profile.item_weights.get(item_id, 1.0)
	return clamp(slot_w * item_w, 0.0, 1.0)


static func pick_item(
	catalog: LpcCatalog,
	profile: CharacterGenProfile,
	slot_name: String,
	body_type: String,
	implied_gender: String,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var items: Array = catalog.items_for_slot(slot_name)
	var compatible: Array = []
	var weights: Array = []
	for raw: Variant in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var item_id: String = str(item.get("id", ""))
		
		var user_tag: String = str(profile.item_gender_tags.get(item_id, "neutral"))
		if user_tag == "female" and implied_gender == "male":
			continue
		if user_tag == "male" and implied_gender == "female":
			continue
		
		if not profile.allow_non_human_parts:
			var reqs: Variant = item.get("required_body_types", [])
			var is_strictly_non_human: bool = false
			if typeof(reqs) == TYPE_ARRAY:
				if reqs.has("non-human") and not reqs.has("human"):
					is_strictly_non_human = true
					
			if is_strictly_non_human:
				continue
				
			if slot_name == "head" and "human" not in item_id:
				continue
				
		if LpcPath.item_supports_body(item, body_type):
			var has_required: bool = true
			var prefix = LpcPath.path_prefix_for_item(item, body_type)
			var test_variant: String = ""
			var variants: Variant = item.get("variants", [])
			if typeof(variants) == TYPE_ARRAY and not variants.is_empty():
				test_variant = str(variants[0])
			var is_held_item = slot_name in [
				"weapon", "weapon_magic_crystal", "shield", "shield_paint", "shield_pattern", "shield_trim"
			]
			
			if not is_held_item:
				for req_anim in profile.required_animations:
					var p = LpcPath.sheet_png(prefix, str(req_anim), "", test_variant)
					if not FileAccess.file_exists(p):
						has_required = false
						break
					
			if has_required:
				compatible.append(item)
				var w: float = get_weight(item_id, slot_name, profile)
				weights.append(w)

	if compatible.is_empty():
		return {}

	# Weighted pick among compatible items.
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		# All weights zeroed â€” return empty (user explicitly excluded all compatible items).
		return {}
	var roll: float = rng.randf() * total
	for i: int in range(compatible.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return compatible[i]
	return compatible[-1]
