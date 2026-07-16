extends SceneTree

func _init():
	print("--- TEST PREVIEW WITH RECIPE ---")
	var preview = CharacterPreview.new()
	preview._ready()
	
	var catalog = LpcCatalog.load_from_disk()
	var profile = CharacterGenProfile.new()
	# body_type is an enum/int in CharacterGenProfile? 
	# Let's just use roll() without touching body_type.
	
	var recipe = CharacterRoller.roll(catalog, profile)
	
	for i in range(preview._actors.size()):
		var actor = preview._actors[i]
		actor.apply_recipe(recipe)
		
	preview.set_action("walk")
	
	print("Actors length: ", preview._actors.size())
	for i in range(preview._actors.size()):
		var actor = preview._actors[i]
		var active_layers = 0
		for spr in actor._layers:
			if spr.visible:
				active_layers += 1
		print("Actor ", i, " visible: ", actor.visible, " pos: ", actor.position.x, " facing: ", actor._facing, " active_layers: ", active_layers)
	print("--- END TEST ---")
	quit()
