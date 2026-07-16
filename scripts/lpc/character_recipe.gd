class_name CharacterRecipe
extends RefCounted

## Rolled LPC layer picks — one item per type_name slot.

var body_type: String = "male"
var selections: Dictionary = {}  # type_name -> { id, z_pos, path_prefix, recolor_kind, recolor, variant, palette_base? }


func duplicate_recipe() -> CharacterRecipe:
	var copy: CharacterRecipe = CharacterRecipe.new()
	copy.body_type = body_type
	copy.selections = selections.duplicate(true)
	return copy
